CREATE OR REPLACE VIEW v_average_production_per_month AS (
    WITH first_full AS (
       SELECT date_trunc('month', measured_on) AS month
       FROM measurements
       GROUP BY month HAVING cast(count(*)/96 AS int) = date_part('day', last_day(month))
       ORDER BY month LIMIT 1
    ), monthly_sums AS (
        SELECT date_trunc('month', measured_on) AS beginning_of_month,
               sum(production) / 4 / 1000       AS kWh
        FROM measurements, first_full
        WHERE beginning_of_month >= first_full.month
        GROUP BY beginning_of_month
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
