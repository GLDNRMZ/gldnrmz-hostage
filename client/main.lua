local Bridge = exports['community_bridge']:Bridge()
local Notify = Bridge.Notify
local HelpText = Bridge.HelpText
local Dispatch = Bridge.Dispatch

local RESOURCE = GetCurrentResourceName()
local Anims = Config.Animations
local Attach = Config.Attach

-- How often (ms) the slower "should this end?" checks run inside the per-frame loops
local CHECK_INTERVAL = 250

---@class HostageState
---@field role 'aggressor'|'hostage'
---@field targetSrc integer?    aggressor: server id of a player hostage
---@field npc integer?          aggressor: NPC hostage ped
---@field aggressorSrc integer? hostage: server id of the aggressor
---@field invBusyWas any?       hostage: invBusy value before we set it

---@type HostageState?
local current = nil
local requesting = false

-- Weapon hashes can come back signed or unsigned, so compare them unsigned.
local function normHash(hash) return hash & 0xFFFFFFFF end

local allowedWeapons = {}
for _, hash in ipairs(Config.AllowedWeapons) do
    allowedWeapons[normHash(hash)] = true
end

local allowedGroups = {}
for _, hash in ipairs(Config.AllowedWeaponGroups or {}) do
    allowedGroups[normHash(hash)] = true
end

---Listed weapon, or any weapon in an allowed weapon group.
local function isAllowedWeapon(weapon)
    if allowedWeapons[normHash(weapon)] then return true end
    return allowedGroups[normHash(GetWeapontypeGroup(weapon))] == true
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function dbg(...)
    if Config.Debug then print(('^5[%s]^7'):format(RESOURCE), ...) end
end

local function notify(key, kind, ...)
    Notify.SendNotify(locale(key, ...), kind or 'error', 3500)
end

local function playAnim(ped, anim, duration)
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(ped, anim.dict, anim.anim, 8.0, -8.0, duration or -1, anim.flag, 0, false, false, false)
end

local function isPlayingAnim(ped, anim)
    return IsEntityPlayingAnim(ped, anim.dict, anim.anim, 3)
end

local function attachTo(ped, parent)
    AttachEntityToEntity(ped, parent, 0, Attach.x, Attach.y, Attach.z, Attach.rx, Attach.ry, Attach.rz,
        false, false, false, false, 2, false)
end

local function getPlayerPedFromServerId(serverId)
    local player = GetPlayerFromServerId(serverId)
    return player ~= -1 and GetPlayerPed(player) or 0
end

local function isIncapacitated(state)
    return state.isDead or state.dead or state.laststand or state.isCuffed
end

---@return boolean ok, string? reason
local function holdingAllowedWeapon(ped)
    local weapon = GetSelectedPedWeapon(ped)
    if not isAllowedWeapon(weapon) then return false, 'need_weapon' end
    -- Clip or reserve ammo (ox_inventory and native loadouts store it differently)
    local _, clip = GetAmmoInClip(ped, weapon)
    if GetAmmoInPedWeapon(ped, weapon) <= 0 and (clip or 0) <= 0 then return false, 'need_ammo' end
    return true
end

local function isHandsUp(ped, serverId)
    if Player(serverId).state.handsup then return true end
    for _, anim in ipairs(Config.HandsUpAnims) do
        if IsEntityPlayingAnim(ped, anim[1], anim[2], 3) then return true end
    end
    return false
end

---------------------------------------------------------------------
-- Keybinds (rebindable in Settings > Key Bindings > FiveM)
---------------------------------------------------------------------
local finishAggressor -- forward declaration

local releaseKey = lib.addKeybind({
    name = 'gldnrmz_hostage_release',
    description = locale('keybind_release'),
    defaultKey = Config.Keys.release,
    disabled = true,
    onPressed = function() finishAggressor('release') end,
})

local killKey = lib.addKeybind({
    name = 'gldnrmz_hostage_kill',
    description = locale('keybind_kill'),
    defaultKey = Config.Keys.kill,
    disabled = true,
    onPressed = function() finishAggressor('kill') end,
})

local function setKeysEnabled(enabled)
    releaseKey:disable(not enabled)
    killKey:disable(not enabled)
end

---------------------------------------------------------------------
-- Text UI (shown once, not every frame)
---------------------------------------------------------------------
local function helpText()
    return locale('help_text', releaseKey:getCurrentKey(), killKey:getCurrentKey())
end

local function showUI()
    if Config.TextUI == 'arp_ui' and GetResourceState('arp_ui') == 'started' then
        exports.arp_ui:Show(releaseKey:getCurrentKey(), locale('release'))
        exports.arp_ui:Show(killKey:getCurrentKey(), locale('kill'))
    elseif Config.TextUI == 'bridge' then
        HelpText.ShowHelpText(helpText(), 'left-center')
    elseif Config.TextUI == 'ox_lib' or Config.TextUI == 'arp_ui' then -- arp_ui falls back to ox_lib when it isn't running
        lib.showTextUI(helpText(), { position = 'left-center' })
    end
