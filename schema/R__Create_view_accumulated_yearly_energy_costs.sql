CREATE OR REPLACE VIEW v_accumulated_yearly_energy_costs AS (
    WITH months AS (
        SELECT range AS value
        FROM range(time_bucket(INTERVAL '1 Year', today()), time_bucket(INTERVAL '1 Year', today()) + INTERVAL '1 Year', INTERVAL '1 Month')
    ),
    per_month AS (
        SELECT date_trunc('month', ifnull(m.measured_on, months.value))       AS month,
               sum(coalesce(production,  0)) / 4 / 1000 AS production,
               sum(coalesce(consumption, 0)) / 4 / 1000 AS consumption,
               sum(coalesce(export,      0)) / 4 / 1000 AS export,
               sum(coalesce(import,      0)) / 4 / 1000 AS import
        FROM measurements m FULL OUTER JOIN months ON date_trunc('month', m.measured_on) = months.value
        GROUP BY month
    )
    SELECT per_month.month,
           round(sum(buy.gross * per_month.consumption) OVER ordered_months / 100.0, 2) AS cost_without_pv,
           round(sum(buy.gross * per_month.import - sell.value * per_month.export) OVER ordered_months / 100.0, 2) AS cost_with_pv
    FROM per_month
    ASOF LEFT JOIN v__buying_prices buy
        ON per_month.month >= buy.valid_from
    ASOF LEFT JOIN v__selling_prices sell
        ON per_month.month >= sell.valid_from AND sell.type = 'partial_sell'
    WINDOW
        ordered_months AS (PARTITION BY year(per_month.month) ORDER BY per_month.month ASC)
    ORDER BY per_month.month ASC
);
