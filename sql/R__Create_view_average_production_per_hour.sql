CREATE OR REPLACE VIEW average_production_per_hour AS (
    WITH hourly_averages AS (
        SELECT date_part('hour', measured_on) AS Hour,
               avg(power)                     AS Wh
        FROM production
        GROUP BY ROLLUP(Hour)
        ORDER BY Hour ASC NULLS LAST
    ), max_Wh AS (
        SELECT max(Wh) AS value FROM hourly_averages
    )
    SELECT hour,
           round(Wh / 1000, 2) AS kWh,
           CASE
             WHEN hour IS NULL THEN ''
             ELSE bar(floor(Wh), 0, floor(max_Wh.value))
           END AS 'Average energy produced'
    FROM hourly_averages, max_Wh
);
