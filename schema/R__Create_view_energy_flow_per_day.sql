CREATE OR REPLACE VIEW v_energy_flow_per_day AS (
    WITH beginning_of_measurements AS (
      SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
      FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    )
    SELECT date_trunc('day', measured_on)               AS day,
           round(sum(production)  / 4 / 1000, 2)        AS production,
           round(sum(consumption) / 4 / 1000, 2)        AS consumption,
           round(sum(import) / 4 / 1000, 2)             AS import,
           round(sum(export)  / 4 / 1000, 2)            AS export,
           round(sum(production - export )  / 4 / 1000) AS internal_consumption
    FROM measurements, beginning_of_measurements bom
    WHERE measured_on >= bom.value
    GROUP BY day
);
