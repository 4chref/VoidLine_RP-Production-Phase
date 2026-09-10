-- vl_identity: unique 3-digit identity number storage.
-- The column stays INT so characters created under the old 4-digit range keep
-- working; only newly generated numbers come from VLConfig.IdMin..IdMax.
-- The resource runs this automatically on start (MariaDB syntax).
-- Run manually only if the automatic migration fails.

ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `voidline_id` INT UNSIGNED NULL DEFAULT NULL;
ALTER TABLE `players` ADD UNIQUE INDEX IF NOT EXISTS `voidline_id` (`voidline_id`);
