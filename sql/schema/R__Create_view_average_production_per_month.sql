CREATE OR REPLACE VIEW average_production_per_month AS (
    WITH monthly_sums AS (
        SELECT date_trunc('month', measured_on)     AS produced_in,
               round(sum(production) / 4 / 1000, 2) AS kWh
        FROM measurements
        GROUP BY produced_in
        ORDER BY produced_in ASC
    ), monthly_averages AS (
        SELECT date_part('month', produced_in) AS Month,
               avg(kWh)                        AS kWh
        FROM monthly_sums
        GROUP BY ROLLUP(Month)
    ), max_kWH AS (
        SELECT max(kWh) AS value FROM monthly_averages
    )
    SELECT strftime(make_date(0, Month, 1), '%B') AS Month,
           kWh,
           CASE
             WHEN monthly_averages.Month IS NULL THEN ''
             ELSE bar(floor(kWh), 0, floor(max_kWH.value))
           END AS 'Average energy produced'
    FROM monthly_averages, max_kWH
    ORDER BY monthly_averages.Month ASC NULLS LAST
);
