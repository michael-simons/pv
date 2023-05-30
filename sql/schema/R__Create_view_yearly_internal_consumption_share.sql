CREATE OR REPLACE VIEW yearly_internal_consumption_share AS (
    WITH beginning_of_measurements AS (
        SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
        FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    ), totals AS (
        SELECT date_part('year', measured_on) AS Year,
               sum(production) / 4 / 1000     AS production,
               sum(consumption) / 4 / 1000    AS consumption,
               sum(export) / 4 / 1000         AS export
        FROM measurements, beginning_of_measurements bom
        WHERE measured_on >= bom.value
        GROUP BY year
    )
    SELECT Year,
           round((production - export) / production * 100, 2)  AS 'Internal consumption in %',
           round((production - export) / consumption * 100, 2) AS 'Autarchy in %'
    FROM totals
);
