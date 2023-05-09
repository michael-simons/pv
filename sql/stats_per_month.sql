SELECT date_trunc('month', measured_on) AS Month,
       round(sum(power) / 4 / 1000, 2) AS 'Energy (kWh)'
FROM production
GROUP BY rollup(Month)
ORDER BY Month ASC NULLS LAST;

