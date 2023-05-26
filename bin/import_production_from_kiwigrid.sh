#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=en_US.UTF-8

_now=$(gdate)

DB="$(pwd)/$1"
BEARER=$2
FROM=${3:-$(gdate -d "$_now" +'%Y-%m-%d')}
TO=${4:-$(gdate -d "$FROM + 6 days" +'%Y-%m-%d')}

mkdir -p .tmp
DIR="$(dirname "$(realpath "$0")")"

curl -f --no-progress-meter "https://hems.kiwigrid.com/v2.30/analytics/production?type=POWER&splitProduction=true&from=${FROM}T00:00:00&to=${TO}T23:59:59&resolution=PT5M" \
 -H 'Accept: application/json' \
 -H "Authorization: Bearer $BEARER" \
 -H 'Host: hems.kiwigrid.com' \
 -H 'Origin: https://new.energymanager.com' | tee \
>((echo "ts,production";  jq --raw-output '.timeseries[] | select(.name == "PowerProduced") | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]') > .tmp/production.csv) \
>((echo "ts,export";      jq --raw-output '.timeseries[] | select(.name == "PowerOut")      | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]') > .tmp/export.csv) \
> /dev/null

curl -f --no-progress-meter "https://hems.kiwigrid.com/v2.30/analytics/consumption?type=POWER&from=${FROM}T00:00:00&to=${TO}T23:59:59&resolution=PT5M" \
 -H 'Accept: application/json' \
 -H "Authorization: Bearer $BEARER" \
 -H 'Host: hems.kiwigrid.com' \
 -H 'Origin: https://new.energymanager.com' | tee \
>((echo "ts,consumption"; jq --raw-output '.timeseries[] | select(.name == "PowerConsumed") | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]') > .tmp/consumption.csv) \
>((echo "ts,import";      jq --raw-output '.timeseries[] | select(.name == "PowerIn")       | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00")),\(.value)") | .[]') > .tmp/import.csv) \
> /dev/null

sleep 3

xsv join ts .tmp/production.csv ts .tmp/consumption.csv  | xsv select '!ts[1]' | \
xsv join ts /dev/stdin ts .tmp/export.csv | xsv select '!ts[1]' | \
xsv join ts /dev/stdin ts .tmp/import.csv | xsv select '!ts[1]' | \
duckdb "$DB" -c ".read $DIR/../sql/import/kiwigrid_production.sql"

rm -rf .tmp

>&2 echo "New end date: $(gdate -d "$TO + 1 days" +'%Y-%m-%d')"
