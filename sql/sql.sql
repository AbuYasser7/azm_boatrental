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
-- Default Seed Example (optional)
-- ====================================================

INSERT INTO `azm_boat_shops`
(`id`, `name`, `balance`, `platform_fee_pct`, `deposit_default`,
 `ped_x`, `ped_y`, `ped_z`, `ped_h`,
 `menu_x`, `menu_y`, `menu_z`, `menu_h`,
 `blip_x`, `blip_y`, `blip_z`)
VALUES
(1, 'Al Azm Marina 1', 0, 10, 100,
 -1600.08, -1176.98, 0.51, 300.47,
 -1600.08, -1176.98, 1.51, 0.88,
 -1600.08, -1176.98, 1.51);

INSERT INTO `azm_boat_prices` (`shop_id`, `model`, `label`, `price`, `min_price`, `max_price`) VALUES
(1, 'dinghy2', 'قارب صغير', 3000, 2000, 8000),
(1, 'seashark', 'جيت سكي', 4000, 2000, 9000),
(1, 'speeder', 'سبيدر', 6000, 4000, 10000),
(1, 'toro', 'تورو', 8000, 5000, 12000),
(1, 'jetmax', 'جيتماكس', 10000, 6000, 15000);
