WITH hourly_averages AS (
    SELECT date_part('hour', measured_on) AS Hour,
           avg(power)                     AS Wh
    FROM production
    GROUP BY ROLLUP(Hour)
    ORDER BY Hour ASC NULLS LAST
)
SELECT hour,
       lpad(round(Wh / 1000, 2), 8, ' ') || ' ' ||
       CASE
         WHEN hour IS NULL THEN ''
         ELSE bar(floor(Wh), 0, 10530)
       END AS 'Average energy produced (kWh)'
FROM hourly_averages;
