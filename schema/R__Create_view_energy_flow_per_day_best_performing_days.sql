CREATE OR REPLACE VIEW v_best_performing_days AS (
    WITH top_1 AS (
        SELECT year(day) AS year,
               day AS value,
               rank() OVER (PARTITION BY year ORDER BY production DESC) AS rnk
        FROM v_energy_flow_per_day
        QUALIFY rnk = 1
        ORDER BY day
    )
    SELECT year,
           m.measured_on,
           production,
           w.shortwave_radiation,
           c.cloud_cover_low AS cloud_coverage
    FROM measurements m
    ASOF LEFT JOIN weather_data w ON w.measured_on - INTERVAL 1 hour <= m.measured_on
    ASOF LEFT JOIN weather_data c ON c.measured_ON <= m.measured_on,
    top_1
    WHERE date_trunc('day', m.measured_on) = top_1.value
    ORDER BY m.measured_on ASC
);
