local Bridge = exports['community_bridge']:Bridge()
local Framework = Bridge.Framework

local RESOURCE = GetCurrentResourceName()

-- Extra slack on distance checks for network lag
local DISTANCE_SLACK = 2.0

---@class HostageSession
---@field target integer?  hostage server id (nil when the hostage is an NPC)
---@field startedAt integer os.time()

---@type table<integer, HostageSession> aggressor -> session
local sessions = {}
---@type table<integer, integer> hostage -> aggressor
local heldBy = {}
---@type table<integer, integer> aggressor -> os.time() the cooldown ends
local cooldowns = {}

-- Weapon hashes can come back signed or unsigned, so compare them unsigned.
local function normHash(hash) return hash & 0xFFFFFFFF end

local allowedWeapons = {}
for _, hash in ipairs(Config.AllowedWeapons) do
    allowedWeapons[normHash(hash)] = true
end

-- Weapon groups can only be read on the client; with groups enabled the server
-- still requires a real weapon in hand (the client checks the group).
local useGroups = next(Config.AllowedWeaponGroups or {}) ~= nil
local UNARMED = normHash(`WEAPON_UNARMED`)
local function isAllowedWeapon(weapon)
    weapon = normHash(weapon)
    if allowedWeapons[weapon] then return true end
    return useGroups and weapon ~= 0 and weapon ~= UNARMED
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function dbg(...)
    if Config.Debug then print(('^5[%s]^7'):format(RESOURCE), ...) end
end

local function warn(fmt, ...)
    print(('^1[%s] ' .. fmt .. '^7'):format(RESOURCE, ...))
end

local function log(logType, src, message, metadata)
    if not Config.Logs or GetResourceState('gldnrmz-logs') ~= 'started' then return end
    pcall(function()
        exports['gldnrmz-logs']:createLog({
            LogType = logType,
            Source = src,
            Message = message,
            Metadata = metadata,
            Resource = RESOURCE,
        })
    end)
end

-- Cuffed, dead or in last stand (qbx, wasabi_ambulance, p_policejob)
local function isIncapacitated(src)
    local state = Player(src).state
    return state.isDead or state.dead or state.laststand or state.isCuffed or false
end

local function distanceBetween(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if pedA == 0 or pedB == 0 then return math.huge end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB))
end

-- Replicated so other resources (police, inventory, phone) can react.
-- Values: 'aggressor' | 'hostage' | nil
local function setRole(src, role)
    if GetPlayerName(src) then
        Player(src).state:set('hostageRole', role, true)
    end
end

---------------------------------------------------------------------
-- Session lifecycle
---------------------------------------------------------------------

---Ends an aggressor's session and frees the hostage.
---@param src integer aggressor
---@param action 'release'|'kill'|'drop'
---@param notifyAggressor boolean? tell the aggressor's client (when the server ended it)
local function endSession(src, action, notifyAggressor)
    local session = sessions[src]
    if not session then return end

    sessions[src] = nil
    cooldowns[src] = os.time() + Config.Cooldown
    setRole(src, nil)

    if notifyAggressor then
        TriggerClientEvent('gldnrmz-hostage:client:forceEnd', src)
    end

    local target = session.target
    if target then
        heldBy[target] = nil
        setRole(target, nil)
        TriggerClientEvent('gldnrmz-hostage:client:freed', target, action)
    end

    dbg('session ended', src, target, action)
end

lib.callback.register('gldnrmz-hostage:server:take', function(src, target)
    if sessions[src] or heldBy[src] then return false, 'already_busy' end

    local now = os.time()
    if cooldowns[src] and cooldowns[src] > now then
        return false, 'cooldown', cooldowns[src] - now
    end

    local job = Framework.GetPlayerJob(src)
    if job and Config.BlacklistedJobs[job] then return false, 'blacklisted_job' end

    local ped = GetPlayerPed(src)
    if ped == 0 or isIncapacitated(src) then return false, 'failed' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'in_vehicle' end
    if not isAllowedWeapon(GetSelectedPedWeapon(ped)) then return false, 'need_weapon' end

    if target ~= nil then
        target = tonumber(target)
        if not target or target == src or not GetPlayerName(target) then return false, 'no_one_nearby' end
        if sessions[target] or heldBy[target] then return false, 'target_busy' end
        if isIncapacitated(target) then return false, 'target_incapacitated' end

        local targetPed = GetPlayerPed(target)
        if targetPed == 0 then return false, 'no_one_nearby' end
        if GetVehiclePedIsIn(targetPed, false) ~= 0 then return false, 'in_vehicle' end

        local dist = distanceBetween(src, target)
        if dist > Config.MaxDistance + DISTANCE_SLACK then
            warn('%s tried to take %s hostage from %.1fm away', src, target, dist)
            return false, 'too_far'
        end
    end

    sessions[src] = { target = target, startedAt = now }
    setRole(src, 'aggressor')

    if target then
        heldBy[target] = src
        setRole(target, 'hostage')
        TriggerClientEvent('gldnrmz-hostage:client:taken', target, src)
    end

    log('custom', src, target
        and ('Took %s (%s) hostage'):format(GetPlayerName(target), target)
        or 'Took an NPC hostage', { target = target })

    local alert = Config.PoliceAlert.enabled and math.random(100) <= Config.PoliceAlert.chance
    return true, alert
end)

