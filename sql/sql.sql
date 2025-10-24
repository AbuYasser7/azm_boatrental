-- ====================================================
--  AZM Boat Rental SQL Schema
--  Built for Al Azm County by abuyasser (discord.gg/azm)
-- ====================================================

CREATE TABLE IF NOT EXISTS `azm_boat_shops` (
  `id` INT NOT NULL PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL,
  `owner_identifier` VARCHAR(64) DEFAULT NULL,
  `owner_name` VARCHAR(64) DEFAULT NULL,
  `expires_at` DATETIME DEFAULT NULL,
  `balance` INT DEFAULT 0,
  `platform_fee_pct` INT DEFAULT 0,
  `deposit_default` INT DEFAULT 0,
  `ped_x` FLOAT DEFAULT 0,
  `ped_y` FLOAT DEFAULT 0,
  `ped_z` FLOAT DEFAULT 0,
  `ped_h` FLOAT DEFAULT 0,
  `menu_x` FLOAT DEFAULT 0,
  `menu_y` FLOAT DEFAULT 0,
  `menu_z` FLOAT DEFAULT 0,
  `menu_h` FLOAT DEFAULT 0,
  `blip_x` FLOAT DEFAULT 0,
  `blip_y` FLOAT DEFAULT 0,
  `blip_z` FLOAT DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ====================================================

CREATE TABLE IF NOT EXISTS `azm_boat_shop_spawns` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `shop_id` INT NOT NULL,
  `x` FLOAT NOT NULL,
  `y` FLOAT NOT NULL,
  `z` FLOAT NOT NULL,
  `h` FLOAT NOT NULL,
  FOREIGN KEY (`shop_id`) REFERENCES `azm_boat_shops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ====================================================

CREATE TABLE IF NOT EXISTS `azm_boat_prices` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `shop_id` INT NOT NULL,
  `model` VARCHAR(50) NOT NULL,
  `label` VARCHAR(50) NOT NULL,
  `price` INT DEFAULT 0,
  `min_price` INT DEFAULT 0,
  `max_price` INT DEFAULT 2147483647,
  FOREIGN KEY (`shop_id`) REFERENCES `azm_boat_shops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ====================================================

CREATE TABLE IF NOT EXISTS `azm_boat_rentals` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `identifier` VARCHAR(64) NOT NULL,
  `shop_id` INT NOT NULL,
  `model` VARCHAR(50) NOT NULL,
  `plate` VARCHAR(20) NOT NULL,
  `rented_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `returned_at` DATETIME DEFAULT NULL,
  `deposit_taken` INT DEFAULT 0,
  `status` ENUM('active', 'returned', 'destroyed', 'abandoned') DEFAULT 'active',
  FOREIGN KEY (`shop_id`) REFERENCES `azm_boat_shops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ====================================================
-- Default Seed Example (optional) — synchronized with shared/config.lua
-- ====================================================

INSERT INTO `azm_boat_shops`
(`id`, `name`, `balance`, `platform_fee_pct`, `deposit_default`,
 `ped_x`, `ped_y`, `ped_z`, `ped_h`,
 `menu_x`, `menu_y`, `menu_z`, `menu_h`,
 `blip_x`, `blip_y`, `blip_z`)
VALUES
(1, 'استئجار قوارب العزم لوس', 0, 10, 100,
  23.77, -2806.98, 5.7, 2.38,
  23.77, -2806.98, 5.7, 2.38,
  23.77, -2806.98, 5.7),
(2, 'استئجار قوارب العزم بوليتو', 0, 10, 100,
 -281.12, 6635.53, 7.56, 230.26,
 -281.12, 6635.53, 7.56, 230.26,
 -281.12, 6635.53, 7.56);

-- Prices for shop 1 and shop 2 (keep labels in Arabic consistent with config)
INSERT INTO `azm_boat_prices` (`shop_id`, `model`, `label`, `price`, `min_price`, `max_price`) VALUES
(1, 'dinghy2', 'قارب صغير', 3000, 2000, 8000),
(1, 'seashark', 'جيت سكي', 4000, 2000, 9000),
(1, 'speeder', 'سبيدر', 6000, 4000, 10000),
(1, 'toro', 'تورو', 8000, 5000, 12000),
(1, 'jetmax', 'جيتماكس', 10000, 6000, 15000),
(2, 'dinghy2', 'قارب صغير', 3000, 2000, 8000),
(2, 'seashark', 'جيت سكي', 4000, 2000, 9000),
(2, 'speeder', 'سبيدر', 6000, 4000, 10000),
(2, 'toro', 'تورو', 8000, 5000, 12000),
(2, 'jetmax', 'جيتماكس', 10000, 6000, 15000);

-- Spawns (synchronized with AZM.Shops.spawns in shared/config.lua)
INSERT IGNORE INTO azm_boat_shop_spawns (shop_id, x, y, z, h) VALUES (1, 14.88, -2822.49, 7.03, 5.79);
INSERT IGNORE INTO azm_boat_shop_spawns (shop_id, x, y, z, h) VALUES (1, 24.88, -2826.72, 5.54, 4.60);
INSERT IGNORE INTO azm_boat_shop_spawns (shop_id, x, y, z, h) VALUES (1, 37.58, -2825.81, 5.54, 2.87);

INSERT IGNORE INTO azm_boat_shop_spawns (shop_id, x, y, z, h) VALUES (2, -291.59, 6635.82, 3.00, 16.62);
INSERT IGNORE INTO azm_boat_shop_spawns (shop_id, x, y, z, h) VALUES (2, -285.34, 6637.68, 3.00, 75.29);
INSERT IGNORE INTO azm_boat_shop_spawns (shop_id, x, y, z, h) VALUES (2, -279.55, 6643.45, 3.00, 9.22);
