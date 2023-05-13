INSERT INTO domain_values (name, value, description)
VALUES ('INSTALLED_PEAK_POWER', '10.53', 'The installed peak power in kilowatt (kW), usually dubbed kWp.')
ON CONFLICT (name) DO NOTHING;
