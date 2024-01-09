CREATE OR REPLACE VIEW v_best_performing_day AS (
    WITH top_1 AS (
        SELECT date_trunc('day', measured_on) AS value,
               rank() OVER (ORDER BY round(sum(production) / 4 / 1000, 2) DESC) AS rnk
        FROM measurements
        GROUP BY value 
        QUALIFY rnk = 1
    )
    SELECT measured_on, production
    FROM measurements, top_1
    WHERE date_trunc('day', measured_on) = top_1.value
    ORDER BY measured_on ASC
);
