# gldnrmz-hostage

A lightweight and optimized script for FiveM that allows players to take other players or NPCs as hostages. Compatible with QB-Core, Qbox, and ESX.

## Features

- **Framework Agnostic**: Works seamlessly with QB-Core, Qbox, and ESX.
- **NPC Support**: Ability to take NPCs as hostages.
- **Smart Targeting**: Prevents grabbing frozen (e.g., shopkeepers) or invincible NPCs.
- **Customizable UI**: Supports multiple TextUI systems (`ox_lib`, `qb-core`, `esx`, `cd_drawtextui`, `arp_ui`, `native`).
- **Police Alerts**: Integrated support for police alerts (supports `tk_dispatch`).
- **Configurable**: extensive configuration for weapons, animations, blacklisted jobs, and more.
- **Optimized**: Low resource usage (0.00ms idle).

## Dependencies

- **Framework**: `qb-core`, `qbx_core`, or `es_extended`.
- **Optional**:
    - `ox_lib` (For notifications and TextUI)
    - `tk_dispatch` (For police alerts)
    - `cd_drawtextui` (If used as TextUI)
    - `arp_ui` (If used as TextUI)

## Installation

1. Download the script and place it in your `resources` folder.
2. Add `ensure gldnrmz-hostage` to your `server.cfg`.
3. Configure the script in `config.lua` to match your server's needs.

## Configuration

### Text UI
You can choose your preferred TextUI system in `config.lua`:

```lua
-- Options: 'ox_lib', 'qb-core', 'esx', 'cd_drawtextui', 'native', 'arp_ui'
Config.TextUI = 'ox_lib'
```

### Weapons
Define which weapons can be used to take a hostage:

```lua
Config.AllowedWeapons = {
    `WEAPON_PISTOL`,
    `WEAPON_COMBATPISTOL`,
    -- Add more...
}
```

### Blacklisted Jobs
Prevent certain jobs from taking hostages:

```lua
Config.BlacklistedJobs = {
    "police",
    "ambulance",
}
```

## Usage

1. Equip a compatible weapon (e.g., Pistol).
2. Aim at a player or NPC.
3. Use the command:
   - `/takehostage`
   - `/th`
4. **Controls**:
   - **G**: Release the hostage.
   - **H**: Kill the hostage.

**Note for Player Targets**: The target player must have their hands up for you to take them hostage.

## Events

- `TakeHostage:sync`: Triggered when taking a hostage.
- `TakeHostage:releaseHostage`: Triggered when releasing a hostage.
- `TakeHostage:killHostage`: Triggered when killing a hostage.
