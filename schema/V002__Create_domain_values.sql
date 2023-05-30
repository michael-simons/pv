CREATE SEQUENCE IF NOT EXISTS domain_values_primary_key_seq;
CREATE TABLE IF NOT EXISTS domain_values (
    id                 INTEGER PRIMARY KEY DEFAULT(nextval('domain_values_primary_key_seq')),
    name               VARCHAR(512) NOT NULL,
    value              VARCHAR(512) NOT NULL,
    description        VARCHAR(1024) NOT NULL,
    CONSTRAINT domain_values_uk UNIQUE (name)
);
