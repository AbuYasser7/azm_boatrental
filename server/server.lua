local ESX = ESX

---@class ActiveRental
--- @field shop_id number
--- @field identifier string
--- @field plate string
--- @field started number (os.time)

local ShopsCache = {}
local ActiveRentals = {}            -- identifier -> ActiveRental
local AbandonedTimes = {}           -- identifier -> last abandoned time (os.time)

-- ====== Config flags (تقدر تنقلها لـ config.lua لو تبغى) ======
local REFUND_DEPOSIT_ON_RETURN   = true
local FORFEIT_DEPOSIT_ON_DESTROY = true

-- ====== Helpers ======
local function iden(xPlayer)
    return xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
end

local function isSuperAdmin(xPlayer)
    local g = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    for _, v in ipairs(AZM.Groups.SuperAdmin or {'superadmin','admin'}) do
        if v == g then return true end
    end
    return false
end

-- ====== DB Seeding / Loading ======
local function ensureSeeds()
    for _, s in ipairs(AZM.Shops) do
        local exist = MySQL.single.await('SELECT id FROM azm_boat_shops WHERE id = ?', { s.id })
        if not exist then
            MySQL.insert.await([[
                INSERT INTO azm_boat_shops
                (id, name, owner_identifier, owner_name, expires_at, balance, platform_fee_pct, deposit_default,
                 ped_x, ped_y, ped_z, ped_h, menu_x, menu_y, menu_z, menu_h, blip_x, blip_y, blip_z)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            ]], { s.id, s.name, nil, nil, nil, 0, 0, 0,
                   s.ped.x, s.ped.y, s.ped.z, s.ped.heading,
                   s.menu.x, s.menu.y, s.menu.z, s.menu.heading,
                   s.blip.x, s.blip.y, s.blip.z })
            for _, sp in ipairs(s.spawns or {}) do
                MySQL.insert.await('INSERT INTO azm_boat_shop_spawns (shop_id, x, y, z, h) VALUES (?,?,?,?,?)', { s.id, sp.x, sp.y, sp.z, sp.h })
            end
            for _, b in ipairs(AZM.Boats or {}) do
                -- default price with wide min/max
                MySQL.insert.await('INSERT INTO azm_boat_prices (shop_id, model, label, price, min_price, max_price) VALUES (?,?,?,?,?,?)',
                    { s.id, b.model, b.label, b.price or 0, 0, 2147483647 })
            end
        end
    end
end

local function loadShops()
    local rows   = MySQL.query.await('SELECT * FROM azm_boat_shops')
    local prices = MySQL.query.await('SELECT * FROM azm_boat_prices')
    local spawns = MySQL.query.await('SELECT * FROM azm_boat_shop_spawns')

    local priceMap = {}
    for _, p in ipairs(prices) do
        priceMap[p.shop_id] = priceMap[p.shop_id] or {}
        priceMap[p.shop_id][p.model] = {
            label    = p.label,
            price    = p.price,
            min_price= p.min_price or 0,
            max_price= p.max_price or 2147483647
        }
    end

    local spawnMap = {}
    for _, sp in ipairs(spawns) do
        spawnMap[sp.shop_id] = spawnMap[sp.shop_id] or {}
        spawnMap[sp.shop_id][#spawnMap[sp.shop_id]+1] = {x=sp.x,y=sp.y,z=sp.z,h=sp.h}
    end

    ShopsCache = {}
    for _, s in ipairs(rows) do
        ShopsCache[s.id] = {
            id = s.id,
            name = s.name,
            owner_identifier = s.owner_identifier,
            owner_name = s.owner_name,
            expires_at = s.expires_at,
            balance = s.balance,
            platform_fee_pct = s.platform_fee_pct or 0,
            deposit_default = s.deposit_default or 0,
            blip = {x=s.blip_x, y=s.blip_y, z=s.blip_z, sprite=455, colour=5, scale=0.8},
            ped  = {x=s.ped_x,  y=s.ped_y,  z=s.ped_z,  heading=s.ped_h,  model='a_m_y_surfer_01'},
            menu = {x=s.menu_x, y=s.menu_y, z=s.menu_z, heading=s.menu_h},
            returnZone = {}, -- visual from client/config
            spawns = spawnMap[s.id] or {},
            prices = priceMap[s.id] or {}
        }
    end
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    ensureSeeds()
    loadShops()
end)

-- ====== Client Sync ======
RegisterNetEvent('azm_boats:clientReady', function()
    local src = source
    TriggerClientEvent('azm_boats:setupShops', src, ShopsCache)
end)

-- ====== Cooldown Logic ======
local function canPlayerRent(identifier)
    if ActiveRentals[identifier] then
        return false, 'You already have an active rental.'
    end
    local lastAbandoned = AbandonedTimes[identifier]
    if lastAbandoned then
        local diff = os.time() - lastAbandoned
        local wait = (AZM.CooldownMinutes * 60) - diff
        if wait > 0 then
            local m = math.floor(wait/60)
            local s = wait % 60
            return false, ('You must wait %02d:%02d before renting again.'):format(m, s)
        end
    end
    return true
