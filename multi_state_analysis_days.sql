DROP TABLE IF EXISTS clustered_study;
CREATE TABLE clustered_study AS
SELECT *,
       CHAR(65 + SUM(is_new_cluster)
                     OVER (PARTITION BY patient ORDER BY JULIANDAY(charge) RANGE UNBOUNDED PRECEDING)) AS cluster_id
FROM (
         SELECT *, distance > 180 AS is_new_cluster
         FROM (
                  SELECT *,
                         JULIANDAY(charge) - LAG(JULIANDAY(charge), 1, JULIANDAY(charge))
                                                 OVER (PARTITION BY patient ORDER BY JULIANDAY(charge)) AS distance
                  FROM study
                  ORDER BY patient, charge))
;

DROP TABLE IF EXISTS first_admission_cluster;
CREATE TABLE first_admission_cluster AS
SELECT patient, cluster_id, charge
FROM clustered_study
WHERE status NOT IN ('Ärztliche Behandlung', 'Überweisungsfall')
GROUP BY patient, cluster_id;

-- delete lines after first admission per cluster
DELETE
FROM clustered_study
WHERE ROWID IN (
    SELECT cs.ROWID
    FROM clustered_study AS cs
             INNER JOIN first_admission_cluster fac
                        ON cs.patient = fac.patient
                            AND cs.cluster_id = fac.cluster_id
    WHERE cs.charge > fac.charge)
;
--
-- DROP TABLE IF EXISTS biggest_cluster;
-- CREATE TABLE biggest_cluster AS
-- SELECT patient, cluster_id, MAX(visits) AS visits
-- FROM (
--          SELECT patient, cluster_id, COUNT(*) AS visits
--          FROM clustered_study
--          GROUP BY patient, cluster_id)
-- GROUP BY patient
-- ;
--
-- -- keep only the biggest clusters of each patient
-- DELETE
-- FROM clustered_study
-- WHERE ROWID NOT IN (
--     SELECT cs.ROWID
--     FROM clustered_study AS cs
--              INNER JOIN biggest_cluster bc
--                         ON cs.patient = bc.patient
--                             AND cs.cluster_id == bc.cluster_id);

-- keep only the first cluster of each patient
DELETE
FROM clustered_study
WHERE cluster_id != 'A';


-- delete patients that have only a single visit (after cleaning the clusters)
DELETE
FROM clustered_study
WHERE ROWID IN (
    SELECT ROWID
    FROM clustered_study
    GROUP BY patient
    HAVING COUNT(*) = 1);

DROP TABLE IF EXISTS min_visit;
CREATE TABLE min_visit AS
SELECT id, patient, charge, JULIANDAY(charge) AS entry
FROM (
         SELECT id,
                patient,
                charge,
                ROW_NUMBER()
                    OVER (PARTITION BY patient ORDER BY charge) AS rn
         FROM clustered_study
         WHERE status IN ('Ärztliche Behandlung', 'Überweisungsfall')
           AND discharge = '') AS a
WHERE rn = 1
ORDER BY patient
;

DROP TABLE IF EXISTS admissions_days;
CREATE TABLE admissions_days AS
SELECT patient, charge, COUNT(*) AS admissions
FROM clustered_study
WHERE discharge != ''
GROUP BY patient, charge
ORDER BY patient, charge;

DROP TABLE IF EXISTS survival_days;
CREATE TABLE survival_days AS
SELECT s.id,
       s.patient,
       s.sex,
       s.age,
       JULIANDAY(s.charge) - m.entry AS entry,
       s.charge,
       s.year_quarter,
       s.provider
           != LAG(s.provider, 1, s.provider)
                  OVER (PARTITION BY s.patient ORDER BY s.charge) AND s.provider != 'check' AS provider_changed,
       COALESCE(SUM(a.admissions), 0) > 0 AS inpatient_stay,
       GROUP_CONCAT(DISTINCT SUBSTR(s.diagnose, 1, 3)) AS diagnoses,
       INSTR(GROUP_CONCAT(DISTINCT SUBSTR(s.diagnose, 0, 3)), 'F2') > 0
           OR INSTR(GROUP_CONCAT(DISTINCT SUBSTR(s.diagnose, 0, 4)), 'F31') > 0
           OR s.diagnose = 'F32.2'
           OR s.diagnose = 'F32.3'
           OR s.diagnose = 'F33.2'
           OR s.diagnose = 'F33.3' > 0 AS severe,
       MIN((s.provider
           != LAG(s.provider, 1, s.provider)
                  OVER (PARTITION BY s.patient ORDER BY s.charge)) + (COALESCE(a.admissions, 0) > 0) * 2,
           2) AS state,
       s.cluster_id
