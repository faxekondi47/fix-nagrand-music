# FixNagrandMusic

## What This Is

A World of Warcraft addon for TBC Classic Anniversary that fixes a bug where Orgrimmar music plays in Nagrand instead of the correct zone music. The addon detects the player's subzone within Nagrand, plays the appropriate original TBC music tracks (day/night variants), and provides slash commands for status, toggle, and debug output. Published to CurseForge and GitHub with automated CI/CD.

## Core Value

Correct Nagrand music plays in every subzone -- the player hears what they're supposed to hear, seamlessly.

## Requirements

### Validated

- ✓ Addon detects when player enters Nagrand and its subzones -- v1.0
- ✓ Orgrimmar (wrong) music is suppressed when in Nagrand -- v1.0 (PlayMusic auto-fade)
- ✓ Correct music track plays for each Nagrand subzone -- v1.0 (6 FileDataIDs, day/night)
- ✓ All Nagrand subzones have their correct music mapped -- v1.0 (single track pool per ZoneMusic.dbc)
- ✓ Music transitions smoothly when moving between Nagrand subzones -- v1.0
- ✓ Addon does nothing outside of Nagrand (no interference with other zones) -- v1.0
- ✓ Music restarts correctly after loading screens -- v1.0
- ✓ Addon cleans up on zone exit, logout, and disconnect -- v1.0
- ✓ Slash commands (/fng, /fng toggle, /fng debug) for player control -- v1.0
- ✓ Per-character persistent settings -- v1.0
- ✓ Published to CurseForge and GitHub with automated CI/CD -- v1.0

### Active

(None -- v1.0 shipped. Define new requirements with `/gsd:new-milestone`.)

### Out of Scope

- Other TBC zones -- only Nagrand is affected by this bug
- Retail WoW support -- targeting TBC Classic Anniversary client only
- Custom music -- this restores original TBC tracks, not custom replacements
- Music volume controls -- use the game's built-in settings
- GUI configuration panel -- overkill for 2 settings, slash commands sufficient
- Minimap button -- overkill for a bug fix addon
- WoD Nagrand support -- different zone, different music, different client

## Context

Shipped v1.0 with 407 LOC Lua + TOC.
Tech stack: Lua 5.1 (WoW sandbox), WoW TOC Interface 20505, GitHub Actions, CurseForge API.
Zone detection: UiMapID 107 + GetZoneText() dual fallback.
Music: PlayMusic() with FileDataIDs 53585-53590, auto-fade drum suppression.
Distribution: GitHub Releases + CurseForge TBC Classic Anniversary.

Known issues from testing:
- Abrupt music stop on hearthstone out of Nagrand (StopMusic cuts instantly, no fade-out)
- Brief Orgrimmar music burst when walking out of Nagrand (zone transition edge case)

## Constraints

- **API:** Must use only WoW addon API available in TBC Classic Anniversary client
- **Performance:** Zero performance impact -- music events are infrequent
- **Compatibility:** Must not conflict with other addons or the default UI

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Nagrand only (not multi-zone) | Only Nagrand has the bug | ✓ Good -- kept scope tight |
| TBC Classic Anniversary only | That's the affected client | ✓ Good -- no compat issues |
| CurseForge + GitHub distribution | Maximum reach for affected players | ✓ Good -- automated pipeline |
| PlayMusic auto-fade for drum suppression | Simpler than CVar manipulation, confirmed in-game | ✓ Good -- no side effects |
| Single track pool for all subzones | Matches Blizzard's ZoneMusic.dbc data | ✓ Good -- accurate to original |
| UiMapID 107 + GetZoneText dual detection | Locale-safe primary, string fallback for resilience | ✓ Good -- works across locales |
| SavedVariablesPerCharacter | Per-character settings for toggle/debug | ✓ Good -- standard WoW pattern |
| Direct zip + curl for CurseForge | Simpler than BigWigsMods/packager, fewer dependencies | ✓ Good -- full control |
| Day/night breakpoints 6:00/18:00 | Standard WoW day/night cycle | ✓ Good -- matches game time |

---
*Last updated: 2026-02-19 after v1.0 milestone*
