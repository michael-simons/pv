#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=en_US.UTF-8

_now=$(gdate)

DIR="$(dirname "$(realpath "$0")")"
DB="$(pwd)/$1"
USERNAME=$2
PASSWORD=$3
FROM=${4:-$(gdate -d "$_now" +'%Y-%m-%d')}
TO=${5:-$(gdate -d "$FROM + 6 days" +'%Y-%m-%d')}

UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15"

mkdir -p .tmp

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

curl -A "$UA" -f --no-progress-meter "https://hems.kiwigrid.com/v2.48/analytics/overview?type=POWER&from=${FROM}T00:00:00&to=${TO}T23:59:59&resolution=PT5M" \
 -H 'Referer: https://new.energymanager.com/' \
 -H 'Accept: application/json' \
 -H "Authorization: Bearer $BEARER" \
 -H 'Host: hems.kiwigrid.com' \
 -H 'Origin: https://new.energymanager.com' > .tmp/overview.json

(echo "ts,production";  jq --raw-output '.timeseries[] | select(.name == "PowerProduced") | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]' .tmp/overview.json) > .tmp/production.csv
(echo "ts,export";      jq --raw-output '.timeseries[] | select(.name == "PowerOut")      | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]' .tmp/overview.json) > .tmp/export.csv
(echo "ts,consumption"; jq --raw-output '.timeseries[] | select(.name == "PowerConsumed") | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]' .tmp/overview.json) > .tmp/consumption.csv
(echo "ts,import";      jq --raw-output '.timeseries[] | select(.name == "PowerIn")       | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]' .tmp/overview.json) > .tmp/import.csv

duckdb -c "COPY (
  SELECT *
    FROM '.tmp/production.csv'
    JOIN '.tmp/consumption.csv' USING (ts)
    JOIN '.tmp/export.csv' USING (ts)
    JOIN '.tmp/import.csv' USING (ts)
) TO '/dev/stdout' (HEADER)" | duckdb "$DB" -c ".read $DIR/kiwigrid_production.sql"

rm -rf .tmp

open_meteo_url=`duckdb "$DB" -s ".mode list" -s "
  SELECT CASE WHEN '$TO' <= today() - 3 THEN 'https://archive-api.open-meteo.com/v1/archive?' 
              ELSE 'https://api.open-meteo.com/v1/forecast?' END || base || '&start_date=$FROM&end_date=$TO'
  FROM v_weather_data_source
" | tail -n1`

duckdb "$DB" -s "SET force_download=true" -s "
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
    FROM read_json_auto('$open_meteo_url')
  )
  ORDER BY measured_on
  ON CONFLICT DO NOTHING
"

>&2 echo "New end date: $(gdate -d "$TO + 1 days" +'%Y-%m-%d')"
