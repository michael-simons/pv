#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=en_US.UTF-8

_now=$(gdate)

DB="$(pwd)/$1"
BEARER=$2
FROM=${3:-$(gdate -d "$_now" +'%Y-%m-%d')}
TO=${4:-$(gdate -d "$FROM + 6 days" +'%Y-%m-%d')}

DIR="$(dirname "$(realpath "$0")")"
cd "$DIR"/..

curl -f --no-progress-meter "https://hems.kiwigrid.com/v2.30/analytics/production?type=POWER&splitProduction=true&from=${FROM}T00:00:00&to=${TO}T23:59:59" \
 -H 'Accept: application/json' \
 -H "Authorization: Bearer $BEARER" \
 -H 'Host: hems.kiwigrid.com' \
 -H 'Origin: https://new.energymanager.com' \
 -H 'Connection: keep-alive' |\
jq --raw-output '.timeseries[] | select(.name == "PowerProduced") | .values | to_entries | map("\(.key | sub("\\+0[12]:00"; ":00"));\(.value)") | .[]' |\
duckdb "$DB" -c '.read ./sql/import/kiwigrid_production.sql'

>&2 echo "New end date: $(gdate -d "$TO + 1 days" +'%Y-%m-%d')"
