CREATE OR REPLACE VIEW average_production_per_month_and_hour AS (
    WITH production_per_month_and_hour AS (
        SELECT any_value(strftime(measured_on, '%B'))    AS Month,
               any_value(date_part('hour', measured_on)) AS Hour,
               avg(production) / 1000                    AS Energy
          FROM measurements
         GROUP BY date_trunc('hour', measured_on)
         ORDER BY Hour
    )
    SELECT *
    FROM production_per_month_and_hour
    PIVOT (
        round(avg(Energy), 2)
        FOR Month IN ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December')
        GROUP BY Hour
    )
);
