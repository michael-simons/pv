CREATE OR REPLACE VIEW peaks AS (
    WITH mm AS (
        SELECT min(production) AS _min, max(production) AS _max
        FROM measurements
        WHERE production <> 0.0
    )
    SELECT round(production, 2) AS production,
           max(measured_on) AS last_time_measured
    FROM mm JOIN measurements ON (production = mm._min OR production = mm._max)
    GROUP BY production
    ORDER BY production ASC
);
