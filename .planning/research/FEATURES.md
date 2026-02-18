# Feature Research

**Domain:** WoW TBC Classic Anniversary addon -- single-zone music bug fix
**Researched:** 2026-02-18
**Confidence:** HIGH

## Context

The Nagrand music bug is a well-documented, long-standing Blizzard bug where Orgrimmar drum loops (or war drum loops) play in Nagrand instead of the correct zone music. Bug reports span from original TBC Classic through TBC Classic Anniversary (2026), confirming Blizzard has not fixed it. This addon uses `PlayMusic()` / `StopMusic()` and zone detection events to override the broken music with the correct Nagrand tracks per subzone.

Nagrand has 35+ subzones, each potentially mapped to different music tracks. The addon scope is intentionally narrow: fix one zone's music, nothing more.

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Correct music per Nagrand subzone | The entire point of the addon. Players download it to hear the right music. | MEDIUM | Requires mapping all ~35 subzones to their correct music file IDs. Core data table + `ZONE_CHANGED` event handling. Most of the work is identifying the correct FileDataIDs/paths for each subzone. |
| Automatic activation in Nagrand | Must "just work" with zero configuration. Install it, enter Nagrand, hear correct music. | LOW | Check `GetZoneText() == "Nagrand"` on zone events. Gate all logic behind this check. |
| Subzone transition handling | When walking between subzones, music should change appropriately without jarring cuts or silence. | MEDIUM | `PlayMusic()` fades out built-in music automatically. But `StopMusic()` is immediate (no fade post-patch 2.2). Need to call `PlayMusic(newTrack)` directly rather than `StopMusic()` then `PlayMusic()` to avoid silence gaps. Test whether calling `PlayMusic()` while another `PlayMusic()` track is playing transitions cleanly. |
| No interference outside Nagrand | Addon must do absolutely nothing when player is not in Nagrand. Zero performance cost, zero audio interference elsewhere. | LOW | Call `StopMusic()` when leaving Nagrand so built-in zone music resumes in other zones. Gate all event processing behind a zone check. |
| Clean startup and shutdown | Music fix activates on entering Nagrand, deactivates on leaving. No orphaned music loops playing in Orgrimmar because the player hearthed out. | LOW | Handle `ZONE_CHANGED_NEW_AREA` for major zone transitions. Call `StopMusic()` on zone exit. Handle `PLAYER_LEAVING_WORLD` (logout/disconnect) for cleanup. |
| Correct TOC metadata | Proper addon name, description, author, version in the `.toc` file. CurseForge-compatible packaging. | LOW | Interface version `20505` for TBC Classic Anniversary. Standard `.toc` fields. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valued by engaged users.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| `/fixnagrand` slash command with status | Gives users confidence the addon is working. `/fixnagrand` or `/fng` prints current state: enabled/disabled, current subzone, current track playing. | LOW | Simple `SlashCmdList` handler. Useful for support/bug reports too. |
| Toggle on/off via slash command | Lets users disable the fix without uninstalling the addon. `/fixnagrand toggle` or `/fng off`. | LOW | Boolean flag, persisted via `SavedVariables`. When disabled, call `StopMusic()` and stop processing events. |
| Debug mode | `/fixnagrand debug` prints zone change events, subzone names, and which music file is being played to chat. Essential for contributors reporting issues and for development. | LOW | Conditional `print()` calls gated behind a debug flag. Invaluable during development, costs nothing in production. |
| Login notification | Brief one-line chat message on login: "FixNagrandMusic v1.0 loaded. Type /fng for help." | LOW | Standard addon pattern. Fires on `PLAYER_LOGIN`. Lets user know it is installed and active without being intrusive. |
| Halaa PvP-aware music | Halaa is a contested PvP town. If the bug specifically mangles Halaa music (the "war drums" may actually be intentional there when Horde controls it), the addon should handle this correctly -- either playing the right Halaa combat music or leaving Halaa's music alone if it is working as intended. | MEDIUM | Requires verifying Halaa's intended music behavior vs. the bug. May need faction/control-state detection. Research needed during implementation. |
| Persisted settings | Remember toggle state and debug mode between sessions using `SavedVariablesPerCharacter`. | LOW | Standard WoW pattern. Declare in `.toc`, load on `ADDON_LOADED`, auto-saved on logout. |

### Anti-Features (Deliberately NOT Building)

