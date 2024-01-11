#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=en_US.UTF-8

DB="$(pwd)/$1"
FROM=${2}
TO=${3}

default_parameters=$(duckdb "$DB" -s ".mode list" -s "
 WITH columns AS (
     SELECT list_aggregate(list(column_name ORDER BY column_index),  'string_agg', ',') AS value
     FROM duckdb_columns()
     WHERE table_name = 'daily_weather_data' AND column_name <> 'ref_date'
   )
   SELECT 'latitude=' || lat || '&longitude=' || long || '&timezone=Europe%2FBerlin&daily=' || columns.value AS base
   FROM v_place_of_installation, columns
" | tail -n1)

duckdb "$DB" -s "SET force_download=true" -s "
  INSERT INTO daily_weather_data BY NAME
  SELECT unnest(time)                                 AS ref_date,
         strptime(unnest(sunrise), '%Y-%m-%dT%H:%M')  AS sunrise,
         strptime(unnest(sunset) , '%Y-%m-%dT%H:%M')  AS sunset,
         unnest(sunshine_duration)                    AS sunshine_duration,
         unnest(daylight_duration)                    AS daylight_duration,
         unnest(precipitation_hours)                  AS precipitation_hours,
         unnest(precipitation_sum)                    AS precipitation_sum,
         unnest(temperature_2m_max)                   AS temperature_2m_max,
         unnest(temperature_2m_min)                   AS temperature_2m_min,
         unnest(weather_code)                         AS weather_code
  FROM (
    SELECT unnest(daily)
    FROM read_json_auto('https://archive-api.open-meteo.com/v1/archive?$default_parameters&start_date=$FROM&end_date=$TO')
  )
  ORDER BY ref_date
  ON CONFLICT DO NOTHING
"
