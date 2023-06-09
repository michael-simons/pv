CREATE OR REPLACE VIEW v_amortization AS (
    WITH acquisition_cost AS (
        SELECT coalesce(cast(any_value(value) AS numeric),0) AS value
        FROM domain_values WHERE name = 'ACQUISITION_COST'
    ),
    beginning_of_measurements AS (
        SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
        FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    ),
    per_month AS (
        SELECT date_trunc('month', measured_on) AS month,
               sum(production) / 4 / 1000  AS production,
               sum(consumption) / 4 / 1000 AS consumption,
               sum(export) / 4 / 1000      AS export,
               sum(import) / 4 / 1000      AS import
        FROM beginning_of_measurements bom, measurements
        WHERE date_trunc('day', measured_on) >= bom.value
        GROUP BY month
    )
    SELECT per_month.month,
           -acquisition_cost.value + round(sum(full_sell.value * per_month.production) OVER ordered_months / 100.0, 2)
                AS full_export,
           -acquisition_cost.value + coalesce(round(sum(part_sell.value * per_month.export + buy.gross * (per_month.production - per_month.export)) OVER ordered_months / 100.0), 0) 
                AS partial_export
    FROM acquisition_cost CROSS JOIN per_month
    ASOF LEFT JOIN v__selling_prices part_sell
        ON per_month.month >= part_sell.valid_from AND part_sell.type = 'partial_sell'
    ASOF LEFT JOIN v__selling_prices full_sell
        ON per_month.month >= full_sell.valid_from AND full_sell.type = 'full_sell'
    ASOF LEFT JOIN v__buying_prices buy
        ON per_month.month >= buy.valid_from
    WINDOW
        ordered_months AS (ORDER BY per_month.month ASC)
    ORDER BY per_month.month ASC
);