end

local function hideUI()
    if Config.TextUI == 'arp_ui' and GetResourceState('arp_ui') == 'started' then
        -- Only remove our prompts, not ones from other resources
        exports.arp_ui:Hide(locale('release'))
        exports.arp_ui:Hide(locale('kill'))
    elseif Config.TextUI == 'bridge' then
        HelpText.HideHelpText()
    elseif Config.TextUI == 'ox_lib' or Config.TextUI == 'arp_ui' then
        lib.hideTextUI()
    elseif Config.TextUI == 'native' then
        ClearAllHelpMessages()
    end
end

local function drawNativeHelp()
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(helpText())
    EndTextCommandDisplayHelp(0, false, false, -1)
end

---------------------------------------------------------------------
-- Police alert
---------------------------------------------------------------------
local function sendPoliceAlert()
    local cfg = Config.PoliceAlert.dispatch
    local coords = GetEntityCoords(cache.ped)

    if Config.PoliceAlert.Function then
        local ok, err = pcall(Config.PoliceAlert.Function, coords)
        if not ok then print(('[gldnrmz-hostage] Config.PoliceAlert.Function failed: %s'):format(err)) end
        return
    end

    Dispatch.SendAlert({
        message = cfg.message,
        code = cfg.code,
        icon = 'fas fa-person-rifle',
        coords = coords,
        jobs = cfg.jobs,
        time = cfg.removeTime,
        blipData = { sprite = cfg.blip.sprite, color = cfg.blip.color, scale = cfg.blip.scale },
    })
end

---------------------------------------------------------------------
-- Target selection
---------------------------------------------------------------------
local function isValidNpc(ped)
    return DoesEntityExist(ped)
        and not IsPedAPlayer(ped)
        and IsPedHuman(ped)
        and not IsPedDeadOrDying(ped, true)
        and not IsEntityPositionFrozen(ped)      -- shopkeepers, job NPCs
        and GetEntityCanBeDamaged(ped)           -- invincible NPCs
        and not IsEntityAttached(ped)            -- already carried / held
        and not IsPedInAnyVehicle(ped, true)
        and (Config.AllowScriptPeds or not IsEntityAMissionEntity(ped))
end

local function getClosestNpc(coords, maxDistance)
    local closest, closestDist = nil, maxDistance
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= cache.ped then
            local dist = #(GetEntityCoords(ped) - coords)
            if dist <= closestDist and isValidNpc(ped) then
                closest, closestDist = ped, dist
            end
        end
    end
    return closest, closestDist
end

---Prefers the ped you're aiming at, then the closest player or NPC.
---@return 'player'|'npc'|nil kind, integer? ped, integer? serverId
local function findTarget()
    local coords = GetEntityCoords(cache.ped)

    local aiming, entity = GetEntityPlayerIsFreeAimingAt(cache.playerId)
    if aiming and entity ~= 0 and IsEntityAPed(entity) and #(GetEntityCoords(entity) - coords) <= Config.MaxDistance then
        if IsPedAPlayer(entity) then
            return 'player', entity, GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
        elseif Config.AllowPeds and isValidNpc(entity) then
            return 'npc', entity
        end
    end

    local playerId, playerPed, playerCoords = lib.getClosestPlayer(coords, Config.MaxDistance, false)
    local playerDist = playerCoords and #(playerCoords - coords) or math.huge

    local npc, npcDist
    if Config.AllowPeds then npc, npcDist = getClosestNpc(coords, Config.MaxDistance) end

    if playerId and (not npc or playerDist <= npcDist) then
        return 'player', playerPed, GetPlayerServerId(playerId)
    elseif npc then
        return 'npc', npc
    end
end

local function requestControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(50)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

---------------------------------------------------------------------
-- NPC hostage
---------------------------------------------------------------------
local function grabNpc(ped)
    SetEntityAsMissionEntity(ped, true, true) -- stop it despawning while held
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    ClearPedTasksImmediately(ped)
    attachTo(ped, cache.ped)
    playAnim(ped, Anims.hostage)
end

local function releaseNpc(ped)
    if not DoesEntityExist(ped) then return end
    DetachEntity(ped, true, false)

    local pos = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 1.2, 0.0)
    SetEntityCoords(ped, pos.x, pos.y, pos.z - 1.0, false, false, false, false)
    playAnim(ped, Anims.released)

    SetTimeout(Config.ReleaseKneel * 1000, function()
        if not DoesEntityExist(ped) then return end
        if not IsPedDeadOrDying(ped, true) then
            ClearPedTasks(ped)
            SetBlockingOfNonTemporaryEvents(ped, false)
            TaskSmartFleePed(ped, cache.ped, 100.0, -1, false, false)
        end
        SetPedAsNoLongerNeeded(ped)
    end)
