Config = {}

-- Options: 'ox_lib', 'qb-core', 'esx', 'cd_drawtextui', 'native', 'arp_ui'
Config.TextUI = 'arp_ui'

Config.AllowPeds = true

Config.BlacklistedJobs = {
    "police",
    "ambulance",
}

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
    `WEAPON_GLOCK20`,
    `WEAPON_GLOCK17`,
    `WEAPON_GLOCK20`,
    `WEAPON_GLOCK22`,
    `WEAPON_GLOCK18C`,
    `WEAPON_DEAGLE`,
    `WEAPON_FNX45`,
    `WEAPON_M1911`,
    `WEAPON_GLOCK19GEN4`,
    `WEAPON_DP9`,
    `WEAPON_BROWNING`,
    -- Add more weapons as needed
}

Config.Animations = {
    agressor = {
        animDict = "anim@gangops@hostage@",
        anim = "perp_idle",
        flag = 49,
    },
    hostage = {
        animDict = "anim@gangops@hostage@",
        anim = "victim_idle",
        attachX = -0.24, -- Adjusted for standing
        attachY = 0.11,  -- Adjusted for standing
        attachZ = 0.05,
        flag = 1,
    },
    release_hostage = {
        animDict = "random@homelandsecurity",
        anim = "knees_loop_girl",
        flag = 1,
    }
}

Config.Controls = {
    Release = 47, -- G
    Kill = 74,    -- H
}

Config.PoliceAlert = {
    enabled = true,
    chance = 20,
    dispatch = {
        title = "Hostage Situation",
        code = "10-90",
        priority = "Priority 1",
        message = "ARMED HOSTAGE TAKING IN PROGRESS",
        showLocation = true,
        showDirection = true,
        showGender = true,
        showWeapon = true,
        platePercentage = 100,
        coordsOffset = 0,
        playSound = true,
        flash = true,
        color = "red",
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
        jobs = { "police", "sheriff" },
    }
}

Config.Text = {
    TakeHostage = "Take Hostage",
    Release = "Release",
    Kill = "Kill",
    HelpText = "[G] Release | [H] Kill",
    NoOneNearby = "No one nearby to take as hostage!",
    NeedWeapon = "You need a pistol with ammo to take a hostage at gunpoint!",
    HandsUp = "Target must have their hands up!",
    InVehicle = "You or the target cannot be in a vehicle!",
    CannotEnterVehicle = "You cannot enter a vehicle while holding a hostage!",
    AlreadyHaveHostage = "You already have a hostage!",
    BlacklistedJob = "You cannot take hostages!"
}
