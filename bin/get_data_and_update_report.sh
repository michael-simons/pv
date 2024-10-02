#!/usr/bin/env bash

# This script creates intervals of 7 days (the longest interval I can get from the 
# vendor of my monitoring system) and runs the import multiple times if necessary.

set -euo pipefail
export LC_ALL=en_US.UTF-8

DIR="$(dirname "$(realpath "$0")")"
DB="$(pwd)/$1"
TARGET="$(< "$DIR"/../.secrets/target)"
USERNAME="$(< "$DIR"/../.secrets/username)"
PASSWORD="$(< "$DIR"/../.secrets/password)"

# Retrieve a bearer
mkdir -p .tmp
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15"
BEARER=$(
curl -A "$UA" -s "https://auth.energymanager.com/auth/realms/solarwatt/protocol/openid-connect/auth?response_type=code&client_id=energy-monitor-home&redirect_uri=https%3A%2F%2Fnew.energymanager.com%2Frest%2Fauth%2Fauth_grant&scope=openid" \
  -H 'Accept:  text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
  --cookie-jar .tmp/cookies.txt |\
xidel -se "//form[@id='kc-form-login']/@action" - |\
xargs -L 1 curl -A "$UA" -sL --cookie .tmp/cookies.txt --cookie-jar .tmp/cookies.txt -H "Content-Type: application/x-www-form-urlencoded" --data "username=$USERNAME&password=$PASSWORD" > /dev/null; \
curl -A "$UA" -s https://new.energymanager.com/context \
 -H 'Referer: https://new.energymanager.com/' \
 -H 'Host: new.energymanager.com' \
 -H 'Accept: application/json' \
 --cookie .tmp/cookies.txt |\
jq --raw-output .oauth.accessToken
)
rm -rf .tmp
  
# And create a secret
# Note to Hannes or anyone from DuckDB: It would be nice if the map expression would 
# support expressions here, too :)
CREATE_SECRET_QUERY="
  CREATE OR REPLACE SECRET energymanager (
      TYPE HTTP,
      EXTRA_HTTP_HEADERS MAP {
          'Referer': 'https://new.energymanager.com/',
          'Authorization': 'Bearer $BEARER',
          'Host': 'hems.kiwigrid.com',
          'Origin': 'https://new.energymanager.com'
      },
      SCOPE 'https://hems.kiwigrid.com'
  )
"

# Query that computes ranges of 7 days max from the last full measurement
RANGES_QUERY="
  WITH RECURSIVE intervals(start, stop) AS (
    SELECT cast(max(measured_on) + INTERVAL 1 DAY AS date) AS start, 
           cast(least(start + INTERVAL 6 DAYS, today() - INTERVAL 1 DAY) AS date) AS stop
    FROM measurements
    HAVING start < today()
    UNION ALL
    SELECT cast(p.stop + INTERVAL 1 DAY AS date) AS next_start, 
           cast(least(next_start + INTERVAL 6 DAY, today() - INTERVAL 1 DAY) AS date) AS next_stop
    FROM intervals p
    WHERE stop < today() - INTERVAL 1 day
  ) 
  SELECT * FROM intervals
"

# The actual import and data processing
IMPORT_QUERY="
  WITH timeseries(v) AS (
    SELECT unnest(timeseries) 
    FROM read_json('https://hems.kiwigrid.com/v2.52/analytics/overview?type=POWER&from=' || getenv('FROM') || 'T00:00:00&to=' || getenv('TO') || 'T23:59:59&resolution=PT5M')
  ), 
  unnested(name, ts, v) AS (
    SELECT v['name'], unnest(map_entries(v['values']), recursive:=true) FROM timeseries
  ),
  pivoted AS (pivot unnested on name using any_value(v)),
  input AS (
    SELECT time_bucket(INTERVAL '15 Minutes', replace(ts, '+', ':00+')::timestamptz) AS _measured_on,
           avg(PowerProduced) AS _production,
           avg(PowerConsumed) AS _consumption,
           avg(PowerOut)      AS _export,
           avg(PowerIn)       AS _import
     FROM pivoted
     GROUP BY _measured_on
     ORDER BY _measured_on ASC
  )
  INSERT INTO measurements (measured_on, production, consumption, export, import)
  SELECT * FROM input
  ON CONFLICT (measured_on) DO UPDATE
  SET production = CASE
         WHEN production = 0 THEN excluded.production
         ELSE (production + excluded.production) / 2 END,
      consumption = excluded.consumption,
      export = excluded.export,
      import = excluded.import
"

# Some stats before
duckdb "$DB" -line\
  -c "SELECT count(*)               AS 'Num measurements before' FROM measurements"\
  -c "SELECT max(measured_on)::date AS 'Last measurement       ' FROM measurements"

CHANGED=false

# Loop over the ranges and kick of the import for each
for i in $(duckdb $DB -readonly -noheader -csv -c "$RANGES_QUERY"); do
  FROM="$(cut -d',' -f1 <<<"$i")"
  export FROM
  TO="$(cut -d',' -f2 <<<"$i")"
  export TO

  echo "Importing from $FROM to $TO"
  duckdb "$DB" -c ".mode trash" -c "$CREATE_SECRET_QUERY" -c "$IMPORT_QUERY"
  
  echo "Updating weather data"
  open_meteo_url=$(duckdb "$DB" -c ".mode list" -c "
    SELECT CASE WHEN getEnv('TO')::date <= today() - 3 THEN 'https://archive-api.open-meteo.com/v1/archive?' 
                ELSE 'https://api.open-meteo.com/v1/forecast?' END || base || '&start_date='|| getenv('FROM') || '&end_date=' || getEnv('TO')
    FROM v_weather_data_source
  " | tail -n1)
  export open_meteo_url

  duckdb "$DB" -c "SET force_download=true" -c "
    INSERT INTO weather_data BY NAME
    SELECT strptime(unnest(time), '%Y-%m-%dT%H:%M')   AS measured_on, 
           unnest(shortwave_radiation)                AS shortwave_radiation,
           unnest(temperature_2m)                     AS temperature_2m,
           unnest(cloud_cover)                        AS cloud_cover,
           unnest(cloud_cover_low)                    AS cloud_cover_low,
           unnest(cloud_cover_mid)                    AS cloud_cover_mid,
           unnest(cloud_cover_high)                   AS cloud_cover_high,
           unnest(weather_code)                       AS weather_code,
           unnest(precipitation)                      AS precipitation,
           unnest(rain)                               AS rain,
           unnest(snowfall)                           AS snowfall
    FROM (
      SELECT unnest(hourly)
      FROM read_json_auto(getEnv('open_meteo_url'))
    )
    ORDER BY measured_on
    ON CONFLICT DO NOTHING
  "
  
  CHANGED=true
done

if [ "$CHANGED" = false ];
then
  echo "Database and report are upto date."
else
  echo "Done..."
  duckdb "$DB" -line\
    -c "SELECT count(*)               AS 'Num measurements after' FROM measurements"\
    -c "SELECT max(measured_on)::date AS 'Last measurement now  ' FROM measurements"

  duckdb "$DB" -c "FROM v_monthly_number_of_measurements";
  (source "$DIR"/../notebooks/.venv/bin/activate && jupyter nbconvert --execute --to html --output index.html --no-input Photovoltaik\ \|\ Familie\ Simons,\ Aachen.ipynb && scp index.html "$TARGET" && rm index.html)
fi
