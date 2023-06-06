CREATE OR REPLACE VIEW v_weekly_quartiles AS (
    WITH per_day AS (
        SELECT date_trunc('day', measured_on)               AS day,
               round(sum(production)  / 4 / 1000, 2)        AS production,
        FROM measurements
        GROUP BY day
    )
    SELECT date_trunc('week', day) AS sow,
           date_part('week', day) AS week,
           min(production) AS min,
           quantile_cont(production, [0.25, 0.5, 0.75]) AS quartiles,
           max(production) AS max,
    FROM per_day
    GROUP BY sow, week
    ORDER BY sow, week
);
