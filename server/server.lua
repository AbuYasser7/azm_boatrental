-- azm_boatrental/server/main.lua
-- Built for Al Azm County by abuyasser (discord.gg/azm)

local ESX = nil
pcall(function() ESX = exports['es_extended']:getSharedObject() end)
if not ESX then TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end) end
if not ESX then
    print("^3[azm_boatrental]^7 ESX not found. Make sure 'es_extended' starts before this resource.")
end

---@class ActiveRental
--- @field shop_id number
--- @field identifier string
--- @field plate string
--- @field started number (os.time)

local ShopsCache = {}
local ActiveRentals = {}            -- identifier -> ActiveRental
local AbandonedTimes = {}           -- identifier -> last abandoned time (os.time)

-- خزنة موارد المدينة (تُجمع فيها حصة المدينة من كل إيجار)
local PlatformVault = 0

-- ====== Config flags ======
local REFUND_DEPOSIT_ON_RETURN   = true
local FORFEIT_DEPOSIT_ON_DESTROY = true

-- يمكنك ضبط نصف قطر التحقق من خلو السباون من الـ config لاحقًا إن رغبت
local SPAWN_CLEAR_RADIUS = (AZM and AZM.SpawnClearRadius) or 5.0

-- ====== Colors ======
local COLOR_INFO    = 3447003
local COLOR_SUCCESS = 5763719
local COLOR_WARN    = 15105570
local COLOR_ERROR   = 15548997

