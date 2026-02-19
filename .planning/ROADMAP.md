# Roadmap: FixNagrandMusic

## Overview

FixNagrandMusic is a narrowly scoped WoW TBC Classic Anniversary addon that fixes a Blizzard-unresolved bug where Orgrimmar drum music plays in Nagrand instead of the correct zone tracks. The roadmap delivers in three phases: first the core music fix (zone detection, music playback, suppression, transitions, resilience), then user-facing quality of life (slash commands, toggle, debug mode), then packaging and distribution (GitHub Actions, CurseForge, README). Phase 1 is the addon's entire reason for existing. Phases 2 and 3 make it polished and distributable.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Core Music Fix** - Zone detection, correct music playback, Orgrimmar suppression, subzone transitions, loading screen resilience, and cleanup
- [x] **Phase 2: User Interface** - Slash commands, toggle, debug mode, login notification, and persisted settings
- [ ] **Phase 3: Packaging and Release** - GitHub Actions CI/CD, CurseForge distribution, and README documentation

## Phase Details

### Phase 1: Core Music Fix
**Goal**: Player enters Nagrand and hears the correct TBC music in every subzone, with no Orgrimmar drum bleed-through, surviving loading screens and cleaning up on exit
**Depends on**: Nothing (first phase)
**Requirements**: MFIX-01, MFIX-02, MFIX-03, MFIX-04, MFIX-05, MFIX-06, MFIX-07, MFIX-08, MFIX-09, PKG-01
**Success Criteria** (what must be TRUE):
  1. Player flying into Nagrand from another zone hears correct Nagrand music begin playing (no Orgrimmar drums)
  2. Player walking between Nagrand subzones (e.g., Sunspring Post to Garadar) hears music transition without silence gaps or drum bursts
  3. Player hearthing out of Nagrand and back hears correct music resume after the loading screen
  4. Player in open grassland areas (no subzone name) hears default Nagrand general tracks
  5. Player leaving Nagrand hears normal game music resume with no leftover Nagrand tracks playing
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md -- Create TOC manifest and complete Lua addon with all core music fix logic
- [x] 01-02-PLAN.md -- In-game validation and fixes for UiMapID, drum suppression, and Interface version
- [x] 01-03-PLAN.md -- Gap closure: add GetSubZoneText() subzone tracking for MFIX-02

### Phase 2: User Interface
**Goal**: Player can check addon status, toggle the fix on/off, enable debug output, and see a login confirmation -- all persisted across sessions
**Depends on**: Phase 1
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05
**Success Criteria** (what must be TRUE):
  1. Player types `/fng` and sees current status: enabled/disabled, current subzone, current track playing
  2. Player types `/fng toggle` and the music fix turns off (game reverts to bugged behavior) or back on (correct music resumes)
  3. Player types `/fng debug` and sees zone/music events printed to chat as they move through Nagrand
  4. Player logs in and sees a one-line confirmation that FixNagrandMusic is loaded
  5. Player's toggle and debug settings survive logout and reload
**Plans**: 1 plan

Plans:
- [x] 02-01-PLAN.md -- Add slash commands (/fng, /fng toggle, /fng debug), login notification, persisted settings, and enabled guards

### Phase 3: Packaging and Release
**Goal**: Addon is packaged and published to CurseForge and GitHub with automated release pipeline and user-facing documentation
**Depends on**: Phase 2
**Requirements**: PKG-02, PKG-03, PKG-04
**Success Criteria** (what must be TRUE):
  1. Pushing a git tag triggers GitHub Actions and produces a downloadable release artifact
  2. CurseForge listing shows the addon under TBC Classic Anniversary with correct metadata
  3. README contains installation instructions, usage examples (`/fng` commands), and known limitations
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Music Fix | 3/3 | Complete | 2026-02-18 |
| 2. User Interface | 1/1 | Complete | 2026-02-19 |
| 3. Packaging and Release | 0/1 | Not started | - |
