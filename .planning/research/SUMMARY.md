# Research Summary: Smooth Music Transitions

**Domain:** WoW TBC Classic Anniversary addon -- music transition polish
**Researched:** 2026-02-19
**Overall confidence:** HIGH

## Executive Summary

FixNagrandMusic v1.0 successfully fixes the core Nagrand music bug. Three polish issues remain that all stem from the same root cause: `StopMusic()` is instant (no fade) since WoW patch 2.2, and calling it immediately on zone exit creates two audible problems -- an abrupt cut when hearthing and a brief Orgrimmar drum burst when walking out. Both are solvable with a single mechanism: CVar-based volume ramping via `SetCVar("Sound_MusicVolume", ...)` driven by a frame `OnUpdate` handler, followed by a delayed `StopMusic()` call.

This pattern is proven in production. The wow-voiceover addon (mrthinger/wow-voiceover) implements exactly this via a `SlideVolume()` function that interpolates volume per-frame using elapsed time. The WoW TBC client (2.4.3 engine baseline) responds well to CVar volume changes, with the client itself applying a ~0.4-0.5 second internal smoothing when CVars are toggled. The total implementation is estimated at 115-175 lines of Lua, a modest addition to the existing ~400 LOC addon.

A third optional feature -- suppressing Orgrimmar music globally via `MuteSoundFile()` -- is independent of the fade mechanism. The API is available in TBC Classic Anniversary (added in patch 2.5.1) and works on "all internal game sounds." However, whether it effectively silences the built-in zone music system's playback of those files is MEDIUM confidence and needs in-game verification before committing to this feature. The Orgrimmar drum FileDataIDs are 53197, 53198, and 53200 (from Wowhead TBC sound database).

## Key Findings

**Stack:** No new dependencies. Uses existing WoW API (`SetCVar`, `GetCVar`, frame `OnUpdate`, `MuteSoundFile`). All APIs confirmed available in TBC Classic Anniversary.

**Architecture:** Add a fade controller (hidden frame with OnUpdate) alongside the existing music controller. The fade is a self-contained mechanism: start fade on zone exit, call StopMusic at completion, restore CVar. Existing stopNagrandMusic/deactivateAddon functions are modified but not restructured.

**Critical pitfall:** Volume restoration failure. If the addon ramps `Sound_MusicVolume` to 0 for a fade and then crashes, disconnects, or the user /reloads mid-fade, their music volume stays at 0. Must implement bulletproof restoration: save original CVar on fade start, restore on fade end, and also restore on PLAYER_LOGOUT and ADDON_LOADED (as a safety net).

## Implications for Roadmap

Based on research, suggested phase structure:

1. **CVar Fade Mechanism** - Build the OnUpdate-based volume ramping system
   - Addresses: Hearthstone abrupt stop, walk-out abrupt stop
   - Avoids: Volume restoration failure pitfall (built with save/restore from the start)

2. **Transition Integration** - Wire the fade into zone exit handlers, solve the drum burst race condition
   - Addresses: Orgrimmar drum burst on walk-out, re-entry-during-fade edge case
   - Avoids: Race condition between StopMusic and game zone music system

3. **Orgrimmar Music Suppression** (optional, contingent on in-game test)
   - Addresses: Optional global muting of Orgrimmar drums via MuteSoundFile
   - Avoids: Feature shipping without API verification (needs in-game test first)

**Phase ordering rationale:**
- The fade mechanism is the foundation -- it must exist before transition integration can use it
- Transition integration is the core value delivery -- it fixes both reported issues (hearthstone cut + drum burst)
- Orgrimmar suppression is independent and optional -- it can ship with or after the fade work, but should not block it

**Research flags for phases:**
- Phase 1-2: Standard patterns with HIGH confidence. OnUpdate + CVar volume ramping is well-documented and production-proven.
- Phase 3: Needs in-game validation. MuteSoundFile on zone music files has MEDIUM confidence -- the API exists and works on game sounds, but no source explicitly confirms it blocks the built-in zone music system from playing those files.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All APIs confirmed available. SetCVar, GetCVar, OnUpdate, MuteSoundFile all documented for TBC Classic Anniversary. |
| Features | HIGH | Three clear issues with well-understood solutions. CVar volume ramping is a proven pattern. |
| Architecture | HIGH | Fade controller is a self-contained addition. Minimal changes to existing code structure. |
| Pitfalls | HIGH | Volume restoration is the main risk, and the mitigation (save/restore + safety nets) is straightforward. |

## Gaps to Address

- **MuteSoundFile effectiveness on zone music:** Cannot be confirmed via documentation. Needs in-game test: `MuteSoundFile(53198)` then enter Orgrimmar. If zone music still plays, MuteSoundFile does not work for this purpose. If silence, the feature is viable.
- **Exact fade duration preference:** Defaulting to 1.5 seconds based on WoW's built-in PlayMusic fade-in feel. May need user feedback after shipping to determine if this is too slow or too fast.
- **Re-entering Nagrand during fade:** If the player turns around mid-fade and re-enters Nagrand, the fade must cancel and volume must restore immediately. This is an edge case that needs careful state management.

## Sources

- [Warcraft Wiki: StopMusic](https://warcraft.wiki.gg/wiki/API_StopMusic) -- Instant stop confirmed post-patch 2.2
- [Warcraft Wiki: PlayMusic](https://warcraft.wiki.gg/wiki/API_PlayMusic) -- Fades built-in zone music, loops
- [Warcraft Wiki: MuteSoundFile](https://warcraft.wiki.gg/wiki/API_MuteSoundFile) -- Available since 2.5.1, works on all internal game sounds
- [Warcraft Wiki: OnUpdate](https://warcraft.wiki.gg/wiki/UIHANDLER_OnUpdate) -- Per-frame handler with elapsed time
- [wow-voiceover SlideVolume](https://github.com/mrthinger/wow-voiceover/blob/master/AI_VoiceOver/Compatibility.lua) -- Production implementation of CVar volume fade
- [Wowhead TBC: Zone-Orgrimmar](https://www.wowhead.com/tbc/sound=2901/zone-orgrimmar) -- Orgrimmar FileDataIDs 53198, 53200
- [Wowhead TBC: Zone Music Day Orgrimmar City](https://www.wowhead.com/tbc/sound=2902/zone-music-day-orgrimmar-city) -- Orgrimmar FileDataID 53197

---
*Research completed: 2026-02-19*
*Ready for roadmap: yes*
