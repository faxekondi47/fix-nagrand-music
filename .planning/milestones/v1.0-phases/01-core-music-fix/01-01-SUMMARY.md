---
phase: 01-core-music-fix
plan: 01
subsystem: audio
tags: [lua, wow-addon, playmusic, zone-detection, day-night, tbc-classic]

# Dependency graph
requires:
  - phase: none
    provides: "First plan -- no dependencies"
provides:
  - "FixNagrandMusic.toc addon manifest (Interface 20505)"
  - "FixNagrandMusic.lua complete addon logic (zone detection, music playback, day/night, cleanup)"
  - "Event-driven frame handler pattern for WoW addon"
affects: [01-02-PLAN, 02-user-interface, 03-packaging]

# Tech tracking
tech-stack:
  added: [lua-5.1-wow-sandbox, wow-toc-20505]
  patterns: [event-driven-frame-handler, playmusic-auto-fade, dual-zone-detection, self-sustaining-timer]

key-files:
  created:
    - FixNagrandMusic/FixNagrandMusic.toc
    - FixNagrandMusic/FixNagrandMusic.lua
  modified: []

key-decisions:
  - "All Nagrand subzones use same track pool (3 day + 3 night) matching Blizzard's original ZoneMusic data"
  - "PlayMusic() used as primary drum suppression via auto-fade, no StopMusic before PlayMusic"
  - "Day/night breakpoints set to 6:00/18:00 per community convention"
  - "60-second self-sustaining timer for day/night monitoring, stops when leaving Nagrand"
  - "isTrackInCurrentPool() check prevents unnecessary track restarts on subzone transitions"

patterns-established:
  - "Event-driven frame handler: handlers table keyed by event name, dispatched via OnEvent script"
  - "State tracking: currentTrackID + isActive + lastTimeOfDay prevent redundant PlayMusic calls"
  - "Dual-method zone detection: C_Map.GetBestMapForUnit primary, GetZoneText fallback"
  - "Frame-deferred zone checks: C_Timer.After(0) on ZONE_CHANGED_NEW_AREA and PLAYER_ENTERING_WORLD"

requirements-completed: [MFIX-01, MFIX-02, MFIX-03, MFIX-04, MFIX-05, MFIX-06, MFIX-07, MFIX-08, MFIX-09, PKG-01]

# Metrics
duration: 2min
completed: 2026-02-18
---

# Phase 1 Plan 1: Create TOC and Lua Addon Summary

**Complete FixNagrandMusic addon with dual zone detection, PlayMusic drum suppression, day/night track rotation, and event-driven subzone/loading-screen resilience**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-18T10:43:40Z
- **Completed:** 2026-02-18T10:45:58Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments
- Created addon manifest (TOC) targeting TBC Classic Anniversary Interface 20505 with SavedVariables pre-declared for Phase 2
- Implemented complete music fix logic in 266 lines of Lua covering all 9 MFIX requirements plus PKG-01
- Dual-method Nagrand detection (C_Map numeric ID + GetZoneText fallback) ensures locale safety
- Day/night track rotation with 60-second monitoring timer switches music responsively even while standing still
- PlayMusic auto-fade suppresses buggy Orgrimmar drums without StopMusic gap anti-pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: Create FixNagrandMusic.toc addon manifest** - `e48f6d2` (feat)
2. **Task 2: Create FixNagrandMusic.lua with complete addon logic** - `e063731` (feat)

## Files Created/Modified
- `FixNagrandMusic/FixNagrandMusic.toc` - Addon manifest: Interface 20505, metadata, SavedVariables declaration, file list
- `FixNagrandMusic/FixNagrandMusic.lua` - Complete addon logic: zone detection, music playback, day/night variants, drum suppression, subzone transitions, loading screen recovery, cleanup

## Decisions Made
- **Track pool strategy:** All Nagrand subzones use the same 3-day/3-night track pool, matching Blizzard's ZoneMusic.dbc data (no per-subzone overrides found in research)
- **Drum suppression method:** PlayMusic() auto-fade as primary strategy; never call StopMusic() before PlayMusic() within Nagrand to avoid drum re-assertion gap
- **Day/night breakpoints:** 6:00/18:00 server time -- community convention closest to WoW's undocumented internal breakpoints
- **Timer architecture:** Self-sustaining C_Timer.After(60) chain that auto-terminates when isActive becomes false
- **Pool-aware track check:** isTrackInCurrentPool() compares currentTrackID against the time-appropriate pool, not just "is anything playing" -- ensures day/night transitions trigger track changes even during subzone events

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - luac was unavailable for syntax validation, so verification was done via manual code review against all 12 plan criteria.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Addon is structurally complete and ready for in-game validation (Plan 01-02)
- Open questions requiring in-game testing: UiMapID (107 vs 477), PlayMusic drum suppression durability, Interface version 20505 confirmation
- SavedVariables declared in TOC for Phase 2 slash command state persistence
- Code is well-sectioned with comment headers for Phase 2 additions

## Self-Check: PASSED

- FOUND: FixNagrandMusic/FixNagrandMusic.toc
- FOUND: FixNagrandMusic/FixNagrandMusic.lua
- FOUND: .planning/phases/01-core-music-fix/01-01-SUMMARY.md
- FOUND: e48f6d2 (Task 1 commit)
- FOUND: e063731 (Task 2 commit)

---
*Phase: 01-core-music-fix*
*Completed: 2026-02-18*
