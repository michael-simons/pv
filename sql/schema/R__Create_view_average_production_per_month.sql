CREATE OR REPLACE VIEW average_production_per_month AS (
    WITH monthly_sums AS (
        SELECT date_trunc('month', measured_on)     AS produced_in,
               round(sum(production) / 4 / 1000, 2) AS kWh
        FROM measurements
        GROUP BY produced_in
        ORDER BY produced_in ASC
    ), monthly_averages AS (
        SELECT time_bucket(INTERVAL '1 Month', produced_in) AS month,
               avg(kWh)                                     AS production
        FROM monthly_sums
        GROUP BY ROLLUP(month)
    ), max_kWH AS (
        SELECT max(production) AS value FROM monthly_averages
    )
    SELECT month,
           production,
           CASE
             WHEN monthly_averages.Month IS NULL THEN ''
             ELSE bar(floor(production), 0, floor(max_kWH.value))
           END AS viz
    FROM monthly_averages, max_kWH
    ORDER BY monthly_averages.Month ASC NULLS LAST
);
