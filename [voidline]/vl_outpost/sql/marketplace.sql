-- =============================================================================
-- vl_outpost -- marketplace schema
-- =============================================================================
-- Rebuilt 2026-09-08 after the resource folder was accidentally deleted.
-- This is a FRESH schema, not a recovered original -- market/server.lua and
-- this file were the two pieces that never touch the game client, so there
-- was nothing in FXServer's own resource cache to pull them back from, and
-- no prior conversation had their real content either. Written to match
-- exactly what the recovered market/client.lua and ui/market.js expect.

CREATE TABLE IF NOT EXISTS `vl_outpost_listings` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `seller` VARCHAR(50) NOT NULL,              -- citizenid, not a server id
    `sellerName` VARCHAR(100) NOT NULL,
    `item` VARCHAR(50) NOT NULL,
    `quantity` INT NOT NULL,
    `price` INT NOT NULL DEFAULT 0,             -- 0 when it's a trade listing
    `metadata` LONGTEXT NULL,                   -- JSON, ox_inventory item metadata
    `tradeItem` VARCHAR(50) NULL,
    `tradeQuantity` INT NULL,
    `createdAt` INT NOT NULL,                   -- unix timestamp
    PRIMARY KEY (`id`),
    KEY `idx_listings_seller` (`seller`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vl_outpost_buy_orders` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `buyer` VARCHAR(50) NOT NULL,
    `buyerName` VARCHAR(100) NOT NULL,
    `item` VARCHAR(50) NOT NULL,
    `quantity` INT NOT NULL,
    `price` INT NOT NULL DEFAULT 0,
    `tradeItem` VARCHAR(50) NULL,
    `tradeQuantity` INT NULL,
    `createdAt` INT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_orders_buyer` (`buyer`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Whatever a listing sale or a fulfilled buy order owes someone who wasn't
-- online (or had no inventory space) to receive it the instant the deal
-- happened. Claimed later from the Pickups tab.
CREATE TABLE IF NOT EXISTS `vl_outpost_pickups` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `owner` VARCHAR(50) NOT NULL,               -- citizenid who can claim this
    `sellerName` VARCHAR(100) NOT NULL,          -- who the payout/item came from
    `item` VARCHAR(50) NOT NULL,
    `quantity` INT NOT NULL,
    `metadata` LONGTEXT NULL,
    `price` INT NOT NULL DEFAULT 0,
    `totalPrice` INT NOT NULL DEFAULT 0,
    `fulfilledTimestamp` INT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_pickups_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vl_outpost_history` (
    `id` INT NOT NULL AUTO_INCREMENT,
    -- listing | purchase | buyOrder | fulfill | listingCancel | buyOrderCancel
    `type` VARCHAR(20) NOT NULL,
    `item` VARCHAR(50) NOT NULL,
    `quantity` INT NOT NULL DEFAULT 0,
    `price` INT NOT NULL DEFAULT 0,
    `totalPrice` INT NOT NULL DEFAULT 0,
    `sellerName` VARCHAR(100) NULL,
    `buyerName` VARCHAR(100) NULL,
    `timestamp` INT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_history_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
