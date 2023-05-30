CREATE OR REPLACE VIEW overall_internal_consumption_share AS (
    WITH beginning_of_measurements AS (
        SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
        FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    ), totals AS (
        SELECT sum(production) / 4 / 1000  AS production,
               sum(consumption) / 4 / 1000 AS consumption,
               sum(export) / 4 / 1000      AS export
        FROM measurements, beginning_of_measurements bom
        WHERE measured_on >= bom.value
    )
    SELECT coalesce(round((production - export) / production  * 100, 2), 0) AS 'Internal consumption in %',
           coalesce(round((production - export) / consumption * 100, 2), 0) AS 'Autarchy in %'
    FROM totals
);
