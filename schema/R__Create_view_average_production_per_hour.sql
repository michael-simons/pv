CREATE OR REPLACE VIEW v_average_production_per_hour   AS (
    SELECT hour(m.measured_on)                         AS hour,
           round(avg(production) / 1000, 2)            AS production,
           round(avg(s.shortwave_radiation) / 1000, 2) AS shortwave_radiation
    FROM measurements m
    ASOF LEFT JOIN weather_data t USING (measured_on)
    ASOF LEFT JOIN weather_data s ON s.measured_on - INTERVAL 1 hour <= m.measured_on
    GROUP BY hour
    ORDER BY hour
);
