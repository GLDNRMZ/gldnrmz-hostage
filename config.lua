Config = {}

Config.Debug        = false -- Print debug info to F8 / server console
Config.VersionCheck = false -- Compare against GLDNRMZ's GitHub version.txt

---------------------------------------------------------------------
-- Gameplay
---------------------------------------------------------------------
Config.AllowPeds        = true  -- Allow taking NPCs hostage
Config.AllowScriptPeds  = false -- Allow NPCs spawned by other resources (job peds, quest NPCs). Off avoids breaking them.
Config.MaxDistance      = 3.0  -- How close the target must be
Config.Cooldown         = 10   -- Seconds before the same player can take another hostage
Config.RequireHandsUp   = true -- Player targets must have their hands up
Config.ReleaseOnRagdoll = true -- Aggressor drops the hostage when tackled / ragdolled
Config.BlockHostageInventory = true -- Sets the `invBusy` state bag on the hostage (ox_inventory, qbx)

-- Text UI while holding a hostage:
--   'arp_ui' - two key prompts via arp_ui
--   'bridge' - community_bridge HelpText (ox_lib / cd_drawtextui / jg-textui / ...)
--   'native' - GTA help text, top-left
--   'none'
Config.TextUI = 'arp_ui'

-- Default keys. Players can rebind these in Settings > Key Bindings > FiveM.
Config.Keys = {
    release = 'G',
    kill    = 'H',
    take    = '', -- Optional key for /takehostage (empty = unbound, players can set it)
}

Config.BlacklistedJobs = {
    police    = true,
    sheriff   = true,
    ambulance = true,
}

-- Weapon that must be in hand (with ammo). Checked on the client and the server.
Config.AllowedWeapons = {
    `WEAPON_PISTOL`,
    `WEAPON_COMBATPISTOL`,
    `WEAPON_PISTOL50`,
    `WEAPON_SNSPISTOL`,
    `WEAPON_HEAVYPISTOL`,
    `WEAPON_VINTAGEPISTOL`,
    `WEAPON_REVOLVER`,
    `WEAPON_DOUBLEACTION`,
    `WEAPON_APPISTOL`,
    `WEAPON_GLOCK17`,
    `WEAPON_GLOCK18C`,
    `WEAPON_GLOCK19GEN4`,
    `WEAPON_GLOCK20`,
    `WEAPON_GLOCK22`,
    `WEAPON_DEAGLE`,
    `WEAPON_FNX45`,
    `WEAPON_M1911`,
    `WEAPON_DP9`,
    `WEAPON_BROWNING`,
}

-- Any weapon in these weapon groups also counts (covers MK2 / ceramic / XM3 / add-on pistols).
-- Set to {} to allow only the exact weapons listed above.
Config.AllowedWeaponGroups = {
    `GROUP_PISTOL`,
}

-- Any of these anims counts as "hands up". The `handsup` state bag (scully_emotemenu) also counts.
Config.HandsUpAnims = {
    { 'random@mugging3', 'handsup_standing_base' }, -- p_policejob
    { 'missminuteman_1ig_2', 'handsup_base' },
    { 'missminuteman_1ig_2', 'handsup_enter' },
    { 'random@arrests@busted', 'idle_a' },
}

Config.Animations = {
    aggressor = { dict = 'anim@gangops@hostage@', anim = 'perp_idle', flag = 49 },
    hostage   = { dict = 'anim@gangops@hostage@', anim = 'victim_idle', flag = 1 },
    perpKill  = { dict = 'anim@gangops@hostage@', anim = 'perp_fail', flag = 168 },
    victimKill = { dict = 'anim@gangops@hostage@', anim = 'victim_fail', flag = 0 },
    shove     = { dict = 'reaction@shove', anim = 'shove_var_a', flag = 120 },
    released  = { dict = 'random@homelandsecurity', anim = 'knees_loop_girl', flag = 1 },
}

-- Hostage offset from the aggressor
Config.Attach = { x = -0.24, y = 0.11, z = 0.05, rx = 0.5, ry = 0.5, rz = 0.0 }

-- Seconds a released hostage kneels (NPCs run off afterwards)
Config.ReleaseKneel = 4

-- Controls the hostage keeps (everything else is disabled while held)
Config.HostageAllowedControls = {
    1, 2,     -- look
    245,      -- chat
    249,      -- push to talk
    199, 200, -- pause menu
}

---------------------------------------------------------------------
-- Police alert
-- Config.PoliceAlert.Function sends it (community_bridge by default); `dispatch` holds the alert details.
---------------------------------------------------------------------
Config.PoliceAlert = {
    enabled = true,
    chance = 20, -- % per hostage taken
    dispatch = {
        title = 'Hostage Situation',
        code = '10-90',
        priority = 'Priority 1',
        message = 'ARMED HOSTAGE TAKING IN PROGRESS',
        showLocation = true,
        showDirection = true,
        showGender = true,
        showWeapon = true,
        coordsOffset = 0,
        playSound = true,
        flash = true,
        color = 'red',
        removeTime = 300000,
        showTime = 15000,
        blip = {
            color = 1,
            sprite = 58,
            scale = 1.2,
            display = 4,
            shortRange = false,
            flash = true,
        },
        jobs = { 'police', 'sheriff' },
    },
    -- Default: community_bridge sends it to whatever dispatch you run (ps / cd / qs / lb / tk / ...).
    Function = function(coords)
        local d = Config.PoliceAlert.dispatch
        exports.community_bridge:Dispatch().SendAlert({
            message = d.message, code = d.code, icon = 'fas fa-person-rifle', coords = coords,
            jobs = d.jobs, time = d.removeTime,
            blipData = { sprite = d.blip.sprite, color = d.blip.color, scale = d.blip.scale },
        })
    end,
    -- tk_dispatch directly (uses the full `dispatch` table above), if you prefer:
    --[[ Function = function(coords)
        local data = table.clone(Config.PoliceAlert.dispatch)
        data.coords = coords
        exports.tk_dispatch:addCall(data)
    end, ]]
}

---------------------------------------------------------------------
-- Logging (gldnrmz-logs). Kills and takes are logged when the resource is running.
---------------------------------------------------------------------
Config.Logs = true
