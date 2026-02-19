# Requirements: FixNagrandMusic

**Defined:** 2026-02-18
**Core Value:** Correct Nagrand music plays in every subzone -- the player hears what they're supposed to hear, seamlessly.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Music Fix

- [x] **MFIX-01**: Addon detects when player enters Nagrand using locale-safe method (numeric map ID or zone text)
- [x] **MFIX-02**: Addon detects player's current subzone within Nagrand via GetSubZoneText()
- [x] **MFIX-03**: Correct Nagrand music track plays for each subzone (day/night variants using FileDataIDs 53585-53590)
- [x] **MFIX-04**: Buggy Orgrimmar drum music is suppressed while in Nagrand (PlayMusic auto-fade or CVar fallback)
- [x] **MFIX-05**: Music transitions smoothly between Nagrand subzones (no silence gaps or drum bursts)
- [x] **MFIX-06**: Addon does nothing outside Nagrand (zero interference with other zones)
- [x] **MFIX-07**: Music restarts correctly after loading screens (dungeons, hearthing, BGs) via PLAYER_ENTERING_WORLD handler
- [x] **MFIX-08**: Addon cleans up on zone exit, logout, and disconnect (StopMusic, restore CVar if modified)
- [x] **MFIX-09**: Empty subzone areas (open grassland with no subzone name) play default Nagrand general tracks

### User Interface

- [x] **UI-01**: `/fng` slash command displays addon status (enabled/disabled, current subzone, current track)
- [x] **UI-02**: `/fng toggle` enables/disables the music fix without uninstalling
- [x] **UI-03**: `/fng debug` toggles debug mode printing zone/music events to chat
- [x] **UI-04**: Brief login notification confirms addon is loaded ("FixNagrandMusic v1.0 loaded. Type /fng for help.")
- [x] **UI-05**: Toggle and debug state persisted across sessions via SavedVariablesPerCharacter

### Packaging

- [x] **PKG-01**: Correct .toc file with Interface 20505, addon metadata, and SavedVariables declaration
- [x] **PKG-02**: GitHub Actions workflow using BigWigsMods/packager@v2 for automated releases
- [x] **PKG-03**: .pkgmeta file configured for CurseForge TBC Classic Anniversary distribution
- [x] **PKG-04**: README.md with installation instructions, usage, and known limitations

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Localization

- **LOC-01**: Localized subzone name table for non-English clients (deDE, frFR, esES, zhCN, koKR)
- **LOC-02**: Verify "Nagrand" zone name consistency across all locales

### Advanced Features

- **ADV-01**: Halaa PvP-aware music (determine if war drums are intentional PvP ambiance)
- **ADV-02**: Day/night track selection based on game time
- **ADV-03**: Per-subzone music overrides (different tracks for different areas)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full music overhaul / custom playlists | Different addon (Soundtrack exists). Massively expands scope. |
| Volume controls | WoW has built-in music volume. No addon API for volume control. |
| Music for other TBC zones | Scope creep. Only Nagrand has this bug. |
| GUI configuration panel | Overkill for 2 settings. Slash commands sufficient. |
| Combat music override | Different sound channel entirely. Out of scope. |
| Minimap button | Overkill for a bug fix addon. |
| WoD Nagrand support | Different zone, different music, different client. |
| Retail WoW support | TBC Classic Anniversary only. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| MFIX-01 | Phase 1 | Complete |
| MFIX-02 | Phase 1 | Complete |
| MFIX-03 | Phase 1 | Complete |
| MFIX-04 | Phase 1 | Complete |
| MFIX-05 | Phase 1 | Complete |
| MFIX-06 | Phase 1 | Complete |
| MFIX-07 | Phase 1 | Complete |
| MFIX-08 | Phase 1 | Complete |
| MFIX-09 | Phase 1 | Complete |
| UI-01 | Phase 2 | Complete |
| UI-02 | Phase 2 | Complete |
| UI-03 | Phase 2 | Complete |
| UI-04 | Phase 2 | Complete |
| UI-05 | Phase 2 | Complete |
| PKG-01 | Phase 1 | Complete |
| PKG-02 | Phase 3 | Complete |
| PKG-03 | Phase 3 | Complete |
| PKG-04 | Phase 3 | Complete |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-02-18*
*Last updated: 2026-02-19 after Phase 2 completion*
