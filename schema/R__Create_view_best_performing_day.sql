CREATE OR REPLACE VIEW v_best_performing_day AS (
    WITH top_1 AS (
        SELECT date_trunc('day', measured_on) AS value,
               rank() OVER (ORDER BY round(sum(production) / 4 / 1000, 2) DESC) AS rnk
        FROM measurements
        GROUP BY value 
        QUALIFY rnk = 1
    )
    SELECT m.measured_on, 
           production,
           shortwave_radiation
    FROM measurements m
    ASOF LEFT JOIN weather_data w ON w.measured_on + INTERVAL 1 hour <= m.measured_on, top_1
    WHERE date_trunc('day', m.measured_on) = top_1.value
    ORDER BY m.measured_on ASC
);
