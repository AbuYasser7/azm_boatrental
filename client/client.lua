-- azm_boatrental/client.lua
-- Built for Al Azm County by abuyasser (discord.gg/azm)

local ESX = exports['es_extended']:getSharedObject()
local PlayerData = {}
local shops = {}
local myRental = nil  -- {shop_id, plate, veh(net)}

-- =========================
-- Localization helper
-- =========================
local function L(key, ...)
    local locTable = (AZM and AZM.Locales and AZM.Locales[AZM.Locale]) or {}
    local s = locTable[key] or key
    if select('#', ...) > 0 then
        return s:format(...)
    end
    return s
end

-- =========================
-- Notify helper (moh_notify / pNotify / ox_lib)
-- =========================
local function notify(arg)
    local system = (AZM and AZM.Notify) or 'ox'  -- 'moh' | 'pnotify' | 'ox'
    local text, typ

    if type(arg) == 'string' then
        text = arg
        typ = 'inform'        -- ...existing code...
        
        local ShopsCache = {}
        local ActiveRentals = {}            -- identifier -> ActiveRental
        local AbandonedTimes = {}           -- identifier -> last abandoned time (os.time)
        
        -- خزنة موارد المدينة (تُجمع فيها حصة المدينة من كل إيجار)
        local PlatformVault = 0
        
        -- ====== Config flags ======
        local REFUND_DEPOSIT_ON_RETURN   = true
        local FORFEIT_DEPOSIT_ON_DESTROY = true
        
        -- ...existing code...
        
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
        
        -- ====== Rental Core (تعديل: تقسيم السعر بين مالك المتجر وحصة المدينة) =====
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
                notify(src, 'Boat unavailable.', 'error')
                sendLog("❌ Boat Unavailable", ("Player: **%s** (%s)\nShop: **%s**\nModel: **%s**"):format(xPlayer.getName(), identifier, shop.name, tostring(model)), COLOR_ERROR)
                return
            end
        
            local price = priceInfo.price or 0
            local minp  = priceInfo.min_price or 0
            local maxp  = priceInfo.max_price or 2147483647
            if price < minp or price > maxp then
                notify(src, ('Price out of allowed range (%d - %d).'):format(minp, maxp), 'error')
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
                notify(src, ('Need $%d (price+deposit).'):format(total), 'error')
                sendLog("💸 Insufficient Cash", ("Player: **%s** (%s)\nNeeded: **$%d**\nHave: **$%d**")
                    :format(xPlayer.getName(), identifier, total, xPlayer.getMoney()), COLOR_WARN)
                return
            end
        
            local spawn = chooseFreeSpawn(shop)
            if not spawn then
                notify(src, 'No spawn points available.', 'error')
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
        
        -- ...existing code...
    else
        text = arg.description or arg.text or ''
        typ  = arg.type or 'inform'
    end

    if system == 'moh' then
        TriggerEvent('moh_notify:SendNotification', {
            type       = (typ == 'error' and 'error') or (typ == 'warning' and 'warning') or 'success',
            text       = text,
            theme      = 'gta',
            layout     = 'topRight',
            timeout    = 5000,
            progressBar= true
        })
    elseif system == 'pnotify' then
        TriggerEvent('pNotify:SendNotification', {
            text       = text,
            type       = (typ == 'error' and 'error') or (typ == 'warning' and 'warning') or 'success',
            layout     = 'topRight',
            timeout    = 5000,
            progressBar= true
        })
    else
        lib.notify({
            title       = L('ui.title'),
            description = text,
            type        = typ
        })
    end
end

-- Help text (E prompt)
local function showHelp(msg)
    AddTextEntry('AZM_BOATS_HELP', msg)
    BeginTextCommandDisplayHelp('AZM_BOATS_HELP')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- =========================
-- Bootstrap
-- =========================
CreateThread(function()
    while not ESX do Wait(0) end
    PlayerData = ESX.GetPlayerData()
    TriggerServerEvent('azm_boats:clientReady')
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

-- =========================
-- Model helper
-- =========================
local function reqModel(hash)
    if not IsModelInCdimage(hash) then return false end
    lib.requestModel(hash)
    return HasModelLoaded(hash)
end

local function spawnClientBoat(model, coords, plate)
    local hash = joaat(model)
    if not reqModel(hash) then
        notify({ description = L('error.model_load_failed', tostring(model)), type = 'error' })
        return nil
    end
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.h or 0.0, true, false)
    if not DoesEntityExist(veh) then
        notify({ description = L('error.spawn_failed'), type = 'error' })
        return nil
    end
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, plate or 'AZMBOAT')
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    return veh
end

