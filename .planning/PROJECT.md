# FixNagrandMusic

## What This Is

A World of Warcraft addon for TBC Classic Anniversary that fixes a bug where Orgrimmar music plays in Nagrand instead of the correct zone music. The addon detects the player's subzone within Nagrand and plays the appropriate original TBC music track for that area.

## Core Value

Correct Nagrand music plays in every subzone — the player hears what they're supposed to hear, seamlessly.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Addon detects when player enters Nagrand and its subzones
- [ ] Orgrimmar (wrong) music is stopped when in Nagrand
- [ ] Correct music track plays for each Nagrand subzone
- [ ] All Nagrand subzones have their correct music mapped
- [ ] Music transitions smoothly when moving between Nagrand subzones
- [ ] Addon does nothing outside of Nagrand (no interference with other zones)
- [ ] Published to CurseForge and GitHub

### Out of Scope

- Other TBC zones — only Nagrand is affected by this bug
- Retail WoW support — targeting TBC Classic Anniversary client only
- Custom music — this restores original TBC tracks, not custom replacements
- Music volume controls — use the game's built-in settings

## Context

- **Bug:** TBC Classic Anniversary client plays Orgrimmar music in Nagrand instead of the correct zone tracks
- **Zone complexity:** Nagrand has multiple subzones, each with potentially different music tracks
- **Research needed:** Exact subzone-to-music-track mappings and WoW API for music control (PlaySoundFile, StopMusic, zone change events)
- **Client:** TBC Classic Anniversary (not retail, not original Classic)
- **Distribution:** CurseForge + GitHub

## Constraints

- **API:** Must use only WoW addon API available in TBC Classic Anniversary client
- **Performance:** Zero performance impact — music events are infrequent
- **Compatibility:** Must not conflict with other addons or the default UI

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Nagrand only (not multi-zone) | Only Nagrand has the bug | — Pending |
| TBC Classic Anniversary only | That's the affected client | — Pending |
| CurseForge + GitHub distribution | Maximum reach for affected players | — Pending |

---
*Last updated: 2026-02-18 after initialization*
