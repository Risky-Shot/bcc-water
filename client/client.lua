local VORPcore = {}
local VORPutils = {}
local WaterPump
local Fill
local Wash
local Drink
local Canteen
local PumpAnim
local Filling = false
local IsWild
local UseCanteen = true

TriggerEvent("getCore", function(core)
    VORPcore = core
end)

TriggerEvent("getUtils", function(utils)
    VORPutils = utils
end)

Citizen.CreateThread(function()
    -- Start Prompts
    local pumpPrompt = VORPutils.Prompts:SetupPromptGroup()
    WaterPump = pumpPrompt:RegisterPrompt(_U("fill"), Config.fillKey, 1, 1, true, 'click')
    local waterPrompts = VORPutils.Prompts:SetupPromptGroup()
    Fill = waterPrompts:RegisterPrompt(_U("fill"), Config.fillKey, 1, 1, true, 'click')
    Wash = waterPrompts:RegisterPrompt(_U("wash"), Config.washKey, 1, 1, true, 'click')
    Drink = waterPrompts:RegisterPrompt(_U("drink"), Config.drinkKey, 1, 1, true, 'click')
    --Start Water
    while true do
        Citizen.Wait(0)
        local player = PlayerPedId()
        local coords = GetEntityCoords(player)
        local sleep = true
        local dead = IsEntityDead(player)
        if not dead then
            -- Waterpumps
            local pumpLoc = Citizen.InvokeNative(0xBFA48E2FF417213F, coords.x, coords.y, coords.z, 1.0, GetHashKey("p_waterpump01x"), 0) -- DoesObjectOfTypeExistAtCoords
            if pumpLoc and IsPedOnFoot(player) then
                sleep = false
                pumpPrompt:ShowGroup("Water Pump")
                if WaterPump:HasCompleted() then
                    PumpAnim = true
                    TriggerServerEvent('oss_water:CheckEmpty')
                end
            else
                -- Wild Waters
                local water = Citizen.InvokeNative(0x5BA7A68A346A5A91, coords.x, coords.y, coords.z) -- GetWaterMapZoneAtCoords
                for k, _ in pairs(Config.locations) do
                    if water == Config.locations[k].hash and IsPedOnFoot(player) then
                        if IsEntityInWater(player) and Citizen.InvokeNative(0xD5FE956C70FF370B, player) then -- GetPedCrouchMovement
                            if Citizen.InvokeNative(0xAC29253EEF8F0180, player) then -- IsPedStill
                                sleep = false
                                waterPrompts:ShowGroup(Config.locations[k].name)
                                if Fill:HasCompleted() then
                                    Filling = true
                                    PumpAnim = false
                                    TriggerServerEvent('oss_water:CheckEmpty')
                                    break
                                end
                                if Wash:HasCompleted() then
                                    if not Filling then
                                        WashPlayer()
                                    end
                                    break
                                end
                                if Drink:HasCompleted() then
                                    if not Filling then
                                        WildDrink()
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if sleep then
                Citizen.Wait(1000)
            end
        end
    end
end)
-- Fill Canteen Animations
RegisterNetEvent('oss_water:FillCanteen')
AddEventHandler('oss_water:FillCanteen', function()
    local player = PlayerPedId()
    Citizen.InvokeNative(0xFCCC886EDE3C63EC, player, 2, true) -- HidePedWeapons
    if not PumpAnim then
        local coords = GetEntityCoords(player)
        local boneIndex = GetEntityBoneIndexByName(player, "SKEL_R_HAND")
        local modelHash = GetHashKey("p_cs_canteen_hercule")
        LoadModel(modelHash)
        Canteen = CreateObject(modelHash, coords.x, coords.y, coords.z, true, false, false)
        SetEntityVisible(Canteen, true)
        SetEntityAlpha(Canteen, 255, false)
        SetModelAsNoLongerNeeded(modelHash)
        AttachEntityToEntity(Canteen, player, boneIndex, 0.12, 0.09, -0.05, 306.0, 18.0, 0.0, false, false, false, true, 2, true)
        PlayAnim("amb_work@world_human_crouch_inspect@male_c@idle_a", "idle_a")
        DeleteObject(Canteen)
        Filling = false
    else
        PlayAnim("amb_work@prop_human_pump_water@female_b@idle_a", "idle_a")
    end
    if Config.showMessages then
        VORPcore.NotifyRightTip(_U("full"), 5000)
    end
end)
-- Drink from Canteen
RegisterNetEvent('oss_water:Drink')
AddEventHandler('oss_water:Drink', function(message)
    local player = PlayerPedId()
    Citizen.InvokeNative(0xFCCC886EDE3C63EC, player, 2, false) -- HidePedWeapons
    if Citizen.InvokeNative(0x6D9F5FAA7488BA46, player) then -- IsPedMale
        TaskStartScenarioInPlace(player, GetHashKey('WORLD_HUMAN_DRINK_FLASK'), -1, true, false, false, false)
        Wait(15000)
        ClearPedTasks(player, true, true)
    else
        TaskStartScenarioInPlace(player, GetHashKey('WORLD_HUMAN_COFFEE_DRINK'), -1, true, false, false, false)
        Wait(15000)
        ClearPedTasks(player, true, true)
        Wait(5000)
        Citizen.InvokeNative(0xFCCC886EDE3C63EC, player, 2, true) -- HidePedWeapons
    end
    IsWild = false
    PlayerStats()
    -- Canteen Level Messages
    if Config.showMessages then
        if message == 4 then
            VORPcore.NotifyRightTip(_U("level_4"), 5000)
        elseif message == 3 then
            VORPcore.NotifyRightTip(_U("level_3"), 5000)
        elseif message == 2 then
            VORPcore.NotifyRightTip(_U("level_2"), 5000)
        elseif message == 1 then
            VORPcore.NotifyRightTip(_U("level_1"), 5000)
        end
    end
end)
-- Drink Directly from Wild Waters
function WildDrink()
    PlayAnim("amb_rest_drunk@world_human_bucket_drink@ground@male_a@idle_c", "idle_h")
    IsWild = true
    PlayerStats()
