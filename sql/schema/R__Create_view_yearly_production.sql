CREATE OR REPLACE VIEW yearly_production AS (
    WITH per_day AS (
        SELECT date_trunc('day', measured_on) AS day,
               sum(power) / 4 / 1000 AS v
        FROM production
        GROUP BY day
    ), totals AS (
      SELECT date_part('year',  day) AS Year,
             round(min(v), 2)        AS worst,
             round(max(v), 2)        AS best,
             round(avg(v), 2)        AS daily_avg,
             round(median(v), 2)     AS daily_median,
             round(sum(v), 2)        AS total
      FROM per_day
      WHERE v <> 0
      GROUP BY year
    )
    SELECT Year,
           totals.worst        AS 'Worst day',
           totals.best         AS 'Best day',
           totals.daily_avg    AS 'Daily average',
           totals.daily_median AS 'Median',
           totals.total        AS 'Total production',
           CAST (CASE WHEN dv.value IS NULL THEN NULL
                      ELSE round(totals.total / CAST(dv.value AS NUMERIC), 2) END AS NUMERIC)
                               AS 'Total yield (kWh/kWp)'
    FROM totals LEFT OUTER JOIN domain_values dv ON (dv.name = 'INSTALLED_PEAK_POWER')
);
