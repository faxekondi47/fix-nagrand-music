# Project Research Summary

**Project:** FixNagrandMusic
**Domain:** WoW TBC Classic Anniversary addon -- single-zone music bug fix
**Researched:** 2026-02-18
**Confidence:** MEDIUM

## Executive Summary

FixNagrandMusic is a narrowly scoped WoW addon that fixes a well-documented, Blizzard-unresolved bug where Orgrimmar drum loops override the correct zone music in Nagrand (Outland). The bug has been confirmed active across TBC Classic, WotLK Classic, and TBC Classic Anniversary (as of February 2026). The addon's strategy is to intercept zone change events, detect when the player is in Nagrand, suppress the game's broken music, and play the correct Nagrand tracks using `PlayMusic()`. The entire addon requires roughly 50-150 lines of Lua and is tiny by any measure -- a single `.lua` file plus a `.toc` manifest.

The recommended approach is event-driven Lua with no external libraries: register `ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA`, and `PLAYER_ENTERING_WORLD` events on a hidden frame, use `GetZoneText()` for zone detection with `C_Map.GetBestMapForUnit()` as a locale-safe alternative, and call `PlayMusic()` with the correct Nagrand FileDataIDs (53585-53590 for day/night tracks, sourced from Wowhead's TBC sound database). The primary music suppression strategy is `PlayMusic()` auto-fade; if the buggy drums fight back, a fallback using `SetCVar("Sound_EnableMusic", 0)` combined with `PlaySoundFile()` on the Master channel is available.

The single greatest risk is that the buggy drum music re-asserts itself over `PlayMusic()` after subzone transitions -- because WoW's internal zone music system can re-trigger on boundary events. This must be tested in-game on day one of development. A secondary risk is FileDataID vs. file path behavior on TBC Classic Anniversary's modern client engine, which must also be validated early. Both risks have known mitigation paths and low recovery cost if they surface.

## Key Findings

### Recommended Stack

This addon requires only the WoW Lua sandbox (Lua 5.1 custom) and the TOC manifest format with `## Interface: 20505`. No external libraries, no ACE3, no XML. The development toolchain is VS Code with the sumneko LuaLS language server, Ketho's vscode-wow-api annotations for WoW API autocomplete, and BugSack + BugGrabber in-game for error capture. The `/reload` command provides a rapid iteration cycle. Distribution via BigWigsMods/packager@v2 on GitHub Actions handles CurseForge and Wago uploads automatically on git tag push.

The critical stack uncertainty is `PlayMusic()` behavior on TBC Classic Anniversary's modern client engine: retail removed file path support in patch 8.2.0, but TBC Anniversary (2.5.x) is on a modern engine that may or may not honor legacy string paths. The safe strategy is to use numeric FileDataIDs as the primary approach and fall back to file paths if needed.

**Core technologies:**
- Lua 5.1 (WoW sandbox): Addon scripting -- the only option; no io/os access
- WoW TOC format (Interface 20505): Addon manifest required for client loading
- `PlayMusic()` / `StopMusic()`: Core music override API
- `ZONE_CHANGED` / `ZONE_CHANGED_NEW_AREA` events: Zone detection triggers
- BigWigsMods/packager@v2: CurseForge packaging and release automation

### Expected Features

The feature scope is intentionally minimal. The addon has one job: play the correct Nagrand music. All features either serve that core fix or are lightweight quality-of-life additions.

**Must have (table stakes for v1.0):**
- Correct Nagrand music per subzone -- the addon's entire reason for existing
- Automatic Nagrand detection -- zero configuration, install and forget
- Subzone transition handling -- no silence gaps or jarring cuts between areas
- Clean startup/shutdown -- no orphaned music loops playing outside Nagrand
- Proper TOC metadata and CurseForge packaging
- Login notification (one line confirming addon loaded)
- `/fng` slash command showing current status

**Should have (v1.x after validation):**
- Toggle on/off via slash command -- with SavedVariables persistence
- Debug mode -- essential for diagnosing user-reported issues
- Halaa PvP-aware music handling -- only if testing confirms Halaa needs special treatment

**Defer (v2+):**
- Localized zone name support -- English-only is acceptable for v1; most TBC Anniversary players use English clients; "Nagrand" is a proper noun likely unchanged across locales
- Other zone music fixes -- out of scope; separate addons if needed

### Architecture Approach

The addon follows the canonical WoW addon pattern: a hidden `CreateFrame("Frame")` registers events and dispatches them through a table-keyed handler. A state machine (INACTIVE / PLAYING / TRANSITIONING) governs music playback to prevent double-plays and missed stops. Music data lives in a static Lua table mapping Nagrand day/night FileDataIDs, with subzone overrides possible but not required for MVP. For MVP, all subzones play the same Nagrand general tracks (day/night variants); the bug is that the WRONG music plays everywhere, not that different subzones need different tracks.

The architecture research identified concrete Nagrand FileDataIDs from Wowhead's TBC sound database: Zone-NagrandDay (Sound ID 9012) uses FileDataIDs 53585-53587; Zone-NagrandNight (Sound ID 9013) uses FileDataIDs 53588-53590. These must be validated in-game before shipping.

**Major components:**
1. Event Handler -- hidden frame registering zone events, dispatching to detection logic
2. Zone Detector -- `GetZoneText()` / `C_Map.GetBestMapForUnit()` comparison, tracks `isInNagrand` state
3. Music Controller -- state machine orchestrating `PlayMusic()` / `StopMusic()`, handles suppress/restore
4. Music Data Table -- static Lua table of Nagrand FileDataIDs with day/night tracks and fallback default

### Critical Pitfalls

1. **Dual music layering** -- `PlayMusic()` may not permanently suppress the buggy drum loop; the game's zone music system re-triggers on subzone boundaries. Mitigation: re-assert `PlayMusic()` on every zone event, and use `SetCVar("Sound_EnableMusic", 0)` as fallback if drums bleed through. Validate this in-game on day one.

2. **Music resets on loading screens** -- `PlayMusic()` stops after any loading screen (dungeon, BG, hearth). Mitigation: register `PLAYER_ENTERING_WORLD` and use `C_Timer.After(0, callback)` to re-check zone and restart music after every loading screen transition.

3. **Localization breaks zone detection** -- `GetZoneText()` returns localized strings; hardcoding `"Nagrand"` breaks non-English clients. Mitigation: use `C_Map.GetBestMapForUnit("player")` returning UiMapID 477 as the primary zone check; fall back to English string only if C_Map is unavailable.

4. **`StopMusic()` resumes the buggy music** -- calling `StopMusic()` explicitly returns control to the game's (buggy) zone music system. Mitigation: during subzone transitions within Nagrand, call `PlayMusic(newTrack)` directly -- never `StopMusic()` then `PlayMusic()`. Only call `StopMusic()` on zone exit.

5. **FileDataID vs. file path confusion** -- TBC Anniversary's modern engine behavior for string paths in `PlayMusic()` is ambiguous. Mitigation: test `PlayMusic(53585)` on day one of development; use numeric FileDataIDs as primary approach.

## Implications for Roadmap

Based on research, the addon should be built in three phases with a clear build-order dependency chain: data first, detection second, playback third, polish fourth.

### Phase 1: Foundation and Core Fix

**Rationale:** Everything else depends on knowing the correct FileDataIDs and confirming that `PlayMusic()` works as expected on TBC Anniversary. These are unknowns that block all other implementation. Validate blockers first before writing any production code.

**Delivers:** A working music fix in Nagrand -- the addon's entire purpose.

**Addresses:** Table stakes features -- correct music per subzone, automatic Nagrand detection, subzone transition handling, clean startup/shutdown, proper TOC metadata.

**Avoids:**
- Dual music layering pitfall (test PlayMusic suppression behavior first; adopt SetCVar fallback if needed)
- FileDataID vs. file path pitfall (validate FileDataIDs 53585-53590 on first day)
- StopMusic resuming buggy music pitfall (design transition logic to use direct PlayMusic replacement)
- Localization pitfall (use C_Map.GetBestMapForUnit() as primary zone detection)
- Music resets on loading screen (register PLAYER_ENTERING_WORLD from the start)

**Build order within phase:**
1. MusicData.lua -- define FileDataIDs, validate with `/run PlayMusic(53585)` in-game
2. ZoneDetection.lua -- implement zone/subzone detection, validate with `/run print(GetZoneText())`
3. MusicController.lua -- state machine, PlayMusic/StopMusic orchestration
4. Core.lua + TOC -- wire everything together, event frame, Interface 20505

### Phase 2: Quality of Life

**Rationale:** Once the core fix is confirmed working across all Nagrand subzones, add the quality-of-life features that make the addon feel polished and support-friendly.

**Delivers:** Toggle, debug mode, persisted settings, login notification, slash command.

**Implements:** SavedVariables (declared in TOC, loaded on ADDON_LOADED), SlashCmdList handler, debug conditional print calls.

**Addresses:** Differentiator features -- toggle on/off, debug mode, persisted settings, login notification, `/fng` slash command.

**Avoids:**
- Player settings respected pitfall (check GetCVar("Sound_EnableMusic") before activating)
- CVar restoration pitfall (save and restore original CVar value, not always write 1)
- No-feedback UX pitfall (login notification and slash command status)

### Phase 3: Edge Cases and Release

**Rationale:** After Phase 2, the addon is functionally complete. Phase 3 handles edge cases, packaging, and distribution.

**Delivers:** CurseForge-ready release package, edge case handling, compatibility verification.

**Addresses:** Packaging via BigWigsMods/packager, `.pkgmeta` configuration, GitHub Actions workflow, Halaa PvP music determination (leave alone or fix), compatibility with other music addons.

**Avoids:**
- TOC version maintenance pitfall (verify Interface number matches current patch on release day)
- Concurrent addon compatibility pitfall (test alongside EpicMusicPlayer, Soundtrack)
- Loading screen edge case pitfall (test dungeon exit, BG exit, hearth, death/graveyard scenarios)

### Phase Ordering Rationale

- **Data before code:** The FileDataIDs are a hard dependency. The music controller cannot be built without knowing what music to play. Validate IDs on the first day of development.
- **Validation gates:** Phase 1 ends only when correct music plays with no drum bleed-through across all Nagrand subzone transitions. Do not move to Phase 2 with unresolved audio issues.
- **Polish after core:** Toggle, debug mode, and SavedVariables are valuable but cannot compensate for a broken core fix. Add them only after the fundamental fix is confirmed solid.
- **Pitfalls front-loaded:** All 5 critical pitfalls are addressed in Phase 1 by design. Recovery cost is low for each, but finding them late adds release risk.

### Research Flags

Phases needing deeper research during planning:

- **Phase 1 (day one in-game validation):** Cannot be fully planned without live testing. FileDataID behavior, PlayMusic suppression persistence, and dual-music layering behavior are unknowns that can only be answered on a live TBC Anniversary server. The first development session should be pure validation, not production code.
- **Phase 3 (Halaa PvP music):** Whether Halaa's war drums are intentional game design or a manifestation of the bug requires in-game testing and possibly cross-referencing with original TBC 2.4.3 behavior. Defer this decision until Phase 3 testing.

Phases with well-documented patterns (skip research-phase):

- **Phase 2 (slash commands, SavedVariables):** These are canonical, extensively documented WoW addon patterns with clear API. No additional research needed.
- **Phase 3 (packaging):** BigWigsMods/packager@v2 is the industry standard with clear documentation and the `-g bcc` flag for TBC Classic. Straightforward configuration.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Core WoW API is well-documented (HIGH confidence); TBC Anniversary-specific PlayMusic behavior (FileDataID vs. path) is unverified and requires in-game testing |
| Features | HIGH | Bug is well-confirmed across multiple forum sources; feature set is narrow and clear; MVP scope is obvious |
| Architecture | MEDIUM | Patterns are canonical WoW addon patterns (HIGH confidence); specific Nagrand FileDataIDs from Wowhead are HIGH confidence but must be validated in-game; dual-music suppression reliability is MEDIUM |
| Pitfalls | MEDIUM | Official API docs confirm most pitfalls (HIGH confidence); TBC Anniversary-specific behaviors inferred from API version tags and community reports |

**Overall confidence:** MEDIUM

The confidence is bounded by two in-game unknowns that cannot be resolved through documentation: (1) whether `PlayMusic()` reliably suppresses the buggy drum music across subzone transitions on TBC Anniversary's modern client, and (2) whether the FileDataIDs 53585-53590 produce audible audio on that client. Both unknowns are easily tested and have known fallback strategies, so they carry low implementation risk despite the documentation uncertainty.

### Gaps to Address

- **FileDataID validation (Phase 1, day one):** Run `/run PlayMusic(53585)` in Nagrand before writing any production code. If it produces correct audio, proceed with FileDataID approach. If silent, test file paths, then bundle OGG files as last resort.
- **PlayMusic suppression durability (Phase 1):** Walk through multiple subzone transitions while `PlayMusic()` is active. If drum loop bleeds through at any point, switch to the `SetCVar("Sound_EnableMusic", 0)` + `PlaySoundFile()` strategy.
- **Interface version (Phase 1):** Run `/dump (select(4, GetBuildInfo()))` on a live TBC Anniversary client to confirm Interface number. STACK.md says 20505; ARCHITECTURE.md noted 20504 as a possibility. Use the confirmed value.
- **C_Map availability (Phase 1):** Run `/run print(C_Map.GetBestMapForUnit("player"))` in Nagrand to confirm UiMapID and API availability. Fall back to `GetZoneText() == "Nagrand"` if C_Map is absent.
- **Halaa music intent (Phase 3):** Test whether entering Halaa triggers the drum loop specifically, or whether the bug is zone-wide. This determines whether Halaa needs special-casing.

## Sources

### Primary (HIGH confidence)
- warcraft.wiki.gg/wiki/API_PlayMusic -- PlayMusic signature, FileDataID behavior, zone music fade
- warcraft.wiki.gg/wiki/API_StopMusic -- StopMusic only affects addon-played music; documented resumption behavior
- warcraft.wiki.gg/wiki/API_PlaySoundFile -- PlaySoundFile signature, channel parameter
- warcraft.wiki.gg/wiki/API_GetZoneText and API_GetSubZoneText -- zone detection APIs
- warcraft.wiki.gg/wiki/ZONE_CHANGED and ZONE_CHANGED_NEW_AREA -- event docs, no payload args
- warcraft.wiki.gg/wiki/TOC_format -- TOC field reference, Interface version 20505 for TBC Classic Anniversary
- warcraft.wiki.gg/wiki/Nagrand -- Complete subzone list
- warcraft.wiki.gg/wiki/Localizing_an_addon -- Localization patterns
- wowdev.wiki/DB/ZoneMusic and DB/SoundEntries -- Music database schema
- wowhead.com/tbc/sound=9012 and 9013 -- Nagrand day/night FileDataIDs (53585-53590)
- github.com/BigWigsMods/packager -- Packaging tool, GitHub Actions, BCC support

### Secondary (MEDIUM confidence)
- us.forums.blizzard.com/en/wow/t/tbc-nagrand-music-bug/993365 -- Bug confirmation
- us.forums.blizzard.com/en/wow/t/orgrimmar-music-in-nagrand/1028737 -- Specific bug symptoms
- us.forums.blizzard.com/en/wow/t/is-nagrand-music-busted/2250797 -- Feb 2026 bug still active
- eu.forums.blizzard.com/en/wow/t/nagrand-music-bug-pls-fix-blizzard/606156 -- EU bug corroboration
- github.com/fondlez/wow-sounds -- TBC 2.4.3 sound file listings
- wowpedia.fandom.com/wiki/API_C_Map.GetBestMapForUnit -- C_Map availability in TBC Classic
- wowinterface.com/forums/showthread.php?t=57109 -- StopMusic behavior community documentation
- github.com/Ketho/vscode-wow-api -- VS Code WoW API annotations

### Tertiary (LOW confidence)
- wowwiki-archive.fandom.com/wiki/API_GetZoneText -- ZONE_CHANGED_NEW_AREA race condition note (old source, needs verification)
- wowace.com/projects/libbabble-subzone-3-0 -- LibBabble-SubZone-3.0 (may not be maintained for TBC Anniversary)

---
*Research completed: 2026-02-18*
*Ready for roadmap: yes*
