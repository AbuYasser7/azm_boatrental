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
  `ped_model` VARCHAR(64) DEFAULT NULL,
  `menu_x` FLOAT DEFAULT 0,
  `menu_y` FLOAT DEFAULT 0,
  `menu_z` FLOAT DEFAULT 0,
  `menu_h` FLOAT DEFAULT 0,
  `blip_x` FLOAT DEFAULT 0,
  `blip_y` FLOAT DEFAULT 0,
  `blip_z` FLOAT DEFAULT 0,
  `blip_sprite` INT DEFAULT NULL,
  `blip_colour` INT DEFAULT NULL,
  `blip_scale` FLOAT DEFAULT 0.8,
  `return_x` FLOAT DEFAULT NULL,
  `return_y` FLOAT DEFAULT NULL,
  `return_z` FLOAT DEFAULT NULL,
  `return_w` FLOAT DEFAULT NULL,
  `return_l` FLOAT DEFAULT NULL,
  `return_h` FLOAT DEFAULT NULL,
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

-- =========================
-- Seed / Sync (idempotent)
-- Use ON DUPLICATE KEY UPDATE to keep DB in sync with shared/config.lua
-- =========================

-- Shops (3 shops as in config)
INSERT INTO azm_boat_shops (id, name, balance, platform_fee_pct, deposit_default,
  ped_x, ped_y, ped_z, ped_h, ped_model,
  menu_x, menu_y, menu_z, menu_h,
  blip_x, blip_y, blip_z,
  return_x, return_y, return_z, return_w, return_l, return_h)
VALUES
(1, 'استئجار قوارب العزم لوس', 0, 10, 100,
  23.77, -2806.98, 5.7, 2.38, 'a_m_y_surfer_01',
  23.77, -2806.98, 5.7, 2.38,
  23.77, -2806.98, 5.7,
  -5.82, -2768.88, 4.96, 8.0, 8.0, 3.0),
(2, 'استئجار قوارب العزم بوليتو', 0, 10, 100,
 -281.12, 6635.53, 7.56, 230.26, 'a_m_y_beach_02',
 -281.12, 6635.53, 7.56, 230.26,
 -281.12, 6635.53, 7.56,
 -806.12, -1498.12, 0.2, 8.0, 8.0, 3.0),
(3, 'استئجار قوارب غرب ساندي', 0, 10, 100,
 -3427.2, 967.62, 8.34, 281.54, 'a_m_y_beach_02',
 -3427.2, 967.62, 8.34, 281.54,
 -3427.2, 967.62, 8.34,
 -3313.96, 952.91, -0.38, 8.0, 8.0, 3.0)
ON DUPLICATE KEY UPDATE
  name = VALUES(name), balance = VALUES(balance), platform_fee_pct = VALUES(platform_fee_pct),
  deposit_default = VALUES(deposit_default), ped_x = VALUES(ped_x), ped_y = VALUES(ped_y),
  ped_z = VALUES(ped_z), ped_h = VALUES(ped_h), ped_model = VALUES(ped_model),
  menu_x = VALUES(menu_x), menu_y = VALUES(menu_y), menu_z = VALUES(menu_z), menu_h = VALUES(menu_h),
  blip_x = VALUES(blip_x), blip_y = VALUES(blip_y), blip_z = VALUES(blip_z),
  return_x = VALUES(return_x), return_y = VALUES(return_y), return_z = VALUES(return_z),
  return_w = VALUES(return_w), return_l = VALUES(return_l), return_h = VALUES(return_h);

-- Prices: use AZM.Boats list for shops 1-3
INSERT INTO azm_boat_prices (shop_id, model, label, price, min_price, max_price) VALUES
(1, 'dinghy2', 'قارب صغير', 8000, 2000, 2147483647),
(1, 'seashark', 'جيت سكي', 8000, 2000, 2147483647),
(1, 'speeder', 'سبيدر', 8000, 4000, 2147483647),
(1, 'toro', 'تورو', 8000, 5000, 2147483647),
(1, 'jetmax', 'جيتماكس', 8000, 6000, 2147483647),
(2, 'dinghy2', 'قارب صغير', 8000, 2000, 2147483647),
(2, 'seashark', 'جيت سكي', 8000, 2000, 2147483647),
(2, 'speeder', 'سبيدر', 8000, 4000, 2147483647),
(2, 'toro', 'تورو', 8000, 5000, 2147483647),
(2, 'jetmax', 'جيتماكس', 8000, 6000, 2147483647),
(3, 'dinghy2', 'قارب صغير', 8000, 2000, 2147483647),
(3, 'seashark', 'جيت سكي', 8000, 2000, 2147483647),
(3, 'speeder', 'سبيدر', 8000, 4000, 2147483647),
(3, 'toro', 'تورو', 8000, 5000, 2147483647),
(3, 'jetmax', 'جيتماكس', 8000, 6000, 2147483647)
ON DUPLICATE KEY UPDATE
  price = VALUES(price), label = VALUES(label), min_price = VALUES(min_price), max_price = VALUES(max_price);

-- Spawns (INSERT IGNORE to avoid duplicates)
INSERT IGNORE INTO azm_boat_shop_spawns (shop_id, x, y, z, h) VALUES
(1, 14.88, -2822.49, 7.03, 5.79),
(1, 24.88, -2826.72, 5.54, 4.60),
(1, 37.58, -2825.81, 5.54, 2.87),
(2, -291.59, 6635.82, 3.00, 16.62),
(2, -285.34, 6637.68, 3.00, 75.29),
(2, -279.55, 6643.45, 3.00, 9.22),
(3, -3438.2, 981.87, 0.10, 85.27),
(3, -3443.66, 963.05, 0.03, 89.82),
(3, -3436.9, 930.46, 0.01, 64.63);
