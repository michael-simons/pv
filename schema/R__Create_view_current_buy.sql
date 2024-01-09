CREATE OR REPLACE VIEW v_current_buy AS (
    WITH latest_price AS (
        SELECT rank() OVER (ORDER BY valid_from DESC, valid_until DESC NULLS FIRST) as pos, valid_from, valid_until, value
        FROM prices
        WHERE type = 'buy'
        QUALIFY pos = 1
    ), latest_tax AS (
        SELECT value
        FROM applicable_vat_values
        ORDER BY valid_from DESC
        LIMIT 1
    )
    SELECT latest_price.value                                      AS net,
           latest_tax.value                                        AS tax,
           round(latest_price.value * (latest_tax.value + 1.0), 2) AS gross
    FROM latest_price, latest_tax
);