end

-- ====== Rental Core ======
local function chooseFreeSpawn(shop)
    -- بسيط: أول نقطة سباون
    return shop.spawns[1]
end

local function randPlate()
    return ("AZ%02d%03d"):format(math.random(10,99), math.random(100,999))
end

ESX.RegisterServerCallback('azm_boats:getCatalog', function(src, cb, shopId)
    local shop = ShopsCache[shopId]
    if not shop then return cb({}, false, 'Shop not found', '') end

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
    local identifier = iden(xPlayer)
    local shop = ShopsCache[shopId]
    if not shop then return end

    local ok, msg = canPlayerRent(identifier)
    if not ok then
        return TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description=msg, type='error'})
    end

    local priceInfo = shop.prices[model]
    if not priceInfo then
        return TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description='Boat unavailable.', type='error'})
    end

    -- enforce min/max
    local price = priceInfo.price or 0
    local minp  = priceInfo.min_price or 0
    local maxp  = priceInfo.max_price or 2147483647
    if price < minp or price > maxp then
        return TriggerClientEvent('ox_lib:notify', src, {
            title='Boat Rental',
            description=('Price out of allowed range (%d - %d).'):format(minp, maxp),
            type='error'
        })
    end

    local deposit = shop.deposit_default or 0
    local platformPct = shop.platform_fee_pct or 0
    if deposit < 0 then deposit = 0 end
    if platformPct < 0 then platformPct = 0 end
    if platformPct > 100 then platformPct = 100 end

    local total = price + deposit
    if xPlayer.getMoney() < total then
        return TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description=('Need $%d (price+deposit).'):format(total), type='error'})
    end

    local spawn = chooseFreeSpawn(shop)
    if not spawn then
        return TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description='No spawn points available.', type='error'})
    end

    -- take money
    xPlayer.removeMoney(total)

    -- platform/owner split on PRICE (not including deposit)
    local platform_amount = math.floor(price * (platformPct/100))
    local owner_amount = price - platform_amount
    -- credit shop vault with platform share immediately; owner share أيضاً في نفس الخزنة (تبسيط)
    MySQL.update.await('UPDATE azm_boat_shops SET balance = balance + ? WHERE id = ?', { platform_amount + owner_amount, shopId })
    shop.balance = (shop.balance or 0) + platform_amount + owner_amount

    local plate = randPlate()

    -- persist rental
    MySQL.insert.await([[
        INSERT INTO azm_boat_rentals (identifier, shop_id, model, plate, rented_at, deposit_taken, status)
        VALUES (?,?,?,?,NOW(),?,?)
    ]], { identifier, shopId, model, plate, deposit, 'active' })

    ActiveRentals[identifier] = { shop_id = shopId, identifier = identifier, plate = plate, started = os.time() }

    TriggerClientEvent('azm_boats:spawnApproved', src, shopId, model, spawn, plate)
    TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description=('Charged $%d (incl. $%d deposit).'):format(total, deposit), type='success'})
end)

