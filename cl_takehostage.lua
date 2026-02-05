local takeHostage = {
    InProgress = false,
    type = "",
    targetSrc = -1,
    targetPed = nil, -- Used for NPC
    isNPC = false
}

local QBCore = nil
local ESX = nil
local PlayerJob = {}

-- Initialize Framework
CreateThread(function()
    Wait(500)
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('qbx_core') == 'started' then
        QBCore = exports['qbx_core']:GetCoreObject()
    elseif GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end

    if QBCore then
        local playerData = QBCore.Functions.GetPlayerData()
        if playerData then PlayerJob = playerData.job end
    elseif ESX then
        local playerData = ESX.GetPlayerData()
        if playerData then PlayerJob = playerData.job end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerJob = QBCore.Functions.GetPlayerData().job
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerJob = xPlayer.job
end)

RegisterNetEvent('esx:setJob', function(job)
    PlayerJob = job
end)

local function ShowNotification(text, type)
    if exports['ox_lib'] then
        exports['ox_lib']:notify({
            title = 'Take Hostage',
            description = text,
            type = type or 'error'
        })
    else
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

local function ShowPersistentUI(text)
    if Config.TextUI == 'ox_lib' then
        exports['ox_lib']:showTextUI(text, {
            position = "left-center",
            icon = 'hand',
            style = {
                borderRadius = 0,
                backgroundColor = '#1f1f1f',
                color = 'white'
            }
        })
    elseif Config.TextUI == 'qb-core' then
        exports['qb-core']:DrawText(text, 'left')
    elseif Config.TextUI == 'esx' then
        exports["esx_textui"]:TextUI(text)
    elseif Config.TextUI == 'cd_drawtextui' then
        exports['cd_drawtextui']:ShowUI('show', text)
    elseif Config.TextUI == 'arp_ui' then
        exports['arp_ui']:Show('G', Config.Text.Release)
        exports['arp_ui']:Show('H', Config.Text.Kill)
    elseif Config.TextUI == 'native' then
        BeginTextCommandDisplayHelp("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandDisplayHelp(0, false, true, -1)
    elseif exports['arp_ui'] then -- Fallback for existing users who might rely on this implicitly if not configured, or remove if you want strict config
        exports['arp_ui']:Show('G', Config.Text.Release)
        exports['arp_ui']:Show('H', Config.Text.Kill)
    else
        BeginTextCommandDisplayHelp("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandDisplayHelp(0, false, true, -1)
    end
end

local function HidePersistentUI()
    if Config.TextUI == 'ox_lib' then
        exports['ox_lib']:hideTextUI()
    elseif Config.TextUI == 'qb-core' then
        exports['qb-core']:HideText()
    elseif Config.TextUI == 'esx' then
        exports["esx_textui"]:HideUI()
    elseif Config.TextUI == 'cd_drawtextui' then
        exports['cd_drawtextui']:HideUI()
    elseif Config.TextUI == 'arp_ui' then
        exports['arp_ui']:Hide()
    elseif Config.TextUI == 'native' then
        ClearAllHelpMessages()
    elseif exports['arp_ui'] then
        exports['arp_ui']:Hide()
    else
        ClearAllHelpMessages()
    end
end

local function TriggerPoliceAlert()
    if Config.PoliceAlert.enabled then
        local alertChance = math.random(1, 100)
        if alertChance <= Config.PoliceAlert.chance then
            local coords = GetEntityCoords(PlayerPedId())
            if exports['tk_dispatch'] then
                exports.tk_dispatch:addCall({
                    title = Config.PoliceAlert.dispatch.title,
                    code = Config.PoliceAlert.dispatch.code,
                    priority = Config.PoliceAlert.dispatch.priority,
                    message = Config.PoliceAlert.dispatch.message,
                    coords = coords,
                    coordsOffset = Config.PoliceAlert.dispatch.coordsOffset,
                    showLocation = Config.PoliceAlert.dispatch.showLocation,
                    showDirection = Config.PoliceAlert.dispatch.showDirection,
                    showGender = Config.PoliceAlert.dispatch.showGender,
                    showVehicle = Config.PoliceAlert.dispatch.showVehicle,
                    showWeapon = Config.PoliceAlert.dispatch.showWeapon,
                    showPerson = Config.PoliceAlert.dispatch.showPerson,
                    showNumber = Config.PoliceAlert.dispatch.showNumber,
                    platePercentage = Config.PoliceAlert.dispatch.platePercentage,
                    takePhoto = Config.PoliceAlert.dispatch.takePhoto,
                    playSound = Config.PoliceAlert.dispatch.playSound,
                    playSoundAll = Config.PoliceAlert.dispatch.playSoundAll,
                    flash = Config.PoliceAlert.dispatch.flash,
                    color = Config.PoliceAlert.dispatch.color,
                    removeTime = Config.PoliceAlert.dispatch.removeTime,
                    showTime = Config.PoliceAlert.dispatch.showTime,
                    blip = {
                        color = Config.PoliceAlert.dispatch.blip.color,
                        sprite = Config.PoliceAlert.dispatch.blip.sprite,
                        scale = Config.PoliceAlert.dispatch.blip.scale,
                        display = Config.PoliceAlert.dispatch.blip.display,
                        shortRange = Config.PoliceAlert.dispatch.blip.shortRange,
                        flash = Config.PoliceAlert.dispatch.blip.flash,
                        radius = Config.PoliceAlert.dispatch.blip.radius,
                    },
                    jobs = Config.PoliceAlert.dispatch.jobs,
                })
            end
        end
    end
end

local function GetClosestPlayer(radius)
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(targetCoords - playerCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
    if closestDistance ~= -1 and closestDistance <= radius then
        return closestPlayer, closestDistance
    else
        return nil, 9999.0
    end
end

local function GetClosestPed(radius)
    local closestDistance = -1
    local closestPed = nil
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local handle, ped = FindFirstPed()
    local success
    repeat
        if ped ~= playerPed and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) and IsPedHuman(ped) and not IsEntityPositionFrozen(ped) and GetEntityCanBeDamaged(ped) then
            local targetCoords = GetEntityCoords(ped)
            local distance = #(targetCoords - playerCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPed = ped
                closestDistance = distance
            end
        end
        success, ped = FindNextPed(handle)
    until not success
    EndFindPed(handle)

    if closestDistance ~= -1 and closestDistance <= radius then
        return closestPed, closestDistance
    else
        return nil, 9999.0
    end
end

local function ensureAnimDict(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(0)
        end        
    end
    return animDict
end

local function releaseHostageNPC()
    local ped = takeHostage.targetPed
    local playerPed = PlayerPedId()
    if DoesEntityExist(ped) then
        local pCoords = GetEntityCoords(playerPed)
        local pForward = GetEntityForwardVector(playerPed)
        local releaseX = pCoords.x + (pForward.x * 1.5)
        local releaseY = pCoords.y + (pForward.y * 1.5)
        
        DetachEntity(ped, true, false)
        SetEntityCoords(ped, releaseX, releaseY, pCoords.z - 1.0, 0, 0, 0, false)
        
        ensureAnimDict(Config.Animations.release_hostage.animDict)
        TaskPlayAnim(ped, Config.Animations.release_hostage.animDict, Config.Animations.release_hostage.anim, 8.0, -8.0, -1, Config.Animations.release_hostage.flag, 0, false, false, false)
    end
    takeHostage.targetPed = nil
    takeHostage.isNPC = false
end

local function killHostageNPC()
    local ped = takeHostage.targetPed
    if DoesEntityExist(ped) then
        DetachEntity(ped, true, false)
        ensureAnimDict("anim@gangops@hostage@")
        TaskPlayAnim(ped, "anim@gangops@hostage@", "victim_fail", 8.0, -8.0, -1, 168, 0, false, false, false)
        SetEntityHealth(ped, 0)
    end
    takeHostage.targetPed = nil
    takeHostage.isNPC = false
end

local function callTakeHostage()
    ClearPedSecondaryTask(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)

    if takeHostage.InProgress then
        ShowNotification(Config.Text.AlreadyHaveHostage, 'error')
        return
    end

    if Config.BlacklistedJobs then
        for _, job in ipairs(Config.BlacklistedJobs) do
            if PlayerJob and PlayerJob.name == job then
                ShowNotification(Config.Text.BlacklistedJob, 'error')
                return
            end
        end
    end

    local canTakeHostage = false
    local foundWeapon = nil

    for i = 1, #Config.AllowedWeapons do
        if HasPedGotWeapon(PlayerPedId(), Config.AllowedWeapons[i], false) then
            if GetAmmoInPedWeapon(PlayerPedId(), Config.AllowedWeapons[i]) > 0 then
                canTakeHostage = true 
                foundWeapon = Config.AllowedWeapons[i]
                break
            end 					
        end
    end

    if not canTakeHostage then 
        ShowNotification(Config.Text.NeedWeapon, 'error')
        return
    end

    if IsPedInAnyVehicle(PlayerPedId(), true) then
        ShowNotification(Config.Text.InVehicle, 'error')
        return
    end

    if not takeHostage.InProgress and canTakeHostage then			
        local closestPlayer, distPlayer = GetClosestPlayer(3.0)
        local closestPed, distPed = nil, 9999.0
        
        if Config.AllowPeds then
            closestPed, distPed = GetClosestPed(3.0)
        end

        if closestPlayer and (not closestPed or distPlayer < distPed) then
            -- Player Target
            local targetSrc = GetPlayerServerId(closestPlayer)
            if targetSrc ~= -1 then
                local targetPed = GetPlayerPed(closestPlayer)
                
                if IsPedInAnyVehicle(targetPed, true) then
                    ShowNotification(Config.Text.InVehicle, 'error')
                    return
                end

                -- Check for hands up animation
                if not IsEntityPlayingAnim(targetPed, "missminuteman_1ig_2", "handsup_base", 3) and 
                   not IsEntityPlayingAnim(targetPed, "random@mugging3", "handsup_standing_base", 3) and 
                   not IsEntityPlayingAnim(targetPed, "random@arrests@busted", "idle_a", 3) then
                    ShowNotification(Config.Text.HandsUp, 'error')
                    return
                end

                SetCurrentPedWeapon(PlayerPedId(), foundWeapon, true)
                takeHostage.InProgress = true
                takeHostage.targetSrc = targetSrc
                takeHostage.isNPC = false
                TriggerServerEvent("TakeHostage:sync", targetSrc)
                ensureAnimDict(Config.Animations.agressor.animDict)
                takeHostage.type = "agressor"
                TriggerPoliceAlert()
            else
                ShowNotification(Config.Text.NoOneNearby, 'error')
            end
        elseif closestPed then
            -- NPC Target
            if IsPedInAnyVehicle(closestPed, true) then
                ShowNotification(Config.Text.InVehicle, 'error')
                return
            end

            SetCurrentPedWeapon(PlayerPedId(), foundWeapon, true)
            takeHostage.InProgress = true
            takeHostage.targetPed = closestPed
            takeHostage.isNPC = true
            
            -- Request control
            NetworkRequestControlOfEntity(closestPed)
            local timeout = 0
            while not NetworkHasControlOfEntity(closestPed) and timeout < 10 do
                Wait(100)
                timeout = timeout + 1
            end

            SetBlockingOfNonTemporaryEvents(closestPed, true)
            SetPedFleeAttributes(closestPed, 0, 0)
            SetPedCombatAttributes(closestPed, 17, 1)
            ClearPedTasksImmediately(closestPed)
            ensureAnimDict(Config.Animations.hostage.animDict)
            AttachEntityToEntity(closestPed, PlayerPedId(), 0, Config.Animations.hostage.attachX, Config.Animations.hostage.attachY, Config.Animations.hostage.attachZ, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
            TaskPlayAnim(closestPed, Config.Animations.hostage.animDict, Config.Animations.hostage.anim, 8.0, -8.0, -1, Config.Animations.hostage.flag, 0, false, false, false)
            
            ensureAnimDict(Config.Animations.agressor.animDict)
            takeHostage.type = "agressor"
            TriggerPoliceAlert()
        else
            ShowNotification(Config.Text.NoOneNearby, 'error')
        end
    end
end 

RegisterCommand("takehostage", function()
    callTakeHostage()
end)

RegisterCommand("th", function()
    callTakeHostage()
end)

RegisterNetEvent("TakeHostage:syncTarget")
AddEventHandler("TakeHostage:syncTarget", function(target)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(target))
    takeHostage.InProgress = true
    ensureAnimDict(Config.Animations.hostage.animDict)
    AttachEntityToEntity(PlayerPedId(), targetPed, 0, Config.Animations.hostage.attachX, Config.Animations.hostage.attachY, Config.Animations.hostage.attachZ, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
    takeHostage.type = "hostage" 
end)

RegisterNetEvent("TakeHostage:releaseHostage")
AddEventHandler("TakeHostage:releaseHostage", function()
    takeHostage.InProgress = false 
    takeHostage.type = ""
    local playerPed = PlayerPedId()
    local pCoords = GetEntityCoords(playerPed)
    local pForward = GetEntityForwardVector(playerPed)
    local releaseX = pCoords.x + (pForward.x * 1.5)
    local releaseY = pCoords.y + (pForward.y * 1.5)

    DetachEntity(playerPed, true, false)
    SetEntityCoords(playerPed, releaseX, releaseY, pCoords.z - 1.0, 0, 0, 0, false)
    
    ensureAnimDict(Config.Animations.release_hostage.animDict)
    TaskPlayAnim(playerPed, Config.Animations.release_hostage.animDict, Config.Animations.release_hostage.anim, 8.0, -8.0, -1, Config.Animations.release_hostage.flag, 0, false, false, false)
    HidePersistentUI()
end)

RegisterNetEvent("TakeHostage:killHostage")
AddEventHandler("TakeHostage:killHostage", function()
    takeHostage.InProgress = false 
    takeHostage.type = ""
    SetEntityHealth(PlayerPedId(), 0)
    DetachEntity(PlayerPedId(), true, false)
    ensureAnimDict("anim@gangops@hostage@")
    TaskPlayAnim(PlayerPedId(), "anim@gangops@hostage@", "victim_fail", 8.0, -8.0, -1, 168, 0, false, false, false)
    HidePersistentUI()
end)

RegisterNetEvent("TakeHostage:cl_stop")
AddEventHandler("TakeHostage:cl_stop", function()
    takeHostage.InProgress = false
    takeHostage.type = "" 
    ClearPedSecondaryTask(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    HidePersistentUI()
end)

-- Optimized Loop
CreateThread(function()
    while true do
        local sleep = 1000
        
        if takeHostage.InProgress then
            sleep = 0
            local playerPed = PlayerPedId()

            if takeHostage.type == "agressor" then
                if not IsEntityPlayingAnim(playerPed, Config.Animations.agressor.animDict, Config.Animations.agressor.anim, 3) then
                    TaskPlayAnim(playerPed, Config.Animations.agressor.animDict, Config.Animations.agressor.anim, 8.0, -8.0, 100000, Config.Animations.agressor.flag, 0, false, false, false)
                end
                
                -- Keep NPC playing anim
                if takeHostage.isNPC and takeHostage.targetPed then
                    if not IsEntityPlayingAnim(takeHostage.targetPed, Config.Animations.hostage.animDict, Config.Animations.hostage.anim, 3) then
                        TaskPlayAnim(takeHostage.targetPed, Config.Animations.hostage.animDict, Config.Animations.hostage.anim, 8.0, -8.0, 100000, Config.Animations.hostage.flag, 0, false, false, false)
                    end
                end

                DisableControlAction(0, 24, true) -- disable attack
                DisableControlAction(0, 25, true) -- disable aim
                DisableControlAction(0, 47, true) -- disable weapon
                DisableControlAction(0, 58, true) -- disable weapon
                DisableControlAction(0, 21, true) -- disable sprint
                DisableControlAction(0, 23, true) -- disable enter vehicle
                if IsDisabledControlJustPressed(0, 23) then
                    ShowNotification(Config.Text.CannotEnterVehicle, 'error')
                end
                DisablePlayerFiring(playerPed, true)
                
                ShowPersistentUI(Config.Text.HelpText)

                if IsEntityDead(playerPed) then	
                    takeHostage.type = ""
                    takeHostage.InProgress = false
                    ensureAnimDict("reaction@shove")
                    TaskPlayAnim(playerPed, "reaction@shove", "shove_var_a", 8.0, -8.0, -1, 168, 0, false, false, false)
                    if takeHostage.isNPC then
                        releaseHostageNPC()
                    else
                        TriggerServerEvent("TakeHostage:releaseHostage", takeHostage.targetSrc)
                    end
                    HidePersistentUI()
                end 

                if IsDisabledControlJustPressed(0, Config.Controls.Release) then -- release	
                    takeHostage.type = ""
                    takeHostage.InProgress = false 
                    ensureAnimDict("reaction@shove")
                    TaskPlayAnim(playerPed, "reaction@shove", "shove_var_a", 8.0, -8.0, -1, 168, 0, false, false, false)
                    if takeHostage.isNPC then
                        releaseHostageNPC()
                    else
                        TriggerServerEvent("TakeHostage:releaseHostage", takeHostage.targetSrc)
                    end
                    HidePersistentUI()
                elseif IsDisabledControlJustPressed(0, Config.Controls.Kill) then -- kill 			
                    takeHostage.type = ""
                    takeHostage.InProgress = false 		
                    ensureAnimDict("anim@gangops@hostage@")
                    TaskPlayAnim(playerPed, "anim@gangops@hostage@", "perp_fail", 8.0, -8.0, -1, 168, 0, false, false, false)
                    if takeHostage.isNPC then
                        killHostageNPC()
                    else
                        TriggerServerEvent("TakeHostage:killHostage", takeHostage.targetSrc)
                        TriggerServerEvent("TakeHostage:stop", takeHostage.targetSrc)
                    end
                    Wait(100)
                    SetPedShootsAtCoord(playerPed, 0.0, 0.0, 0.0, 0)
                    HidePersistentUI()
                end

            elseif takeHostage.type == "hostage" then
                if not IsEntityPlayingAnim(playerPed, Config.Animations.hostage.animDict, Config.Animations.hostage.anim, 3) then
                    TaskPlayAnim(playerPed, Config.Animations.hostage.animDict, Config.Animations.hostage.anim, 8.0, -8.0, 100000, Config.Animations.hostage.flag, 0, false, false, false)
                end

                DisableControlAction(0, 21, true) -- disable sprint
                DisableControlAction(0, 24, true) -- disable attack
                DisableControlAction(0, 25, true) -- disable aim
                DisableControlAction(0, 47, true) -- disable weapon
                DisableControlAction(0, 58, true) -- disable weapon
                DisableControlAction(0, 263, true) -- disable melee
                DisableControlAction(0, 264, true) -- disable melee
                DisableControlAction(0, 257, true) -- disable melee
                DisableControlAction(0, 140, true) -- disable melee
                DisableControlAction(0, 141, true) -- disable melee
                DisableControlAction(0, 142, true) -- disable melee
                DisableControlAction(0, 143, true) -- disable melee
                DisableControlAction(0, 75, true) -- disable exit vehicle
                DisableControlAction(27, 75, true) -- disable exit vehicle  
                DisableControlAction(0, 22, true) -- disable jump
                DisableControlAction(0, 32, true) -- disable move up
                DisableControlAction(0, 268, true)
                DisableControlAction(0, 33, true) -- disable move down
                DisableControlAction(0, 269, true)
                DisableControlAction(0, 34, true) -- disable move left
                DisableControlAction(0, 270, true)
                DisableControlAction(0, 35, true) -- disable move right
                DisableControlAction(0, 271, true)
                DisableControlAction(0, 30, true) -- disable move lr
                DisableControlAction(0, 31, true) -- disable move ud
                DisableControlAction(0, 23, true) -- disable enter vehicle
                DisableControlAction(0, 44, true) -- disable cover
            end
        end
        Wait(sleep)
    end
end)

-- Exports
exports("TakeHostage", callTakeHostage)