end

local function killNpc(ped)
    if not DoesEntityExist(ped) then return end
    DetachEntity(ped, true, false)
    playAnim(ped, Anims.victimKill)
    SetEntityHealth(ped, 0)
    SetPedAsNoLongerNeeded(ped)
end

local function dropNpc(ped)
    if not DoesEntityExist(ped) then return end
    DetachEntity(ped, true, false)
    ClearPedTasks(ped)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedAsNoLongerNeeded(ped)
end

---------------------------------------------------------------------
-- Aggressor
---------------------------------------------------------------------
local function getHostagePed(state)
    if state.npc then return state.npc end
    return getPlayerPedFromServerId(state.targetSrc)
end

---Returns true when the aggressor should let go (down, tackled, disarmed, hostage gone).
local function aggressorShouldDrop(state)
    local ped = cache.ped
    if IsEntityDead(ped) or isIncapacitated(LocalPlayer.state) then return true end
    if Config.ReleaseOnRagdoll and IsPedRagdoll(ped) then return true end
    if not isAllowedWeapon(GetSelectedPedWeapon(ped)) then return true end

    local hostage = getHostagePed(state)
    if hostage == 0 or not DoesEntityExist(hostage) or IsPedDeadOrDying(hostage, true) then return true end
    if state.targetSrc and isIncapacitated(Player(state.targetSrc).state) then return true end
    return false
end

---@param action 'release'|'kill'|'drop'
---@param fromServer boolean? the server already ended the session
function finishAggressor(action, fromServer)
    local state = current
    if not state or state.role ~= 'aggressor' then return end
    current = nil

    setKeysEnabled(false)
    hideUI()

    local ped = cache.ped
    local victim = getHostagePed(state)

    if action == 'kill' then
        playAnim(ped, Anims.perpKill)
    elseif action == 'release' then
        playAnim(ped, Anims.shove)
    else
        ClearPedSecondaryTask(ped)
    end

    if state.npc then
        if action == 'kill' then killNpc(state.npc)
        elseif action == 'release' then releaseNpc(state.npc)
        else dropNpc(state.npc) end
    end

    if not fromServer then
        TriggerServerEvent('gldnrmz-hostage:server:end', action)
    end

    if action == 'kill' and victim ~= 0 then
        SetTimeout(100, function()
            local head = GetPedBoneCoords(victim, 31086, 0.0, 0.0, 0.0) -- SKEL_Head
            SetPedShootsAtCoord(cache.ped, head.x, head.y, head.z, true)
        end)
    end

    dbg('aggressor finished', action)
end

local function aggressorLoop()
    local nextCheck = 0
    while current and current.role == 'aggressor' do
        local ped = cache.ped

        if not isPlayingAnim(ped, Anims.aggressor) then playAnim(ped, Anims.aggressor) end
        if current.npc and not isPlayingAnim(current.npc, Anims.hostage) then playAnim(current.npc, Anims.hostage) end

        DisablePlayerFiring(cache.playerId, true)
        DisableControlAction(0, 21, true)  -- sprint
        DisableControlAction(0, 22, true)  -- jump
        DisableControlAction(0, 23, true)  -- enter vehicle
        DisableControlAction(0, 24, true)  -- attack
        DisableControlAction(0, 25, true)  -- aim
        DisableControlAction(0, 37, true)  -- weapon wheel
        DisableControlAction(0, 44, true)  -- cover
        DisableControlAction(0, 47, true)  -- detonate
        DisableControlAction(0, 58, true)  -- throw grenade
        DisableControlAction(0, 140, true) -- melee
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 257, true)
        DisableControlAction(0, 263, true)

        if IsDisabledControlJustPressed(0, 23) then notify('cannot_enter_vehicle') end
        if Config.TextUI == 'native' then drawNativeHelp() end

        local now = GetGameTimer()
        if now >= nextCheck then
            nextCheck = now + CHECK_INTERVAL
            if aggressorShouldDrop(current) then
                finishAggressor('drop')
                break
            end
        end

        Wait(0)
    end
end

---@param targetSrc integer?
---@param npc integer?
---@param alert boolean
local function startAggressor(targetSrc, npc, alert)
    current = { role = 'aggressor', targetSrc = targetSrc, npc = npc }

    if npc then grabNpc(npc) end
    playAnim(cache.ped, Anims.aggressor)

    setKeysEnabled(true)
    showUI()
    if alert then sendPoliceAlert() end

    CreateThread(aggressorLoop)
end

