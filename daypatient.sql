DROP TABLE IF EXISTS filtered_ts;
CREATE TABLE filtered_ts AS
SELECT ID + 0 AS id,
       Patient_Pseudonym + 0 AS patient,
       -- sex remap W-1;M-0
       Geschlecht == 'W' AS sex,
       Min_Age + 0 AS age,
       Behandler_pseudonym AS provider,
       Fallstatus AS status,
       Abteilung AS unit,
       Diagnose AS diagnose,
       PLZ AS zipcode,
       SUBSTR(Aufnahmedatum, 7, 4) || '-' || SUBSTR(Aufnahmedatum, 4, 2) || '-' ||
       SUBSTR(Aufnahmedatum, 1, 2) AS charge,
       IIF(Entlassdatum,
           SUBSTR(Entlassdatum, 7, 4) || '-' || SUBSTR(Entlassdatum, 4, 2) || '-' || SUBSTR(Entlassdatum, 1, 2),
           '') AS discharge,
       IFNULL(CAST(JULIANDAY(SUBSTR(Entlassdatum, 7, 4) || '-' || SUBSTR(Entlassdatum, 4, 2) || '-' ||
                             SUBSTR(Entlassdatum, 1, 2)) -
                   JULIANDAY(SUBSTR(Aufnahmedatum, 7, 4) || '-' || SUBSTR(Aufnahmedatum, 4, 2) || '-' ||
                             SUBSTR(Aufnahmedatum, 1, 2)) AS INTEGER),
              0) AS days_inpatient_stay,
       (STRFTIME('%Y', JULIANDAY(SUBSTR(Aufnahmedatum, 7, 4) || '-' || SUBSTR(Aufnahmedatum, 4, 2) || '-' ||
                                 SUBSTR(Aufnahmedatum, 1, 2))) - 2019) * 4 + ((STRFTIME('%m', JULIANDAY(
           SUBSTR(Aufnahmedatum, 7, 4) || '-' || SUBSTR(Aufnahmedatum, 4, 2) || '-' ||
           SUBSTR(Aufnahmedatum, 1, 2))) - 1) / 3 +
                                                                              1) AS quarter,
       STRFTIME('%Y', JULIANDAY(SUBSTR(Aufnahmedatum, 7, 4) || '-' || SUBSTR(Aufnahmedatum, 4, 2) || '-' ||
                                SUBSTR(Aufnahmedatum, 1, 2))) || '-Q' || ((STRFTIME('%m', JULIANDAY(
           SUBSTR(Aufnahmedatum, 7, 4) || '-' || SUBSTR(Aufnahmedatum, 4, 2) || '-' ||
           SUBSTR(Aufnahmedatum, 1, 2))) - 1) / 3 +
                                                                          1) AS year_quarter
FROM original
-- in the correct PLZ (or empty)
WHERE Patient_Pseudonym IN (
    SELECT DISTINCT Patient_Pseudonym
    FROM original
    WHERE PLZ IN ('10551',
                  '10553',
                  '10555',
                  '10557',
                  '10559',
                  '10785',
                  '10787',
                  '13347',
                  '13349',
                  '13351',
                  '13353',
                  '13355',
                  '13357',
                  '13359'
        ))
  -- only specific statuses
  AND Fallstatus IN ('Ärztliche Behandlung', 'Überweisungsfall', 'teilstationär')
-- keep only adults
  AND Min_Age >= 18
-- Delete patients with diverse sex (unfortunately the base is too small - 2 patients)
  AND Geschlecht IN ('W', 'M')
ORDER BY 1
;

-- Create aux table min_quarter_ts to then exclude initial visits that were admissions
DROP TABLE IF EXISTS min_quarter_ts;
CREATE TABLE min_quarter_ts AS
SELECT id, patient, charge, quarter
FROM (
         SELECT id,
                patient,
                charge,
                quarter,
                ROW_NUMBER()
                    OVER (PARTITION BY patient ORDER BY charge) AS rn
         FROM filtered_ts
         WHERE status IN ('Ärztliche Behandlung', 'Überweisungsfall')
           AND discharge = '') AS a