-- Aggressor ends their own session. The server decides who the hostage is.
RegisterNetEvent('gldnrmz-hostage:server:end', function(action)
    local src = source
    local session = sessions[src]
    if not session then return end

    if action ~= 'kill' and action ~= 'drop' then action = 'release' end

    if action == 'kill' then
        if isIncapacitated(src) then
            action = 'drop'
        elseif session.target then
            local dist = distanceBetween(src, session.target)
            if dist > Config.MaxDistance + DISTANCE_SLACK then
                warn('%s tried to kill hostage %s from %.1fm away', src, session.target, dist)
                action = 'drop'
            else
                log('deaths', src, ('Executed hostage %s (%s)'):format(GetPlayerName(session.target), session.target),
                    { target = session.target })
            end
        end
    end

    endSession(src, action)
end)

-- Hostage's client couldn't find the aggressor's ped. Only honoured right after the take.
RegisterNetEvent('gldnrmz-hostage:server:abort', function()
    local src = source
    local aggressor = heldBy[src]
    if aggressor and sessions[aggressor] and os.time() - sessions[aggressor].startedAt <= 5 then
        endSession(aggressor, 'drop', true)
    end
end)

---------------------------------------------------------------------
-- Watchdog: ends sessions when either side goes down, gets cuffed or separated,
-- even if the aggressor's client stops responding.
---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(next(sessions) and 1000 or 3000)
        for src, session in pairs(sessions) do
            local target = session.target
            if isIncapacitated(src) then
                endSession(src, 'drop', true)
            elseif target and (isIncapacitated(target) or distanceBetween(src, target) > 10.0) then
                endSession(src, 'drop', true)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source

    if sessions[src] then
        endSession(src, 'drop')
    end

    local aggressor = heldBy[src]
    if aggressor then
        heldBy[src] = nil
        if sessions[aggressor] then
            sessions[aggressor].target = nil
            endSession(aggressor, 'drop', true)
        end
    end

    cooldowns[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    for src in pairs(sessions) do setRole(src, nil) end
    for src in pairs(heldBy) do setRole(src, nil) end
end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------

---@return 'aggressor'|'hostage'|nil
exports('GetHostageRole', function(src)
    if sessions[src] then return 'aggressor' end
    if heldBy[src] then return 'hostage' end
end)

---Frees a player from a hostage situation, whichever side they are on.
exports('ForceRelease', function(src)
    if sessions[src] then
        endSession(src, 'release', true)
        return true
    end
    local aggressor = heldBy[src]
    if aggressor then
        endSession(aggressor, 'release', true)
        return true
    end
    return false
end)

---------------------------------------------------------------------
-- Version check
---------------------------------------------------------------------
if Config.VersionCheck then
    CreateThread(function()
        local current = GetResourceMetadata(RESOURCE, 'version', 0)
        PerformHttpRequest(('https://raw.githubusercontent.com/GLDNRMZ/%s/main/version.txt'):format(RESOURCE), function(status, text)
            if status ~= 200 or not text then
                print(('^1[GLDNRMZ] Unable to check version for %s^0'):format(RESOURCE))
                return
            end
            local latest = text:gsub('%s+', '')
            if latest ~= current then
                print(('^1[GLDNRMZ] %s is out of date! Latest: %s | Current: %s^0'):format(RESOURCE, latest, current))
            else
                print(('^2[GLDNRMZ] %s is up to date! (%s)^0'):format(RESOURCE, current))
            end
        end)
    end)
end
