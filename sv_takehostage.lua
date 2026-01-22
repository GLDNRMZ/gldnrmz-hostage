local takingHostage = {}
-- takingHostage[source] = targetSource, source is takingHostage targetSource
local takenHostage = {}
-- takenHostage[targetSource] = source, targetSource is being takenHostage by source

local function GetDistance(id1, id2)
    local ped1 = GetPlayerPed(id1)
    local ped2 = GetPlayerPed(id2)
    if ped1 and ped2 and DoesEntityExist(ped1) and DoesEntityExist(ped2) then
        local c1 = GetEntityCoords(ped1)
        local c2 = GetEntityCoords(ped2)
        return #(c1 - c2)
    end
    return 1000.0
end

RegisterNetEvent("TakeHostage:sync")
AddEventHandler("TakeHostage:sync", function(targetSrc)
    local source = source
    
    if not targetSrc or targetSrc == -1 then return end

    -- Security: Check distance
    local dist = GetDistance(source, targetSrc)
    if dist > 5.0 then
        print(string.format("^1[TakeHostage] Warning: Player %s tried to take hostage %s but was too far (%.2f units)^7", source, targetSrc, dist))
        return
    end

    TriggerClientEvent("TakeHostage:syncTarget", targetSrc, source)
    takingHostage[source] = targetSrc
    takenHostage[targetSrc] = source
end)

RegisterNetEvent("TakeHostage:releaseHostage")
AddEventHandler("TakeHostage:releaseHostage", function(targetSrc)
    local source = source
    
    -- Security: Ensure source is the agressor
    if takingHostage[source] == targetSrc then 
        TriggerClientEvent("TakeHostage:releaseHostage", targetSrc, source)
        takingHostage[source] = nil
        takenHostage[targetSrc] = nil
    else
        print(string.format("^1[TakeHostage] Warning: Player %s tried to release hostage %s but was not the agressor^7", source, targetSrc))
    end
end)

RegisterNetEvent("TakeHostage:killHostage")
AddEventHandler("TakeHostage:killHostage", function(targetSrc)
    local source = source

    -- Security: Ensure source is the agressor
    if takingHostage[source] == targetSrc then 
        TriggerClientEvent("TakeHostage:killHostage", targetSrc, source)
        takingHostage[source] = nil
        takenHostage[targetSrc] = nil
    else
        print(string.format("^1[TakeHostage] Warning: Player %s tried to kill hostage %s but was not the agressor^7", source, targetSrc))
    end
end)

RegisterNetEvent("TakeHostage:stop")
AddEventHandler("TakeHostage:stop", function(targetSrc)
    local source = source

    if takingHostage[source] == targetSrc then
        TriggerClientEvent("TakeHostage:cl_stop", targetSrc)
        takingHostage[source] = nil
        takenHostage[targetSrc] = nil
    elseif takenHostage[source] == targetSrc then
        -- If the victim triggers stop (e.g. disconnect cleanup logic might trigger this, but usually client logic handles it)
        -- In this script, the client only triggers 'stop' if agressor kills?
        -- Actually, client only triggers 'stop' after 'killHostage' in the agressor logic.
        TriggerClientEvent("TakeHostage:cl_stop", targetSrc)
        takenHostage[source] = nil
        takingHostage[targetSrc] = nil
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    
    if takingHostage[source] then
        local target = takingHostage[source]
        TriggerClientEvent("TakeHostage:cl_stop", target)
        takenHostage[target] = nil
        takingHostage[source] = nil
    end

    if takenHostage[source] then
        local agressor = takenHostage[source]
        TriggerClientEvent("TakeHostage:cl_stop", agressor)
        takingHostage[agressor] = nil
        takenHostage[source] = nil
    end
end)

local function CheckVersion()
	PerformHttpRequest('https://raw.githubusercontent.com/GLDNRMZ/'..GetCurrentResourceName()..'/main/version.txt', function(err, text, headers)
		local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')
		if not text then 
			print('^1[GLDNRMZ] Unable to check version for '..GetCurrentResourceName()..'^0')
			return 
		end
		local result = text:gsub("\r", ""):gsub("\n", "")
		if result ~= currentVersion then
			print('^1[GLDNRMZ] '..GetCurrentResourceName()..' is out of date! Latest: '..result..' | Current: '..currentVersion..'^0')
		else
			print('^2[GLDNRMZ] '..GetCurrentResourceName()..' is up to date! ('..currentVersion..')^0')
		end
	end)
end

Citizen.CreateThread(function()
	-- CheckVersion()
end)