WHERE rn = 1
;

-- exclude initial visits that were admissions
DELETE
FROM filtered_ts
WHERE id IN (
    SELECT f.id
    FROM filtered_ts AS f
             INNER JOIN min_quarter_ts AS m
                        ON f.patient = m.patient
    WHERE f.charge < m.charge);


-- identify first admission
DROP TABLE IF EXISTS min_admission_quarter_ts;
CREATE TABLE min_admission_quarter_ts AS
SELECT id, patient, charge, quarter
FROM (
         SELECT id,
                patient,
                charge,
                quarter,
                ROW_NUMBER()
                    OVER (PARTITION BY patient ORDER BY charge) AS rn
         FROM filtered_ts
         WHERE discharge != '') AS a
WHERE rn = 1
;

-- create new table with patients that were
-- at least twice Outpatient with diagnose F or empty
DROP TABLE IF EXISTS study_ts;
CREATE TABLE study_ts AS
SELECT *
FROM filtered_ts
WHERE patient IN (
    SELECT f.patient
    FROM filtered_ts AS f
             LEFT JOIN min_admission_quarter_ts maq
                       ON f.patient = maq.patient
    WHERE f.status IN ('Ärztliche Behandlung', 'Überweisungsfall')
      AND (f.charge < maq.charge OR maq.charge IS NULL)
    GROUP BY f.patient
    HAVING COUNT(*) > 1
    ORDER BY f.patient)
  AND patient IN (
    SELECT DISTINCT patient
    FROM filtered_ts
    WHERE (diagnose LIKE 'F%' OR diagnose = ''))
;

-- table study_ts is ready

-- multi state analysis

-- create clusters from the study_ts table
-- the interest is on the first cluster of each patient
DROP TABLE IF EXISTS clustered_study_ts;
CREATE TABLE clustered_study_ts AS
SELECT *,
       CHAR(65 + SUM(is_new_cluster)
                     OVER (PARTITION BY patient ORDER BY JULIANDAY(charge) RANGE UNBOUNDED PRECEDING)) AS cluster_id
FROM (
         SELECT *, distance > 180 AS is_new_cluster
         FROM (
                  SELECT *,
                         JULIANDAY(charge) - LAG(JULIANDAY(charge), 1, JULIANDAY(charge))
                                                 OVER (PARTITION BY patient ORDER BY JULIANDAY(charge)) AS distance
                  FROM study_ts
                  ORDER BY patient, charge))
;

DROP TABLE IF EXISTS first_admission_cluster_ts;
CREATE TABLE first_admission_cluster_ts AS
SELECT patient, cluster_id, charge
FROM clustered_study_ts
WHERE status NOT IN ('Ärztliche Behandlung', 'Überweisungsfall')
GROUP BY patient, cluster_id;

-- delete lines after first admission per cluster
DELETE
FROM clustered_study_ts
WHERE ROWID IN (
    SELECT cs.ROWID
    FROM clustered_study_ts AS cs
             INNER JOIN first_admission_cluster_ts fac
                        ON cs.patient = fac.patient
                            AND cs.cluster_id = fac.cluster_id
    WHERE cs.charge > fac.charge)
;

-- only keep the first cluster of each patient
DELETE
FROM clustered_study_ts
WHERE cluster_id != 'A';


-- delete patients that have only a single visit (after cleaning the clusters)
DELETE
FROM clustered_study_ts
WHERE ROWID IN (
    SELECT ROWID
    FROM clustered_study_ts
    GROUP BY patient
    HAVING COUNT(*) = 1);

