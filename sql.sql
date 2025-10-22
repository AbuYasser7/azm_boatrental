-- =========================================
-- Al Azm County — Advanced Boat Rental (ESX)
-- Database Schema — by abuyasser (discord.gg/azm)
-- Version: 2.1.0
-- =========================================

-- Main boat shops table
CREATE TABLE IF NOT EXISTS `azm_boat_shops` (
  `id` INT PRIMARY KEY,
  `name` VARCHAR(64) NOT NULL,
  `owner_identifier` VARCHAR(64) DEFAULT NULL,
  `owner_name` VARCHAR(64) DEFAULT NULL,
  `expires_at` DATETIME DEFAULT NULL,
  `balance` INT NOT NULL DEFAULT 0,
  `platform_fee_pct` INT DEFAULT 0,
  `deposit_default` INT DEFAULT 0,
  `ped_x` DOUBLE, `ped_y` DOUBLE, `ped_z` DOUBLE, `ped_h` DOUBLE,
  `menu_x` DOUBLE, `menu_y` DOUBLE, `menu_z` DOUBLE, `menu_h` DOUBLE,
  `blip_x` DOUBLE, `blip_y` DOUBLE, `blip_z` DOUBLE,
  INDEX(`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Spawn points for each shop
CREATE TABLE IF NOT EXISTS `azm_boat_shop_spawns` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `shop_id` INT NOT NULL,
  `x` DOUBLE, `y` DOUBLE, `z` DOUBLE, `h` DOUBLE,
  CONSTRAINT `fk_shop_spawn` FOREIGN KEY (`shop_id`) REFERENCES `azm_boat_shops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Boat catalog and price configuration
CREATE TABLE IF NOT EXISTS `azm_boat_prices` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `shop_id` INT NOT NULL,
  `model` VARCHAR(32) NOT NULL,
  `label` VARCHAR(48) NOT NULL,
  `price` INT NOT NULL,
  `min_price` INT DEFAULT 0,
  `max_price` INT DEFAULT 2147483647,
  CONSTRAINT `fk_shop_price` FOREIGN KEY (`shop_id`) REFERENCES `azm_boat_shops`(`id`) ON DELETE CASCADE,
  UNIQUE KEY `uniq_shop_model` (`shop_id`, `model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Active and historical rentals
CREATE TABLE IF NOT EXISTS `azm_boat_rentals` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `identifier` VARCHAR(64) NOT NULL,
  `shop_id` INT NOT NULL,
  `model` VARCHAR(32) NOT NULL,
  `plate` VARCHAR(12) NOT NULL,
  `rented_at` DATETIME NOT NULL,
  `returned_at` DATETIME DEFAULT NULL,
  `deposit_taken` INT DEFAULT 0,
  `status` ENUM('active','returned','destroyed','abandoned') NOT NULL DEFAULT 'active',
  CONSTRAINT `fk_rentals_shop` FOREIGN KEY (`shop_id`) REFERENCES `azm_boat_shops`(`id`) ON DELETE CASCADE,
  INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================================
-- Default data seeding (optional)
-- =========================================
INSERT IGNORE INTO `azm_boat_shops` (`id`, `name`, `balance`) VALUES
(1, 'Boat Shop 1', 0),
(2, 'Boat Shop 2', 0),
(3, 'Boat Shop 3', 0);

-- Default boats (seeded per shop)
INSERT IGNORE INTO `azm_boat_prices` (`shop_id`, `model`, `label`, `price`)
VALUES
(1, 'dinghy2', 'Dinghy', 300),
(1, 'seashark', 'Seashark', 250),
(1, 'speeder', 'Speeder', 600),
(2, 'dinghy2', 'Dinghy', 300),
(2, 'seashark', 'Seashark', 250),
(3, 'dinghy2', 'Dinghy', 300);

-- =========================================
-- End of File
-- Designed for مقاطعة العزم — Al Azm County
-- by abuyasser (discord.gg/azm)
-- =========================================
