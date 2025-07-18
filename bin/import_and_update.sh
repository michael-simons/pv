#!/usr/bin/env bash

# This script creates intervals of 7 days (the longest interval I can get from the
# vendor of my monitoring system) and runs the import multiple times if necessary.

set -euo pipefail
export LC_ALL=en_US.UTF-8

DIR="$(dirname "$(realpath "$0")")"
DB="$(realpath "$1")"
TARGET="$(< "$DIR"/../.secrets/target)"
USERNAME="$(< "$DIR"/../.secrets/username)"
PASSWORD="$(< "$DIR"/../.secrets/password)"

# Retrieve a bearer
mkdir -p .tmp
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15"
BEARER=$(
curl -LA "$UA" -s "https://new.energymanager.com" \
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

# And create a secret, the map expression here doesn't support nested expressions,
# hence using the env variable directly.
CREATE_SECRET_QUERY="
  CREATE OR REPLACE SECRET energymanager (
      TYPE HTTP,
      EXTRA_HTTP_HEADERS MAP {
          'Authorization': 'Bearer $BEARER',
          'Origin': 'https://new.energymanager.com',
          'Referer': 'https://new.energymanager.com/'
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
  UNION
  SELECT cast(today() - INTERVAL 7 DAY AS date) AS start,
         cast(today() - INTERVAL 1 DAY AS date) AS stop
  FROM measurements having(count(*)) = 0
"

#
# The actual import and data processing
#
# The JSON being processed looks like this
#
# {
#     "timeseries": [
#         {
#             "name": "PowerConsumed",
#             "aggregated": 9443,
#             "guid": "REDACTED",
#             "id": "REDACTED~PowerConsumed",
#             "unit": "WATT",
#             "values": {
#                 "2024-09-30T13:55+02:00": 354
#             }
#         },
#     ],
#     "resolution": "PT5M",
#     "time_zone": "Europe/Berlin"
# }
#
# A list of timeseries, with nested list of values, represented as maps, so they
# must be unnested twice, and once recursive, and than pivoted to use the various
# serieses as columns.
#
IMPORT_QUERY="
  WITH timeseries(v) AS (
    SELECT unnest(timeseries)
    FROM read_json('https://hems.kiwigrid.com/v6/analytics/overview?type=POWER&from=' || getenv('FROM') || 'T00:00:00&to=' || getenv('TO') || 'T23:59:59&resolution=PT5M')
  ),
  unnested(name, ts, v) AS (
    SELECT v['name'], unnest(map_entries(v['values']), recursive:=true) FROM timeseries
  ),
  pivoted AS (pivot unnested ON name USING any_value(v)),
  input AS (
    SELECT time_bucket(INTERVAL '15 Minutes', replace(ts, '+', ':00+')::timestamptz)::timestamp AS _measured_on,
           coalesce(avg(PowerProduced), 0) AS _production,
           coalesce(avg(PowerConsumed), 0) AS _consumption,
           coalesce(avg(PowerOut),0 )      AS _export,
           coalesce(avg(PowerIn), 0)       AS _import
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

IMPORT_QUERY_STORAGE="
  WITH timeseries(v) AS (
    SELECT unnest(timeseries)
    FROM read_json('https://hems.kiwigrid.com/v6/analytics/storage?type=POWER&from=' || getenv('FROM') || 'T00:00:00&to=' || getenv('TO') || 'T23:59:59&resolution=PT5M')
  ),
  unnested(name, ts, v) AS (
    SELECT v['name'], unnest(map_entries(v['values']), recursive:=true) FROM timeseries
  ),
  pivoted AS (pivot unnested ON name USING any_value(v)),
  input AS (
    SELECT time_bucket(INTERVAL '15 Minutes', replace(ts, '+', ':00+')::timestamptz)::timestamp AS _measured_on,
           coalesce(avg(PowerBuffered), 0) AS _buffered,
           coalesce(avg(PowerReleased), 0) AS _released,
           coalesce(avg(StateOfCharge), 0) AS _state_of_charge
     FROM pivoted
     GROUP BY _measured_on
     ORDER BY _measured_on ASC
  )
  INSERT INTO measurements (measured_on, buffered, released, state_of_charge)
  SELECT * FROM input
  ON CONFLICT (measured_on) DO UPDATE
  SET buffered = coalesce(buffered, excluded.buffered),
      released = coalesce(released, excluded.released),
      state_of_charge = coalesce(state_of_charge, excluded.state_of_charge)
"

IMPORT_QUERY_BATTERY_HEALTH=$(duckdb "$DB" -c ".mode list" -c "
SELECT 'WITH src AS (' ||
         list_reduce(
           list_transform(range(0, np.value::integer), lambda i: 'SELECT id, pk from read_json(''http://' || ip.value || '/pack?p=' || i || ''')'),
           lambda v1, v2: v1 || ' UNION ' || v2) ||
       ')
        INSERT INTO battery_health BY NAME
        SELECT today() AS ref_date, id.sn AS serial, list({serial: pk.sn, soh: pk.soh, op: pk.op}) AS packs
        FROM src
        GROUP BY serial
        ON CONFLICT DO UPDATE SET packs = excluded.packs'  AS stmt
FROM domain_values np, domain_values ip
WHERE np.name = 'BATTERY_NUM_PACKS'
  AND ip.name = 'BATTERY_IP'
" | tail -n+2)

# Query for importing the weather data from Openmeteo, the API URL will be computed
# dynamically, depending on how far back in the request is
IMPORT_QUERY_WEATHER_DATA="
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
    FROM read_json_auto(getenv('open_meteo_url'))
  )
  ORDER BY measured_on
  ON CONFLICT DO NOTHING
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

  # The weather URL is dynamically computed with a bunch of columns
  open_meteo_url=$(duckdb "$DB" -c ".mode list" -c "
    SELECT CASE WHEN getenv('TO')::date <= today() - 3 THEN 'https://archive-api.open-meteo.com/v1/archive?'
                ELSE 'https://api.open-meteo.com/v1/forecast?' END || base || '&start_date='|| getenv('FROM') || '&end_date=' || getenv('TO')
    FROM v_weather_data_source
  " | tail -n+2)
  export open_meteo_url

  # Run all imports
  echo "Importing from $FROM to $TO"
  duckdb "$DB" \
    -c ".mode trash" \
    -c "LOAD ICU" \
    -c "SET TimeZone='Europe/Berlin'" \
    -c "SET force_download=true" \
    -c "$CREATE_SECRET_QUERY" \
    -c "$IMPORT_QUERY" \
    -c "$IMPORT_QUERY_STORAGE" \
    -c "$IMPORT_QUERY_BATTERY_HEALTH" \
    -c "$IMPORT_QUERY_WEATHER_DATA"

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

  NOTEBOOKS="$DIR"/../notebooks
  # Setup the python environment if not available
  if [ ! -d "$NOTEBOOKS"/.venv/ ] ; then
    python3 -m venv "$NOTEBOOKS"/.venv/
    (source "$NOTEBOOKS"/.venv/bin/activate && pip3 install -r "$NOTEBOOKS"/requirements.txt)
  fi

  IFS=$'\r\n' GLOBIGNORE='*' command eval 'SCP_OPTIONS=($(cat "$DIR"/../.secrets/scp_options))'
  ln -s "$DB" "$NOTEBOOKS"/__pv_db.duckdb__
  (source "$NOTEBOOKS"/.venv/bin/activate && jupyter nbconvert --execute --to html --output index.html --no-input "$NOTEBOOKS"/Photovoltaik\ \|\ Familie\ Simons,\ Aachen.ipynb && scp "${SCP_OPTIONS[@]}" "$NOTEBOOKS"/index.html "$TARGET" && rm "$NOTEBOOKS"/index.html)
  rm "$NOTEBOOKS"/__pv_db.duckdb__
fi
