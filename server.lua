local doorStates = {} -- [doorHash] = true when open

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

RegisterNetEvent('coi_door_lock:checkAdmin', function()
    local src = source
    TriggerClientEvent('coi_door_lock:setAdmin', src, IsAdmin(src), doorStates)
end)

RegisterNetEvent('coi_door_lock:toggle', function(hashes)
    local src = source
    if not IsAdmin(src) or type(hashes) ~= 'table' then return end

    local open = not doorStates[hashes[1]]
    local changed = {}
    for _, hash in ipairs(hashes) do
        if type(hash) == 'number' then
            doorStates[hash] = open or nil
            changed[#changed + 1] = hash
        end
    end

    TriggerClientEvent('coi_door_lock:apply', -1, changed, open)
end)
