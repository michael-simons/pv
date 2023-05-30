CREATE OR REPLACE VIEW v_yearly_internal_consumption_share AS (
    WITH beginning_of_measurements AS (
        SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
        FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    ), totals AS (
        SELECT date_part('year', measured_on)      AS year,
               sum(production) / 4 / 1000          AS production,
               sum(consumption) / 4 / 1000         AS consumption,
               sum(production - export) / 4 / 1000 AS internal_consumption
        FROM measurements, beginning_of_measurements bom
        WHERE measured_on >= bom.value
        GROUP BY year
    )
    SELECT year,
           CASE WHEN production = 0  THEN 0 ELSE round(internal_consumption / production * 100, 2)  END AS internal_consumption,
           CASE WHEN consumption = 0 THEN 0 ELSE round(internal_consumption / consumption * 100, 2) END AS autarchy
    FROM totals
);
