CREATE OR REPLACE VIEW best_performing_day AS (
    WITH top_1 AS (
        SELECT date_trunc('day', measured_on) AS value,
               rank() OVER (ORDER BY round(sum(power) / 4 / 1000, 2) DESC)
        FROM production
        GROUP BY value LIMIT 1
    )
    SELECT measured_on, power
    FROM production, top_1
    WHERE date_trunc('day', measured_on) = top_1.value
    ORDER BY measured_on ASC
);