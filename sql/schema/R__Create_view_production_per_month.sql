CREATE OR REPLACE VIEW production_per_month AS (
    SELECT date_trunc('month', measured_on)     AS Month,
           round(sum(production) / 4 / 1000, 2) AS 'Energy (kWh)'
    FROM measurements
    GROUP BY rollup(Month)
    ORDER BY Month ASC NULLS LAST
);
