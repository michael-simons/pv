CREATE OR REPLACE VIEW v_average_consumption_per_month_and_hour AS (
    WITH beginning_of_measurements AS (
        SELECT coalesce(date_trunc('month', cast(any_value(value) AS date) + interval 1 month), (SELECT min(measured_on) FROM measurements)) AS value
        FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
    ),
    consumption_per_month_and_hour AS (
        SELECT any_value(date_part('month', measured_on))AS month,
               any_value(date_part('hour', measured_on)) AS hour,
               avg(consumption) / 1000                   AS consumption
          FROM measurements, beginning_of_measurements bom
         WHERE measured_on >= bom.value
         GROUP BY date_trunc('hour', measured_on)
         ORDER BY Hour
    )
    PIVOT consumption_per_month_and_hour
    ON month IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
    USING avg(consumption)
    GROUP BY hour
    ORDER BY hour
);
