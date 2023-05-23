-- CREATE OR REPLACE VIEW money_wip AS (
    WITH ppm AS (
        SELECT date_trunc('month', measured_on) AS month,
               sum(production) / 4 / 1000 AS value
        FROM measurements
        GROUP BY month
    ), raw_values AS (
        SELECT ppm.month, sum(sell.value * ppm.value) OVER(ORDER BY ppm.month ASC) AS value
        FROM ppm ASOF LEFT JOIN selling_prices sell ON ppm.month >= sell.valid_from AND sell.type = 'partial_sell'
    )
    SELECT raw_values.month, round(raw_values.value / 100,2) AS "Total net compensation in EUR"
    FROM raw_values
    ORDER BY month ASC
--);
;
