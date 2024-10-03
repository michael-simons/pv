-- noinspection SqlResolveForFile

--
-- How much CO2 save per year
--
CREATE OR REPLACE VIEW v_accumulated_yearly_co2_savings AS (
  WITH per_day AS (
      SELECT date_trunc('day', measured_on) AS day,
             sum(production) / 4 / 1000 AS production,
             sum(export)     / 4 / 1000 AS export
      FROM measurements, v$_beginning_of_measurements bom
      WHERE measured_on >= bom.value
      GROUP BY day
  )
  SELECT date_part('year',  day) AS year,
         round(sum(co2.value * (production - export)) / 1000.0, 2)        AS total,
    FROM per_day ASOF LEFT JOIN co2_factor_per_year co2
      ON date_part('year',  day) >= co2.year
    GROUP BY date_part('year',  day)
);


--
-- Accumulated yearly energy costs, with and without (hypothetical) PV
--
CREATE OR REPLACE VIEW v_accumulated_yearly_energy_costs AS (
  WITH months AS (
      SELECT range AS value
      FROM range(time_bucket(INTERVAL '1 Year', today()), time_bucket(INTERVAL '1 Year', today()) + INTERVAL '1 Year', INTERVAL '1 Month')
  ),
  per_month AS (
      SELECT date_trunc('month', ifnull(m.measured_on, months.value))       AS month,
             sum(coalesce(production,  0)) / 4 / 1000 AS production,
             sum(coalesce(consumption, 0)) / 4 / 1000 AS consumption,
             sum(coalesce(export,      0)) / 4 / 1000 AS export,
             sum(coalesce(import,      0)) / 4 / 1000 AS import
      FROM measurements m FULL OUTER JOIN months ON date_trunc('month', m.measured_on) = months.value
      GROUP BY month
  )
  SELECT per_month.month,
         round(sum(buy.gross * per_month.consumption) OVER ordered_months / 100.0, 2) AS cost_without_pv,
         round(sum(buy.gross * per_month.import - sell.value * per_month.export) OVER ordered_months / 100.0, 2) AS cost_with_pv
  FROM per_month
  ASOF LEFT JOIN v$_buying_prices buy
      ON per_month.month >= buy.valid_from
  ASOF LEFT JOIN v$_selling_prices sell
      ON per_month.month >= sell.valid_from AND sell.type = 'partial_sell'
  WINDOW
      ordered_months AS (PARTITION BY year(per_month.month) ORDER BY per_month.month ASC)
  ORDER BY per_month.month ASC
);


--
-- The sad story of when the invest will have amortized
--
CREATE OR REPLACE VIEW v_amortization AS (
  WITH acquisition_cost AS (
      SELECT coalesce(cast(any_value(value) AS numeric),0) AS value
      FROM domain_values WHERE name = 'ACQUISITION_COST'
  ),
  partial_selling_prices  AS (
    SELECT * FROM v$_selling_prices WHERE type = 'partial_sell'
  ),
  full_selling_prices  AS (
    SELECT * FROM v$_selling_prices WHERE type = 'full_sell'
  ),
  per_month AS (
      SELECT date_trunc('month', measured_on) AS month,
             sum(production) / 4 / 1000  AS production,
             sum(consumption) / 4 / 1000 AS consumption,
             sum(export) / 4 / 1000      AS export,
             sum(import) / 4 / 1000      AS import
      FROM v$_beginning_of_measurements bom, measurements
      WHERE date_trunc('day', measured_on) >= bom.value
      GROUP BY month
  )
  SELECT per_month.month,
         round(-acquisition_cost.value + sum(full_sell.value * per_month.production) OVER ordered_months / 100.0, 2)
              AS full_export,
         round(-acquisition_cost.value + coalesce(sum(part_sell.value * per_month.export + buy.gross * (per_month.production - per_month.export)) OVER ordered_months / 100.0, 0))
              AS partial_export
  FROM acquisition_cost CROSS JOIN per_month
  ASOF LEFT JOIN partial_selling_prices part_sell
      ON per_month.month >= part_sell.valid_from
  ASOF LEFT JOIN full_selling_prices full_sell
      ON per_month.month >= full_sell.valid_from
  ASOF LEFT JOIN v$_buying_prices buy
      ON per_month.month >= buy.valid_from
  WINDOW
      ordered_months AS (ORDER BY per_month.month ASC)
  ORDER BY per_month.month ASC
);


