CREATE OR REPLACE VIEW average_production_per_month AS (
    WITH monthly_sums AS (
        SELECT date_trunc('month', measured_on) AS produced_in,
               round(sum(power) / 4 / 1000, 2) AS kWh
        FROM production
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
           lpad(kWh,8, ' ') || ' ' ||
           CASE
             WHEN monthly_averages.Month IS NULL THEN ''
             ELSE bar(floor(kWh), 0, floor(max_kWH.value))
           END AS 'Average energy produced (kWh)'
    FROM monthly_averages, max_kWH
    ORDER BY monthly_averages.Month ASC NULLS LAST
);