-- =========================
-- World setup (blips/peds/zones + E prompt)
-- =========================
RegisterNetEvent('azm_boats:setupShops', function(_shops)
    shops = _shops or {}
    for _, s in pairs(shops) do
        -- Blip
        local b = AddBlipForCoord(s.blip.x, s.blip.y, s.blip.z)
        SetBlipSprite(b, s.blip.sprite or 455)
        SetBlipScale(b, s.blip.scale or 0.8)
        SetBlipColour(b, s.blip.colour or 5)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(L('ui.blip_name'))
        EndTextCommandSetBlipName(b)

        -- Ped
        local pedModel = s.ped and s.ped.model or 'a_m_y_surfer_01'
        local pedHash = joaat(pedModel)
        if reqModel(pedHash) then
            local ped = CreatePed(4, pedHash, s.ped.x, s.ped.y, s.ped.z, s.ped.heading or 0.0, false, true)
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
        end

        -- ===== تَعديل: إزالة ox_target والاعتماد على زر E فقط =====
        -- نتحقق مع السرفر هل اللاعب مالك هذا الفرع أو أدمين عالي الصلاحية
        ESX.TriggerServerCallback('azm_boats:isOwner', function(isOwner)
            s._isOwner = isOwner
        end, s.id)

        -- منطقة الإرجاع: علامة مرئية + مساعدة E
        if s.returnZone then
            CreateThread(function()
                local markerVec = vector3(s.returnZone.x, s.returnZone.y, s.returnZone.z)
                while true do
                    Wait(0)
                    local ped = PlayerPedId()
                    local pos = GetEntityCoords(ped)
                    local dist = #(pos - markerVec)

                    if dist <= 60.0 then
                        DrawMarker(1, s.returnZone.x, s.returnZone.y, s.returnZone.z - 1.0, 0.0,0.0,0.0, 0.0,0.0,0.0, s.returnZone.w or 6.0, s.returnZone.l or 6.0, s.returnZone.h or 2.0, 0,180,255,120, false, true, 2, false, nil, nil, false)
                    end

                    if dist <= 5.0 then
                        showHelp(L('hint.press_e_return'))
                        if IsControlJustPressed(0, AZM and AZM.InteractKey or 38) then
                            tryReturnBoat(s.id)
                            Wait(500)
                        end
                    else
                        Wait(300)
                    end
                end
            end)
        end

        -- تفاعل زر E الموحد: إذا كان المالك نعرض قائمة تحوي "استئجار" و"لوحة المالك" و"إرجاع"
        CreateThread(function()
            local key = (AZM and AZM.InteractKey) or 38 -- 38 = E
            local menuVec = vector3(s.menu.x, s.menu.y, s.menu.z)
            while true do
                Wait(0)
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                if #(pos - menuVec) <= 2.0 then
                    if s._isOwner then
                        -- نعرض رسالة عامة (المالك يرى الخيارات عند الضغط)
                        showHelp(L('hint.press_e_owner'))
                        if IsControlJustPressed(0, key) then
                            local opts = {
                                { title = L('menu.boats_title', s.name or ('#'..s.id)), icon = 'ship', onSelect = function() openShopMenu(s.id) end },
                                { title = L('ui.return_boat'), icon = 'reply', onSelect = function() tryReturnBoat(s.id) end },
                                { title = L('ui.owner_panel'), icon = 'sack-dollar', onSelect = function() TriggerServerEvent('azm_boats:reqOwnerMenu') end }
                            }
                            lib.registerContext({ id = 'azm_interact_'..s.id, title = L('ui.open_shop', s.name or ('#'..s.id)), options = opts })
                            lib.showContext('azm_interact_'..s.id)
                            Wait(500)
                        end
                    else
                        showHelp(L('hint.press_e_rent'))
                        if IsControlJustPressed(0, key) then
                            openShopMenu(s.id)
                            Wait(500)
                        end
                    end
                else
                    Wait(300)
                end
            end
        end)
    end
end)

-- =========================
-- Rental spawn approval from server
-- =========================
RegisterNetEvent('azm_boats:spawnApproved', function(shop_id, model, coords, plate)
    local veh = spawnClientBoat(model, coords, plate)
    if not veh then return end
    myRental = { shop_id = shop_id, plate = plate, veh = VehToNet(veh) }
    notify({ description = L('notif.enjoy', model), type = 'success' })
end)

-- Watcher: if the rented boat is destroyed, tell server
CreateThread(function()
    while true do
        Wait(1500)
        if myRental and myRental.veh then
            local veh = NetToVeh(myRental.veh)
            if DoesEntityExist(veh) and IsEntityDead(veh) then
                TriggerServerEvent('azm_boats:markDestroyed')
                myRental = nil
                notify({ description = L('notif.destroyed'), type = 'warning' })
            end
        end
    end
end)