Features that seem good but create problems, scope creep, or violate the addon's purpose.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full music overhaul / custom playlists | "While you're at it, let me pick my own music for Nagrand" | Completely different addon (Soundtrack already does this). Massively expands scope. Requires UI, playlist management, file scanning. | Point users to the Soundtrack addon for full music customization. FixNagrandMusic restores *intended* behavior, not custom behavior. |
| Volume controls | "Let me adjust the music volume" | WoW already has music volume controls in Sound settings. Duplicating this is pointless and confusing. No addon API for volume control anyway. | Tell users to use the built-in Sound settings. |
| Music for other zones | "Can you also fix Hellfire Peninsula / Zangarmarsh / etc?" | Scope creep. Each zone needs its own research, subzone mapping, and music file identification. The addon name is literally "FixNagrandMusic." | If other zones have bugs, create separate focused addons or expand scope in a deliberate v2 with a name change. Do not silently grow. |
| GUI configuration panel | "Add an options panel with checkboxes" | Overkill for a bug fix addon with 2 settings (enabled + debug). Adds Ace3/LibStub dependencies or manual frame code. Increases maintenance surface. | Slash commands are sufficient. `/fng toggle` and `/fng debug` cover all user-facing settings. |
| Combat music override | "Play special music during combat in Nagrand" | Different feature entirely. Combat music is a separate sound channel. Van32's CombatMusic addon exists for this. | Out of scope. Leave combat music alone. |
| Minimap button | "Add a minimap icon to toggle the addon" | Requires LibDataBroker or manual minimap button code. Overkill for a fix addon. Clutters minimap for something users toggle once (if ever). | Slash command only. |
| Support for non-Outland Nagrand (WoD) | "Does this work in Draenor Nagrand?" | Completely different zone, different music files, different bug (if any). WoD Nagrand is a separate zone ID. TBC Anniversary players are the target audience. | Out of scope. If WoD Nagrand has issues, that is a different addon. |
| Localization of slash commands | "Support /fixnagrandmusik for German clients" | Unnecessary complexity. Slash commands are conventionally English in WoW addons. Zone names from GetZoneText()/GetSubZoneText() are already localized by the game client. | Use English slash commands. Zone detection works automatically across locales because WoW returns localized names, but the addon needs localized zone name lookups (this IS table stakes, handled in the zone name constant). |

## Feature Dependencies

```
[Correct music per subzone]
    requires [Automatic Nagrand detection]
    requires [Subzone transition handling]
    requires [Clean startup/shutdown]

[Toggle on/off]
    requires [Automatic Nagrand detection] (to know what to toggle)
    enhances [Clean startup/shutdown] (toggle off = same as leaving zone)
    requires [Persisted settings] (to remember state)

[Debug mode]
    enhances [Correct music per subzone] (shows what track is playing)
    enhances [Subzone transition handling] (shows zone change events)
    requires [Persisted settings] (to remember debug state)

[Slash command with status]
    enhances [Toggle on/off]
    enhances [Debug mode]
    standalone (no hard dependencies)

[Login notification]
    standalone (no dependencies)

[Halaa PvP-aware music]
    requires [Correct music per subzone]
    requires [Automatic Nagrand detection]
```

### Dependency Notes

- **All features require Nagrand detection:** Every feature gates on the core zone check. This is the foundation.
- **Toggle requires persistence:** Without `SavedVariables`, toggle resets every login, which is frustrating. These ship together.
- **Debug mode requires persistence:** Same reasoning. Debug should stay on until the user turns it off.
- **Halaa awareness is optional and risky:** The war drums may be intentional in Halaa (PvP ambiance). Needs in-game testing to determine if Halaa should be left alone or fixed. Ship without Halaa special-casing first, add if needed.

## MVP Definition

### Launch With (v1.0)

Minimum viable product -- what ships to CurseForge day one.

- [x] Correct music per Nagrand subzone -- the entire reason the addon exists
- [x] Automatic Nagrand detection -- zero-config activation
- [x] Subzone transition handling -- no jarring silence or wrong tracks between areas
- [x] Clean startup/shutdown -- no orphaned music outside Nagrand
- [x] Proper TOC metadata -- installable via CurseForge
- [x] Login notification -- one line confirming addon is loaded
- [x] `/fng` slash command with status -- "is it working?" answer

### Add After Validation (v1.x)

Features to add once the core fix is confirmed working across all subzones.

- [ ] Toggle on/off -- add when users request ability to temporarily disable
- [ ] Persisted settings via SavedVariables -- add alongside toggle
- [ ] Debug mode -- add when bug reports come in and you need users to provide diagnostic info
- [ ] Halaa PvP-aware music -- add after in-game testing confirms Halaa needs special handling

### Future Consideration (v2+)

Features to defer until the addon has proven its value.

- [ ] Localized zone name support -- defer until non-English users report the addon not activating (GetZoneText returns localized names, so the addon needs a lookup table per locale; English-only is fine for v1 if most TBC Anniversary players use English clients)
- [ ] Other zone music fixes -- only if Blizzard introduces more broken zone music and the community asks for it

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Correct music per subzone | HIGH | MEDIUM | P1 |
| Automatic Nagrand detection | HIGH | LOW | P1 |
| Subzone transition handling | HIGH | MEDIUM | P1 |
| Clean startup/shutdown | HIGH | LOW | P1 |
| TOC metadata | HIGH | LOW | P1 |
| Login notification | LOW | LOW | P1 |
| Slash command with status | MEDIUM | LOW | P1 |
| Toggle on/off | MEDIUM | LOW | P2 |
| Persisted settings | MEDIUM | LOW | P2 |
| Debug mode | MEDIUM | LOW | P2 |
| Halaa PvP awareness | LOW | MEDIUM | P3 |
| Locale support | MEDIUM | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible (likely v1.1)
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Soundtrack | EpicMusicPlayer | BC Reimagined | FixNagrandMusic (Ours) |
|---------|-----------|-----------------|---------------|------------------------|
| Fix Nagrand bug specifically | No (general purpose) | No (general purpose) | No (replaces all BC music, not a fix) | Yes -- targeted fix |
| Zero configuration | No (extensive setup required) | No (UI-driven) | No (file replacement install) | Yes -- install and forget |
| Subzone-level control | Yes (manual assignment) | Yes (manual) | No (zone-level replacement) | Yes (automatic, preconfigured) |
| Lightweight | No (large addon with UI) | No (3000+ song library) | Yes (file replacement, no runtime code) | Yes (single Lua file, minimal memory) |
| Works on TBC Anniversary | Unclear (last updated varies) | Unclear | Yes (static files) | Yes (built for it) |
| Custom music support | Yes | Yes | No | No (intentional -- restores original) |

