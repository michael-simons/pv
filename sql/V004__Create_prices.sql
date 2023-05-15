CREATE SEQUENCE IF NOT EXISTS prices_primary_key_seq;
CREATE TABLE IF NOT EXISTS prices (
    id          INTEGER PRIMARY KEY DEFAULT(nextval('prices_primary_key_seq')),
    value       DECIMAL(5,2) NOT NULL, -- Net price before value added tax in ct/kWh
    type        VARCHAR(8) NOT NULL CHECK(type IN ('buy', 'sell')),
    valid_from  DATE NOT NULL,
    valid_until DATE,
    CONSTRAINT prices_uk UNIQUE (type, valid_from)
);
