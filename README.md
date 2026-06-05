# DAdmin

DAdmin is an unfinished Garry's Mod admin addon written in GLua.

I am posting this as-is because I do not plan to finish it. A lot of the core admin-system work is already here, but it still needs cleanup, runtime testing, and a few bigger design decisions before it should be treated like a finished production addon.

## What This Is

DAdmin is a custom moderation/admin framework for Garry's Mod servers. It includes a Derma-based admin menu, rank and permission handling, moderation commands, player reports, cases, logs, safezones, playtime tracking, and several staff tools.

It is best viewed as a working/experimental codebase for someone who wants to learn from it, fork it, finish it, or pull out pieces for their own server project.

## Current Status

This is not a polished release.

The included project notes describe the addon as mostly working in several areas, but still unfinished in others. Static code work was done, but full live-server validation is still needed.

Known unfinished or incomplete areas include:

- Sit room and jail physicalization still need a real live-server implementation.
- Some older and newer UI panels still overlap and should be consolidated.
- Storage is currently JSON-based; SQLite/database support is only represented in config/planning and is not fully implemented.
- Some permissions are still broad and could use more granular per-tab/per-action control.
- Runtime testing is still needed for reports, sits, cases, evidence, screengrabs, tab visibility, and non-admin access behavior.

Use this with that context in mind.

## Features

- Rank-based admin permission system
- Default ranks for user, moderator, admin, superadmin, and owner
- Admin menu opened through console/chat commands
- Moderation commands for kick, ban, unban, mute, unmute, gag, ungag, freeze, unfreeze, slay, ignite, jail, and unjail
- Movement/admin commands for goto, bring, return, noclip, god, ungod, strip, respawn, spectate, and unspectate
- Rank commands for creating ranks, deleting ranks, setting immunity, inheritance, permissions, and user ranks
- Reports and cases system
- Player history and notes
- Warnings system
- Sits system
- Screengrab capture and viewer
- Large logging system for admin actions and game events
- Guard/radar style detection modules
- Safezone module with editor-style controls
- Playtime tracking with HUD/admin management
- Settings panel with server/admin configuration
- Permission matrix UI
- Command palette
- Evidence viewer
- Permission graph
- Player manager and bulk actions

## Commands / Menu Access

The addon registers a client menu command:

```text
dadmin_menu
```

There is also a shorter alias:

```text
dmenu
```

The menu can also be opened through chat shortcuts:

```text
!dadmin
/dadmin
!menu
```

The server-side command runner supports the configured chat prefix and console command flow. The default project notes reference commands such as:

```text
!kick <player> [reason]
!ban <player> <length> [reason]
!mute <player> [length]
!gag <player> [length]
!freeze <player>
!goto <player>
!bring <player>
!return <player>
!setrank <player> <rank>
!screengrab <player>
```

Exact behavior depends on the current rank permissions and whatever changes you make after forking it.

## Installation

1. Put the `dadmin` folder into your Garry's Mod server's addons folder:

```text
garrysmod/addons/dadmin
```

2. Make sure the folder contains the Lua autorun file:

```text
garrysmod/addons/dadmin/lua/autorun/dadmin_init.lua
```

3. Restart the server.

4. Join once as the intended owner/admin account and check the server console/client console for Lua errors.

5. Open the menu with:

```text
dadmin_menu
```

or:

```text
!dadmin
```

## Storage

DAdmin currently uses Garry's Mod `DATA` storage under:

```text
data/dadmin/
```

The addon writes JSON files for things like ranks, users, bans, logs, settings, history, and related systems. It also creates a backup folder:

```text
data/dadmin/backups/
```

The config has database-related options, but JSON is the actual default backend in this build.

## Default Ranks

The included rank system defines these default ranks:

- `user`
- `moderator`
- `admin`
- `superadmin`
- `owner`

The first known joining player may be bootstrapped into the `owner` rank if no owner is already stored. Review this behavior before putting the addon on a public/live server.

## Development Notes

Important files and folders:

```text
lua/autorun/dadmin_init.lua
lua/dadmin/config/
lua/dadmin/core/
lua/dadmin/commands/
lua/dadmin/modules/
lua/dadmin/services/
lua/dadmin/ui/
lua/dadmin/net/
```

Some included planning/review notes are useful if you want to continue development:

```text
DADMIN_REVIEW_NOTES.md
DADMIN_PHASED_COMPLETION_ROADMAP.md
FEATURE_STATUS.md
DADMIN_COMPLETE_INTEGRATION.txt
```

## Things To Finish

If someone wants to continue this project, the best next steps are:

1. Test it on a real dedicated Garry's Mod server.
2. Fix any server/client Lua errors from actual runtime use.
3. Decide how sit rooms and jail rooms should work.
4. Consolidate duplicate/legacy UI panels.
5. Tighten permission checks for every UI action.
6. Decide whether JSON storage is enough or whether SQLite/MySQL should be implemented properly.
7. Add clearer documentation for every command and permission.

## Warning

This addon handles admin powers, punishments, screenshots, logs, and permissions. Do not install it on a live public server without reviewing the code and testing it first.

In particular, review:

- net message validation
- rank and permission checks
- screengrab behavior
- data storage behavior
- first-owner bootstrap behavior
- any command that can punish, teleport, freeze, jail, or modify players

## License

No license has been selected yet.

If you want people to legally fork, modify, or reuse this project, add a license file before publishing it. MIT is common for open-source game/server tools, but choose whatever fits how you want the code to be used.

## Final Note

This is unfinished and released as-is. If it helps your server, your addon, or your own admin-system project, feel free to use it as a starting point.
