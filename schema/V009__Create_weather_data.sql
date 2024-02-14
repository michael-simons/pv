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
