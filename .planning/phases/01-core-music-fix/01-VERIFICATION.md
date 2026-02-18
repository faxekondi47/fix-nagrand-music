---
phase: 01-core-music-fix
verified: 2026-02-18T12:00:00Z
status: gaps_found
score: 10/11 must-haves verified
re_verification: false
gaps:
  - truth: "Addon detects Nagrand zone entry using dual-method detection (UiMapID + GetZoneText fallback)"
    status: partial
    reason: >
      MFIX-02 in REQUIREMENTS.md states detection via GetSubZoneText() for current subzone.
      The code does not call GetSubZoneText() anywhere. The plan re-interpreted MFIX-02 as
      part of dual-method zone (not subzone) detection. The implementation handles subzone
      transitions via ZONE_CHANGED/ZONE_CHANGED_INDOORS events and a single track pool for
      all subzones, but never identifies which subzone the player is in. Whether this fulfills
      MFIX-02's intent depends on user acceptance of the single-pool design decision.
    artifacts:
      - path: "FixNagrandMusic/FixNagrandMusic.lua"
        issue: "GetSubZoneText() never called; MFIX-02 requirement specifies subzone-level detection"
    missing:
      - "Clarify: does MFIX-02 require per-subzone identification, or is event-driven subzone handling sufficient?"
      - "If per-subzone ID required: add GetSubZoneText() call and document subzone names handled"
human_verification:
  - test: "Confirm in-game test results are current"
    expected: "All 7 tests from Plan 01-02 Task 1 passed (UiMapID 107, Interface 20505, PlayMusic drum suppression, subzone transitions, loading screen recovery, zone exit)"
    why_human: "Plan 01-02 was a human checkpoint; SUMMARY claims 'all pass' but automated verification cannot confirm live game behavior"
  - test: "MFIX-02 design intent"
    expected: "User accepts single-pool approach (no per-subzone detection) as satisfying MFIX-02, or requests GetSubZoneText implementation"
    why_human: "Requirement literally says GetSubZoneText(); code intentionally omits it. Need human sign-off on design deviation"
---

# Phase 1: Core Music Fix - Verification Report

**Phase Goal:** Player enters Nagrand and hears the correct TBC music in every subzone, with no Orgrimmar drum bleed-through, surviving loading screens and cleaning up on exit.
**Verified:** 2026-02-18T12:00:00Z
**Status:** gaps_found (1 requirement interpretation gap + 2 human verification items)
**Re-verification:** No -- initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Addon loads without errors when placed in WoW Interface/AddOns directory | ? HUMAN | TOC is structurally valid (Interface 20505, FixNagrandMusic.lua ref). Syntax check unavailable (luac not installed). In-game load confirmed by human test in Plan 01-02. |
| 2 | Addon detects Nagrand zone entry using dual-method detection (UiMapID + GetZoneText fallback) | PARTIAL | `isInNagrand()` exists with C_Map.GetBestMapForUnit primary (NAGRAND_MAP_ID=107) and GetZoneText fallback. MFIX-02 also requires subzone detection via GetSubZoneText() -- not present. |
| 3 | Correct day tracks (53585-53587) play during daytime hours (6:00-17:59) | VERIFIED | NAGRAND_TRACKS.day = {53585, 53586, 53587}. isDayTime() returns true when hours >= 6 and < 18. getRandomTrack() selects from day pool when isDayTime() is true. PlayMusic() called with selected track. |
| 4 | Correct night tracks (53588-53590) play during nighttime hours (18:00-5:59) | VERIFIED | NAGRAND_TRACKS.night = {53588, 53589, 53590}. isDayTime() returns false outside 6-18 hours. getRandomTrack() selects from night pool. Day/night monitor checks every 60s via C_Timer.After. |
| 5 | Music continues uninterrupted across subzone boundaries within Nagrand | VERIFIED | ZONE_CHANGED and ZONE_CHANGED_INDOORS handlers call playNagrandMusic(). playNagrandMusic() checks isTrackInCurrentPool(currentTrackID) -- returns early (no restart) if same time-of-day pool track is playing. StopMusic() never called before PlayMusic() within Nagrand. |
| 6 | Music restarts after loading screens (hearthing, dungeons, BGs) | VERIFIED | PLAYER_ENTERING_WORLD handler defers via C_Timer.After(0) then calls activateAddon() if isInNagrand(). In-game validated per Plan 01-02. |
| 7 | Addon stops music and cleans up when player leaves Nagrand | VERIFIED | ZONE_CHANGED_NEW_AREA handler calls deactivateAddon() when not isInNagrand() and isActive. deactivateAddon() calls stopNagrandMusic() (StopMusic() + state reset) and restores savedMusicCVar. PLAYER_LOGOUT also calls deactivateAddon(). |
| 8 | Addon does nothing outside Nagrand | VERIFIED | ZONE_CHANGED and ZONE_CHANGED_INDOORS handlers guard on `if isActive` -- no-op when not in Nagrand. Day/night timer chain stops when isActive=false (startDayNightTimer returns early). All handlers are inert unless isActive=true or isInNagrand() returns true. |
| 9 | Music switches from day to night tracks (and vice versa) when game time transitions, even while standing still | VERIFIED | startDayNightTimer() self-sustaining C_Timer.After(60, startDayNightTimer) chain runs while isActive. Compares isDayTime() against lastTimeOfDay. On mismatch: calls PlayMusic() with new pool track without StopMusic() gap. |
| 10 | Addon respects user's Sound_EnableMusic setting -- does nothing if music is disabled | VERIFIED | playNagrandMusic() checks `GetCVar("Sound_EnableMusic") ~= "1"` at entry. Prints info message and returns without PlayMusic() call. isActive remains false; day/night timer not started. |
| 11 | Visible error message in chat if addon cannot determine correct track | VERIFIED | printError() defined: prints "|cFFFF0000FixNagrandMusic Error:|r " .. msg. Called in playNagrandMusic() when newTrack is nil. Called in startDayNightTimer() on day/night transition failure. |

