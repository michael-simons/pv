CREATE OR REPLACE VIEW v_monthly_number_of_measurements AS (
  SELECT year(measured_on) AS y, month(measured_on) AS m, cast(count(*) / 96.0 AS int) AS days
  FROM measurements 
  GROUP BY ALL order BY ALL
);