**Our competitive position:** The only addon purpose-built to fix this specific bug with zero configuration. Soundtrack and EpicMusicPlayer are general-purpose music overhaul tools -- overkill for users who just want correct Nagrand music. BC Reimagined replaces ALL zone music, not restoring the original. We are the "install and forget" solution.

## Technical Considerations for Features

### Music File Identification (Critical Path)

The hardest part of the core feature is identifying the correct music FileDataIDs or file paths for each Nagrand subzone. Approaches:

1. **FileDataID approach** (preferred for TBC Classic Anniversary): Use numeric IDs with `PlayMusic(fileDataID)`. More reliable, less fragile.
2. **File path approach** (fallback): Use paths like `"Sound\\Music\\ZoneMusic\\Nagrand\\..."`. Works in TBC Classic since file path support was only dropped in retail patch 8.2.0.
3. **Reference sources:** The `fondlez/wow-sounds` GitHub repo has TBC 2.4.3 sound file listings. WoWHead TBC sounds database (`wowhead.com/tbc/sounds`) has searchable sound entries with file IDs.

### Zone Name Localization (Deferred Complexity)

`GetZoneText()` returns localized zone names. For English clients, checking `== "Nagrand"` works. For other locales (German: "Nagrand", French: "Nagrand", Spanish: "Nagrand") -- Nagrand may actually be the same across locales since it is a proper noun. **Needs verification.** If it differs, a locale lookup table is needed.

### Event Handling (Core Architecture)

Three events matter:
- `ZONE_CHANGED` -- subzone transition within Nagrand (most frequent, triggers music switch)
- `ZONE_CHANGED_NEW_AREA` -- entering/leaving Nagrand entirely (triggers activation/deactivation)
- `ZONE_CHANGED_INDOORS` -- entering buildings within Nagrand (may need indoor music handling)

All three should be registered. The handler checks zone first, then subzone, then plays the mapped track.

## Sources

- [Blizzard Forum: TBC Nagrand Music Bug](https://us.forums.blizzard.com/en/wow/t/tbc-nagrand-music-bug/993365) -- HIGH confidence, official bug report
- [Blizzard Forum: Orgrimmar music in Nagrand](https://us.forums.blizzard.com/en/wow/t/orgrimmar-music-in-nagrand/1028737) -- HIGH confidence, confirms specific bug
- [Blizzard Forum: Is Nagrand music busted (Feb 2026)](https://us.forums.blizzard.com/en/wow/t/is-nagrand-music-busted/2250797) -- HIGH confidence, confirms bug persists
- [Warcraft Wiki: PlayMusic API](https://warcraft.wiki.gg/wiki/API_PlayMusic) -- HIGH confidence, official API docs
- [Warcraft Wiki: StopMusic API](https://warcraft.wiki.gg/wiki/API_StopMusic) -- HIGH confidence, StopMusic is immediate post-2.2
- [Warcraft Wiki: GetSubZoneText API](https://warcraft.wiki.gg/wiki/API_GetSubZoneText) -- HIGH confidence, confirms TBC availability
- [Warcraft Wiki: ZONE_CHANGED event](https://warcraft.wiki.gg/wiki/ZONE_CHANGED) -- HIGH confidence
- [Warcraft Wiki: Nagrand subzones](https://warcraft.wiki.gg/wiki/Nagrand) -- HIGH confidence, full subzone list
- [fondlez/wow-sounds GitHub](https://github.com/fondlez/wow-sounds) -- MEDIUM confidence, TBC 2.4.3 sound file listings
- [WoWHead TBC Sounds](https://www.wowhead.com/tbc/sounds) -- MEDIUM confidence, searchable sound database
- [CurseForge: Soundtrack addon](https://www.curseforge.com/wow/addons/soundtrack) -- MEDIUM confidence, competitor analysis
- [CurseForge: EpicMusicPlayer](https://www.curseforge.com/wow/addons/epic-music-player) -- MEDIUM confidence, competitor analysis
- [WoWInterface: BC Soundtrack Reimagined](https://www.wowinterface.com/downloads/info26063-BurningCrusadeSoundtrackReimagined.html) -- MEDIUM confidence, competitor analysis

---
*Feature research for: WoW TBC Classic Anniversary Nagrand music bug fix addon*
*Researched: 2026-02-18*