--
-- Average consumption per month and hours
--
CREATE OR REPLACE VIEW v_average_consumption_per_month_and_hour AS (
  WITH beginning_of_measurements AS (
      SELECT coalesce(date_trunc('month', cast(any_value(value) AS date) + interval 1 month), (SELECT min(measured_on) FROM measurements)) AS value
      FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
  ),
  consumption_per_month_and_hour AS (
      SELECT any_value(date_part('month', measured_on))AS month,
             any_value(date_part('hour', measured_on)) AS hour,
             avg(consumption) / 1000                   AS consumption
        FROM measurements, beginning_of_measurements bom
       WHERE measured_on >= bom.value
       GROUP BY date_trunc('hour', measured_on)
       ORDER BY Hour
  )
  PIVOT consumption_per_month_and_hour
  ON month IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
  USING avg(consumption)
  GROUP BY hour
  ORDER BY hour
);


--
-- Share of internal consumption (using what we produce) per hour
--
CREATE OR REPLACE VIEW v_average_internal_consumption_share_per_hour AS (
  WITH hours as (SELECT range AS value FROM range(0, 24, 1)),
  totals AS (
      SELECT date_part('hour', measured_on) AS hour,
             avg(production)          AS production,
             avg(consumption)         AS consumption,
             avg(production - export) AS internal_consumption
      FROM measurements, v$_beginning_of_measurements bom
      WHERE measured_on >= bom.value
      GROUP BY hour
  )
  SELECT hours.value AS hour,
         CASE WHEN coalesce(production, 0)  = 0 THEN 0 ELSE round(internal_consumption / production * 100, 2)  END AS internal_consumption,
         CASE WHEN coalesce(consumption, 0) = 0 THEN 0 ELSE round(internal_consumption / consumption * 100, 2) END AS autarchy
  FROM hours left outer join totals on totals.hour = hours.value
  ORDER BY hours.value ASC
);


--
-- Yearly share of internal consumption
--
CREATE OR REPLACE VIEW v_yearly_internal_consumption_share AS (
  WITH totals AS (
      SELECT date_part('year', measured_on)      AS year,
             sum(production) / 4 / 1000          AS production,
             sum(consumption) / 4 / 1000         AS consumption,
             sum(production - export) / 4 / 1000 AS internal_consumption
      FROM measurements, v$_beginning_of_measurements bom
      WHERE measured_on >= bom.value
      GROUP BY year
  )
  SELECT year,
         CASE WHEN production = 0  THEN 0 ELSE round(internal_consumption / production * 100, 2)  END AS internal_consumption,
         CASE WHEN consumption = 0 THEN 0 ELSE round(internal_consumption / consumption * 100, 2) END AS autarchy
  FROM totals
);


--
-- Internal usage over all
--
CREATE OR REPLACE VIEW v_overall_internal_consumption_share AS (
    WITH totals AS (
        SELECT sum(production) / 4 / 1000          AS production,
               sum(consumption) / 4 / 1000         AS consumption,
               sum(production - export) / 4 / 1000 AS internal_consumption
        FROM measurements, v$_beginning_of_measurements bom
        WHERE measured_on >= bom.value
    )
    SELECT CASE WHEN production = 0  THEN 0 ELSE coalesce(round(internal_consumption / production  * 100, 2), 0) END AS internal_consumption,
           CASE WHEN consumption = 0 THEN 0 ELSE coalesce(round(internal_consumption / consumption * 100, 2), 0) END AS autarchy
    FROM totals
);


--
-- Average production per hour
--
CREATE OR REPLACE VIEW v_average_production_per_hour   AS (
  SELECT hour(m.measured_on)                         AS hour,
         round(avg(production) / 1000, 2)            AS production,
         round(avg(s.shortwave_radiation) / 1000, 2) AS shortwave_radiation
  FROM measurements m
  ASOF LEFT JOIN weather_data t USING (measured_on)
  ASOF LEFT JOIN weather_data s ON s.measured_on - INTERVAL 1 hour <= m.measured_on
  GROUP BY hour
  ORDER BY hour
);


--
-- Average production per month
--
CREATE OR REPLACE VIEW v_average_production_per_month AS (
  WITH monthly_sums AS (
      SELECT date_trunc('month', measured_on) AS beginning_of_month,
             sum(production) / 4 / 1000       AS kWh
      FROM measurements
      GROUP BY beginning_of_month
      HAVING cast(count(*)/96 AS int) = date_part('day', last_day(beginning_of_month))
  ), monthly_solar AS (
      SELECT date_trunc('month', measured_on) AS beginning_of_month,
             sum(shortwave_radiation) / 1000  AS kWh_mm
      FROM weather_data
      GROUP BY beginning_of_month
  )
  SELECT month(beginning_of_month)           AS month,
         round(avg(kWh), 2)                  AS production,
         round(avg(kWh_mm), 2)               AS shortwave_radiation
  FROM monthly_sums
  LEFT OUTER JOIN monthly_solar w USING (beginning_of_month)
  GROUP BY month
  ORDER BY month ASC
);


