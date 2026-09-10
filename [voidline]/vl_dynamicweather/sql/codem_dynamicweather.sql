-- codem-dynamicweather · SQL storage
-- When Config.Storage = 'sql', this table is created AUTOMATICALLY on start.
-- Provided only for manual/optional setup:

CREATE TABLE IF NOT EXISTS `codem_dynamicweather` (
    `id`   INT NOT NULL PRIMARY KEY,
    `data` LONGTEXT NOT NULL
);
