CREATE OR REPLACE VIEW v_weather_data_source AS (
  WITH columns AS (
    SELECT list_aggregate(list(column_name ORDER BY column_index),  'string_agg', ',') AS value
    FROM duckdb_columns()
    WHERE table_name = 'weather_data' AND column_name <> 'measured_on'
  )
  SELECT 'latitude=' || lat || '&longitude=' || long || '&timezone=Europe%2FBerlin&hourly=' || columns.value AS base
  FROM v_place_of_installation, columns
);
