CREATE OR REPLACE VIEW v_accumulated_yearly_energy_costs AS (
    WITH beginning_of_measurements AS (
        SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
        FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    ),
    months as (
        SELECT range AS value, greatest(range, bom.value) AS start, range + INTERVAL '1 Month' AS end
        FROM range(time_bucket(INTERVAL '1 Year', today()), time_bucket(INTERVAL '1 Year', today()) + INTERVAL '1 Year', INTERVAL '1 Month'),
        beginning_of_measurements bom
    ),
    per_month AS (
        SELECT months.value                             AS month,
               sum(coalesce(production,  0)) / 4 / 1000 AS production,
               sum(coalesce(consumption, 0)) / 4 / 1000 AS consumption,
               sum(coalesce(export,      0)) / 4 / 1000 AS export,
               sum(coalesce(import,      0)) / 4 / 1000 AS import
        FROM months LEFT OUTER JOIN measurements m ON m.measured_on BETWEEN months.start AND months.end
        GROUP BY month
    )
    SELECT per_month.month,
           round(sum(buy.gross * per_month.consumption) OVER (ORDER BY per_month.month ASC) / 100.0, 2) AS cost_without_pv,
           round(sum(buy.gross * per_month.import - sell.value * per_month.export) OVER (ORDER BY per_month.month ASC) / 100.0, 2) AS cost_with_pv
    FROM per_month
    ASOF LEFT JOIN v__buying_prices buy
        ON per_month.month >= buy.valid_from
    ASOF LEFT JOIN v__selling_prices sell
        ON per_month.month >= sell.valid_from AND sell.type = 'partial_sell'
    ORDER BY per_month.month ASC
);
