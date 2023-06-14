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
curl -A "$UA" -s https://auth.energymanager.com/login \
 -H "Content-Type: application/x-www-form-urlencoded" \
 --data "username=$USERNAME&password=$PASSWORD&autologin=false&channel=solarwatt&originalRequest=%2Fauthorize%3Fresponse_type%3Dcode%26amp%3Bredirect_uri%3Dhttps%253A%252F%252Fnew.energymanager.com%252Frest%252Fauth%252Fauth_grant%253Fchannel%253Dsolarwatt%26amp%3Bstate%3DwBdeInUYbZcqIpT15sXny6kj%26amp%3Bclient_id%3Dkiwigrid.energy-monitor-home" \
 --cookie-jar .tmp/cookies.txt |\
jq --raw-output '"https://auth.energymanager.com/authorize?response_type=code&state=&client_id=kiwigrid.energy-monitor-home&overrideRedirectUri=true&redirect_uri=" + .redirectUri' |\
xargs -L 1 curl -A "$UA" -sL --cookie .tmp/cookies.txt --cookie-jar .tmp/cookies.txt > /dev/null; \
curl -A "$UA" -s https://new.energymanager.com/context \
 -H 'Referer: https://new.energymanager.com/' \
 -H 'Host: new.energymanager.com' \
 -H 'Accept: application/json' \
 --cookie .tmp/cookies.txt |\
jq --raw-output .oauth.accessToken
)

curl -A "$UA" -f --no-progress-meter "https://hems.kiwigrid.com/v2.30/analytics/production?type=POWER&splitProduction=true&from=${FROM}T00:00:00&to=${TO}T23:59:59&resolution=PT5M" \
 -H 'Referer: https://new.energymanager.com/' \
 -H 'Accept: application/json' \
 -H "Authorization: Bearer $BEARER" \
 -H 'Host: hems.kiwigrid.com' \
 -H 'Origin: https://new.energymanager.com' > .tmp/production.json

(echo "ts,production";  jq --raw-output '.timeseries[] | select(.name == "PowerProduced") | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]' .tmp/production.json) > .tmp/production.csv
(echo "ts,export";      jq --raw-output '.timeseries[] | select(.name == "PowerOut")      | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]' .tmp/production.json) > .tmp/export.csv

curl -A "$UA" -f --no-progress-meter "https://hems.kiwigrid.com/v2.30/analytics/consumption?type=POWER&from=${FROM}T00:00:00&to=${TO}T23:59:59&resolution=PT5M" \
 -H 'Referer: https://new.energymanager.com/' \
 -H 'Accept: application/json' \
 -H "Authorization: Bearer $BEARER" \
 -H 'Host: hems.kiwigrid.com' \
 -H 'Origin: https://new.energymanager.com' > .tmp/consumption.json

(echo "ts,consumption"; jq --raw-output '.timeseries[] | select(.name == "PowerConsumed") | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]' .tmp/consumption.json) > .tmp/consumption.csv
(echo "ts,import";      jq --raw-output '.timeseries[] | select(.name == "PowerIn")       | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]' .tmp/consumption.json) > .tmp/import.csv

duckdb -c "COPY (
  SELECT *
    FROM '.tmp/production.csv'
    JOIN '.tmp/consumption.csv' USING (ts)
    JOIN '.tmp/export.csv' USING (ts)
    JOIN '.tmp/import.csv' USING (ts)
) TO '/dev/stdout' (HEADER)" | duckdb "$DB" -c ".read $DIR/kiwigrid_production.sql"

rm -rf .tmp

>&2 echo "New end date: $(gdate -d "$TO + 1 days" +'%Y-%m-%d')"
