#

## Requirements

- [SQLite 3](https://www.sqlite.org/)
- [R](https://www.r-project.org/) and [RStudio](https://posit.co/download/rstudio-desktop/) IDE

## Data cleaning

In order to work with the raw data, some cleaning is necessary. sqlite will be
used for this step.

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
   ```

5. You should now have a `database.sqlite` file containing your database, with a
   table called `original` inside.

### 2. The cleaning itself

Next, we need to run a sqlite script to extract the relevant data from the
database and create a new table.
