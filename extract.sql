# Generate data
.read inpatient.sql
.read daypatient.sql

.mode csv
.headers on

# Export inpatient data
.once 'output/survival_inpatient_complete.csv'
SELECT * FROM survival_transition_st ORDER BY id, entry;
.once 'output/survival_inpatient_severe.csv'
SELECT * FROM survival_transition_st WHERE severe = 1 ORDER BY id, entry;
.once 'output/survival_inpatient_non_severe.csv'
SELECT * FROM survival_transition_st WHERE severe = 0 ORDER BY id, entry;

# Export daypatient data
.once 'output/survival_daypatient_complete.csv'
SELECT * FROM survival_transition_ts ORDER BY id, entry;
.once 'output/survival_daypatient_severe.csv'
SELECT * FROM survival_transition_ts WHERE severe = 1 ORDER BY id, entry;
.once 'output/survival_daypatient_non_severe.csv'
SELECT * FROM survival_transition_ts WHERE severe = 0 ORDER BY id, entry;
