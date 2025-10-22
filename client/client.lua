-- azm_boatrental/client.lua (CLEANED)
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
        typ = 'inform'
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

-- Help text (E prompt) - use AddTextComponentSubstringPlayerName for proper Unicode display
local function showHelp(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(tostring(msg))
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- draw a small top-left key prompt (E) with Arabic text (no squares)
local function drawTopLeftEPrompt(text)
    -- rectangle background
    local x, y, w, h = 0.08, 0.02, 0.16, 0.05
    DrawRect(x + w/2, y + h/2, w, h, 0, 0, 0, 180)

    -- key box (E)
    local keyX, keyY, keyW, keyH = x + 0.014, y + 0.013, 0.028, 0.036
    DrawRect(keyX + keyW/2, keyY + keyH/2, keyW, keyH, 220, 220, 220, 255)
    -- draw key letter
    SetTextFont(0)
    SetTextScale(0.35, 0.35)
    SetTextColour(0, 0, 0, 255)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString("E")
    DrawText(keyX + keyW/2 - 0.003, keyY + keyH/2 - 0.007)

    -- draw message (Arabic) to the right of key
    SetTextFont(4)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextWrap(x + 0.06, x + w - 0.01)
    SetTextEntry("STRING")
    AddTextComponentString(tostring(text))
    DrawText(x + 0.06, y + 0.015)
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

-- safety: cache created peds/vehicles so we can clean up
local createdPeds = {}
local createdVehicles = {}

-- safe model loader (blocking, small timeout)
local function safeRequestModel(hash, timeout)
    timeout = timeout or 5000
    if not IsModelInCdimage(hash) then return false end
    if HasModelLoaded(hash) then return true end
    RequestModel(hash)
    local t0 = GetGameTimer()
    while not HasModelLoaded(hash) and (GetGameTimer() - t0) < timeout do
        Wait(10)
    end
    return HasModelLoaded(hash)
end

local function reqModel(hash)
    return safeRequestModel(hash, 5000)
end

local function ensureCleanVehicles(maxKeep)
    maxKeep = maxKeep or 6
    -- حذف المركبات القديمة إذا تجاوزنا الحد
    while #createdVehicles > maxKeep do
        local v = table.remove(createdVehicles, 1)
        if v and v.veh and DoesEntityExist(v.veh) then
            SetEntityAsMissionEntity(v.veh, true, true)
            DeleteEntity(v.veh)
        end
    end
end

local function fixGroundZ(x,y,z)
    local gz = nil
    local retries = 10
    for i=1,retries do
        local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 5.0, 0)
        if found and groundZ and groundZ > -1000 then
            gz = groundZ
            break
        end
        z = z + 1.0
        Wait(10)
    end
    return gz or z
end

local function spawnClientBoat(model, coords, plate)
    -- حماية من تسريب كيانات
    ensureCleanVehicles(6)

    local hash = joaat(model)
    if not reqModel(hash) then
        notify({ description = L('error.model_load_failed', tostring(model)), type = 'error' })
        return nil
    end

    -- تصحيح z إلى أرض ثابتة إن أمكن
    coords.z = fixGroundZ(coords.x, coords.y, coords.z or 0.0)

    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z + 0.5, coords.h or 0.0, true, false)
    if not DoesEntityExist(veh) then
        SetModelAsNoLongerNeeded(hash)
        notify({ description = L('error.spawn_failed'), type = 'error' })
        return nil
    end

    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, plate or ('AZM'..math.random(1000,9999)))

    -- warp with small delay to ensure entity valid
    Wait(50)
    if DoesEntityExist(veh) then
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    end

    local netId = VehToNet(veh)
    createdVehicles[#createdVehicles+1] = {veh = veh, net = netId}

    SetModelAsNoLongerNeeded(hash)
    return veh
end

-- create ped with caching and safe model handling
local function ensurePedForShop(s)
    if s._pedEntity and DoesEntityExist(s._pedEntity) then return end
    local pedModel = s.ped and s.ped.model or 'a_m_y_surfer_01'
    local pedHash = joaat(pedModel)
    if not reqModel(pedHash) then return end

    local ped = CreatePed(4, pedHash, s.ped.x, s.ped.y, s.ped.z, s.ped.heading or 0.0, false, true)
    if DoesEntityExist(ped) then
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        s._pedEntity = ped
        createdPeds[#createdPeds+1] = ped
    end
    SetModelAsNoLongerNeeded(pedHash)
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

        -- Ped: use cached safe creator
        ensurePedForShop(s)

        -- owner check cached
        ESX.TriggerServerCallback('azm_boats:isOwner', function(isOwner)
            s._isOwner = isOwner
        end, s.id)

        -- Return zone: visibility marker + top-left E prompt within 50m, press E to return
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

                    if dist <= 50.0 then
                        -- draw top-left prompt (Arabic)
                        drawTopLeftEPrompt("اضغط للتفاعل")
                        if IsControlJustPressed(0, AZM and AZM.InteractKey or 38) then
                            tryReturnBoat(s.id)
                            Wait(500)
                        end
                    else
                        Wait(250)
                    end
                end
            end)
        end

        -- E interaction (owner sees owner menu) - unchanged except help messages are Arabic
        CreateThread(function()
            local key = (AZM and AZM.InteractKey) or 38 -- 38 = E
            local menuVec = vector3(s.menu.x, s.menu.y, s.menu.z)
            while true do
                Wait(0)
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                if #(pos - menuVec) <= 2.0 then
                    if s._isOwner then
                        showHelp("اضغط ~INPUT_PICKUP~ لعرض خيارات المتجر")
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
                        showHelp("اضغط ~INPUT_PICKUP~ للاستئجار")
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
            }
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
    if not shop then return notify({ description = L('error.owner_panel'), type = 'error' }) end

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

    -- نقل الملكية: يطلب رقم السيرفر للاعب المستلم
    opts[#opts+1] = {
        title = "نقل الملكية",
        icon = 'exchange-alt',
        onSelect = function()
            local input = lib.inputDialog("نقل الملكية", {
                { type='number', label='رقم اللاعب على السيرفر (server id)', required=true, min=1 }
            })
            if input and input[1] then
                local targetServerId = tonumber(input[1])
                -- optional: اطلب أيام الانتهاء أو اترك فارغة للاحتفاظ كما هو
                local daysInput = lib.inputDialog("أيام ملكية (ضع 0 لـدائم)", {
                    { type='number', label='أيام', required=true, min=0 }
                })
                local days = 0
                if daysInput and daysInput[1] then days = tonumber(daysInput[1]) end
                TriggerServerEvent('azm_boats:transferOwner', shop.id, targetServerId, days)
            end
        end
    }

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

-- cleanup entities on resource stop to avoid pool leaks
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- delete created vehicles
    for _, v in ipairs(createdVehicles) do
        local ent = v.veh
        if ent and DoesEntityExist(ent) then
            SetEntityAsMissionEntity(ent, true, true)
            DeleteEntity(ent)
        end
    end
    createdVehicles = {}

    -- delete created peds
    for _, p in ipairs(createdPeds) do
        if p and DoesEntityExist(p) then
            SetEntityAsMissionEntity(p, true, true)
            DeleteEntity(p)
        end
    end
    createdPeds = {}
end)