**Score:** 10/11 truths verified (1 partial due to MFIX-02 GetSubZoneText gap)

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `FixNagrandMusic/FixNagrandMusic.toc` | Addon manifest for TBC Classic Anniversary | VERIFIED | Exists. 9 lines. Contains `Interface: 20505`, `FixNagrandMusic.lua` file reference, `SavedVariables: FixNagrandMusicDB`. |
| `FixNagrandMusic/FixNagrandMusic.lua` | Complete addon logic -- zone detection, music playback, day/night, cleanup | VERIFIED | Exists. 266 lines (min_lines: 120 satisfied). All 10 sections present. Substantive implementation -- no stubs, no placeholders, no empty returns. |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `FixNagrandMusic/FixNagrandMusic.toc` | `FixNagrandMusic/FixNagrandMusic.lua` | TOC file list loads Lua file | WIRED | Line 9 of TOC: `FixNagrandMusic.lua` -- exact filename reference present. |
| `FixNagrandMusic/FixNagrandMusic.lua` | WoW Events | Event handler dispatches via RegisterEvent | WIRED | `frame:RegisterEvent(event)` called for all 5 handlers (ZONE_CHANGED_NEW_AREA, ZONE_CHANGED, ZONE_CHANGED_INDOORS, PLAYER_ENTERING_WORLD, PLAYER_LOGOUT) via `for event in pairs(handlers)` loop. OnEvent script dispatches to handlers[event](...). |
| `FixNagrandMusic/FixNagrandMusic.lua` | PlayMusic API | Plays FileDataIDs from NAGRAND_TRACKS table | WIRED | PlayMusic() called in playNagrandMusic() (line 119) and startDayNightTimer() (line 157) with trackID from NAGRAND_TRACKS pools. |
| `FixNagrandMusic/FixNagrandMusic.lua` | Day/night timer | C_Timer.After(60) periodic check | WIRED | C_Timer.After(60, startDayNightTimer) on line 166. Self-sustaining chain started by activateAddon() via startDayNightTimer(), stopped when isActive=false. |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| MFIX-01 | 01-01, 01-02 | Locale-safe zone detection (numeric map ID or zone text) | SATISFIED | isInNagrand() dual-method: C_Map.GetBestMapForUnit("player")==107 primary, GetZoneText()=="Nagrand" fallback. In-game confirmed UiMapID 107 correct. |
| MFIX-02 | 01-01 | Subzone detection via GetSubZoneText() | PARTIAL | Plan 01-01 Section 4 covers MFIX-02 under zone detection, not subzone detection. GetSubZoneText() never called. Subzone transitions handled via events + single track pool. Design intent may supersede literal requirement -- human sign-off needed. |
| MFIX-03 | 01-01, 01-02 | Correct music with day/night variants (FileDataIDs 53585-53590) | SATISFIED | All 6 FileDataIDs in NAGRAND_TRACKS. isDayTime() selects pool. Day/night monitor switches tracks on time change. In-game confirmed music plays correctly. |
| MFIX-04 | 01-01, 01-02 | Drum suppression (PlayMusic auto-fade or CVar fallback) | SATISFIED | PlayMusic() called directly -- WoW's auto-fade replaces current zone track (Strategy A). StopMusic() never called before PlayMusic() within Nagrand (drum gap anti-pattern avoided). In-game confirmed Strategy A sufficient. |
| MFIX-05 | 01-01 | Smooth subzone transitions (no silence gaps or drum bursts) | SATISFIED | isTrackInCurrentPool() check prevents restart if correct time-of-day track already playing. ZONE_CHANGED and ZONE_CHANGED_INDOORS re-assert PlayMusic without StopMusic gap. |
| MFIX-06 | 01-01 | Zero interference outside Nagrand | SATISFIED | All handlers guard on isActive/isInNagrand(). Timer chain terminates when isActive=false. No events processed outside Nagrand logic paths. |
| MFIX-07 | 01-01, 01-02 | Loading screen recovery via PLAYER_ENTERING_WORLD | SATISFIED | PLAYER_ENTERING_WORLD registered, handler defers via C_Timer.After(0), calls activateAddon() if in Nagrand. In-game confirmed hearthstone round-trip works. |
| MFIX-08 | 01-01 | Cleanup on zone exit, logout, disconnect | SATISFIED | deactivateAddon() called from ZONE_CHANGED_NEW_AREA (zone exit) and PLAYER_LOGOUT. Calls stopNagrandMusic() + restores savedMusicCVar. State reset: currentTrackID=nil, isActive=false, lastTimeOfDay=nil. |
| MFIX-09 | 01-01 | Empty subzone areas play default Nagrand general tracks | SATISFIED | Design decision: single NAGRAND_TRACKS pool for all subzones (no per-subzone overrides). ZONE_CHANGED fires even for unnamed areas; playNagrandMusic() re-asserts track. |
| PKG-01 | 01-01 | Correct .toc file with Interface 20505, metadata, SavedVariables | SATISFIED | TOC verified: `## Interface: 20505`, `## Title: FixNagrandMusic`, `## Notes: ...`, `## Author: mig`, `## Version: @project-version@`, `## X-Category: Audio & Video`, `## SavedVariables: FixNagrandMusicDB`, `FixNagrandMusic.lua`. |

