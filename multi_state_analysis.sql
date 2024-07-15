CREATE TABLE admissions AS
SELECT patient, quarter, COUNT(*) AS admissions
FROM study
WHERE discharge != ''
GROUP BY patient, quarter
ORDER BY patient, quarter;


-- for survival analysis (multistate)
-- CREATE TABLE survival AS
SELECT s.id,
       s.patient,
       s.sex,
       s.age,
       s.year_quarter,
       s.quarter - m.quarter AS relative_quarter,
       (s.quarter - m.quarter) * 3 AS start_time,
       (s.quarter - m.quarter) * 3 + 3 AS stop_time,
       s.provider
           != LAG(s.provider, 1, s.provider)
                  OVER (PARTITION BY s.patient ORDER BY s.quarter) AS provider_changed,
       COALESCE(SUM(a.admissions), 0) > 0 AS inpatient_stay,
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

CREATE TABLE survival_complete AS
SELECT MIN(x.id) AS id,
       x.patient,
       x.sex,
       x.age,
       x.year_quarter,
       x.start_time,
       x.stop_time,
       x.provider_changed,
       x.inpatient_stay,
       GROUP_CONCAT(DISTINCT n.diagnose) AS diagnoses,
       INSTR(GROUP_CONCAT(DISTINCT SUBSTR(n.diagnose, 0, 3)), 'F2') > 0
           OR INSTR(GROUP_CONCAT(DISTINCT SUBSTR(n.diagnose, 0, 4)), 'F31') > 0
           OR n.diagnose = 'F32.2'
           OR n.diagnose = 'F32.3'
           OR n.diagnose = 'F33.2'
           OR n.diagnose = 'F33.3' > 0 AS severe,
       -- todo: calculate comorbidity
       x.from_state,
       MAX(x.state, x.from_state) AS to_state
FROM (SELECT s.*,
             COALESCE(
                     (SELECT MAX(x.state)
                      FROM survival AS x
                      WHERE s.patient = x.patient
                        AND x.start_time < s.start_time),
                     0
             ) AS from_state
      FROM survival AS s
      ORDER BY s.patient + 0, s.Year_Quarter) AS x
         INNER JOIN study AS n
                    ON n.patient = x.patient
                        AND n.year_quarter = x.year_quarter
GROUP BY x.patient, x.year_quarter
ORDER BY x.patient, x.year_quarter;

-- delete extra visits after first state "2"
DELETE
-- SELECT *
FROM survival_complete
WHERE from_state = 2
  AND to_state = 2;

CREATE TABLE clustered_survival AS
SELECT *,
       CHAR(65 + SUM(is_new_cluster)
                     OVER (PARTITION BY patient + 0 ORDER BY start_time RANGE UNBOUNDED PRECEDING)) AS cluster_id
FROM (SELECT *, distance > 6 AS is_new_cluster
      FROM (SELECT *,
                   start_time -
                   LAG(start_time, 1, start_time)
                       OVER (PARTITION BY patient ORDER BY start_time) AS distance
            FROM survival_complete
            ORDER BY patient, start_time))
;

CREATE TABLE clustered_totals AS
SELECT patient, cluster_id, COUNT(*) AS num_quarters
FROM clustered_survival
-- WHERE patient IN (SELECT DISTINCT patient FROM clustered_survival WHERE cluster_id != 'A')
GROUP BY patient, cluster_id;

CREATE TABLE largest_cluster AS
SELECT patient, cluster_id, MAX(num_quarters) AS num_quarters
FROM clustered_totals
GROUP BY patient;


-- delete patients where the biggest cluster is size 1 (only one line)
DELETE
FROM clustered_totals
WHERE patient IN (SELECT patient
                  FROM largest_cluster
                  WHERE num_quarters = 1);

DELETE
FROM largest_cluster
WHERE num_quarters = 1
;

DELETE
FROM clustered_totals
WHERE ROWID IN (SELECT ct.ROWID
                FROM clustered_totals AS ct
                         INNER JOIN largest_cluster AS lc
                                    ON ct.patient = lc.patient
                                        AND ct.cluster_id != lc.cluster_id);


SELECT *
FROM clustered_totals
WHERE patient = 225
;

SELECT *
FROM clustered_survival
WHERE patient = 225;
