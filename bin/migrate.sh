#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=en_US.UTF-8

DIR="$(dirname "$(realpath "$0")")"
DB="$(pwd)/$1"
CREATE_INITIAL_DATA=${2:-"false"}

find $DIR/../schema -iname "V*__*.sql" -print | sort |\
 (xargs cat; echo "SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' ORDER BY table_name ASC")|\
 duckdb "$DB"

find $DIR/../schema -iname "R__*.sql" -print | sort |\
  (xargs cat; echo "SELECT table_name FROM information_schema.tables WHERE table_type = 'VIEW' ORDER BY table_name ASC")|\
  duckdb "$DB"

if [ "$CREATE_INITIAL_DATA" == "true" ]
then
java bin/initial_data.java | duckdb "$DB" "INSERT INTO measurements(measured_on) SELECT ts::timestamptz FROM read_csv_auto('/dev/stdin') ON CONFLICT (measured_on) DO NOTHING";
fi