### Orphaned Requirements Check

REQUIREMENTS.md Traceability table maps MFIX-01 through MFIX-09 and PKG-01 to Phase 1. All 10 Phase 1 requirements appear in Plan 01-01 frontmatter. No orphaned requirements.

UI-01 through UI-05 are mapped to Phase 2 (not this phase). PKG-02 through PKG-04 are Phase 3. None are orphaned to Phase 1.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | -- | No TODO/FIXME/HACK/PLACEHOLDER comments | -- | -- |
| None | -- | No stub returns (return null, return {}) | -- | -- |
| None | -- | StopMusic() not called before PlayMusic() within Nagrand | -- | Anti-pattern correctly avoided per research |

No blocker anti-patterns found. Code is substantive throughout.

**Notable code quality observation:** The `isInitialLogin` and `isReloadingUi` parameters are received by `handlers.PLAYER_ENTERING_WORLD` but not used (the handler activates on any PLAYER_ENTERING_WORLD if in Nagrand). This is correct behavior -- the handler correctly recovers after any loading screen regardless of login type.

---

## Human Verification Required

### 1. In-Game Functional Validation

**Test:** Perform the 7 tests from Plan 01-02 Task 1 (or confirm they have already been completed in-game).
**Expected:**
- Test 1: Addon appears enabled in AddOns list
- Test 2: `/run print("MapID:", C_Map.GetBestMapForUnit("player"))` prints 107 in Nagrand
- Test 3: `/dump (select(4, GetBuildInfo()))` prints 20505
- Test 4: Correct Nagrand music plays on entry, Orgrimmar drums gone
- Test 5: Music continues across Sunspring Post / Garadar / open grassland transitions
- Test 6: Music resumes within 1-2 seconds after hearthstone round-trip
- Test 7: Nagrand music stops and new zone music plays on exit
**Why human:** Automated verification cannot run a WoW client. SUMMARY claims all 7 tests passed but this was a Plan 01-02 checkpoint -- the summary reflects what the user reported, which cannot be independently re-verified here.

### 2. MFIX-02 Design Deviation Sign-Off

**Test:** Review whether the GetSubZoneText() omission is acceptable.
**Expected:** User confirms one of:
  (a) Single-pool design (no per-subzone detection) satisfies MFIX-02 intent -- "correct music in every subzone" via event handling is sufficient, or
  (b) GetSubZoneText() should be added to track which subzone the player is in (e.g., for debug output or future per-subzone overrides)
**Why human:** The requirement as written says "detects player's current subzone via GetSubZoneText()" but the implementation deliberately uses events + single pool instead. This is a legitimate design decision documented in the PLAN but deviates from the literal requirement. Human sign-off closes this gap.

---

## Gaps Summary

**One gap blocks full verification:**

**MFIX-02 -- GetSubZoneText() not called.** REQUIREMENTS.md requires subzone detection using GetSubZoneText(). The code never calls this API. The plan interpreted MFIX-02 as part of dual-method zone detection (C_Map + GetZoneText) and made a design decision to use a single track pool for all subzones rather than per-subzone detection. The implementation correctly handles subzone transitions via ZONE_CHANGED / ZONE_CHANGED_INDOORS events, and music works in all subzones including unnamed open areas (MFIX-09). However, the addon cannot report which subzone the player is in -- this matters for Phase 2 (the `/fng` status command in UI-01 is supposed to show "current subzone").

If the user accepts the single-pool design as sufficient for Phase 1, this gap can be closed by updating REQUIREMENTS.md to reflect the actual implementation approach. If per-subzone identification is required now (for Phase 2 readiness), GetSubZoneText() should be added -- it could be stored in a `currentSubzone` state variable for debug/UI use without changing the music logic.

**This gap does not prevent the music from working correctly.** All music plays correctly in all subzones. The gap is about whether the implementation formally satisfies the requirement's literal API specification, not about functional behavior.

---

_Verified: 2026-02-18T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
