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
