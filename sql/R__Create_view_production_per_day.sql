CREATE OR REPLACE VIEW production_per_day AS (
    SELECT date_trunc('day', measured_on) AS Day,
           round(sum(power) / 4 / 1000, 2) AS 'Energy (kWh)'
    FROM production
    GROUP BY Day
);