local function takeHostage()
    if current or requesting then return notify('already_busy') end
    if cache.vehicle then return notify('in_vehicle') end
    local armed, why = holdingAllowedWeapon(cache.ped)
    if not armed then return notify(why) end

    local kind, targetPed, targetSrc = findTarget()
    if not kind or not targetPed then return notify('no_one_nearby') end
    if IsPedInAnyVehicle(targetPed, true) then return notify('in_vehicle') end

    if kind == 'player' and Config.RequireHandsUp and not isHandsUp(targetPed, targetSrc) then
        return notify('hands_up')
    end

    requesting = true

    if kind == 'npc' and not requestControl(targetPed) then
        requesting = false
        return notify('no_control')
    end

    local ok, result, arg = lib.callback.await('gldnrmz-hostage:server:take', false, kind == 'player' and targetSrc or nil)
    requesting = false

    if not ok then return notify(result or 'failed', 'error', arg) end

    -- The NPC may have died or been taken while we waited on the server
    if kind == 'npc' and not isValidNpc(targetPed) then
        TriggerServerEvent('gldnrmz-hostage:server:end', 'drop')
        return notify('no_one_nearby')
    end

    startAggressor(kind == 'player' and targetSrc or nil, kind == 'npc' and targetPed or nil, result)
end

RegisterCommand('takehostage', takeHostage, false)
RegisterCommand('th', takeHostage, false)
RegisterKeyMapping('takehostage', locale('keybind_take'), 'keyboard', Config.Keys.take or '')
TriggerEvent('chat:addSuggestion', '/takehostage', locale('command_help'))
TriggerEvent('chat:addSuggestion', '/th', locale('command_help'))

-- Server ended our session (we went down, hostage dropped, admin release, ...)
RegisterNetEvent('gldnrmz-hostage:client:forceEnd', function()
    finishAggressor('drop', true)
end)

---------------------------------------------------------------------
-- Hostage
---------------------------------------------------------------------
local function setInventoryBlocked(state, blocked)
    if not Config.BlockHostageInventory then return end
    if blocked then
        state.invBusyWas = LocalPlayer.state.invBusy
        LocalPlayer.state:set('invBusy', true, true)
    else
        LocalPlayer.state:set('invBusy', state.invBusyWas or false, true)
    end
end

local function hostageLoop()
    local allowed = Config.HostageAllowedControls
    while current and current.role == 'hostage' do
        local ped = cache.ped
        if not IsEntityDead(ped) and not isPlayingAnim(ped, Anims.hostage) then
            playAnim(ped, Anims.hostage)
        end

        DisableAllControlActions(0)
        for i = 1, #allowed do EnableControlAction(0, allowed[i], true) end

        Wait(0)
    end
end

RegisterNetEvent('gldnrmz-hostage:client:taken', function(aggressorSrc)
    if current then return end

    local aggressorPed = lib.waitFor(function()
        local ped = getPlayerPedFromServerId(aggressorSrc)
        if ped ~= 0 then return ped end
    end, nil, 2000)

    if not aggressorPed then
        TriggerServerEvent('gldnrmz-hostage:server:abort')
        return
    end

    current = { role = 'hostage', aggressorSrc = aggressorSrc }
    setInventoryBlocked(current, true)

    local ped = cache.ped
    ClearPedTasks(ped) -- drop hands-up / emotes
    attachTo(ped, aggressorPed)
    playAnim(ped, Anims.hostage)

    CreateThread(hostageLoop)
end)

RegisterNetEvent('gldnrmz-hostage:client:freed', function(action)
    local state = current
    if not state or state.role ~= 'hostage' then return end
    current = nil
    setInventoryBlocked(state, false)

    local ped = cache.ped
    DetachEntity(ped, true, false)

    if action == 'kill' then
        playAnim(ped, Anims.victimKill)
        SetEntityHealth(ped, 0)
    elseif action == 'release' then
        local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
        SetEntityCoords(ped, pos.x, pos.y, pos.z - 1.0, false, false, false, false)
        playAnim(ped, Anims.released, Config.ReleaseKneel * 1000)
    else
        ClearPedTasks(ped)
    end
end)

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE or not current then return end
    local ped = cache.ped

    if current.role == 'aggressor' then
        if current.npc then dropNpc(current.npc) end
        ClearPedSecondaryTask(ped)
        hideUI()
    else
        DetachEntity(ped, true, false)
        ClearPedTasks(ped)
        setInventoryBlocked(current, false)
    end
    current = nil
end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
exports('TakeHostage', takeHostage)
exports('IsTakingHostage', function() return current ~= nil and current.role == 'aggressor' end)
exports('IsHostage', function() return current ~= nil and current.role == 'hostage' end)
---@return 'aggressor'|'hostage'|nil
exports('GetHostageRole', function() return current and current.role end)
