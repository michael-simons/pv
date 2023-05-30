CREATE OR REPLACE VIEW v_average_production_per_hour AS (
    SELECT date_part('hour', measured_on)   AS hour,
           round(avg(production) / 1000, 2) AS production
    FROM measurements
    GROUP BY hour
    ORDER BY hour
);
