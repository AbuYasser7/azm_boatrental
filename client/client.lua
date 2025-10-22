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

        -- ox_target (يبقى كما هو)
        exports.ox_target:addBoxZone({
            coords = vec3(s.menu.x, s.menu.y, s.menu.z),
            size = vec3(1.2, 1.2, 1.2),
            rotation = 45,
            debug = AZM and AZM.Debug or false,
            options = {
                {
                    name = ('boat_shop_menu_%s'):format(s.id),
                    icon = 'fa-solid fa-ship',
                    label = L('ui.open_shop', s.name or ('#'..s.id)),
                    distance = 2.0,
                    onSelect = function()
                        openShopMenu(s.id)
                    end
                },
                {
                    name = ('boat_owner_menu_%s'):format(s.id),
                    icon = 'fa-solid fa-sack-dollar',
                    label = L('ui.owner_panel'),
                    distance = 2.0,
                    onSelect = function()
                        TriggerServerEvent('azm_boats:reqOwnerMenu')
                    end
                }
            }
        })

        -- Return zone
        if s.returnZone then
            exports.ox_target:addBoxZone({
                coords = vec3(s.returnZone.x, s.returnZone.y, s.returnZone.z),
                size = vec3(s.returnZone.w or 6.0, s.returnZone.l or 6.0, s.returnZone.h or 2.0),
                rotation = 0,
                debug = AZM and AZM.Debug or false,
                options = {
                    {
                        name = ('boat_return_%s'):format(s.id),
                        icon = 'fa-solid fa-rotate-left',
                        label = L('ui.return_boat'),
                        distance = 5.0,
                        onSelect = function()
                            tryReturnBoat(s.id)
                        end
                    }
                }
            })
        end

        -- إضافة تفاعل زر E بدون إلغاء ox_target
        CreateThread(function()
            local key = (AZM and AZM.InteractKey) or 38 -- 38 = E
            local prompt = (AZM and AZM.Locale == 'ar')
                and 'اضغط ~INPUT_PICKUP~ لاستئجار قارب'
                or 'Press ~INPUT_PICKUP~ to rent a boat'

            local menuVec = vector3(s.menu.x, s.menu.y, s.menu.z)
            while true do
                Wait(0)
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                if #(pos - menuVec) <= 2.0 then
                    showHelp(prompt)
                    if IsControlJustPressed(0, key) then
                        openShopMenu(s.id)
                        -- مهلة صغيرة لتفادي تكرار الفتح
                        Wait(500)
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
