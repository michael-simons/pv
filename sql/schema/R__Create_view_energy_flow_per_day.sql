DROP VIEW IF EXISTS production_per_day;
CREATE OR REPLACE VIEW energy_flow_per_day AS (
    SELECT date_trunc('day', measured_on)       AS Day,
           round(sum(production)  / 4 / 1000, 2) AS 'Production (kWh)',
           round(sum(consumption) / 4 / 1000, 2) AS 'Consumption (kWh',
           round(sum(export)  / 4 / 1000, 2)     AS 'Export (kWh)',
           round(sum(import) / 4 / 1000, 2)      AS 'Import (kWh)'
    FROM measurements
    GROUP BY Day
);