-- =========================
-- Menus
-- =========================
function openShopMenu(shopId)
    ESX.TriggerServerCallback('azm_boats:getCatalog', function(catalog, canRent, cooldownText, shopName)
        if not canRent then
            return notify({ description = cooldownText or L('error.cannot_rent'), type = 'error' })
        end
        if not catalog or #catalog == 0 then
            return notify({ description = L('error.no_catalog'), type = 'error' })
        end

        local opts = {}
        for _, b in ipairs(catalog) do
            opts[#opts+1] = {
                title = ("%s — $%d"):format(b.label, b.price),
                icon = 'ship',
                onSelect = function()
                    TriggerServerEvent('azm_boats:requestRent', shopId, b.model)
                end
            end
        end

        lib.registerContext({
            id = 'azm_boat_menu_'..shopId,
            title = L('menu.boats_title', shopName or ('#'..shopId)),
            options = opts
        })
        lib.showContext('azm_boat_menu_'..shopId)
    end, shopId)
end

function tryReturnBoat(shopId)
    if not myRental or myRental.shop_id ~= shopId then
        return notify({ description = L('error.no_rental_this_shop'), type = 'error' })
    end
    local veh = NetToVeh(myRental.veh)
    if not DoesEntityExist(veh) then
        return notify({ description = L('error.boat_not_found'), type = 'error' })
    end
    TriggerServerEvent('azm_boats:returnBoat')
    DeleteVehicle(veh)
    myRental = nil
    notify({ description = L('notif.returned'), type = 'success' })
end

-- =========================
-- Owner Panel (server checks ownership then sends us the shop object)
-- =========================
RegisterNetEvent('azm_boats:openOwnerMenu', function(shop)
    if not shop then return notify(L('error.owner_panel')) end

    local opts = {
        { title = L('owner.shop', shop.name or ('#'..shop.id)), icon = 'store' },
        { title = L('owner.balance', tonumber(shop.balance) or 0), icon = 'sack-dollar' },
    }

    if shop.platform_fee_pct then
        opts[#opts+1] = { title = L('owner.platform_fee', shop.platform_fee_pct or 0), icon='percent' }
    end
    if shop.deposit_default then
        opts[#opts+1] = { title = L('owner.deposit_default', shop.deposit_default or 0), icon='coins' }
    end

    -- Quick withdraws
    opts[#opts+1] = {
        title = L('owner.withdraw_1000'),
        icon = 'arrow-down',
        onSelect = function() TriggerServerEvent('azm_boats:withdraw', shop.id, 1000) end
    }
    opts[#opts+1] = {
        title = L('owner.withdraw_5000'),
        icon = 'arrow-down',
        onSelect = function() TriggerServerEvent('azm_boats:withdraw', shop.id, 5000) end
    }

    -- Custom withdraw
    opts[#opts+1] = {
        title = L('menu.withdraw_custom'),
        icon = 'arrow-down',
        onSelect = function()
            local input = lib.inputDialog(L('menu.withdraw_custom'), {
                { type='number', label=L('ui.amount'), required=true, min=1 }
            })
            if input and input[1] then
                TriggerServerEvent('azm_boats:withdraw', shop.id, tonumber(input[1]))
            end
        end
    }

    -- Deposit (custom)
    opts[#opts+1] = {
        title = L('menu.deposit_custom'),
        icon = 'arrow-up',
        onSelect = function()
            local input = lib.inputDialog(L('menu.deposit_custom'), {
                { type='number', label=L('ui.amount'), required=true, min=1 }
            })
            if input and input[1] then
                TriggerServerEvent('azm_boats:deposit', shop.id, tonumber(input[1]))
            end
        end
    }

    -- Price editor
    opts[#opts+1] = {
        title = L('menu.set_prices'),
        icon = 'tag',
        onSelect = function() openPriceMenu(shop.id) end
    }

    -- Refresh
    opts[#opts+1] = {
        title = L('menu.refresh'),
        icon = 'rotate',
        onSelect = function() TriggerServerEvent('azm_boats:reqOwnerMenu') end
    }

    lib.registerContext({
        id='azm_boat_owner_'..shop.id,
        title=L('menu.owner_title', shop.name or ('#'..shop.id)),
        options=opts
    })
    lib.showContext('azm_boat_owner_'..shop.id)
end)

function openPriceMenu(shopId)
    ESX.TriggerServerCallback('azm_boats:getCatalog', function(catalog)
        if not catalog or #catalog == 0 then
            return notify({ description = L('error.no_catalog_shop'), type = 'error' })
        end
        local opts = {}
        for _, b in ipairs(catalog) do
            opts[#opts+1] = {
                title = ("%s — $%d"):format(b.label, b.price),
                icon = 'tag',
                onSelect = function()
                    local input = lib.inputDialog(L('menu.set_price_for', b.label), {
                        {type='number', label=L('ui.new_price'), required=true, min=0}
                    })
                    if input and input[1] then
                        TriggerServerEvent('azm_boats:setPrice', shopId, b.model, tonumber(input[1]))
                    end
                end
            }
        end
        lib.registerContext({ id = 'azm_boat_prices_'..shopId, title = L('menu.set_prices'), options = opts })
        lib.showContext('azm_boat_prices_'..shopId)
    end, shopId)
end

-- =========================
-- Commands (owner quick access)
-- =========================
RegisterCommand('boatshop', function()
    TriggerServerEvent('azm_boats:reqOwnerMenu')
end)

-- Optional quick return command
RegisterCommand('returnboat', function()
    if myRental and myRental.shop_id then
        tryReturnBoat(myRental.shop_id)
    else
        notify({ description = L('error.no_active_rental'), type = 'error' })
    end
end)
