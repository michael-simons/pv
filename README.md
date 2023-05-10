# pv

⚠️ Programs and scripts in this repository are not meant to be used and may damage your equipment.

## Requirements

### For the power logger

A snapshot build of the [Energy systems reading toolkit](https://energy.basjes.nl) is required for the logger to be compiled.

Build the power logger with

```bash
mvn -f logger/pom.xml clean package
```

### Database

[DuckDB](https://duckdb.org) >= 0.7.1, Java 17 for running `initial_data.java`.

Right now, the SQL scripts work on a single DuckDB table:

```bash
duckdb pv.db < sql/schema.sql
```

Some statistics will look odd without data for all quarterly hours until now:

```bash
java sql/initial_data.java | duckdb pv.db "INSERT INTO production SELECT ts::timestamptz, power FROM read_csv_auto('/dev/stdin') ON CONFLICT (measured_on) DO NOTHING";
```

Values are stored per quarterly hour, as local date times (local timezone is assumed). For dealing with specifics to your area, i.e. changes during summer / winter time observations, scripts needs adjustement. 

`production` looks like this:

```
D show production;
┌─────────────┬──────────────┬─────────┬─────────┬─────────┬───────┐
│ column_name │ column_type  │  null   │   key   │ default │ extra │
│   varchar   │   varchar    │ varchar │ varchar │ varchar │ int32 │
├─────────────┼──────────────┼─────────┼─────────┼─────────┼───────┤
│ measured_on │ TIMESTAMP    │ NO      │ PRI     │         │       │
│ power       │ DECIMAL(8,3) │ NO      │         │         │       │
└─────────────┴──────────────┴─────────┴─────────┴─────────┴───────┘
```

## Usage

### Logger

Run the power logger with

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

### Database

#### Import from the loggers output

_Logger puts out 1 minute measurements in watt (W)._

```bash
duckdb pv.db < sql/import_logger.sql
```

#### Import from energymanager.com

_Export is 15 minutes average watt (W)_.

```bash
duckdb pv.db < sql/import_energymanager.sql
```

#### Import from meteocontrol.com daily chart export

_Export is 5 minutes average kilowatt (kW)._

```bash
duckdb pv.db < sql/import_meteocontrol.sql
```

Concatenating several exports into one file via [xsv](https://github.com/BurntSushi/xsv):

```bash
find . -type f -iname "chart*.csv" -print0 | xargs -r0 xsv cat -d ";" rows | xsv fmt -t ";" > meteocontrol.csv
```

#### Purging data

For example:

```sql
DELETE FROM production WHERE date_trunc('day', measured_on) < '2023-04-20' AND false;
```

#### Statistics

##### Overalls

```bash
duckdb --readonly pv.db < sql/stats_overall.sql
```

##### Per Month

```bash
duckdb --readonly pv.db < sql/stats_per_month.sql
```

##### Per day

```bash
duckdb --readonly pv.db < sql/stats_per_day.sql
```

##### Peaks

```bash
duckdb --readonly pv.db < sql/stats_peaks.sql
```

##### Per hour and month

_Needs DuckDB Nightly (> v0.7.2-dev2706 43a97f9078)_

```bash
./duckdb --readonly pv.db < sql/stats_per_hour_and_month.sql
```

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
logrotate -f  etc/logrotate.conf 
```
