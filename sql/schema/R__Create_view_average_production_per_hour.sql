CREATE OR REPLACE VIEW average_production_per_hour AS (
    WITH hourly_averages AS (
        SELECT date_part('hour', measured_on) AS hour,
               avg(production)                AS production
        FROM measurements
        GROUP BY ROLLUP(Hour)
        ORDER BY Hour ASC NULLS LAST
    ), max_Wh AS (
        SELECT max(production) AS value FROM hourly_averages
    )
    SELECT hour,
           round(production / 1000, 2) AS production,
           CASE
             WHEN hour IS NULL THEN ''
             ELSE bar(floor(production), 0, floor(max_Wh.value))
           END AS viz
    FROM hourly_averages, max_Wh
);
select * from average_production_per_hour;