# pv

⚠️ Programs and scripts in this repository are not meant to be used and may damage your equipment (Of course I use them myself but you never know with expensive equiptment).

## Requirements

### For the power logger

The logger is based on the [Energy systems reading toolkit](https://energy.basjes.nl). Thanks a ton for your work, [Niels Basjes](https://mastodon.basjes.nl/@niels). 

Build the power logger with

```bash
mvn -f logger/pom.xml clean package
```

### For the database

[DuckDB](https://duckdb.org) >= 0.8.0, Java 17 for running `initial_data.java`.

The schema is kind of separated in non-repeatable migrations and repeatable migrations. 
In reality, the non-repeatable ones are idempotent, too, at least at the moment. 
All schema scripts starts with an uppercase `V` followed by an incrementing number contain tables and the like.
All statistics work with views. Those are named with an uppercase `R` to indicate that the contained statements are always repeatable:

The schema can be applied as follows:

```bash
./bin/migrate.sh pv.db
```

Measurements are stored per quarterly hour, as local date times (local timezone is assumed). 
For dealing with specifics to your area, i.e. changes during summer / winter time observations, scripts needs adjustment.
All views - think of them as public API to this database - start with an `v_`.

### For the Jupyter notebook

I have added a `requirements.txt` usable with `pip` like this:

```bash
pip install -r requirements.txt
```

## Usage

### Logger

Run the power logger with:

```bash
./logger/target/assembly/bin/log-power-output
```

Again, this might damage your inverter, burn down the house and what not. Use at your own risk.

On macOS, you can use `launchctl` to run this program as a service. See below for logfile rotation.

```bash
launchctl submit -l log-power-output -o `pwd`/logger.csv -- `pwd`/logger/target/log-power-output -a your.address 
```

Remove again with

```bash
launchctl remove log-power-output
```

### Jupyter Notebook

Run the notebook with:

```bash
jupyter notebook notebooks/Photovoltaik\ \|\ Familie\ Simons,\ Aachen.ipynb
```

Produce HTML without input boxes and code:

```bash
jupyter nbconvert --execute --to html --output index.html --no-input notebooks/Photovoltaik\ \|\ Familie\ Simons,\ Aachen.ipynb
```

Clear existing output with:

```bash
jupyter nbconvert --ClearOutputPreprocessor.enabled=True --inplace notebooks/Photovoltaik\ \|\ Familie\ Simons,\ Aachen.ipynb
```

I have a rendered version with my current dataset at [simons.ac/pv](http://simons.ac/pv).

### Database

#### Import from the loggers output

_Logger puts out 1 minute measurements in watt (W)._

```bash
more logger.csv | duckdb pv.db -c ".read bin/import_logger.sql"
```

#### Import from energymanager.com

_Export is 15 minutes average watt (W)_.

```bash
more energymanager.csv | duckdb pv.db -c ".read bin/import_energymanager.sql"
```

#### Import from meteocontrol.com daily chart export

_Export is 5 minutes average kilowatt (kW)._

```bash
more chart.csv | duckdb pv.db -c ".read bin/import_meteocontrol.sql"
```

Concatenating several exports into one file via [xsv](https://github.com/BurntSushi/xsv):

```bash
find . -type f -iname "chart*.csv" -print0 | xargs -r0 xsv cat -d ";" rows | xsv fmt -t ";" | duckdb pv.db -c ".read bin/import_meteocontrol.sql"
```

#### Creating backups

The whole database can be exported either as CSV files like this

```sql
EXPORT DATABASE 'target_folder';
```

Or if you prefer [Parquet](https://parquet.apache.org), use the following:

```sql
EXPORT DATABASE 'target_folder' (FORMAT PARQUET, COMPRESSION ZSTD);
```

#### Examples

You can get a list of all views to explorer directly from the information schema like this:

```bash
duckdb --readonly pv.db "SELECT table_name FROM information_schema.tables WHERE table_type = 'VIEW' ORDER BY table_name ASC"
```

Their titles should hopefully be self-explanatory, and I only want to show two highlights here. 
The `bar` function and the pivot support. The following adds a bit to the view named `v_average_production_per_month` and produces a quick chart in the terminal, showing the average energy produced per hour:

```bash
duckdb --readonly notebooks/pv.db <<-SQL
WITH max_kWh AS (SELECT max(production) AS value FROM v_average_production_per_hour)
SELECT hour AS Hour, bar(production, 0, max_kWh.value) AS 'Average energy produced (kWh)'
FROM v_average_production_per_hour, max_kWH
ORDER BY hour ASC;
SQL
```

Should look something like this, which I totally love:

![stats_avg_per_month_example](media/stats_avg_per_hour.png)

Of course this is also possible per month:

```bash
duckdb --readonly notebooks/pv.db <<-SQL
WITH max_kWH AS (SELECT max(production) AS value FROM v_average_production_per_month)
SELECT month AS Month, 
     bar(production, 0, max_kWH.value) AS 'Average energy produced (kWh)'
FROM v_average_production_per_month, max_kWH
ORDER BY month ASC;
SQL
```

Then there is the `PIVOT` statement being used in `v_average_production_per_month_and_hour` view to compute the average per
hour _and_ month. Originally I displayed the month names as headers, but that is not that useful as an API for the database when you want todo the translation later:

```bash
duckdb --readonly notebooks/pv.db "SELECT * FROM v_average_production_per_month_and_hour"
```
![stats_avg_per_hour_and_month](media/stats_avg_per_hour_and_month.png)

## Managing log files

### Using `split`

`split` can be used to split data into files with a given number of lines or chunk-size like that:

```bash
./logger/target/log-power-output -a your.address | split -d -l4690 - logger.csv.
```

If needed they can be aggregated into one file like this

```bash
find . -type f -iname "logger.csv.*" -print0 | xargs -r0 cat | sort > logger.csv
```

### Using `logrotate`

There's a template configuration file for `logrotate` that might be helpful. Assuming you are logging like this:

```bash
./logger/target/log-power-output -a your.address >> logger.csv
```

you can rotate everything with this command

```bash
logrotate -f etc/logrotate.conf 
```
