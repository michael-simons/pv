CREATE OR REPLACE VIEW v_accumulated_yearly_co2_savings AS (
    WITH beginning_of_measurements AS (
        SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
        FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    ),
    per_day AS (
        SELECT date_trunc('day', measured_on) AS day,
               sum(production) / 4 / 1000 AS production,
               sum(export)     / 4 / 1000 AS export
        FROM measurements, beginning_of_measurements bom
        WHERE measured_on >= bom.value
        GROUP BY day
    )
    SELECT date_part('year',  day) AS year,
           round(sum(co2.value * (production - export)) / 1000.0, 2)        AS total,
      FROM per_day ASOF LEFT JOIN co2_factor_per_year co2
        ON date_part('year',  day) >= co2.year
      GROUP BY date_part('year',  day)
);
