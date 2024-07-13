CREATE TABLE filtered_plz AS
SELECT ID + 0 AS id,
       Patient_Pseudonym + 0 AS patient,
       Geschlecht AS sex,
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
WHERE Patient_Pseudonym IN (SELECT DISTINCT Patient_Pseudonym
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
-- delete emergency
  AND Fallstatus not in ('Notfalldienst/Vertretung/Notfall', 'vorstationär')
-- keep only adults
  AND Min_Age >= 18
-- Delete patients with diverse sex (unfortunately the base is too small - 2 patients)
  AND Geschlecht IN ('W', 'M')
ORDER BY 1
;

-- Create aux table min_quarter to then exclude initial visits that were admissions
CREATE TABLE min_quarter AS
SELECT id, patient, charge, quarter
FROM (SELECT id,
             patient,
             charge,
             quarter,
             ROW_NUMBER()
                     OVER (PARTITION BY patient ORDER BY charge) AS rn
      FROM filtered_plz
      WHERE status IN ('Ärztliche Behandlung', 'Überweisungsfall')
        AND discharge = '') AS a
WHERE rn = 1
;

-- exclude initial visits that were admissions
DELETE
FROM filtered_plz
WHERE id IN (SELECT f.id
             FROM filtered_plz AS f
                      INNER JOIN min_quarter AS m
                                 ON f.patient = m.patient
             WHERE f.charge < m.charge);

-- create new table with patients that were
-- at least twice Outpatient with diagnose F or empty
CREATE TABLE study AS
SELECT *
FROM filtered_plz
WHERE patient IN (SELECT patient
                  FROM filtered_plz
                  WHERE discharge = ''
                  GROUP BY patient
                  HAVING COUNT(*) > 1
                  ORDER BY patient)
  AND patient IN (SELECT DISTINCT patient
                  FROM filtered_plz
                  WHERE (diagnose LIKE 'F%' OR diagnose = ''))
;
