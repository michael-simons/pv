WITH per_day AS (
    SELECT sum(power) / 4 / 1000 AS v
    FROM production
    GROUP BY date_trunc('day', measured_on)
)
SELECT round(min(v), 2)    AS 'Worst day',
       round(max(v), 2)    AS 'Best day',
       round(avg(v), 2)    AS 'Daily average',
       round(median(v), 2) AS 'Median',
       round(sum(v), 2)    AS 'Total production'
FROM per_day
WHERE v <> 0;
