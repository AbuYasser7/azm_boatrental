# ⚓ Al Azm County — Advanced Boat Rental (ESX)
*Developed by **abuyasser** — [discord.gg/azm](https://discord.gg/azm)*

Fully featured and customizable **ESX Boat Rental System** built for **مقاطعة العزم — Al Azm County**.  
Includes multi-shop ownership, vaults, platform fees, deposits, cooldowns, and admin controls — all powered by **ox_lib**, **ox_target**, and **oxmysql**.

---

## 🧭 Overview
This system lets players rent boats from multiple rental points.  
Each shop can have its **own owner**, **pricing**, **vault**, **expiry date**, and **spawn points**.  
Superadmins can manage ownership, platform fees, and financial settings.

---

## 🧩 Core Features
- 🏝 **Multiple Boat Shops**
  - Each shop with its own ped, blip, spawn, and return zone.
  - Owners assigned by license (ESX identifier).
  - Optional ownership expiry (30 / 120 days or unlimited).

- 💰 **Vault System**
  - Tracks all shop income.
  - Owners and superadmins can withdraw or deposit funds.

- ⚙️ **Dynamic Pricing**
  - Per-boat adjustable prices (with enforced min/max limits).
  - Superadmin command to enforce limits for each model.

- 💵 **Platform Fee + Deposits**
  - Server keeps a % as platform revenue.
  - Security deposit on rental — refundable or forfeited based on return/destroy status.

- ⏳ **Cooldown Logic**
  - 1 rental per hour only if last boat was **abandoned**.
  - Returning or destroying a boat resets cooldown immediately.

- 🧑‍✈️ **Admin / Owner Control**
  - Full command suite and owner panel (lib menus).
  - Real-time balance updates and secure transaction logging.

---

## 🗺 Folder Structure
```
azm_boatrental/
├─ fxmanifest.lua
├─ LICENSE
├─ README.md
├─ .gitignore
├─ sql/
│  └─ sql.sql
├─ shared/
│  └─ config.lua
├─ client/
│  └─ main.lua
└─ server/
   └─ main.lua
```

---

## ⚙️ Installation
1. Ensure dependencies are installed and running:
   - `ox_lib`, `ox_target`, `oxmysql`, and **new** `es_extended`
2. Import    ```bash /sql/sql.sql``` into your database.
3. Place the folder in your resources and add to your `server.cfg`:
   ```bash
   ensure ox_lib
   ensure ox_target
   ensure oxmysql
   ensure es_extended
   ensure azm_boatrental
   ```
4. Restart your server — shops will be auto-seeded into the DB if not found.
5. Assign shop owners using the admin command below.

---

## 🧠 Commands

| Command | Role | Description |
|----------|------|-------------|
| `/boatshop_setowner <shopId> <serverId> <days>` | Superadmin | Assigns shop owner (0 = unlimited) |
| `/boatshop_getlicense <serverId>` | Superadmin | Displays player’s ESX identifier |
| `/boatshop_setlimits <shopId> <model> <minPrice> <maxPrice>` | Superadmin | Sets min/max allowed price |
| `/boatshop_setfee <shopId> <feePct>` | Superadmin | Sets platform fee percentage |
| `/boatshop_deposit <shopId> <amount>` | Owner/Superadmin | Deposit funds into vault |
| `/boatshop_withdraw <shopId> <amount>` | Owner/Superadmin | Withdraw funds from vault |
| `/boatshop` | Owner | Opens owner panel when near their shop |

---

## 🧾 Money Flow
| Event | Action |
|--------|--------|
| Rent Boat | Player pays (price + deposit) |
| Platform Fee | % of price added to server revenue |
| Owner Earnings | Remainder stored in shop vault |
| Boat Returned | Deposit refunded (configurable) |
| Boat Destroyed/Abandoned | Deposit forfeited or refunded (configurable) |

---

## 🧱 Database Schema
Tables created by `sql.sql`:
- `azm_boat_shops`
- `azm_boat_shop_spawns`
- `azm_boat_prices`
- `azm_boat_rentals`

Each table is relational and supports automatic seeding on first start.

---

## ⚙️ Configuration (config.lua)
| Setting | Description |
|----------|--------------|
| `AZM.CooldownMinutes` | Delay before next rental after abandonment |
| `AZM.Boats` | Default list of rentable boats |
| `AZM.Shops` | Shop coordinates, peds, blips, spawns |
| `AZM.Groups.SuperAdmin` | Permissions for server management |

---

## 🪙 Developer Notes
- Built with **ox_lib context menus** and **ox_target zones**.
- Fully compatible with **new ESX exports** system.
- Optimized for low resource usage and modular scaling.
- All main logic refactored to support multiple owners, concurrent rentals, and SQL-based persistence.

---

## 🖋 Credits
Designed and Developed for **مقاطعة العزم — Al Azm County**  
By **abuyasser** — [discord.gg/azm](https://discord.gg/azm)

© 2025 All Rights Reserved  
Distributed under the **MIT License**.