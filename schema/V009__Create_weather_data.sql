-- See https://open-meteo.com/en/docs/

CREATE TABLE IF NOT EXISTS weather_data (
    measured_on         TIMESTAMP PRIMARY KEY,
    shortwave_radiation DECIMAL(8,3) NOT NULL, -- in W/m^
    temperature_2m      DECIMAL(8,3) NOT NULL, -- in °C
    cloud_cover         DECIMAL(8,3) NOT NULL, -- in % 
    cloud_cover_low     DECIMAL(8,3) NOT NULL, -- in % 
    cloud_cover_mid     DECIMAL(8,3) NOT NULL, -- in % 
    cloud_cover_high    DECIMAL(8,3) NOT NULL, -- in %
    weather_code        USMALLINT NOT NULL,
    precipitation       DECIMAL(8,3) NOT NULL, -- in mm
    rain                DECIMAL(8,3) NOT NULL, -- in mm
    snowfall            DECIMAL(8,3) NOT NULL -- in cm
);


CREATE OR REPLACE VIEW v_weather_data_source AS (
  WITH columns AS (
    SELECT list_aggregate(list(column_name ORDER BY column_index),  'string_agg', ',') AS value
    FROM duckdb_columns()
    WHERE table_name = 'weather_data' AND column_name <> 'measured_on'
  )
  SELECT 'latitude=' || lat || '&longitude=' || long || '&timezone=Europe%2FBerlin&hourly=' || columns.value AS base
  FROM v_place_of_installation, columns
);