--
-- A pivot table for average production per month and hour
--
CREATE OR REPLACE VIEW v_average_production_per_month_and_hour AS (
  WITH production_per_month_and_hour AS (
      SELECT any_value(date_part('month', measured_on))AS month,
             any_value(date_part('hour', measured_on)) AS hour,
             avg(production) / 1000                    AS production
        FROM measurements
       GROUP BY date_trunc('hour', measured_on)
       ORDER BY hour
  )
  PIVOT production_per_month_and_hour
  ON month IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
  USING avg(production)
  GROUP BY hour
  ORDER BY hour
);


--
-- Weekly quartiles of production, with cloud coverage per week
--
CREATE OR REPLACE VIEW v_weekly_quartiles AS (
  WITH per_day AS (
      SELECT date_trunc('day', measured_on)               AS day,
             round(sum(production)  / 4 / 1000, 2)        AS production,
      FROM measurements
      GROUP BY day
  ), radiation_per_day AS (
      SELECT date_trunc('day', measured_on)               AS day,
             sum(shortwave_radiation) / 1000              AS kWh_mm
      FROM weather_data
      GROUP BY day
  )
  SELECT date_trunc('week', per_day.day)              AS sow,
         date_part('week', per_day.day)               AS week,
         min(production)                              AS min,
         quantile_cont(production, [0.25, 0.5, 0.75]) AS quartiles,
         max(production)                              AS max,
         round(avg(kWh_mm), 2)                        AS shortwave_radiation,
         CASE CAST(avg(cloud_cover_low)/25 AS int)
           WHEN 0 THEN '○'
           WHEN 1 THEN '◔'
           WHEN 2 THEN '◑'
           WHEN 3 THEN '◕'
           WHEN 4 THEN '●'
         END                                          AS cloud_coverage
  FROM per_day
  LEFT JOIN weather_data w ON date_trunc('day', w.measured_on) = per_day.day
  LEFT JOIN radiation_per_day USING (day)
  GROUP BY sow, week
  ORDER BY sow, week
);


--
-- Yearly production
--
CREATE OR REPLACE VIEW v_yearly_production AS (
  WITH per_day AS (
      SELECT date_trunc('day', measured_on) AS day,
             sum(production) / 4 / 1000 AS v
      FROM measurements
      GROUP BY day
  ), totals AS (
    SELECT date_part('year',  day) AS year,
           round(min(v), 2)        AS worst,
           round(max(v), 2)        AS best,
           round(avg(v), 2)        AS daily_avg,
           round(median(v), 2)     AS daily_median,
           round(sum(v), 2)        AS total
    FROM per_day
    WHERE v <> 0
    GROUP BY year
  )
  SELECT year,
         totals.worst,
         totals.best,
         totals.daily_avg,
         totals.daily_median,
         totals.total,
         CAST (CASE WHEN dv.value IS NULL THEN NULL
                    ELSE round(totals.total / CAST(dv.value AS NUMERIC), 2) END AS NUMERIC)
                             AS total_yield
  FROM totals LEFT OUTER JOIN domain_values dv ON (dv.name = 'INSTALLED_PEAK_POWER')
);


--
-- Overall statistics wrt production
--
CREATE OR REPLACE VIEW v_overall_production AS (
  WITH per_day AS (
      SELECT sum(production) / 4 / 1000 AS v
      FROM measurements
      GROUP BY date_trunc('day', measured_on)
  ), totals AS (
    SELECT round(min(v), 2)    AS worst,
           round(max(v), 2)    AS best,
           round(avg(v), 2)    AS daily_avg,
           round(median(v), 2) AS daily_median,
           round(sum(v), 2)    AS total
    FROM per_day
    WHERE v <> 0
  )
  SELECT totals.worst,
         totals.best,
         totals.daily_avg,
         totals.daily_median,
         totals.total,
         CAST (CASE WHEN dv.value IS NULL THEN NULL
                    ELSE round(totals.total / CAST(dv.value AS NUMERIC), 2) END AS NUMERIC)
                             AS total_yield
  FROM totals LEFT OUTER JOIN domain_values dv ON (dv.name = 'INSTALLED_PEAK_POWER')
);


--
-- Peak production values
--
CREATE OR REPLACE VIEW v_peaks AS (
  WITH mm AS (
      SELECT min(production) AS _min, max(production) AS _max
      FROM measurements
      WHERE production <> 0.0
  )
  SELECT round(production, 2) AS production,
         max(measured_on) AS last_time_measured
  FROM mm JOIN measurements ON (production = mm._min OR production = mm._max)
  GROUP BY production
  ORDER BY production ASC
);


