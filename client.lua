-- azm_boatrental / client.lua
-- Built for Al Azm County by abuyasser (discord.gg/azm)

local ESX = ESX
local PlayerData = {}
local shops = {}
local myRental = nil  -- {shop_id, plate, veh(net)}

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
-- Helpers
-- =========================
local function notify(opts)
    if type(opts) == 'string' then
        return lib.notify({title = 'Boat Rental', description = opts, type = 'inform'})
    end
    opts.title = opts.title or 'Boat Rental'
    lib.notify(opts)
end

local function reqModel(hash)
    lib.requestModel(hash)
end

local function spawnClientBoat(model, coords, plate)
    reqModel(joaat(model))
    local veh = CreateVehicle(joaat(model), coords.x, coords.y, coords.z, coords.h or 0.0, true, false)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, plate or 'AZMBOAT')
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    return veh
end

-- =========================
-- World setup (blips/peds/zones)
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
        AddTextComponentString('Boat Rental')
        EndTextCommandSetBlipName(b)

        -- Ped
        local pedModel = s.ped and s.ped.model or 'a_m_y_surfer_01'
        reqModel(joaat(pedModel))
        local ped = CreatePed(4, joaat(pedModel), s.ped.x, s.ped.y, s.ped.z, s.ped.heading or 0.0, false, true)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        -- Menu zone (rent)
        exports.ox_target:addBoxZone({
            coords = vec3(s.menu.x, s.menu.y, s.menu.z),
            size = vec3(1.2, 1.2, 1.2),
            rotation = 45,
            debug = AZM and AZM.Debug or false,
            options = {
                {
                    name = ('boat_shop_menu_%s'):format(s.id),
                    icon = 'fa-solid fa-ship',
                    label = ('Open Boat Shop (%s)'):format(s.name),
                    distance = 2.0,
                    onSelect = function()
                        openShopMenu(s.id)
                    end
                },
                {
                    name = ('boat_owner_menu_%s'):format(s.id),
                    icon = 'fa-solid fa-sack-dollar',
                    label = 'Owner Panel',
                    distance = 2.0,
                    onSelect = function()
                        -- الطلب يتم من السيرفر للتحقق من الملكية ثم يرجّع لنا بيانات المتجر
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
                        label = 'Return Rented Boat',
                        distance = 5.0,
                        onSelect = function()
                            tryReturnBoat(s.id)
                        end
                    }
                }
            })
        end
    end
end)

-- =========================
-- Rental spawn approval from server
-- =========================
RegisterNetEvent('azm_boats:spawnApproved', function(shop_id, model, coords, plate)
    local veh = spawnClientBoat(model, coords, plate)
    myRental = {shop_id = shop_id, plate = plate, veh = VehToNet(veh)}
    notify({description = ('Enjoy your %s!'):format(model), type = 'success'})
end)

-- Watcher: if the rented boat is destroyed, tell server
CreateThread(function()
    while true do
        Wait(1500)
        if myRental and myRental.veh then
            local veh = NetToVeh(myRental.veh)
            if DoesEntityExist(veh) then
                if IsEntityDead(veh) then
                    TriggerServerEvent('azm_boats:markDestroyed')
                    myRental = nil
                    notify({description='Boat destroyed. You may rent again.', type='warning'})
                end
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
            return notify({description=cooldownText or 'You cannot rent right now.', type='error'})
        end
        if not catalog or #catalog == 0 then
            return notify({description='No boats available right now.', type='error'})
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
            title = ('%s — Boats'):format(shopName or ('Shop '..shopId)),
            options = opts
        })
        lib.showContext('azm_boat_menu_'..shopId)
    end, shopId)
end

function tryReturnBoat(shopId)
    if not myRental or myRental.shop_id ~= shopId then
        return notify({description='You have no active rental for this shop.', type='error'})
    end
    local veh = NetToVeh(myRental.veh)
    if not DoesEntityExist(veh) then
        return notify({description='Boat not found.', type='error'})
    end
    TriggerServerEvent('azm_boats:returnBoat')
    DeleteVehicle(veh)
    myRental = nil
    notify({description='Boat returned. You can rent again now.', type='success'})
