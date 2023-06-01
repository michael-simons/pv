# Importer

Before I wrote the logger and before our smart devices had been working proper, I tried to scrape data from various more or less good apis.
I keep those scripts around just in case.

## From energymanager.com

_Export is 15 minutes average watt (W)_.

```bash
more energymanager.csv | duckdb pv.db -c ".read bin/import_energymanager.sql"
```

## From meteocontrol.com daily chart export

_Export is 5 minutes average kilowatt (kW)._

```bash
more chart.csv | duckdb pv.db -c ".read bin/import_meteocontrol.sql"
```

Concatenating several exports into one file via [xsv](https://github.com/BurntSushi/xsv):

```bash
find . -type f -iname "chart*.csv" -print0 | xargs -r0 xsv cat -d ";" rows | xsv fmt -t ";" | duckdb pv.db -c ".read bin/import_meteocontrol.sql"
```
