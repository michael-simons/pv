CREATE OR REPLACE VIEW v_average_production_per_month AS (
    WITH monthly_sums AS (
        SELECT date_trunc('month', measured_on)     AS month,
               round(sum(production) / 4 / 1000, 2) AS kWh
        FROM measurements
        GROUP BY month
    )
    SELECT month    AS month,
           avg(kWh) AS production
    FROM monthly_sums
    GROUP BY month
    ORDER BY month ASC
);