--
-- For how much money to we currently buy electricity?
--
CREATE OR REPLACE VIEW v_current_buy AS (
  WITH latest_price AS (
      SELECT rank() OVER (ORDER BY valid_from DESC, valid_until DESC NULLS FIRST) as pos, valid_from, valid_until, value
      FROM prices
      WHERE type = 'buy'
      QUALIFY pos = 1
  ), latest_tax AS (
      SELECT value
      FROM applicable_vat_values
      ORDER BY valid_from DESC
      LIMIT 1
  )
  SELECT latest_price.value                                      AS net,
         latest_tax.value                                        AS tax,
         round(latest_price.value * (latest_tax.value + 1.0), 2) AS gross
  FROM latest_price, latest_tax
);


--
-- Energy flow per day
--
CREATE OR REPLACE VIEW v_energy_flow_per_day AS (
  SELECT date_trunc('day', measured_on)                  AS day,
         round(sum(production)  / 4 / 1000, 2)           AS production,
         round(sum(consumption) / 4 / 1000, 2)           AS consumption,
         round(sum(import) / 4 / 1000, 2)                AS import,
         round(sum(export)  / 4 / 1000, 2)               AS export,
         round(sum(production - export )  / 4 / 1000, 2) AS internal_consumption
  FROM measurements, v$_beginning_of_measurements bom
  WHERE measured_on >= bom.value
  GROUP BY day
);


--
-- Same, but per month
--
CREATE OR REPLACE VIEW v_energy_flow_per_month AS (
  SELECT date_trunc('month', measured_on)      AS month,
         round(sum(production)  / 4 / 1000, 2) AS production,
         round(sum(consumption) / 4 / 1000, 2) AS consumption,
         round(sum(import) / 4 / 1000, 2)      AS import,
         round(sum(export)  / 4 / 1000, 2)     AS export
  FROM measurements
  GROUP BY rollup(month)
  ORDER BY month ASC NULLS LAST
);


--
-- Energy flow on the best day (day with highest production)
--
CREATE OR REPLACE VIEW v_best_performing_days AS (
  WITH top_1 AS (
      SELECT year(day) AS year,
             day AS value,
             rank() OVER (PARTITION BY year ORDER BY production DESC) AS rnk
      FROM v_energy_flow_per_day
      QUALIFY rnk = 1
      ORDER BY day
  )
  SELECT year,
         m.measured_on,
         production,
         w.shortwave_radiation,
         c.cloud_cover_low AS cloud_coverage
  FROM measurements m
  ASOF LEFT JOIN weather_data w ON w.measured_on - INTERVAL 1 hour <= m.measured_on
  ASOF LEFT JOIN weather_data c ON c.measured_ON <= m.measured_on,
  top_1
  WHERE date_trunc('day', m.measured_on) = top_1.value
  ORDER BY m.measured_on ASC
);


--
-- A quick sanity check for the importer
--
CREATE OR REPLACE VIEW v_monthly_number_of_measurements AS (
  SELECT year(measured_on) AS y, month(measured_on) AS m, cast(count(*) / 96.0 AS int) AS days
  FROM measurements
  GROUP BY ALL order BY ALL
);


--
-- Place of installation
--
CREATE OR REPLACE VIEW v_place_of_installation AS (
  SELECT (SELECT coalesce(cast(any_value(value) AS decimal(7,5)), 50.775555) FROM domain_values WHERE name = 'LATITUDE') AS lat,
         (SELECT coalesce(cast(any_value(value) AS decimal(7,5)), 6.083611) FROM domain_values WHERE name = 'LONGITUDE') AS long
);


--
-- This reads the columns of the weather data tables and computes the url to get the data from openmeteo
--
CREATE OR REPLACE VIEW v_weather_data_source AS (
  WITH columns AS (
    SELECT list_aggregate(list(column_name ORDER BY column_index),  'string_agg', ',') AS value
    FROM duckdb_columns()
    WHERE table_name = 'weather_data' AND column_name <> 'measured_on'
  )
  SELECT 'latitude=' || lat || '&longitude=' || long || '&timezone=Europe%2FBerlin&hourly=' || columns.value AS base
  FROM v_place_of_installation, columns
);


--
-- Interesting, monthly weather data
--
CREATE OR REPLACE VIEW v_monthly_weather AS (
  WITH monthly_sums AS (
    SELECT year(ref_date)                   AS year,
           month(ref_date)                  AS month,
           sum(precipitation_sum)           AS precipitation,
           sum(sunshine_duration) / 60 / 60 AS sunshine_duration,
           avg((temperature_2m_min + temperature_2m_max) / 2)  temperature_2m
    FROM   daily_weather_data
    GROUP BY ALL
  )
  SELECT month,
         round(avg(precipitation), 2)       AS average_precipitation_mm,
         round(avg(sunshine_duration), 2)   AS average_sunshine_duration_h,
         round(avg(temperature_2m), 2)      AS average_temperature
  FROM monthly_sums
  GROUP BY month
  ORDER BY month
);