-- noinspection SqlResolveForFile

--
-- Beginning of measurements
--
CREATE OR REPLACE VIEW v$_beginning_of_measurements AS (
 SELECT coalesce(cast(any_value(value) AS date), (SELECT min(measured_on) FROM measurements)) AS value
 FROM domain_values WHERE name = 'FIRST_PROPER_READINGS_ON'
);


--
-- Consecutive list of buying prices
--
DROP VIEW IF EXISTS v__buying_prices;
CREATE OR REPLACE VIEW v$_buying_prices AS (
  -- Make sure we have a list of consecutive prices by traversing them recursively
  WITH RECURSIVE buy(valid_from, valid_until, value) AS (
      SELECT valid_from, valid_until, value FROM prices p
      WHERE type = 'buy' AND NOT EXISTS (SELECT '' FROM prices o WHERE o.type = p.type AND o.valid_from < p.valid_from AND valid_until IS NOT NULL)
      UNION ALL
      SELECT p.valid_from, p.valid_until, p.value
      FROM prices p, buy
      WHERE p.type = 'buy'
        AND p.valid_from = buy.valid_until + INTERVAL 1 DAY
  )
  SELECT greatest(buy.valid_from, vat.valid_from) AS valid_from,
         least(buy.valid_until, vat.valid_until)  AS valid_until,
         buy.value                                AS net,
         round((buy.value - coalesce(lag(buy.value) OVER ordered_prices, buy.value)) / coalesce(lag(buy.value) OVER ordered_prices, buy.value), 4)
                                                  AS change,
         vat.value                                AS tax,
         round(buy.value * (vat.value + 1.0), 2)  AS gross
  FROM buy
  -- Join in all valid applicable taxes in the validity period of the price
  JOIN applicable_vat_values vat ON (
      vat.valid_from >= buy.valid_from AND vat.valid_from <= buy.valid_until OR
      vat.valid_from < buy.valid_from  AND coalesce(vat.valid_until, current_date()) > buy.valid_from
  )
  WINDOW
      ordered_prices AS (ORDER BY greatest(buy.valid_from, vat.valid_from))
  ORDER BY valid_from ASC
);


--
-- Same for selling
--
DROP VIEW IF EXISTS v__selling_prices;
CREATE OR REPLACE VIEW v$_selling_prices AS (
    -- Make sure we have a list of consecutive prices by traversing them recursively
    WITH RECURSIVE sell(valid_from, valid_until, value, type) AS (
        SELECT valid_from, valid_until, value, p.type FROM prices p
        WHERE type IN ('partial_sell', 'full_sell') AND NOT EXISTS (SELECT '' FROM prices o WHERE o.type = p.type AND o.valid_from < p.valid_from AND valid_until IS NOT NULL)
        UNION ALL
        SELECT p.valid_from, p.valid_until, p.value, p.type
        FROM prices p, sell
        WHERE p.type = sell.type
          AND p.valid_from = sell.valid_until + INTERVAL 1 DAY
    )
    SELECT sell.valid_from    AS valid_from,
           sell.valid_until   AS valid_until,
           sell.value         AS value,
           sell.type          AS type
    FROM sell
    ORDER BY valid_from ASC
);
