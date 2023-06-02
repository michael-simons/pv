CREATE OR REPLACE VIEW v_average_energy_flow_per_day AS (
    WITH beginning_of_measurements AS (
      SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
      FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    ),
    per_day AS (
      SELECT date_trunc('day', measured_on)        AS day,
             sum(production)  / 4 / 1000           AS production,
             sum(consumption) / 4 / 1000           AS consumption,
             sum(import) / 4 / 1000                AS import,
             sum(production - export )  / 4 / 1000 AS internal_consumption
      FROM measurements, beginning_of_measurements bom
      WHERE measured_on >= bom.value
      GROUP BY day
    )
    SELECT date_part('dayofyear', day)         AS dayofyear,
           round(avg(production), 2)           AS production,
           round(avg(consumption), 2)          AS consumption,
           round(avg(import), 2)               AS import,
           round(avg(internal_consumption), 2) AS internal_consumption
    FROM per_day
    GROUP BY dayofyear
);
