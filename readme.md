# Provider Change Survival Analysis

## Requirements

- [SQLite 3](https://www.sqlite.org/)
- [R](https://www.r-project.org/)
  and [RStudio](https://posit.co/download/rstudio-desktop/) IDE

## Data preparation

In order to work with the data, some preparation work is necessary.
This will run some SQL scripts to extract CSV files that are used for the
thesis.
sqlite will be used for this step.

### 1. Database creation instructions

1. Download your CSV data file and put it into the folder you want to work with.
   Make sure your file is saved with the encoding `UTF-8`.

2. From your terminal, navigate to the folder.

3. Run `sqlite3` command to enter it.

4. Import the data:

   ```sqlite3
   .mode csv
   .import <YOUR_FILE>.csv original
   .mode table
   # visualize your data to make sure it's properly imported
   select * from original limit 10;
   # save to database.sqlite file
   .save database.sqlite
   .exit
   ```

5. You should now have a `database.sqlite` file containing your database, with a
   table called `original` inside.

### 2. Preparing and extracting the patients data

Next, we need to run some scripts to extract the relevant data from the
database and create the relevant CSV files.

On your terminal, run the following commands to extract information about inpatients.
```shell
cat inpatient.sql | sqlite3 database.sqlite 
sqlite3 -header -csv database.sqlite 'SELECT * FROM survival_transition_st ORDER BY id, entry;' > output/survival_inpatient_complete.csv
sqlite3 -header -csv database.sqlite 'SELECT * FROM survival_transition_st WHERE severe = 1 ORDER BY id, entry;' > output/survival_inpatient_severe.csv
sqlite3 -header -csv database.sqlite 'SELECT * FROM survival_transition_st WHERE severe = 0 ORDER BY id, entry;' > output/survival_inpatient_non_severe.csv
```

Next, run the commands below to extract information about daypatients.

```shell
cat daypatient.sql | sqlite3 database.sqlite
sqlite3 -header -csv database.sqlite 'SELECT * FROM survival_transition_ts ORDER BY id, entry;' > output/survival_daypatient_complete.csv
sqlite3 -header -csv database.sqlite 'SELECT * FROM survival_transition_ts WHERE severe = 1 ORDER BY id, entry;' > output/survival_daypatient_severe.csv
sqlite3 -header -csv database.sqlite 'SELECT * FROM survival_transition_ts WHERE severe = 0 ORDER BY id, entry;' > output/survival_daypatient_non_severe.csv
```

Now your CSV files should be in the [output](output) folder inside the project.

## Running the analysis

Now that all that data is ready, the analysis can run.
For this, we will use R and RStudio.

Open the project in RStudio and there, open the file [survival_analysis.rmd](survival_analysis.rmd).
Now, you can run the code and obtain the results of the analysis.
