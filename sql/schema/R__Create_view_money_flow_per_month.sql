CREATE OR REPLACE VIEW money_flow_per_month AS (
    WITH beginning_of_measurements AS (
            SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
            FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    ),
    per_month AS (
        SELECT date_trunc('month', measured_on) AS month,
            sum(production) / 4 / 1000  AS production,
            sum(consumption) / 4 / 1000 AS consumption,
            sum(export) / 4 / 1000      AS export,
            sum(import) / 4 / 1000      AS import
        FROM measurements, beginning_of_measurements bom
        WHERE measured_on >= bom.value
        GROUP BY month
    )
    SELECT per_month.month AS 'Month',
            round(sum(buy.gross * per_month.import) / 100.0, 2)                                 AS 'Delivery costs',
            round(sum(sell.value * per_month.export) / 100.0, 2)                                AS 'Remuneration for feeding',
            round(sum(buy.gross * per_month.import - sell.value * per_month.export) / 100.0, 2) AS 'Balance',
            round(sum(buy.gross * (per_month.production - per_month.export)) / 100.0, 2)        AS 'Benefit through internal consumption'
    FROM per_month
    ASOF LEFT JOIN _buying_prices buy
        ON per_month.month >= buy.valid_from
    ASOF LEFT JOIN _selling_prices sell
        ON per_month.month >= sell.valid_from AND sell.type = 'partial_sell'
    GROUP BY per_month.month
    ORDER BY per_month.month
);
