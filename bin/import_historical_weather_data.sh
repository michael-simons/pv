#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=en_US.UTF-8

_now=$(gdate)

DIR="$(dirname "$(realpath "$0")")"
DB="$(pwd)/$1"
FROM=${2}
TO=${3}

default_parameters=`duckdb "$DB" -s ".mode list" -s "SELECT base FROM v_weather_data_source" | tail -n1`

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
    FROM read_json_auto('https://archive-api.open-meteo.com/v1/archive?$default_parameters&start_date=$FROM&end_date=$TO')
  )
  ORDER BY measured_on
  ON CONFLICT DO NOTHING
"
