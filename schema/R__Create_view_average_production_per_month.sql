CREATE OR REPLACE VIEW v_average_production_per_month AS (
    WITH monthly_sums AS (
        SELECT month(measured_on)              AS month,
               sum(production) / 4 / 1000      AS kWh
        FROM measurements
        GROUP BY month
    ), monthly_solar AS (
        SELECT month(measured_on)              AS month,
               sum(shortwave_radiation) / 1000 AS kWh_mm,
               round(avg(temperature_2m), 2)   AS temperature
        FROM weather_data
        GROUP BY month
    )
    SELECT month                               AS month,
           round(avg(kWh), 2)                  AS production,
           round(avg(kWh_mm), 2)               AS shortwave_radiation,
           any_value(temperature)              AS temperature
    FROM monthly_sums
    LEFT OUTER JOIN monthly_solar w USING (month)
    GROUP BY month
    ORDER BY month ASC
);