RegisterNetEvent('azm_boats:returnBoat', function()
    local src      = source
    local xPlayer  = ESX.GetPlayerFromId(src)
    local identifier = iden(xPlayer)
    local active   = ActiveRentals[identifier]
    if not active then return end

    local row = MySQL.single.await([[
        SELECT r.id, r.deposit_taken, r.shop_id
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
        TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description=('Deposit $%d refunded.'):format(deposit), type='success'})
    else
        -- keep deposit in vault
        MySQL.update.await('UPDATE azm_boat_shops SET balance = balance + ? WHERE id = ?', { deposit, shopId })
        if ShopsCache[shopId] then
            ShopsCache[shopId].balance = (ShopsCache[shopId].balance or 0) + deposit
        end
    end

    MySQL.update.await([[
        UPDATE azm_boat_rentals
        SET status = 'returned', returned_at = NOW()
        WHERE id = ?
    ]], { row.id })

    ActiveRentals[identifier] = nil
    AbandonedTimes[identifier] = nil  -- no cooldown on proper return
end)

RegisterNetEvent('azm_boats:markDestroyed', function()
    local src       = source
    local xPlayer   = ESX.GetPlayerFromId(src)
    local identifier= iden(xPlayer)
    local active    = ActiveRentals[identifier]
    if not active then return end

    local row = MySQL.single.await([[
        SELECT r.id, r.deposit_taken, r.shop_id
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
    end

    ActiveRentals[identifier] = nil
    -- destroyed waives cooldown too
    AbandonedTimes[identifier] = nil
end)

-- mark abandoned if player drops with active rental -> triggers cooldown
AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = iden(xPlayer)
    local active = ActiveRentals[identifier]
    if active then
        local row = MySQL.single.await([[
            SELECT r.id, r.deposit_taken, r.shop_id
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
    -- NOTE: حساب المسافة على السيرفر يتطلب OneSync؛ تقدر تستبدله بتحقق client → server
    for _, shop in pairs(ShopsCache) do
        -- السماح مباشرة: افتح لوحة المالك إذا كان هو المالك (التحقق المكاني يجرى على الكلاينت عادة)
        if shop.owner_identifier == identifier and (not shop.expires_at or os.time() < os.time(shop.expires_at)) then
            TriggerClientEvent('azm_boats:openOwnerMenu', src, shop)
            return
        end
    end
    TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description='You are not the owner of a nearby shop.', type='error'})
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
        return TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description='Price outside allowed limits.', type='error'})
    end

    MySQL.update.await('UPDATE azm_boat_prices SET price = ? WHERE shop_id = ? AND model = ?', { newPrice, shopId, model })
    if shop.prices[model] then shop.prices[model].price = newPrice end
    TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description='Price updated.', type='success'})
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
        return TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description='Not enough in the vault.', type='error'})
    end

    MySQL.update.await('UPDATE azm_boat_shops SET balance = balance - ? WHERE id = ?', { amount, shopId })
    shop.balance = (shop.balance or 0) - amount
    xPlayer.addMoney(amount)
    TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description=('Withdrew $%d'):format(amount), type='success'})
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
        return TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description='Not enough cash to deposit.', type='error'})
    end

    xPlayer.removeMoney(amount)
    MySQL.update.await('UPDATE azm_boat_shops SET balance = balance + ? WHERE id = ?', { amount, shopId })
    shop.balance = (shop.balance or 0) + amount
    TriggerClientEvent('ox_lib:notify', src, {title='Boat Rental', description=('Deposited $%d'):format(amount), type='success'})
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
end, true, {help = 'Set boat shop owner', arguments = {
    {name='shop', help='Shop ID', type='number'},
    {name='id', help='Server ID', type='number'},
    {name='days', help='Days (0 = unlimited)', type='number'}
}})

ESX.RegisterCommand('boatshop_getlicense', {'admin','superadmin'}, function(xPlayer, args, showError)
    local targetId = tonumber(args.id)
    local t = ESX.GetPlayerFromId(targetId)
    if not t then return showError('Player not online') end
    xPlayer.showNotification(('Identifier: %s'):format(iden(t)))
end, true, {help='Get player license/identifier', arguments={{name='id', type='number', help='Server ID'}}})

ESX.RegisterCommand('boatshop_setlimits', {'admin','superadmin'}, function(xPlayer, args, showError)
    if not isSuperAdmin(xPlayer) then return end
    local shopId = tonumber(args.shop)
    local model  = tostring(args.model or '')
    local minP   = tonumber(args.minp)
    local maxP   = tonumber(args.maxp)
    if not (shopId and model and minP and maxP and maxP >= minP) then
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
    else
        showError('Model not found for this shop.')
    end
end, true, {help='Set min/max price limits', arguments={
    {name='shop', type='number', help='Shop ID'},
    {name='model', type='string', help='Boat model'},
    {name='minp', type='number', help='Min price'},
    {name='maxp', type='number', help='Max price'}
}})

ESX.RegisterCommand('boatshop_setfee', {'admin','superadmin'}, function(xPlayer, args, showError)
    if not isSuperAdmin(xPlayer) then return end
    local shopId = tonumber(args.shop)
    local fee    = tonumber(args.fee)
    if not (shopId and fee and fee >= 0 and fee <= 100) then
        return showError('Usage: /boatshop_setfee <shopId> <feePct 0..100>')
    end
    MySQL.update.await('UPDATE azm_boat_shops SET platform_fee_pct = ? WHERE id = ?', { fee, shopId })
    if ShopsCache[shopId] then ShopsCache[shopId].platform_fee_pct = fee end
    xPlayer.showNotification(('Platform fee for shop %d set to %d%%'):format(shopId, fee))
end, true, {help='Set platform fee % for a shop', arguments={
    {name='shop', type='number', help='Shop ID'},
    {name='fee',  type='number', help='Percent 0..100'}
}})

ESX.RegisterCommand('boatshop_deposit', {'admin','superadmin','user'}, function(xPlayer, args, showError)
    local shopId = tonumber(args.shop)
    local amount = tonumber(args.amount)
    if not (shopId and amount and amount > 0) then
        return showError('Usage: /boatshop_deposit <shopId> <amount>')
    end
    -- allow owner or superadmin
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
    -- allow owner or superadmin
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
end, true, {help='Withdraw from shop vault', arguments={
    {name='shop', type='number', help='Shop ID'},
    {name='amount', type='number', help='Amount'}
}})

-- utility for vec3 on server if needed
function vec3(x, y, z) return vector3(x+0.0, y+0.0, z+0.0) end