DROP TABLE IF EXISTS min_visit_ts;
CREATE TABLE min_visit_ts AS
SELECT id, patient, charge, JULIANDAY(charge) AS entry
FROM (
         SELECT id,
                patient,
                charge,
                ROW_NUMBER()
                    OVER (PARTITION BY patient ORDER BY charge) AS rn
         FROM clustered_study_ts
         WHERE status IN ('Ärztliche Behandlung', 'Überweisungsfall')
           AND discharge = '') AS a
WHERE rn = 1
ORDER BY patient
;

DROP TABLE IF EXISTS admissions_ts;
CREATE TABLE admissions_ts AS
SELECT patient, charge, COUNT(*) AS admissions
FROM clustered_study_ts
WHERE discharge != ''
GROUP BY patient, charge
ORDER BY patient, charge;

DROP TABLE IF EXISTS survival_ts;
CREATE TABLE survival_ts AS
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
FROM clustered_study_ts AS s
         INNER JOIN min_visit_ts AS m
                    ON s.patient = m.patient
         LEFT JOIN admissions_ts AS a
                   ON s.patient = a.patient
                       AND s.charge = a.charge
GROUP BY s.patient, s.charge
ORDER BY diagnoses DESC, s.patient, s.charge
;


DROP TABLE IF EXISTS survival_history_ts;
CREATE TABLE survival_history_ts AS
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
           FROM survival_ts
           WHERE patient = sh.patient) AS severe,
       sh.from_state,
       MAX(sh.state, sh.from_state) AS to_state
FROM (
         SELECT s.*,
                COALESCE(
                    (
                        SELECT MAX(sb.state)
                        FROM survival_ts AS sb
                        WHERE s.patient = sb.patient
                          AND sb.entry < s.entry),
                    0
                ) AS from_state
         FROM survival_ts AS s
         ORDER BY s.patient, s.charge) AS sh
         INNER JOIN clustered_study_ts AS n
                    ON n.patient = sh.patient
                        AND n.charge = sh.charge
GROUP BY sh.patient, sh.charge
ORDER BY sh.patient, sh.charge;

-- aux table to turn last final state 1 into censored
DROP TABLE IF EXISTS max_start_ts;
CREATE TABLE max_start_ts AS
SELECT patient, MAX(entry) AS mstart
FROM survival_history_ts
WHERE patient IN (
    SELECT patient
    FROM (
             SELECT patient, MAX(to_state) AS mst
             FROM survival_history_ts
             GROUP BY patient
             ORDER BY patient)
    WHERE mst = 1)
GROUP BY patient
ORDER BY patient
;

-- set final state 1 to censored
UPDATE survival_history_ts
SET to_state = 'cens'
WHERE id IN (
    SELECT id
    FROM survival_history_ts AS s
             INNER JOIN max_start_ts AS m
                        ON s.patient = m.patient
                            AND s.entry = m.mstart)
;

DROP TABLE IF EXISTS survival_transition_ts;
-- create table with "from" state 0
CREATE TABLE survival_transition_ts AS
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
FROM survival_history_ts
WHERE from_state = 0
GROUP BY patient
HAVING MAX(to_state) > 0
ORDER BY patient, entry;

-- insert missing "from" state 1
INSERT INTO survival_transition_ts
SELECT patient AS id,
       sex,
       age,
       (
           SELECT MAX(exit)
           FROM survival_transition_ts AS svt
           WHERE svt.id = patient
             AND svt."from" = 0) AS entry,
       MAX(entry) AS exit,
       MAX(provider_changed) AS provider_changed,
       MAX(inpatient_stay) AS inpatient_stay,
       GROUP_CONCAT(DISTINCT main_diagnoses) AS diagnoses,
       COUNT(DISTINCT main_diagnoses) > 1 AS comorbidity,
       MAX(severe) AS severe,
       MIN(from_state) AS `from`,
       MAX(to_state) AS `to`
FROM survival_history_ts
WHERE from_state = 1
GROUP BY patient
HAVING MAX(to_state) > 1
ORDER BY patient, entry;
