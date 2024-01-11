DROP VIEW IF EXISTS v_best_performing_day;
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
           shortwave_radiation
    FROM measurements m
    ASOF LEFT JOIN weather_data w ON w.measured_on - INTERVAL 1 hour <= m.measured_on, top_1
    WHERE date_trunc('day', m.measured_on) = top_1.value
    ORDER BY m.measured_on ASC
);