FROM clustered_study AS s
         INNER JOIN min_visit AS m
                    ON s.patient = m.patient
         LEFT JOIN admissions_days AS a
                   ON s.patient = a.patient
                       AND s.charge = a.charge
GROUP BY s.patient, s.charge
ORDER BY diagnoses DESC, s.patient, s.charge
-- LIMIT 100
;


DROP TABLE IF EXISTS survival_history_days;
CREATE TABLE survival_history_days AS
SELECT MIN(sh.id) AS id,
       sh.patient,
       sh.sex,
       sh.age,
       sh.year_quarter,
       sh.entry,
       sh.provider_changed,
       sh.inpatient_stay,
       GROUP_CONCAT(DISTINCT n.diagnose) AS diagnoses,
       GROUP_CONCAT(DISTINCT SUBSTR(n.diagnose, 1, 3)) AS main_diagnoses,
       (
           SELECT MAX(severe)
           FROM survival_days
           WHERE patient = sh.patient) AS severe,
       -- todo: calculate comorbidity
       sh.from_state,
       MAX(sh.state, sh.from_state) AS to_state
FROM (
         SELECT s.*,
                COALESCE(
                    (
                        SELECT MAX(sb.state)
                        FROM survival_days AS sb
                        WHERE s.patient = sb.patient
                          AND sb.entry < s.entry),
                    0
                ) AS from_state
         FROM survival_days AS s
         ORDER BY s.patient, s.charge) AS sh
         INNER JOIN clustered_study AS n
                    ON n.patient = sh.patient
                        AND n.charge = sh.charge
GROUP BY sh.patient, sh.charge
ORDER BY sh.patient, sh.charge;

-- aux table to turn last final state 1 into 99
DROP TABLE IF EXISTS max_start_days;
CREATE TABLE max_start_days AS
SELECT patient, MAX(entry) AS mstart
FROM survival_history_days
WHERE patient IN (
    SELECT patient
    FROM (
             SELECT patient, MAX(to_state) AS mst
             FROM survival_history_days
             GROUP BY patient
             ORDER BY patient)
    WHERE mst = 1)
GROUP BY patient
ORDER BY patient
;

-- set final state 1 to 99
UPDATE survival_history_days
SET to_state = 99
WHERE id IN (
    SELECT id
    FROM survival_history_days AS s
             INNER JOIN max_start_days AS m
                        ON s.patient = m.patient
                            AND s.entry = m.mstart)
;

DROP TABLE IF EXISTS survival_transition_days;
-- create table with "from" state 0
CREATE TABLE survival_transition_days AS
SELECT patient AS id,
       sex,
       age,
       0 AS entry,
       MAX(entry) - MIN(entry) AS exit,
       MAX(provider_changed) AS provider_changed,
       MAX(inpatient_stay) AS inpatient_stay,
       GROUP_CONCAT(DISTINCT main_diagnoses) AS diagnoses,
       COUNT(DISTINCT main_diagnoses) > 1 AS comorbidity,
       MAX(severe) AS severe,
       MIN(from_state) AS `from`,
       MAX(to_state) AS `to`
FROM survival_history_days
WHERE from_state = 0
GROUP BY patient
HAVING MAX(to_state) > 0
ORDER BY patient, entry;

-- insert missing "from" state 1
INSERT INTO survival_transition_days
SELECT patient AS id,
       sex,
       age,
       (
           SELECT MAX(exit)
           FROM survival_transition_days AS st
           WHERE st.id = patient
             AND st."from" = 0) AS entry,
       MAX(entry) AS exit,
       MAX(provider_changed) AS provider_changed,
       MAX(inpatient_stay) AS inpatient_stay,
       GROUP_CONCAT(DISTINCT main_diagnoses) AS diagnoses,
       COUNT(DISTINCT main_diagnoses) > 1 AS comorbidity,
       MAX(severe) AS severe,
       MIN(from_state) AS `from`,
       MAX(to_state) AS `to`
FROM survival_history_days
WHERE from_state = 1
GROUP BY patient
HAVING MAX(to_state) > 1
ORDER BY patient, entry;


-- survival_cluster_not_severe
SELECT *
FROM survival_transition_days
WHERE severe = 0
ORDER BY id, entry;


