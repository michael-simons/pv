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