# gldnrmz-hostage

Take players or NPCs hostage at gunpoint. Works on Qbox, QB-Core and ESX through `community_bridge`.

## ✨ Features

- **Server-authoritative**: the server checks the job, the weapon in hand, distance, cooldown and whether either side is already involved, cuffed or down. Clients can't pick who gets grabbed or killed.
- **Players and NPCs**: aim at someone to choose them, or take the closest valid target. Frozen, invincible and script-spawned NPCs are skipped.
- **Ends on its own**: the hostage is freed if the aggressor dies, goes into last stand, gets cuffed, is tackled, holsters the gun, disconnects or the resource restarts.
- **Rebindable keys**: Release / Kill (G / H by default) are FiveM key mappings.
- **State bags**: `Player(src).state.hostageRole` is `'aggressor'`, `'hostage'` or `nil` so other scripts can react. The hostage also gets `invBusy` while held.
- **Police alerts**: `Config.PoliceAlert.Function` sends them through community_bridge by default (any supported dispatch). A tk_dispatch version is included as a commented example.
- **Logs**: takes and executions go to `gldnrmz-logs` when it's running.
- **0.00 ms idle**: per-frame threads only run while a hostage situation is active.

## 📦 Requirements

- [OneSync](https://docs.fivem.net/docs/scripting-reference/onesync/)
- [ox_lib](https://github.com/overextended/ox_lib)
- [community_bridge](https://github.com/TheOrderFivem/community_bridge) **0.13.6 or newer** ([Qbox](https://github.com/Qbox-project/qbx_core), [QBCore](https://github.com/qbcore-framework/qb-core) or [ESX](https://github.com/esx-framework/esx_core), plus any target / inventory it supports)
- Optional: `arp_ui` (alternative key prompts), `gldnrmz-logs`

## ⚡ Installation

1. Start `ox_lib` and `community_bridge` before this resource, then add `ensure gldnrmz-hostage` to `server.cfg`.
2. Review `config.lua` (allowed weapons, blacklisted jobs, police alert). No items or SQL needed.

## 🎮 Usage

1. Hold a loaded pistol: any weapon in `Config.AllowedWeaponGroups` (all pistols by default) or listed in `Config.AllowedWeapons`.
2. Player targets must have their hands up (any `Config.HandsUpAnims` anim or the scully `handsup` state bag).
3. `/takehostage` or `/th`. You can also bind a key under Settings > Key Bindings > FiveM.
4. **G** releases (hostage kneels, NPCs then run), **H** kills.

## ⚙️ Configuration

Everything is in `config.lua`. Text is in `locales/en.json`.

| Option | What it does |
| --- | --- |
| `Config.TextUI` | `'ox_lib'` (default), `'arp_ui'`, `'bridge'`, `'native'` or `'none'` |
| `Config.AllowedWeapons` / `Config.AllowedWeaponGroups` | Weapons that can take a hostage |
| `Config.MaxDistance` | How close the target must be |
| `Config.Cooldown` | Seconds between hostage takes per player |
| `Config.RequireHandsUp` | Player targets must have hands up |
| `Config.ReleaseOnRagdoll` | Drop the hostage when tackled |
| `Config.AllowPeds` / `Config.AllowScriptPeds` | NPC targets |
| `Config.BlacklistedJobs` | Jobs that can't take hostages (`{ police = true }`) |
| `Config.PoliceAlert` | Chance, alert details and `Function` (which dispatch to use) |

## 🔌 Exports

Client:

```lua
exports['gldnrmz-hostage']:TakeHostage()
exports['gldnrmz-hostage']:IsTakingHostage() -- boolean
exports['gldnrmz-hostage']:IsHostage()       -- boolean
exports['gldnrmz-hostage']:GetHostageRole()  -- 'aggressor' | 'hostage' | nil
```

Server:

```lua
exports['gldnrmz-hostage']:GetHostageRole(src) -- 'aggressor' | 'hostage' | nil
exports['gldnrmz-hostage']:ForceRelease(src)   -- frees src from either side, returns boolean
```

## 🆕 Changes in 2.1.0

- Any pistol counts by default (`Config.AllowedWeaponGroups`), so MK2 / ceramic / add-on pistols work. An empty gun now says "Your pistol isn't loaded!".
- Text UI defaults to ox_lib; arp_ui is optional.
- The police alert is a config function (any dispatch) instead of preferring tk_dispatch.

## 🆕 Changes in 2.0.0

- Server owns all session state. The old `TakeHostage:*` events trusted the client's target id and are gone.
- Fixed: a hostage who died or went into last stand stayed attached.
- Fixed: Text UI exports were called every frame. arp_ui now only removes this script's prompts instead of clearing all of them.
- Fixed: `exports['x']` checks were always true, so the fallbacks never ran. Uses `GetResourceState` now.
- Fixed: NPC hostages stayed attached on resource restart and could despawn while held.
- Fixed: the kill shot fired at map origin (0, 0, 0). It now aims at the hostage's head.
- Job checks moved to the server through `community_bridge`.
- ox_lib keybinds, locales, callbacks and `GetGamePool` replaced the old loops and hard-coded controls.

## 📄 License

**GLDNRMZ Script License** - see [LICENSE](LICENSE).

- ✅ Run it on your own server and edit it for that server
- ❌ Don't sell it, re-upload or share it (free or paid), or put it in a pack or server build
- ❌ Don't remove the credits or claim it as your own

Need something else, like a commercial license? Ask on [Discord](https://discord.gg/7YHJ7774jA).

<!-- gldnrmz-links -->
---

## 🔗 Links

<p align="center">
  <a href="https://discord.gg/7YHJ7774jA"><img src="https://img.shields.io/badge/Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord" /></a>
  <a href="https://forum.cfx.re/u/gldnrmz/summary"><img src="https://img.shields.io/badge/Cfx.re-F40552?style=for-the-badge&logoColor=white" alt="Cfx.re forum" /></a>
  <a href="https://5metrics.dev/resources?search=gldnrmz"><img src="https://img.shields.io/badge/5Metrics-00BFFF?style=for-the-badge&logoColor=white" alt="5Metrics" /></a>
  <a href="https://gldnrmz.tebex.io"><img src="https://img.shields.io/badge/Tebex-FFD700?style=for-the-badge&logoColor=black" alt="Tebex store" /></a>
  <a href="https://www.buymeacoffee.com/gldnrmz"><img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-FF813F?style=for-the-badge&logo=buymeacoffee&logoColor=white" alt="Buy me a coffee" /></a>
</p>
