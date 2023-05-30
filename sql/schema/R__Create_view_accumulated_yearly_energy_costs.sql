CREATE OR REPLACE VIEW accumulated_yearly_energy_costs AS (
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
        WHERE measured_on BETWEEN greatest(time_bucket(interval '1 year', today()), bom.value) AND today() + interval '1 day'
        GROUP BY month
    )
    SELECT per_month.month,
           round(sum(buy.gross * per_month.consumption) OVER (ORDER BY per_month.month ASC) / 100.0, 2) AS cost_without_pv,
           round(sum(buy.gross * per_month.import - sell.value * per_month.export) OVER (ORDER BY per_month.month ASC) / 100.0, 2) AS cost_with_pv
    FROM per_month
    ASOF LEFT JOIN _buying_prices buy
        ON per_month.month >= buy.valid_from
    ASOF LEFT JOIN _selling_prices sell
        ON per_month.month >= sell.valid_from AND sell.type = 'partial_sell'
);