end

-- =========================
-- Owner Panel (server checks ownership then sends us the shop object)
-- =========================
RegisterNetEvent('azm_boats:openOwnerMenu', function(shop)
    if not shop then return notify('Owner panel not available.') end

    local opts = {
        { title = ('Shop: %s'):format(shop.name or ('#'..shop.id)), icon = 'store' },
        { title = ('Balance: $%d'):format(tonumber(shop.balance) or 0), icon = 'sack-dollar' },
    }

    if shop.platform_fee_pct then
        opts[#opts+1] = { title = ('Platform Fee: %d%%'):format(shop.platform_fee_pct or 0), icon='percent' }
    end
    if shop.deposit_default then
        opts[#opts+1] = { title = ('Deposit Default: $%d'):format(shop.deposit_default or 0), icon='coins' }
    end

    -- Quick withdraws
    opts[#opts+1] = {
        title = 'Withdraw $1,000',
        icon = 'arrow-down',
        onSelect = function() TriggerServerEvent('azm_boats:withdraw', shop.id, 1000) end
    }
    opts[#opts+1] = {
        title = 'Withdraw $5,000',
        icon = 'arrow-down',
        onSelect = function() TriggerServerEvent('azm_boats:withdraw', shop.id, 5000) end
    }

    -- Custom withdraw
    opts[#opts+1] = {
        title = 'Withdraw (custom)',
        icon = 'arrow-down',
        onSelect = function()
            local input = lib.inputDialog('Withdraw amount', {
                { type='number', label='Amount', required=true, min=1 }
            })
            if input and input[1] then
                TriggerServerEvent('azm_boats:withdraw', shop.id, tonumber(input[1]))
            end
        end
    }

    -- Deposit (custom)
    opts[#opts+1] = {
        title = 'Deposit (custom)',
        icon = 'arrow-up',
        onSelect = function()
            local input = lib.inputDialog('Deposit amount', {
                { type='number', label='Amount', required=true, min=1 }
            })
            if input and input[1] then
                TriggerServerEvent('azm_boats:deposit', shop.id, tonumber(input[1]))
            end
        end
    }

    -- Price editor
    opts[#opts+1] = {
        title = 'Set Prices',
        icon = 'tag',
        onSelect = function() openPriceMenu(shop.id) end
    }

    -- Refresh
    opts[#opts+1] = {
        title = 'Refresh',
        icon = 'rotate',
        onSelect = function() TriggerServerEvent('azm_boats:reqOwnerMenu') end
    }

    lib.registerContext({
        id='azm_boat_owner_'..shop.id,
        title=('Owner Panel — %s'):format(shop.name or ('#'..shop.id)),
        options=opts
    })
    lib.showContext('azm_boat_owner_'..shop.id)
end)

function openPriceMenu(shopId)
    ESX.TriggerServerCallback('azm_boats:getCatalog', function(catalog)
        if not catalog or #catalog == 0 then
            return notify({description='No boats configured for this shop.', type='error'})
        end
        local opts = {}
        for _, b in ipairs(catalog) do
            opts[#opts+1] = {
                title = ("%s — $%d"):format(b.label, b.price),
                icon = 'tag',
                onSelect = function()
                    local input = lib.inputDialog('Set price for '..b.label, {
                        {type='number', label='New price', required=true, min=0}
                    })
                    if input and input[1] then
                        TriggerServerEvent('azm_boats:setPrice', shopId, b.model, tonumber(input[1]))
                    end
                end
            }
        end
        lib.registerContext({ id = 'azm_boat_prices_'..shopId, title = 'Set Prices', options = opts })
        lib.showContext('azm_boat_prices_'..shopId)
    end, shopId)
end

-- =========================
-- Command (owner quick access)
-- =========================
RegisterCommand('boatshop', function()
    TriggerServerEvent('azm_boats:reqOwnerMenu')
end)
