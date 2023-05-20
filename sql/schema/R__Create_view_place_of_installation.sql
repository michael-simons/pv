CREATE OR REPLACE VIEW place_of_installation AS (
    WITH cfg as (
        SELECT 'lat_long' AS name,
               cast(lat.value  AS decimal(7,5)) AS lat,
               cast(long.value AS decimal(7,5)) AS long
        FROM   domain_values lat, domain_values long
        WHERE lat.name = 'LATITUDE'
          AND long.name = 'LONGITUDE'
    ), default_values as (SELECT 'lat_long' AS name, 50.775555 AS lat, 6.083611 AS long)
    SELECT coalesce(cfg.lat, default_values.lat) AS lat,
           coalesce(cfg.long, default_values.long) AS long,
    FROM default_values LEFT OUTER JOIN cfg on default_values.name = cfg.name
);
