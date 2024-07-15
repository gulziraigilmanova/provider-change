CREATE TABLE admissions AS
SELECT patient, quarter, COUNT(*) AS admissions
FROM study
WHERE discharge != ''
GROUP BY patient, quarter
ORDER BY patient, quarter;

-- for survival analysis (multistate)
CREATE TABLE survival AS
SELECT s.id,
       s.patient,
       s.sex,
       s.age,
       s.year_quarter,
       s.quarter - m.quarter AS relative_quarter,
       (s.quarter - m.quarter) * 3 AS entry,
       (s.quarter - m.quarter) * 3 + 3 AS exit,
       s.provider
           != LAG(s.provider, 1, s.provider)
                  OVER (PARTITION BY s.patient ORDER BY s.quarter) AS provider_changed,
       COALESCE(SUM(a.admissions), 0) > 0 AS inpatient_stay,
       INSTR(GROUP_CONCAT(DISTINCT SUBSTR(s.diagnose, 0, 3)), 'F2') > 0
           OR INSTR(GROUP_CONCAT(DISTINCT SUBSTR(s.diagnose, 0, 4)), 'F31') > 0
           OR s.diagnose = 'F32.2'
           OR s.diagnose = 'F32.3'
           OR s.diagnose = 'F33.2'
           OR s.diagnose = 'F33.3' > 0 AS severe,
       MIN((s.provider
           != LAG(s.provider, 1, s.provider)
                  OVER (PARTITION BY s.patient ORDER BY s.quarter)) + (COALESCE(a.admissions, 0) > 0) * 2,
           2) AS state
FROM study AS s
         INNER JOIN min_quarter AS m
                    ON s.patient = m.patient
         LEFT JOIN admissions AS a
                   ON s.patient = a.patient
                       AND s.quarter = a.quarter
GROUP BY s.patient, year_quarter
ORDER BY s.patient, year_quarter
-- LIMIT 100
;

CREATE TABLE survival_history AS
SELECT MIN(sh.id) AS id,
       sh.patient,
       sh.sex,
       sh.age,
       sh.year_quarter,
       sh.entry,
       sh.exit,
       sh.provider_changed,
       sh.inpatient_stay,
       GROUP_CONCAT(DISTINCT n.diagnose) AS diagnoses,
       (SELECT MAX(severe) FROM survival WHERE patient = sh.patient) AS severe,
       -- todo: calculate comorbidity
       sh.from_state,
       MAX(sh.state, sh.from_state) AS to_state
FROM (SELECT s.*,
             COALESCE(
                     (SELECT MAX(sb.state)
                      FROM survival AS sb
                      WHERE s.patient = sb.patient
                        AND sb.entry < s.entry),
                     0
             ) AS from_state
      FROM survival AS s
      ORDER BY s.patient + 0, s.Year_Quarter) AS sh
         INNER JOIN study AS n
                    ON n.patient = sh.patient
                        AND n.year_quarter = sh.year_quarter
GROUP BY sh.patient, sh.year_quarter
ORDER BY sh.patient, sh.year_quarter;

-- delete extra visits after first state "2"
DELETE
FROM survival_history
WHERE from_state = 2
  AND to_state = 2;

CREATE TABLE clustered_survival AS
SELECT *,
       CHAR(65 + SUM(is_new_cluster)
                     OVER (PARTITION BY patient + 0 ORDER BY entry RANGE UNBOUNDED PRECEDING)) AS cluster_id
FROM (SELECT *, distance > 6 AS is_new_cluster
      FROM (SELECT *,
                   entry -
                   LAG(entry, 1, entry)
                       OVER (PARTITION BY patient ORDER BY entry) AS distance
            FROM survival_history
            ORDER BY patient, entry))
;

-- delete clusters that are not the first one
DELETE
FROM clustered_survival
WHERE cluster_id != 'A';

-- delete patients that have only a single visit (after cleaning the clusters)
DELETE
FROM clustered_survival
WHERE ROWID IN (SELECT ROWID
                FROM clustered_survival
                GROUP BY patient, cluster_id
                HAVING COUNT(*) = 1);

-- aux table to turn last final state 1 into 99
CREATE TABLE max_start AS
SELECT patient, MAX(entry) AS mstart
FROM clustered_survival
WHERE patient IN (SELECT patient
                  FROM (SELECT patient, MAX(to_state) AS mst
                        FROM clustered_survival
                        GROUP BY patient
                        ORDER BY patient)
                  WHERE mst = 1)
GROUP BY patient
ORDER BY patient
;

-- set final state 1 to 99
UPDATE clustered_survival
SET to_state = 99
WHERE id IN (SELECT id
             FROM clustered_survival AS s
                      INNER JOIN max_start AS m
                                 ON s.patient = m.patient
                                     AND s.entry = m.mstart)
;

-- survival_complete
SELECT patient,
       sex,
       age,
       year_quarter,
       entry,
       exit,
       provider_changed,
       inpatient_stay,
       diagnoses,
       severe,
       from_state,
       to_state
FROM clustered_survival;
