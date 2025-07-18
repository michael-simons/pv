-- noinspection SqlResolveForFile


--
-- The actual measurements, stored for every 15 minutes
--
CREATE TABLE IF NOT EXISTS measurements (
  measured_on TIMESTAMP PRIMARY KEY,
  production  DECIMAL(8,3) NOT NULL DEFAULT 0,
  consumption DECIMAL(8,3) NOT NULL DEFAULT 0,
  import DECIMAL(8,3)      NOT NULL DEFAULT 0,
  export DECIMAL(8,3)      NOT NULL DEFAULT 0
);
ALTER TABLE measurements ADD COLUMN IF NOT EXISTS buffered DECIMAL(8,3);
ALTER TABLE measurements ADD COLUMN IF NOT EXISTS released DECIMAL(8,3);
ALTER TABLE measurements ADD COLUMN IF NOT EXISTS state_of_charge UTINYINT;


--
-- Stores some configuration and inventory data
--
CREATE SEQUENCE IF NOT EXISTS domain_values_primary_key_seq;
CREATE TABLE IF NOT EXISTS domain_values (
  id                 INTEGER PRIMARY KEY DEFAULT(nextval('domain_values_primary_key_seq')),
  name               VARCHAR(512) NOT NULL,
  value              VARCHAR(512) NOT NULL,
  description        VARCHAR(1024) NOT NULL,
  CONSTRAINT domain_values_uk UNIQUE (name)
);


--
-- Applicable VAT
--
CREATE TABLE IF NOT EXISTS applicable_vat_values (
  valid_from  DATE NOT NULL PRIMARY KEY,
  valid_until DATE,
  value       DECIMAL(3,2) NOT NULL -- Value in percent
);


--
-- Prices for buying and selling electricity
--
CREATE SEQUENCE IF NOT EXISTS prices_primary_key_seq;
CREATE TABLE IF NOT EXISTS prices (
  id          INTEGER PRIMARY KEY DEFAULT(nextval('prices_primary_key_seq')),
  value       DECIMAL(5,2) NOT NULL, -- Net price before value added tax in ct/kWh
  type        VARCHAR(8) NOT NULL CHECK(type IN ('buy', 'full_sell', 'partial_sell')),
  valid_from  DATE NOT NULL,
  valid_until DATE,
  CONSTRAINT prices_uk UNIQUE (type, valid_from)
);


--
-- The values recorded and accepted by the supplier
--
CREATE SEQUENCE IF NOT EXISTS official_measurements_primary_key_seq;
CREATE TABLE IF NOT EXISTS official_measurements (
  id           INTEGER PRIMARY KEY DEFAULT(nextval('official_measurements_primary_key_seq')),
  period_start DATE NOT NULL,
  period_end   DATE NOT NULL,
  import       DECIMAL(7,2) NOT NULL, -- Imported energy in kWH
  export       DECIMAL(7,2) NULL, -- Exporte energy in kWH
  CONSTRAINT official_measurements UNIQUE (period_start, period_end)
);


--
-- Factor how much CO2 in g/kWh in Germanys energy mix
--
CREATE TABLE IF NOT EXISTS co2_factor_per_year (
  year        INTEGER PRIMARY KEY,
  value       INTEGER NOT NULL -- in g/kWh
);


--
-- Measurements / forecast of weather from Open Meteo
-- See https://open-meteo.com/en/docs/
--
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


--
-- Historical weather data
--
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


--
-- Battery health
--
CREATE TABLE IF NOT EXISTS battery_health (
    ref_date          DATE,
    serial            VARCHAR(16),
    -- soh (State of health) in percent, op (Operating time) in seconds
    packs             STRUCT(serial VARCHAR(16), soh DECIMAL(4,2), op UINTEGER)[],
    PRIMARY KEY (ref_date, serial)
);


--
-- Other utilities
--
CREATE TABLE IF NOT EXISTS other_utilities (
  year        USMALLINT NOT NULL,
  type        VARCHAR(32) NOT NULL CHECK (type in ('electricity', 'water', 'gas')),
  consumption DECIMAL(8,3) NOT NULL,
  PRIMARY KEY (year, type)
);


--
-- Gas parameters
--
CREATE TABLE IF NOT EXISTS gas_parameters (
  year        USMALLINT PRIMARY KEY,
  ab_wert     DECIMAL(6,4) NOT NULL,
  z_zahl      DECIMAL(5,4) NOT NULL
);