-- ====== Webhook Helper ======
local function sendLog(title, message, color)
    if not AZM or not AZM.Logs or not AZM.Logs.enable then return end
    local webhook = AZM.Webhooks and AZM.Webhooks.main
    if not webhook then return end

    local payload = {
        username = AZM.Logs.username or "azm_boatrental",
        avatar_url = AZM.Logs.avatar,
        embeds = {{
            title = title,
            description = message,
            color = color or COLOR_INFO,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    PerformHttpRequest(webhook, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- ====== Notify Helper (يحترم AZM.Notify) ======
local function notify(src, msg, typ)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.showNotification then
        xPlayer.showNotification(msg)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { msg } })
    end
end

-- ====== Helpers ======
local function isSuperAdmin(xPlayer)
    if not xPlayer then return false end
    if xPlayer.getGroup then
        local grp = xPlayer.getGroup()
        if grp and AZM and AZM.Groups and AZM.Groups.SuperAdmin then
            for _, g in ipairs(AZM.Groups.SuperAdmin) do
                if grp == g then return true end
            end
        end
    end
    -- fallback: try xPlayer.getPermissions or groups table if exists
    return false
end

-- ====== Helper: get player identifier safely ======
-- Accepts: server id (number), ESX xPlayer object, or identifier string -> returns identifier string or nil
local function iden(playerOrSource)
    if not playerOrSource then return nil end

    -- if given identifier string already
    if type(playerOrSource) == 'string' then
        return playerOrSource
    end

    -- if given numeric server id
    if type(playerOrSource) == 'number' then
        local ids = GetPlayerIdentifiers(playerOrSource)
        if ids and #ids > 0 then
            return ids[1]
        end
        return nil
    end

    -- if given ESX player object
    if type(playerOrSource) == 'table' then
        -- common properties in different ESX versions
        if playerOrSource.identifier and type(playerOrSource.identifier) == 'string' then
            return playerOrSource.identifier
        end
        if playerOrSource.getIdentifier and type(playerOrSource.getIdentifier) == 'function' then
            local ok, id = pcall(playerOrSource.getIdentifier, playerOrSource)
            if ok and type(id) == 'string' then return id end
        end
        -- sometimes ESX passes player.source in object
        if playerOrSource.source and type(playerOrSource.source) == 'number' then
            local ids = GetPlayerIdentifiers(playerOrSource.source)
            if ids and #ids > 0 then return ids[1] end
        end
    end

    return nil
end

-- ====== DB Loading ======
local function loadShops()
    local rows = MySQL.query.await('SELECT * FROM azm_boat_shops') or {}
    local prices = MySQL.query.await('SELECT * FROM azm_boat_prices') or {}
    local spawns = MySQL.query.await('SELECT * FROM azm_boat_shop_spawns') or {}

    local priceMap = {}
    for _, p in ipairs(prices) do
        priceMap[p.shop_id] = priceMap[p.shop_id] or {}
        priceMap[p.shop_id][p.model] = {
            label = p.label,
            price = tonumber(p.price) or 0,
            min_price = tonumber(p.min_price) or 0,
            max_price = tonumber(p.max_price) or 2147483647
        }
    end

    local spawnMap = {}
    for _, sp in ipairs(spawns) do
        spawnMap[sp.shop_id] = spawnMap[sp.shop_id] or {}
        spawnMap[sp.shop_id][#spawnMap[sp.shop_id]+1] = { x = tonumber(sp.x), y = tonumber(sp.y), z = tonumber(sp.z), h = tonumber(sp.h) }
    end

    ShopsCache = {}
    for _, s in ipairs(rows) do
        -- parse expires_at if exists
        local expires_ts = nil
        if s.expires_at and type(s.expires_at) == 'string' then
            local y,m,d,H,M,S = s.expires_at:match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
            if y then
                expires_ts = os.time({ year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=tonumber(H), min=tonumber(M), sec=tonumber(S) })
            end
        end

        ShopsCache[s.id] = {
            id = s.id,
            name = s.name,
            owner_identifier = s.owner_identifier,
            owner_name = s.owner_name,
            expires_at = s.expires_at,
            expires_at_ts = expires_ts,
            balance = tonumber(s.balance) or 0,
            platform_fee_pct = tonumber(s.platform_fee_pct) or 0,
            deposit_default = tonumber(s.deposit_default) or 0,
            blip = { x = tonumber(s.blip_x) or 0, y = tonumber(s.blip_y) or 0, z = tonumber(s.blip_z) or 0, sprite = tonumber(s.blip_sprite) or 455, colour = tonumber(s.blip_colour) or 5, scale = tonumber(s.blip_scale) or 0.8 },
            ped  = { x = tonumber(s.ped_x) or 0, y = tonumber(s.ped_y) or 0, z = tonumber(s.ped_z) or 0, heading = tonumber(s.ped_h) or 0, model = s.ped_model or 'a_m_y_surfer_01' },
            menu = { x = tonumber(s.menu_x) or 0, y = tonumber(s.menu_y) or 0, z = tonumber(s.menu_z) or 0, heading = tonumber(s.menu_h) or 0 },
            returnZone = (s.return_x and { x=tonumber(s.return_x), y=tonumber(s.return_y), z=tonumber(s.return_z), w = tonumber(s.return_w) or 6.0, l = tonumber(s.return_l) or 6.0, h = tonumber(s.return_h) or 2.0 } ) or nil,
            spawns = spawnMap[s.id] or {},
            prices = priceMap[s.id] or {}
        }
    end

    -- push to clients
    TriggerClientEvent('azm_boats:setupShops', -1, ShopsCache)
end

-- load shops on resource start
CreateThread(function()
    Wait(1000)
    loadShops()
    sendLog("🔄 Resource Start", "azm_boatrental started and shops loaded.", COLOR_INFO)
end)

-- ====== Client Sync ======
RegisterNetEvent('azm_boats:clientReady', function()
    local src = source
    TriggerClientEvent('azm_boats:setupShops', src, ShopsCache)
end)

-- ====== Ownership check callback (يحدد إذا اللاعب مالك الفرع أو سوبرأدمن) =====
ESX.RegisterServerCallback('azm_boats:isOwner', function(src, cb, shopId)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return cb(false) end
    local identifier = iden(xPlayer)
    local shop = ShopsCache[shopId]
    if not shop then return cb(false) end
    if shop.owner_identifier == identifier or isSuperAdmin(xPlayer) then
        cb(true)
    else
        cb(false)
    end
end)

-- ====== Owner transfer event (سيرفر) =====
RegisterNetEvent('azm_boats:transferOwner', function(shopId, targetServerId, days)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if not isSuperAdmin(xPlayer) then
        notify(src, "لا تملك صلاحية نقل ملكية المتجر. هذه الخاصية للسوبرأدمن فقط.", 'error')
        return
    end

    -- بقية منطق النقل كما كان (كما في النسخة السابقة)
    local shop = ShopsCache[shopId]
    if not shop then
        notify(src, "المتجر غير موجود.", 'error'); return
    end

    local target = ESX.GetPlayerFromId(tonumber(targetServerId))
    if not target then notify(src, "اللاعب الهدف غير متصل.", 'error'); return end

    local targetIdentifier = iden(target)
    local targetName = target.getName and target.getName() or ("#" .. tostring(targetServerId))
    local expires_sql = nil
    if tonumber(days) and tonumber(days) > 0 then
        expires_sql = ("DATE_ADD(NOW(), INTERVAL %d DAY)"):format(tonumber(days))
    end

    if expires_sql then
        MySQL.update.await('UPDATE azm_boat_shops SET owner_identifier = ?, owner_name = ?, expires_at = ' .. expires_sql .. ' WHERE id = ?', { targetIdentifier, targetName, shopId })
    else
        MySQL.update.await('UPDATE azm_boat_shops SET owner_identifier = ?, owner_name = ?, expires_at = NULL WHERE id = ?', { targetIdentifier, targetName, shopId })
    end

    loadShops()
    notify(src, "تم نقل ملكية المتجر بنجاح.", 'success')
    notify(target.source or tonumber(targetServerId), ("تم منحك ملكية المتجر: %s"):format(shop.name or ("#" .. shopId)), 'success')
    sendLog("🔁 Ownership Transferred (admin)", ("Shop %s (ID %d) transferred to %s by %s"):format(shop.name or ("#"..shopId), shopId, targetName, xPlayer.getName()), COLOR_INFO)
end)

-- ====== Helper: server-side localization (SL) ======
local function SL(key, ...)
    local loc = (AZM and AZM.Locales and AZM.Locales[AZM.Locale]) or {}
    local s = loc[key] or key
    if select('#', ...) > 0 then
        return s:format(...)
    end
    return s
end

-- ====== Cooldown Logic ======
local function canPlayerRent(identifier)
    if ActiveRentals[identifier] then
        return false, SL('error.active_rental')
    end
    local lastAbandoned = AbandonedTimes[identifier]
    if lastAbandoned then
        local diff = os.time() - lastAbandoned
        local wait = (AZM.CooldownMinutes * 60) - diff
        if wait > 0 then
            local m = math.floor(wait/60)
            local s = wait % 60
            return false, SL('error.must_wait', m, s)
        end
    end
    return true
end

-- ====== Rental Core (تعديل: تقسيم السعر بين مالك المتجر وحصة المدينة) =====
-- فحص خلوّ السباون (OneSync)
-- old isSpawnClear used GetAllVehicles (not valid on server). Replace with safe stub (يمكن تحسين لاحقاً بخبرة OneSync)
local function isSpawnClear(spawn)
    -- لا نفعل فحصاً دقيقاً من السيرفر — إذا رغبت بفحص حقيقي استخدم فحص client-side أو OneSync natives المُمكّنة على السيرفر
    return true
end

local function chooseFreeSpawn(shop)
    if not shop then return nil end
    -- إذا توجد سباونات من القاعدة نعيد أول واحد صالح
    if shop.spawns and #shop.spawns > 0 then
        local s = shop.spawns[1]
        return { x = s.x + 0.0, y = s.y + 0.0, z = s.z + 0.0, h = s.h + 0.0 }
    end

    -- fallback إلى config AZM.Shops إن وُجد تعريف محلي
    if AZM and AZM.Shops then
        for _, s in ipairs(AZM.Shops) do
            if s.id == shop.id and s.spawns and #s.spawns > 0 then
                local sp = s.spawns[1]
                return { x = sp.x + 0.0, y = sp.y + 0.0, z = sp.z + 0.0, h = sp.h + 0.0 }
            end
        end
    end

    return nil
end

local function randPlate()
    return ("AZ%02d%03d"):format(math.random(10,99), math.random(100,999))
end

ESX.RegisterServerCallback('azm_boats:getCatalog', function(src, cb, shopId)
    local shop = ShopsCache[shopId]
    if not shop then return cb({}, false, SL('error.shop_not_found'), '') end

    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = iden(xPlayer)
    local canRent, message = canPlayerRent(identifier)

    local catalog = {}
    for model, info in pairs(shop.prices) do
        catalog[#catalog+1] = {label = info.label, model = model, price = info.price}
    end
    table.sort(catalog, function(a,b) return a.price < b.price end)
    cb(catalog, canRent, message, shop.name)
end)

RegisterNetEvent('azm_boats:requestRent', function(shopId, model)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = iden(xPlayer)
    local shop = ShopsCache[shopId]
    if not shop then return end

    local ok, msg = canPlayerRent(identifier)
    if not ok then
        notify(src, msg, 'error')
        sendLog("⛔ Rent Blocked", ("Player: **%s** (%s)\nReason: %s"):format(xPlayer.getName(), identifier, msg), COLOR_WARN)
        return
    end

    local priceInfo = shop.prices[model]
    if not priceInfo then
        notify(src, SL('error.boat_unavailable'), 'error')
        sendLog("❌ Boat Unavailable", ("Player: **%s** (%s)\nShop: **%s**\nModel: **%s**"):format(xPlayer.getName(), identifier, shop.name, tostring(model)), COLOR_ERROR)
        return
    end

    local price = priceInfo.price or 0
    local minp  = priceInfo.min_price or 0
    local maxp  = priceInfo.max_price or 2147483647
    if price < minp or price > maxp then
        notify(src, SL('error.price_out_of_range', minp, maxp), 'error')
        sendLog("⚠️ Price Out of Range", ("Shop: **%s**\nModel: **%s**\nPrice: **%d** (Allowed: %d - %d)\nBy: **%s** (%s)")
            :format(shop.name, tostring(model), price, minp, maxp, xPlayer.getName(), identifier), COLOR_WARN)
        return
    end

    local deposit = shop.deposit_default or 0
    local platformPct = shop.platform_fee_pct or 0
    if deposit < 0 then deposit = 0 end
    if platformPct < 0 then platformPct = 0 end
    if platformPct > 100 then platformPct = 100 end

    local total = price + deposit
    if xPlayer.getMoney() < total then
        notify(src, SL('error.need_money', total), 'error')
        sendLog("💸 Insufficient Cash", ("Player: **%s** (%s)\nNeeded: **$%d**\nHave: **$%d**")
            :format(xPlayer.getName(), identifier, total, xPlayer.getMoney()), COLOR_WARN)
        return
    end

    local spawn = chooseFreeSpawn(shop)
    if not spawn then
        notify(src, SL('error.no_spawn'), 'error')
        sendLog("🚫 No Spawn", ("Shop: **%s** | Requested by **%s** (%s)"):format(shop.name, xPlayer.getName(), identifier), COLOR_ERROR)
        return
    end

    -- take money (price + deposit)
    xPlayer.removeMoney(total)

    -- تقسيم السعر: platformPct = نسبة خدمة المدينة (مثال: 50%)
    -- owner_share = السعر * (100 - platformPct) / 100
    local owner_share = math.floor(price * (100 - platformPct) / 100)
    local platform_share = price - owner_share

    -- نضيف حصة المالك إلى رصيد المتجر
    MySQL.update.await('UPDATE azm_boat_shops SET balance = balance + ? WHERE id = ?', { owner_share, shopId })
    shop.balance = (shop.balance or 0) + owner_share

    -- نحفظ حصة المدينة داخل الخزنة العامة (قابلة للسحب بأمر سوبرأدمن)
    PlatformVault = PlatformVault + platform_share

    local plate = randPlate()

    -- persist rental
    MySQL.insert.await([[
        INSERT INTO azm_boat_rentals (identifier, shop_id, model, plate, rented_at, deposit_taken, status)
        VALUES (?,?,?,?,NOW(),?,?)
    ]], { identifier, shopId, model, plate, deposit, 'active' })

    ActiveRentals[identifier] = { shop_id = shopId, identifier = identifier, plate = plate, started = os.time() }

    TriggerClientEvent('azm_boats:spawnApproved', src, shopId, model, spawn, plate)
    notify(src, ('Charged $%d (incl. $%d deposit).'):format(total, deposit), 'success')

    sendLog("🛥️ Boat Rented (Split)", ("Player: **%s** (%s)\nShop: **%s** (ID %d)\nModel: **%s**\nPrice: **$%d** | OwnerShare: **$%d** | CityShare: **$%d** | Platform%%: **%d%%**\nPlate: **%s**")
        :format(xPlayer.getName(), identifier, shop.name, shopId, tostring(model), price, owner_share, platform_share, platformPct, plate), COLOR_SUCCESS)
end)

-- ====== أمر سوبرأدمن لسحب حصة المدينة من الخزنة =====
ESX.RegisterCommand('boatshop_claimplatform', {'superadmin'}, function(xPlayer, args, showError)
    if not isSuperAdmin(xPlayer) then return end
    local amt = PlatformVault or 0
    if amt <= 0 then return xPlayer.showNotification('لا توجد أموال في خزنة المدينة.') end
    PlatformVault = 0
    xPlayer.addMoney(amt)
    xPlayer.showNotification(('تم سحب $%d من خزنة المدينة'):format(amt))
    sendLog("🏛️ PlatformVault Claimed", ("By Admin: **%s** | Amount: **$%d**"):format(xPlayer.getName(), amt), COLOR_INFO)
end, true, { help = 'Claim platform vault', arguments = {} })

-- ====== Rental Return / Destruction ======
RegisterNetEvent('azm_boats:returnBoat', function()
    local src      = source
    local xPlayer  = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = iden(xPlayer)
    local active   = ActiveRentals[identifier]
    if not active then return end

    local row = MySQL.single.await([[
        SELECT r.id, r.deposit_taken, r.shop_id, r.model, r.plate
        FROM azm_boat_rentals r
        WHERE r.identifier = ? AND r.plate = ? AND r.status = 'active'
        ORDER BY r.id DESC LIMIT 1
    ]], { identifier, active.plate })

    if not row then
        ActiveRentals[identifier] = nil
        return
    end

    local deposit = row.deposit_taken or 0
    local shopId  = row.shop_id
    if REFUND_DEPOSIT_ON_RETURN and deposit > 0 then
        xPlayer.addMoney(deposit)
        notify(src, ('Deposit $%d refunded.'):format(deposit), 'success')
        sendLog("⚓ Boat Returned (Refunded)", ("Player: **%s** (%s)\nShopID: **%d**\nModel: **%s** | Plate: **%s**\nDeposit Refunded: **$%d**")
            :format(xPlayer.getName(), identifier, shopId, row.model, row.plate, deposit), COLOR_SUCCESS)
    else
        MySQL.update.await('UPDATE azm_boat_shops SET balance = balance + ? WHERE id = ?', { deposit, shopId })
        if ShopsCache[shopId] then
            ShopsCache[shopId].balance = (ShopsCache[shopId].balance or 0) + deposit
        end
        sendLog("⚓ Boat Returned (Deposit Kept)", ("Player: **%s** (%s)\nShopID: **%d**\nModel: **%s** | Plate: **%s**\nDeposit Kept: **$%d**")
            :format(xPlayer.getName(), identifier, shopId, row.model, row.plate, deposit), COLOR_INFO)
    end

    MySQL.update.await([[
        UPDATE azm_boat_rentals
        SET status = 'returned', returned_at = NOW()
        WHERE id = ?
    ]], { row.id })

    ActiveRentals[identifier] = nil
    AbandonedTimes[identifier] = nil
end)

RegisterNetEvent('azm_boats:markDestroyed', function()
    local src       = source
    local xPlayer   = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier= iden(xPlayer)
    local active    = ActiveRentals[identifier]
    if not active then return end

    local row = MySQL.single.await([[
        SELECT r.id, r.deposit_taken, r.shop_id, r.model, r.plate
        FROM azm_boat_rentals r
        WHERE r.identifier = ? AND r.plate = ? AND r.status = 'active'
        ORDER BY r.id DESC LIMIT 1
    ]], { identifier, active.plate })

    if row then
        if FORFEIT_DEPOSIT_ON_DESTROY and (row.deposit_taken or 0) > 0 then
            MySQL.update.await('UPDATE azm_boat_shops SET balance = balance + ? WHERE id = ?', { row.deposit_taken, row.shop_id })
            if ShopsCache[row.shop_id] then
                ShopsCache[row.shop_id].balance = (ShopsCache[row.shop_id].balance or 0) + row.deposit_taken
            end
        end
        MySQL.update.await('UPDATE azm_boat_rentals SET status = ?, returned_at = NOW() WHERE id = ?', { 'destroyed', row.id })
        sendLog("💥 Boat Destroyed", ("Player: **%s** (%s)\nShopID: **%d**\nModel: **%s** | Plate: **%s**\nDeposit Forfeited: **$%d**")
            :format(xPlayer.getName(), identifier, row.shop_id, row.model, row.plate, row.deposit_taken or 0), COLOR_WARN)
    end

    ActiveRentals[identifier] = nil
    AbandonedTimes[identifier] = nil
end)

-- mark abandoned if player drops with active rental -> triggers cooldown
AddEventHandler('playerDropped', function(reason)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = iden(xPlayer)
    local active = ActiveRentals[identifier]
    if active then
        local row = MySQL.single.await([[
            SELECT r.id, r.deposit_taken, r.shop_id, r.model, r.plate
            FROM azm_boat_rentals r
            WHERE r.identifier = ? AND r.plate = ? AND r.status = 'active'
            ORDER BY r.id DESC LIMIT 1
        ]], { identifier, active.plate })

        if row then
            if FORFEIT_DEPOSIT_ON_DESTROY and (row.deposit_taken or 0) > 0 then
                MySQL.update.await('UPDATE azm_boat_shops SET balance = balance + ? WHERE id = ?', { row.deposit_taken, row.shop_id })
                if ShopsCache[row.shop_id] then
                    ShopsCache[row.shop_id].balance = (ShopsCache[row.shop_id].balance or 0) + row.deposit_taken
                end
            end
            MySQL.update.await('UPDATE azm_boat_rentals SET status = ?, returned_at = NOW() WHERE id = ?', { 'abandoned', row.id })
            sendLog("🏳️ Boat Abandoned (playerDropped)", ("Player: **%s** (%s)\nShopID: **%d**\nModel: **%s** | Plate: **%s**\nReason: %s")
                :format(xPlayer.getName(), identifier, row.shop_id, row.model, row.plate, tostring(reason or "unknown")), COLOR_WARN)
        end

        ActiveRentals[identifier] = nil
        AbandonedTimes[identifier] = os.time()
    end
end)

-- ====== Owner/Admin Utilities ======
RegisterNetEvent('azm_boats:reqOwnerMenu', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = iden(xPlayer)
    for _, shop in pairs(ShopsCache) do
        -- تحقق من انتهاء الملكية باستخدام expires_at_ts (تم حفظه عند التحميل)
        if shop.owner_identifier == identifier and (not shop.expires_at_ts or os.time() < shop.expires_at_ts) then
            TriggerClientEvent('azm_boats:openOwnerMenu', src, shop)
            return
        end
    end
    notify(src, 'You are not the owner of a nearby shop.', 'error')
end)

RegisterNetEvent('azm_boats:setPrice', function(shopId, model, newPrice)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = iden(xPlayer)
    local shop = ShopsCache[shopId]
    if not shop then return end
    if shop.owner_identifier ~= identifier and not isSuperAdmin(xPlayer) then return end

    local row = MySQL.single.await('SELECT min_price, max_price FROM azm_boat_prices WHERE shop_id = ? AND model = ?', { shopId, model })
    if not row then return end
    newPrice = tonumber(newPrice) or 0
    if newPrice < (row.min_price or 0) or newPrice > (row.max_price or 2147483647) then
        notify(src, 'Price outside allowed limits.', 'error')
        sendLog("🔧 Price Change FAILED", ("ShopID: **%d** | Model: **%s**\nTried: **$%d** (Allowed: %d - %d)\nBy: **%s** (%s)")
            :format(shopId, tostring(model), newPrice, row.min_price or 0, row.max_price or 2147483647, xPlayer.getName(), identifier), COLOR_ERROR)
        return
    end

    MySQL.update.await('UPDATE azm_boat_prices SET price = ? WHERE shop_id = ? AND model = ?', { newPrice, shopId, model })
    if shop.prices[model] then shop.prices[model].price = newPrice end
    notify(src, 'Price updated.', 'success')
    sendLog("🔧 Price Updated", ("ShopID: **%d** | Model: **%s**\nNew Price: **$%d**\nBy: **%s** (%s)")
        :format(shopId, tostring(model), newPrice, xPlayer.getName(), identifier), COLOR_INFO)
end)

RegisterNetEvent('azm_boats:withdraw', function(shopId, amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = iden(xPlayer)
    local shop = ShopsCache[shopId]
    if not shop then return end
    if shop.owner_identifier ~= identifier and not isSuperAdmin(xPlayer) then return end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local row = MySQL.single.await('SELECT balance FROM azm_boat_shops WHERE id = ?', { shopId })
    if not row or row.balance < amount then
        notify(src, 'Not enough in the vault.', 'error')
        sendLog("🏦 Withdraw FAILED", ("ShopID: **%d**\nRequested: **$%d** | Current: **$%d**\nBy: **%s** (%s)")
            :format(shopId, amount, row and row.balance or 0, xPlayer.getName(), identifier), COLOR_ERROR)
        return
    end

    MySQL.update.await('UPDATE azm_boat_shops SET balance = balance - ? WHERE id = ?', { amount, shopId })
    shop.balance = (shop.balance or 0) - amount
    xPlayer.addMoney(amount)
    notify(src, ('Withdrew $%d'):format(amount), 'success')

    sendLog("🏦 Withdraw", ("ShopID: **%d**\nAmount: **$%d**\nBy: **%s** (%s)"):format(shopId, amount, xPlayer.getName(), identifier), COLOR_SUCCESS)
end)

RegisterNetEvent('azm_boats:deposit', function(shopId, amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = iden(xPlayer)
    local shop = ShopsCache[shopId]
    if not shop then return end
    if shop.owner_identifier ~= identifier and not isSuperAdmin(xPlayer) then return end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    if xPlayer.getMoney() < amount then
        notify(src, 'Not enough cash to deposit.', 'error')
        sendLog("🏦 Deposit FAILED", ("ShopID: **%d**\nAmount: **$%d** | Cash: **$%d**\nBy: **%s** (%s)")
            :format(shopId, amount, xPlayer.getMoney(), xPlayer.getName(), identifier), COLOR_ERROR)
        return
    end

    xPlayer.removeMoney(amount)
    MySQL.update.await('UPDATE azm_boat_shops SET balance = balance + ? WHERE id = ?', { amount, shopId })
    shop.balance = (shop.balance or 0) + amount
    notify(src, ('Deposited $%d'):format(amount), 'success')

    sendLog("🏦 Deposit", ("ShopID: **%d**\nAmount: **$%d**\nBy: **%s** (%s)"):format(shopId, amount, xPlayer.getName(), identifier), COLOR_SUCCESS)
end)

-- ====== Admin Commands ======
ESX.RegisterCommand('boatshop_setowner', {'admin','superadmin'}, function(xPlayer, args, showError)
    if not isSuperAdmin(xPlayer) then return end
    local shopId  = tonumber(args.shop)
    local targetId= tonumber(args.id)
    local days    = tonumber(args.days)
    local t = ESX.GetPlayerFromId(targetId)
    if not t then return showError('Player not online') end

    local ident = iden(t)
    local name  = (t.getName and t.getName()) or GetPlayerName(targetId)
    local expires = nil
    if days and days > 0 then
        expires = os.date('%Y-%m-%d %H:%M:%S', os.time() + (days * 86400))
    end

    MySQL.update.await('UPDATE azm_boat_shops SET owner_identifier = ?, owner_name = ?, expires_at = ? WHERE id = ?', { ident, name, expires, shopId })
    loadShops()
    xPlayer.showNotification(('Shop %d owner set to %s (%s)'):format(shopId, name, ident))

    sendLog("🛂 Set Owner", ("ShopID: **%d**\nOwner: **%s** (`%s`)\nBy Admin: **%s**")
        :format(shopId, name, ident, xPlayer.getName()), COLOR_INFO)
end, true, {help = 'Set boat shop owner', arguments = {
    {name='shop', help='Shop ID', type='number'},
    {name='id', help='Server ID', type='number'},
    {name='days', help='Days (0 = unlimited)', type='number'}
}})

ESX.RegisterCommand('boatshop_getlicense', {'admin','superadmin'}, function(xPlayer, args, showError)
    local targetId = tonumber(args.id)
    local t = ESX.GetPlayerFromId(targetId)
    if not t then return showError('Player not online') end
    local ident = iden(t)
    xPlayer.showNotification(('Identifier: %s'):format(ident))
    sendLog("🆔 Get License", ("Target: **%s** (srv:%d)\nIdentifier: `%s`\nBy Admin: **%s**")
        :format((t.getName and t.getName()) or GetPlayerName(targetId), targetId, ident, xPlayer.getName()), COLOR_INFO)
end, true, {help='Get player license/identifier', arguments={{name='id', type='number', help='Server ID'}}})

ESX.RegisterCommand('boatshop_setlimits', {'admin','superadmin'}, function(xPlayer, args, showError)
    if not isSuperAdmin(xPlayer) then return end
    local shopId = tonumber(args.shop)
    local model  = tostring(args.model or '')
    local minP   = tonumber(args.minp)
    local maxP   = tonumber(args.maxp)
    if not (shopId and model and minP ~= nil and maxP ~= nil and maxP >= minP) then
        return showError('Usage: /boatshop_setlimits <shopId> <model> <minPrice> <maxPrice>')
    end
    local aff = MySQL.update.await('UPDATE azm_boat_prices SET min_price = ?, max_price = ? WHERE shop_id = ? AND model = ?',
        { minP, maxP, shopId, model })
    if aff and aff > 0 then
        if ShopsCache[shopId] and ShopsCache[shopId].prices[model] then
            ShopsCache[shopId].prices[model].min_price = minP
            ShopsCache[shopId].prices[model].max_price = maxP
        end
        xPlayer.showNotification(('Limits updated for %s (shop %d): %d - %d'):format(model, shopId, minP, maxP))
        sendLog("🧱 Set Limits", ("ShopID: **%d** | Model: **%s**\nMin: **$%d** | Max: **$%d**\nBy Admin: **%s**")
            :format(shopId, model, minP, maxP, xPlayer.getName()), COLOR_INFO)
    else
        showError('Model not found for this shop.')
        sendLog("🧱 Set Limits FAILED", ("ShopID: **%d** | Model: **%s**\nBy Admin: **%s**")
            :format(shopId, model, xPlayer.getName()), COLOR_ERROR)
    end
end, true, {help='Set min/max price limits', arguments={
    {name='shop', type='number', help='Shop ID'},
    {name='model', type='string', help='Boat model'},
    {name='minp', type='number', help='Min price'},
    {name='maxp', type='number', help='Max price'}
}})

-- أمر: ضبط نسبة المنصة (platform fee) — سوبرأدمن فقط
ESX.RegisterCommand('boatshop_setfee', {'superadmin'}, function(xPlayer, args, showError)
    local shopId = tonumber(args[1])
    local pct = tonumber(args[2])
    if not shopId or not pct then
        return xPlayer.showNotification('استخدام: /boatshop_setfee <shopId> <percentage>')
    end
    if pct < 0 or pct > 100 then return xPlayer.showNotification('النسبة يجب أن تكون بين 0 و 100') end

    MySQL.update.await('UPDATE azm_boat_shops SET platform_fee_pct = ? WHERE id = ?', { pct, shopId })
    loadShops()
    xPlayer.showNotification(('تم ضبط نسبة المنصة للمحل %d الى %d%%'):format(shopId, pct))
    sendLog("⚙️ set fee", ("Shop %d platform fee set to %d%% by %s"):format(shopId, pct, xPlayer.getName()), COLOR_INFO)
end, true, { help = 'Set platform fee %', arguments = {
    { name = 'shopId', help = 'Shop ID', type = 'number' },
    { name = 'percentage', help = 'Platform fee percentage', type = 'number' }
}})

ESX.RegisterCommand('boatshop_deposit', {'admin','superadmin','user'}, function(xPlayer, args, showError)
    local shopId = tonumber(args.shop)
    local amount = tonumber(args.amount)
    if not (shopId and amount and amount > 0) then
        return showError('Usage: /boatshop_deposit <shopId> <amount>')
    end
    if not isSuperAdmin(xPlayer) then
        local shop = ShopsCache[shopId]
        if not shop or shop.owner_identifier ~= iden(xPlayer) then
            return showError('Not the owner.')
        end
    end
    if xPlayer.getMoney() < amount then
        return showError('Not enough cash.')
    end
    xPlayer.removeMoney(amount)
    MySQL.update.await('UPDATE azm_boat_shops SET balance = balance + ? WHERE id = ?', { amount, shopId })
    if ShopsCache[shopId] then ShopsCache[shopId].balance = (ShopsCache[shopId].balance or 0) + amount end
    xPlayer.showNotification(('Deposited $%d to shop %d'):format(amount, shopId))
    sendLog("🏦 Deposit (cmd)", ("ShopID: **%d**\nAmount: **$%d**\nBy: **%s** (%s)")
        :format(shopId, amount, xPlayer.getName(), iden(xPlayer)), COLOR_SUCCESS)
end, true, {help='Deposit to shop vault', arguments={
    {name='shop', type='number', help='Shop ID'},
    {name='amount', type='number', help='Amount'}
}})

ESX.RegisterCommand('boatshop_withdraw', {'admin','superadmin','user'}, function(xPlayer, args, showError)
    local shopId = tonumber(args.shop)
    local amount = tonumber(args.amount)
    if not (shopId and amount and amount > 0) then
        return showError('Usage: /boatshop_withdraw <shopId> <amount>')
    end
    if not isSuperAdmin(xPlayer) then
        local shop = ShopsCache[shopId]
        if not shop or shop.owner_identifier ~= iden(xPlayer) then
            return showError('Not the owner.')
        end
    end
    local row = MySQL.single.await('SELECT balance FROM azm_boat_shops WHERE id = ?', { shopId })
    if not row or row.balance < amount then
        return showError('Not enough in the vault.')
    end
    MySQL.update.await('UPDATE azm_boat_shops SET balance = balance - ? WHERE id = ?', { amount, shopId })
    if ShopsCache[shopId] then ShopsCache[shopId].balance = (ShopsCache[shopId].balance or 0) - amount end
    xPlayer.addMoney(amount)
    xPlayer.showNotification(('Withdrew $%d from shop %d'):format(amount, shopId))
    sendLog("🏦 Withdraw (cmd)", ("ShopID: **%d**\nAmount: **$%d**\nBy: **%s** (%s)")
        :format(shopId, amount, xPlayer.getName(), iden(xPlayer)), COLOR_SUCCESS)
end, true, {help='Withdraw from shop vault', arguments={
    {name='shop', type='number', help='Shop ID'},
    {name='amount', type='number', help='Amount'}
}})

-- أمر: ضبط الوديعة الافتراضية (deposit) — سوبرأدمن فقط
ESX.RegisterCommand('boatshop_setdeposit', {'superadmin'}, function(xPlayer, args, showError)
    local shopId = tonumber(args[1])
    local amount = tonumber(args[2])
    if not shopId or not amount then
        return xPlayer.showNotification('استخدام: /boatshop_setdeposit <shopId> <amount>')
    end
    if amount < 0 then amount = 0 end

    MySQL.update.await('UPDATE azm_boat_shops SET deposit_default = ? WHERE id = ?', { amount, shopId })
    loadShops()
    xPlayer.showNotification(('تم ضبط الوديعة للمحل %d الى $%d'):format(shopId, amount))
    sendLog("⚙️ set deposit", ("Shop %d deposit set to $%d by %s"):format(shopId, amount, xPlayer.getName()), COLOR_INFO)
end, true, { help = 'Set default deposit', arguments = {
    { name = 'shopId', help = 'Shop ID', type = 'number' },
    { name = 'amount', help = 'Deposit amount', type = 'number' }
}})

-- utility for vec3 on server if needed
function vec3(x, y, z) return vector3(x+0.0, y+0.0, z+0.0) end
