CREATE OR REPLACE VIEW peaks AS (
    WITH mm AS (
        SELECT min(power) AS _min, max(power) AS _max
        FROM production
        WHERE power <> 0.0
    )
    SELECT power AS 'Power (W)',
           list(measured_on) AS 'Measured on'
    FROM mm JOIN production ON (power = mm._min OR power = mm._max)
    GROUP BY power
);