end
-- Wash Player in Wild Waters
function WashPlayer()
    local player = PlayerPedId()
    PlayAnim("amb_misc@world_human_wash_face_bucket@ground@male_a@idle_d", "idle_l")
    Citizen.InvokeNative(0x6585D955A68452A5, player) -- ClearPedEnvDirt
    Citizen.InvokeNative(0x523C79AEEFCC4A2A, player, 10, "ALL") -- ClearPedDamageDecalByZone
    Citizen.InvokeNative(0x8FE22675A5A45817, player) -- ClearPedBloodDamage
    Citizen.InvokeNative(0xE3144B932DFDFF65, player, 0.0, -1, 1, 1) -- SetPedDirtCleaned
end
-- Boosts from Drinking
function PlayerStats()
    local player = PlayerPedId()
    local health = Citizen.InvokeNative(0x36731AC041289BB1, player, 0) -- GetAttributeCoreValue
    local stamina = Citizen.InvokeNative(0x36731AC041289BB1, player, 1) -- GetAttributeCoreValue
    print()
    if IsWild then
        -- Wild Waters
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, health + Config.wildHealth) -- SetAttributeCoreValue
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 1, stamina + Config.wildStamina) -- SetAttributeCoreValue
        TriggerEvent('vorpmetabolism:changeValue', "Thirst", Config.wildThirst)
    else
        -- Canteen
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, health + Config.health) -- SetAttributeCoreValue
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 1, stamina + Config.stamina) -- SetAttributeCoreValue
        TriggerEvent('vorpmetabolism:changeValue', "Thirst", Config.thirst)
    end
end

RegisterNetEvent('oss_water:Filling')
AddEventHandler('oss_water:Filling', function()
    Filling = false
end)

RegisterNetEvent('oss_water:UseCanteen')
AddEventHandler('oss_water:UseCanteen', function(data)
    if UseCanteen then
        TriggerServerEvent('oss_water:UpdateCanteen', data)
        UseCanteen = false
        Wait(15000)
        UseCanteen = true
    end
end)

function PlayAnim(dict, anim)
    local player = PlayerPedId()
    LoadAnim(dict)
    Citizen.InvokeNative(0xFCCC886EDE3C63EC, player, 2, true) -- HidePedWeapons
    TaskPlayAnim(player, dict, anim, 1.0, 1.0, -1, 17, 1.0, false, false, false)
    Wait(10000)
    ClearPedTasks(player, false, false)
end

function LoadAnim(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
    Wait(10)
    end
end

function LoadModel(model)
    while not HasModelLoaded(model) do
        RequestModel(model)
        Citizen.Wait(10)
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    ClearPedTasksImmediately(PlayerPedId())
    if Canteen then
        DeleteObject(Canteen)
    end
    WaterPump:DeletePrompt()
    Fill:DeletePrompt()
    Wash:DeletePrompt()
    Drink:DeletePrompt()
end)