local doorStates = {} -- [doorHash] = true when open, false when closed/locked
local sqlReady = false

local function IsAdmin(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if Config.AllowedSteam[id] then return true end
    end

    if GetResourceState('vorp_core') == 'started' then
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if ok and core and core.getUser then
            local user = core.getUser(src)
            if user then
                local group = user.getGroup
                if type(group) == 'function' then group = user.getGroup() end
                if group and Config.AdminGroups[group] then return true end
            end
        end
    end

    return false
end

-- ===== Door info lookup (RB_DoorHashes comes from the shared door_hashes.lua) =====
-- entry format: { doorHash, modelHash, modelName, x, y, z }
local function GetDoorInfo(hash)
    local info = RB_DoorHashes and RB_DoorHashes[hash]
    if type(info) ~= 'table' then return nil end
    return {
        model = info[3],
        x = tonumber(info[4]) or 0.0,
        y = tonumber(info[5]) or 0.0,
        z = tonumber(info[6]) or 0.0,
    }
end

-- ===== Embedded SQL: auto create + load persisted states on resource start =====
local SCHEMA = [[
    CREATE TABLE IF NOT EXISTS `admin_door_status` (
        `door_hash` BIGINT NOT NULL,
        `model_name` VARCHAR(64) DEFAULT NULL,
        `loc_x` DOUBLE NOT NULL DEFAULT 0,
        `loc_y` DOUBLE NOT NULL DEFAULT 0,
        `loc_z` DOUBLE NOT NULL DEFAULT 0,
        `status` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = open, 0 = closed/locked',
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`door_hash`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

-- States sent to clients ("closed" rows can be skipped if the owner only wants open doors persisted)
local function GetSyncStates()
    local out = {}
    for hash, open in pairs(doorStates) do
        if open or Config.RestoreClosedDoors then
            out[hash] = open
        end
    end
    return out
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    Wait(500)

    local count = 0
    local ok, err = pcall(function()
        MySQL.query.await(SCHEMA)
        local rows = MySQL.query.await('SELECT `door_hash`, `status` FROM `admin_door_status`')

        for _, row in ipairs(rows or {}) do
            local hash = tonumber(row.door_hash)
            if hash then
                doorStates[hash] = (tonumber(row.status) == 1)
                count = count + 1
            end
        end
    end)

    if ok then
        sqlReady = true
        print(('^2[coi_door_lock]^7 `admin_door_status` ready - %d persisted door state(s) loaded.'):format(count))
        -- Push restored states to everyone already connected (covers clients that asked before the DB was ready)
        TriggerClientEvent('coi_door_lock:applyStates', -1, GetSyncStates())
    else
        print('^1[coi_door_lock] Database init failed: ' .. tostring(err) .. '^7')
    end
end)

-- Upsert (door hash + location + status) on every open/close action
local function SaveDoorStatus(entries)
    if not Config.SaveToDatabase or #entries == 0 then return end

    CreateThread(function()
        local waited = 0
        while not sqlReady and waited < 10000 do
            Wait(100)
            waited = waited + 100
        end

        if not sqlReady then
            print('^1[coi_door_lock] Database not ready - door status not saved.^7')
            return
        end

        for _, entry in ipairs(entries) do
            local ok, err = pcall(function()
                MySQL.update.await([[
                    INSERT INTO `admin_door_status`
                        (`door_hash`, `model_name`, `loc_x`, `loc_y`, `loc_z`, `status`, `updated_at`)
                    VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                    ON DUPLICATE KEY UPDATE
                        `model_name` = VALUES(`model_name`),
                        `loc_x` = VALUES(`loc_x`),
                        `loc_y` = VALUES(`loc_y`),
                        `loc_z` = VALUES(`loc_z`),
                        `status` = VALUES(`status`),
                        `updated_at` = CURRENT_TIMESTAMP
                ]], {
                    entry.hash,
                    entry.model,
                    entry.x,
                    entry.y,
                    entry.z,
                    entry.open and 1 or 0,
                })
            end)

            if not ok then
                print(('^1[coi_door_lock] Failed to save door %s: %s^7'):format(tostring(entry.hash), tostring(err)))
            end
        end
    end)
end

RegisterNetEvent('coi_door_lock:checkAdmin', function()
    local src = source
    TriggerClientEvent('coi_door_lock:setAdmin', src, IsAdmin(src), GetSyncStates())
end)

RegisterNetEvent('coi_door_lock:toggle', function(hashes)
    local src = source
    if not IsAdmin(src) or type(hashes) ~= 'table' then return end

    local open = not doorStates[hashes[1]]
    local changed, entries = {}, {}
    for _, hash in ipairs(hashes) do
        if type(hash) == 'number' then
            doorStates[hash] = open
            changed[#changed + 1] = hash

            local info = GetDoorInfo(hash)
            entries[#entries + 1] = {
                hash = hash,
                model = info and info.model or nil,
                x = info and info.x or 0.0,
                y = info and info.y or 0.0,
                z = info and info.z or 0.0,
                open = open,
            }
        end
    end

    TriggerClientEvent('coi_door_lock:apply', -1, changed, open)
    SaveDoorStatus(entries)
end)
