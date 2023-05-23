CREATE TABLE IF NOT EXISTS prices_new (
    id          INTEGER PRIMARY KEY DEFAULT(nextval('prices_primary_key_seq')),
    value       DECIMAL(5,2) NOT NULL, -- Net price before value added tax in ct/kWh
    type        VARCHAR(8) NOT NULL CHECK(type IN ('buy', 'full_sell', 'partial_sell')),
    valid_from  DATE NOT NULL,
    valid_until DATE,
    CONSTRAINT prices_uk UNIQUE (type, valid_from)
);

INSERT INTO prices_new SELECT id, value, CASE WHEN type = 'sell' THEN 'partial_sell' ELSE type END, valid_from, valid_until FROM prices;

DROP TABLE prices;

ALTER TABLE prices_new RENAME TO prices;
