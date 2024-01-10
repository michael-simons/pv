-- See https://open-meteo.com/en/docs/

CREATE TABLE IF NOT EXISTS daily_weather_data (
    ref_date            DATE PRIMARY KEY,
    sunrise             TIMESTAMP NOT NULL,
    sunset              TIMESTAMP NOT NULL,
    sunshine_duration   UINTEGER NOT NULL, -- in seconds
    daylight_duration   UINTEGER NOT NULL, -- in seconds
    precipitation_hours USMALLINT NOT NULL, -- in hours
    precipitation_sum   DECIMAL(8,3) NOT NULL, -- in mm
    temperature_2m_max  DECIMAL(8,3) NOT NULL, -- in °C
    temperature_2m_min  DECIMAL(8,3) NOT NULL, -- in °C
    weather_code        USMALLINT NOT NULL
);
