-- of_stash schema. Applied automatically at first boot by src/server/db.lua (CREATE TABLE IF NOT
-- EXISTS), so importing this file by hand is optional. Item contents are NOT stored here — the
-- active inventory (ox_inventory, etc.) persists those under the stash's inventory key.

CREATE TABLE IF NOT EXISTS `of_stashes` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `stash_key`        VARCHAR(64)  NOT NULL,                -- stable inventory key (unique)
    `label`            VARCHAR(128) NOT NULL,
    `owner_type`       ENUM('personal','job','gang','shared','code') NOT NULL DEFAULT 'personal',
    `owner_value`      VARCHAR(255) NULL,                    -- identifier / job / gang / shared list
    `min_grade`        INT          NOT NULL DEFAULT 0,      -- job/gang minimum grade
    `access_code`      VARCHAR(32)  NULL,                    -- owner_type = 'code'
    `interaction`      ENUM('target','marker','prop','float') NOT NULL DEFAULT 'target',
    `coords`           JSON         NULL,                    -- {x,y,z}
    `heading`          FLOAT        NOT NULL DEFAULT 0.0,
    `prop_model`       VARCHAR(64)  NULL,
    `blip`             JSON         NULL,                    -- {enabled,sprite,color,scale,label}
    `slots`            INT          NOT NULL DEFAULT 50,
    `max_weight`       INT          NOT NULL DEFAULT 100000, -- grams
    `unit_tier`        VARCHAR(32)  NULL,                    -- set when this row is a storage unit
    `rentable`         TINYINT(1)   NOT NULL DEFAULT 0,      -- 1 = players can rent/buy this unit
    `rent_expires`     INT          NULL,                    -- unix seconds; NULL = owned outright
    `metadata`         JSON         NULL,
    `created_by`       VARCHAR(64)  NULL,                    -- admin identifier / 'system'
    `created_at`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_stash_key` (`stash_key`),
    KEY `idx_owner` (`owner_type`, `owner_value`),
    KEY `idx_unit` (`unit_tier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
