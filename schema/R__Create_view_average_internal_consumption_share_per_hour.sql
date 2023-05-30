CREATE OR REPLACE VIEW v_average_internal_consumption_share_per_hour AS (
    WITH beginning_of_measurements AS (
        SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
        FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    ),
    hours as (SELECT range AS value FROM range(0, 24, 1)),
    totals AS (
        SELECT date_part('hour', measured_on) AS hour,
               avg(production)          AS production,
               avg(consumption)         AS consumption,
               avg(production - export) AS internal_consumption
        FROM measurements, beginning_of_measurements bom
        WHERE measured_on >= bom.value
        GROUP BY hour
    )
    SELECT hours.value AS hour,
           CASE WHEN coalesce(production, 0)  = 0 THEN 0 ELSE round(internal_consumption / production * 100, 2)  END AS internal_consumption,
           CASE WHEN coalesce(consumption, 0) = 0 THEN 0 ELSE round(internal_consumption / consumption * 100, 2) END AS autarchy
    FROM hours left outer join totals on totals.hour = hours.value
    ORDER BY hours.value ASC
);
