local isAdmin = false
local doorStates = {}
local prompt, promptGroup

local function RegisterDoor(hash)
    if IsDoorRegisteredWithSystem and IsDoorRegisteredWithSystem(hash) then return end
    Citizen.InvokeNative(0xD99229FE93B46286, hash, 1, 1, 0, 0, 0, 0)
end

local function ApplyDoor(hash, open)
    RegisterDoor(hash)
    if open then
        DoorSystemSetDoorState(hash, 0)
        DoorSystemSetOpenRatio(hash, 1.0, true)
    else
        DoorSystemSetOpenRatio(hash, 0.0, true)
        DoorSystemSetDoorState(hash, 1)
    end
end

local function PlayClick()
    PlaySoundFrontend(Config.Sound.name, Config.Sound.set, true, 0)
end

local function CreatePrompt()
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, 0xCEFD9220) -- E
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', Config.PromptText))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetStandardMode(prompt, true)
    PromptRegisterEnd(prompt)
end

-- Returns the nearest door entry and its distance
local function GetNearestDoor(coords)
    local best, bestDist = nil, Config.Distance
    for _, info in pairs(RB_DoorHashes) do
        local dist = #(coords - vector3(info[4], info[5], info[6]))
        if dist < bestDist then best, bestDist = info, dist end
    end
    return best
end

-- Nearest door plus any paired door right next to it
local function GetDoorGroup(target)
    local origin = vector3(target[4], target[5], target[6])
    local hashes = { target[1] }
    for _, info in pairs(RB_DoorHashes) do
        if info[1] ~= target[1] and #(origin - vector3(info[4], info[5], info[6])) <= Config.PairDistance then
            hashes[#hashes + 1] = info[1]
        end
    end
    return hashes
end

local function ApplyStates(states)
    if type(states) ~= 'table' then return end
    for hash, open in pairs(states) do
        if type(hash) == 'number' then
            doorStates[hash] = open
            ApplyDoor(hash, open)
        end
    end
end

RegisterNetEvent('coi_door_lock:setAdmin', function(admin, states)
    isAdmin = admin
    ApplyStates(states)
end)

-- Restored (persisted) states pushed by the server once the database is ready
RegisterNetEvent('coi_door_lock:applyStates', function(states)
    ApplyStates(states)
end)

RegisterNetEvent('coi_door_lock:apply', function(hashes, open)
    for _, hash in ipairs(hashes) do
        doorStates[hash] = open
        ApplyDoor(hash, open)
    end
    PlayClick()
end)

-- Doors reset when the player respawns / changes character, so re-sync the saved states
AddEventHandler('playerSpawned', function()
    CreateThread(function()
        Wait(1500)
        TriggerServerEvent('coi_door_lock:checkAdmin')
    end)
end)

CreateThread(function()
    CreatePrompt()
    PromptSetVisible(prompt, false)
    PromptSetEnabled(prompt, false)
    TriggerServerEvent('coi_door_lock:checkAdmin')

    while true do
        local wait = 1000
        if isAdmin then
            local target = GetNearestDoor(GetEntityCoords(PlayerPedId()))
            if target then
                wait = 0
                PromptSetEnabled(prompt, true)
                PromptSetVisible(prompt, true)
                if PromptHasStandardModeCompleted(prompt, 0) then
                    TriggerServerEvent('coi_door_lock:toggle', GetDoorGroup(target))
                    Wait(500)
                end
            else
                PromptSetEnabled(prompt, false)
                PromptSetVisible(prompt, false)
                wait = 500
            end
        else
            PromptSetEnabled(prompt, false)
            PromptSetVisible(prompt, false)
        end
        Wait(wait)
    end
end)
