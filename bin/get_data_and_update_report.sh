#!/usr/bin/env bash

# This script creates intervals of 7 days (the longest interval I can get from the 
# vendor of my monitoring system) and runs the import multiple times if necessary.

set -euo pipefail
export LC_ALL=en_US.UTF-8

DIR="$(dirname "$(realpath "$0")")"
DB="$(pwd)/$1"
TARGET="$(< $DIR/../.secrets/target)"
USERNAME="$(< $DIR/../.secrets/username)"
PASSWORD="$(< $DIR/../.secrets/password)"

RANGES_QUERY='WITH RECURSIVE intervals(start, stop) AS (
  SELECT cast(max(measured_on) + INTERVAL 1 DAY AS date) AS start, 
         cast(least(start + INTERVAL 6 DAYS, today() - INTERVAL 1 DAY) AS date) AS stop
  FROM measurements
  HAVING start < today()
  UNION ALL
  SELECT cast(p.stop + INTERVAL 1 DAY AS date) AS next_start, 
         cast(least(next_start + INTERVAL 6 DAY, today() - INTERVAL 1 DAY) AS date) AS next_stop
  FROM intervals p
  WHERE stop < today() - INTERVAL 1 day
) SELECT * FROM intervals'


duckdb $DB -line\
  -c "SELECT count(*)               AS 'Num measurements before' FROM measurements"\
  -c "SELECT max(measured_on)::date AS 'Last measurement       ' FROM measurements"

CHANGED=false

for i in $(duckdb $DB -noheader -csv -c "$RANGES_QUERY"); do
  START="$(cut -d',' -f1 <<<"$i")"
  END="$(cut -d',' -f2 <<<"$i")"
  echo "Importing from $START to $END"
  $DIR/import_production_from_kiwigrid.sh $1 "$USERNAME" "$PASSWORD" $START $END
  CHANGED=true
done

if [ "$CHANGED" = true ];
then
  echo "Done..."
  duckdb $DB -line\
    -c "SELECT count(*)               AS 'Num measurements after' FROM measurements"\
    -c "SELECT max(measured_on)::date AS 'Last measurement now  ' FROM measurements"

  duckdb $DB -c "FROM v_monthly_number_of_measurements";
  (source $DIR/../notebooks/.venv/bin/activate && jupyter nbconvert --execute --to html --output index.html --no-input Photovoltaik\ \|\ Familie\ Simons,\ Aachen.ipynb && scp index.html $TARGET && rm index.html)
else
  echo "Database and report are upto date."
fi
