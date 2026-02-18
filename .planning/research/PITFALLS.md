# Pitfalls Research

**Domain:** WoW addon -- zone music fix/replacement (TBC Classic Anniversary)
**Researched:** 2026-02-18
**Confidence:** MEDIUM (official WoW API wiki docs verified; TBC Anniversary-specific behaviors inferred from API version tags and community reports)

## Critical Pitfalls

### Pitfall 1: Dual Music Layering -- PlayMusic Does Not Suppress the Buggy Zone Music

**What goes wrong:**
You call `PlayMusic("Sound\\Music\\ZoneMusic\\...")` to play the correct Nagrand track, and the game's built-in buggy Orgrimmar drum loop continues playing underneath it. The player hears both tracks simultaneously -- the correct Nagrand music layered on top of the broken drum loop. This is the single most likely show-stopping bug for this addon.

**Why it happens:**
`PlayMusic()` is documented to fade out currently playing built-in music when called, but this behavior is inconsistent. The Nagrand bug involves the game's internal music system looping war drums from Halaa/Orgrimmar. If the game re-triggers its zone music after PlayMusic fades it (e.g., on subzone transition, combat events, or internal music cycling), the buggy track returns. PlayMusic only replaces the music channel once -- it does not persistently suppress the game's zone music system.

**How to avoid:**
Use a two-pronged approach:
1. Call `SetCVar("Sound_EnableMusic", 0)` to disable the game's built-in music engine entirely while in Nagrand
2. Use `PlaySoundFile(fileDataID, "Master")` on the Master or SFX channel (NOT the Music channel) for your replacement tracks
3. Restore `SetCVar("Sound_EnableMusic", 1)` when the player leaves Nagrand

Alternative approach: Use `PlayMusic()` for the correct track, but re-assert it on every `ZONE_CHANGED` and `ZONE_CHANGED_NEW_AREA` event to overpower the buggy game music each time it tries to restart. Combined with disabling music via CVar, this is more reliable.

**Warning signs:**
- During testing, you hear drums faintly under your replacement music
- Music "fights" -- alternating between your track and game drums
- Re-entering a subzone restarts the drum loop over your track

**Phase to address:**
Phase 1 (Core Implementation) -- this is the fundamental technical challenge. Must be validated before building any other features.

---

### Pitfall 2: Music Resets on Loading Screens

**What goes wrong:**
The player enters a dungeon, battleground, or crosses a continent boundary (e.g., hearthing out of Nagrand then returning). The loading screen kills all addon-played music. When they return to Nagrand, there is either silence (if game music is CVar-disabled) or the buggy drums resume with no replacement playing.

**Why it happens:**
`PlayMusic()` audio played to the Music channel stops and cannot resume after a loading screen. This is a hard limitation of WoW's FMOD sound engine. There is no pause/resume API. The `PLAYER_ENTERING_WORLD` event fires after loading screens, but the music channel needs a frame to be ready before playback works.

**How to avoid:**
Register for `PLAYER_ENTERING_WORLD` event. On that event, use a one-frame delay via `C_Timer.After(0, callback)` or an `OnUpdate` frame that fires once, then re-check the zone and restart the correct music track. The pattern is:
```lua
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    C_Timer.After(0, function()
        if GetZoneText() == "Nagrand" then
            RestartCorrectMusic()
        end
    end)
end)
```

**Warning signs:**
- Silence after hearthing back to Nagrand
- Music works on initial login but not after dungeon runs
- Players report "addon stopped working" after PvP

**Phase to address:**
Phase 1 (Core Implementation) -- must handle loading screen recovery from day one or the addon appears broken in normal play.

---

### Pitfall 3: Localization Breaks Zone/Subzone Detection

**What goes wrong:**
You hardcode `GetZoneText() == "Nagrand"` and `GetSubZoneText() == "Halaa"` and the addon works perfectly in English but is completely non-functional on German, French, Korean, Chinese, and Russian clients. `GetZoneText()` returns the localized zone name -- "Nagrand" in English, but different strings in every other locale.

**Why it happens:**
`GetZoneText()` and `GetSubZoneText()` return the client's localized zone name strings. There is no non-localized zone text API in TBC Classic. Developers test only in their own locale and never discover the breakage.

**How to avoid:**
Use `C_Map.GetBestMapForUnit("player")` which returns a numeric `uiMapID` -- these are locale-independent. Nagrand's uiMapID is a fixed number. For subzone detection, since TBC Classic may not have granular map IDs for subzones, use a fallback strategy:
1. Primary: `C_Map.GetBestMapForUnit("player")` for zone-level detection (confirmed available in TBC Anniversary 2.5.5)
2. Secondary: For subzone granularity, use `GetSubZoneText()` but maintain a localization table mapping subzone names across all supported locales (enUS, deDE, frFR, esES, esMX, ptBR, ruRU, koKR, zhCN, zhTW)
3. Consider using `LibBabble-SubZone-3.0` if it is maintained for TBC Anniversary, though embedding a focused lookup table for just Nagrand's ~12 subzones is simpler

**Warning signs:**
- Bug reports from non-English users saying "addon does nothing"
- String comparison logic with no locale handling
- No localization files in the addon structure

**Phase to address:**
Phase 1 (Core Implementation) -- use numeric map IDs from the start. Do NOT start with English strings and "add localization later" -- the architecture must be locale-aware from the beginning.

---

### Pitfall 4: FileDataID vs File Path Confusion Across API Versions

**What goes wrong:**
You use file paths like `"Sound\\Music\\ZoneMusic\\Outland\\NagrandDay.mp3"` in your `PlayMusic()` call. This works if TBC Classic Anniversary still supports file paths, but silently fails if the client follows the retail Patch 8.2.0 change that dropped file path support in favor of FileDataIDs.

**Why it happens:**
The WoW API went through a breaking change in Patch 8.2.0 (retail) that removed string-based file path support from `PlayMusic()` and `PlaySoundFile()`, replacing it with numeric FileDataIDs. TBC Classic Anniversary (2.5.5) is based on a modern client that has backported many retail API changes. The warcraft.wiki.gg documentation confirms PlayMusic is available in BC Anniversary but the exact behavior of file paths vs FileDataIDs is ambiguous for Classic variants.

**How to avoid:**
1. Test both approaches immediately in-game on TBC Classic Anniversary client
2. Prefer FileDataIDs -- they are future-proof and work regardless of client version
3. Look up Nagrand music FileDataIDs from wow.tools (https://wow.tools/files/#search=sound/music) or the fondlez/wow-sounds GitHub repository
4. For custom addon-bundled OGG files, file paths (`Interface\\AddOns\\FixNagrandMusic\\sounds\\track.ogg`) should still work as they reference addon files, not game data files

**Warning signs:**
- `PlayMusic()` returns true but no sound plays
- Music works on one client version but not another
- Using string paths for game music files

**Phase to address:**
Phase 1 (Core Implementation) -- validate the correct approach on the first day of development. This is a 5-minute test that prevents weeks of debugging.

---

### Pitfall 5: StopMusic Resumes the Buggy Game Music

**What goes wrong:**
You call `StopMusic()` intending silence or a transition, and the game's built-in zone music system immediately resumes playing the buggy Orgrimmar drum loop. Now the bug is back and the player thinks the addon is broken.

**Why it happens:**
`StopMusic()` only stops addon-played music (from `PlayMusic()`). It explicitly does NOT stop built-in zone music. In fact, calling `StopMusic()` has the documented side effect of resuming the game's own zone music. This is by design -- the API treats addon music as a temporary override, and stopping it means "return to normal game behavior."

**How to avoid:**
Never call `StopMusic()` while in Nagrand unless you are immediately following it with a new `PlayMusic()` call for the correct track. When transitioning between subzone tracks within Nagrand, call `PlayMusic(newTrack)` directly -- this automatically stops the previous addon track and replaces it. Only use `StopMusic()` when the player leaves Nagrand and you WANT the game's normal zone music to resume.

If using the CVar approach (disabling game music), `StopMusic()` is safe because the game music engine is disabled and cannot resume.

**Warning signs:**
- Brief drum loop bursts during subzone transitions
- Music "blips" when changing tracks
- Calling StopMusic() anywhere in your code without immediately calling PlayMusic()

**Phase to address:**
Phase 1 (Core Implementation) -- design the music transition logic correctly from the start. This is an architecture decision, not a bug fix.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoding English subzone strings | Faster initial development | Breaks for ~40% of WoW's player base on non-English clients | Never -- use map IDs from day one |
| Using OnUpdate polling instead of events | Catches edge cases events miss | Runs every frame, wastes CPU, interferes with game performance | Only as a safety net with heavy throttling (1-2 second interval), never as primary detection |
| Bundling OGG files instead of using game FileDataIDs | Guarantees correct music plays | Huge addon download size, CurseForge 1.2GB limit, copyright concerns with Blizzard music | Never for Blizzard's own tracks -- use FileDataIDs. Only for truly custom audio. |
| Skipping the CVar music disable approach | Simpler code, fewer side effects | Dual-music layering bug surfaces in edge cases | Only if PlayMusic is confirmed to reliably suppress game music on every zone/subzone transition -- test extensively first |
| Single global enable/disable with no per-zone intelligence | Simpler state management | Addon affects zones other than Nagrand, or fails to activate when player enters Nagrand from unexpected direction | Never -- scope the addon tightly to Nagrand |

## Integration Gotchas

Common mistakes when connecting to WoW's sound/music systems.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| PlayMusic channel | Assuming PlayMusic on Music channel permanently overrides zone music | PlayMusic replaces zone music temporarily; zone transitions and game events can re-trigger the built-in music. Must re-assert on every zone event. |
| MuteSoundFile API | Trying to use MuteSoundFile to silence the buggy drum loop | MuteSoundFile mutes individual FileDataIDs but does not persist across client restarts (only survives /reload). You would need to re-mute on every login AND know the exact FileDataIDs of the buggy drum tracks. Viable but fragile. |
| Sound_EnableMusic CVar | Setting CVar to 0 globally and forgetting to restore it | Always restore to 1 when leaving Nagrand. Save and restore the player's original preference rather than always setting to 1 -- they may have had music disabled by choice. |
| TOC Interface version | Using wrong interface number (20504 instead of 20505) | TBC Classic Anniversary uses Interface: 20505. Verify against the current client. The number may increment with patches -- check on each patch day. |
| PlaySoundFile channel selection | Using "Music" channel for PlaySoundFile, conflicting with game music | If supplementing (not replacing) zone music, use "SFX" or "Master" channel. If replacing, use "Music" channel but with CVar disable strategy. |
| ZONE_CHANGED event timing | Calling GetSubZoneText() in the same frame as ZONE_CHANGED and getting stale data | Use `C_Timer.After(0, callback)` to defer the zone text read by one frame, ensuring the game has updated the zone data. |

## Performance Traps

Patterns that work in testing but cause problems in gameplay.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| OnUpdate without throttling | FPS drops, especially on low-end machines | Use event-driven detection (ZONE_CHANGED events) as primary, with a heavily throttled OnUpdate (every 2+ seconds) only as backup | Immediately on low-end hardware; noticeable at high frame rates (240fps = 240 calls/sec) |
| Calling PlayMusic on every frame/tick | Audio stuttering, music restarts from beginning constantly | Only call PlayMusic when the track actually needs to change (track state variable) | Immediately -- music restarts from the beginning every time PlayMusic is called |
| Large subzone lookup tables loaded at addon init | Memory usage spikes on login, slow ADDON_LOADED | Nagrand has ~12 subzones -- this is not a realistic concern for this addon. Keep lookup tables small and static. | Not a real concern for this addon; only matters for addons mapping all 1000+ subzones |
| Excessive CVar writes | SetCVar has overhead if called frequently | Only write CVar when the value actually needs to change. Cache the current state. | Becomes noticeable if writing CVar on every frame or event without checking current value |

## UX Pitfalls

Common user experience mistakes in zone music replacement addons.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Music cuts abruptly on zone boundary | Jarring silence or sudden track switch when stepping one foot out of Nagrand | Implement a brief fade-out or let the current track finish its loop naturally. If using CVar disable, restore music with a small delay. |
| No way to disable the addon in-game | Player must log out, disable addon, log back in if they don't want the fix | Provide a simple slash command (`/fixnagrand off`) and/or a minimap button to toggle |
| Volume mismatch between addon music and game | Replacement tracks are noticeably louder or quieter than music in neighboring zones | PlayMusic respects the Music channel volume. If using PlaySoundFile on another channel, match volumes carefully. Test at multiple volume settings. |
| Addon overrides intentionally disabled music | Player has music turned off in settings, addon re-enables it | Check `GetCVar("Sound_EnableMusic")` before doing anything. If the player has music disabled, the addon should do nothing. |
| No feedback that the addon is working | Player installs addon, enters Nagrand, has no idea if the fix is active | Print a subtle chat message on zone entry: "FixNagrandMusic: Playing correct Nagrand music" (once per session, not spammy) |
| Music does not match subzone mood | Playing gentle Nagrand ambience while at Ring of Blood or Halaa PvP battle | Map specific tracks to subzones -- Halaa gets more intense music, Telaar gets peaceful music, etc. |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Zone detection:** Works in English -- verify with numeric map IDs that it works on all localized clients
- [ ] **Music plays on login:** Works after /reload -- verify it also works after a cold login (PLAYER_ENTERING_WORLD fires differently on first login vs reload)
- [ ] **Subzone transitions:** Works walking between subzones -- verify it works when FLYING between subzones at high speed (events may fire rapidly or be skipped)
- [ ] **Loading screen recovery:** Works entering Nagrand on foot -- verify it works after hearthing to Shattrath and flying back, or after exiting a dungeon into Nagrand
- [ ] **Player settings respected:** Addon plays music -- verify it respects the player's Music volume setting and does not play if they have music disabled
- [ ] **Edge zones:** Works in central Nagrand -- verify at the Zangarmarsh border (coordinates ~71.8, 37.7) where the bug is reported to be worst, and at Twilight Ridge
- [ ] **CVar restoration:** Addon disables game music in Nagrand -- verify it is ALWAYS restored on /reload, logout, and zone exit (even unexpected disconnects via `PLAYER_LOGOUT` event)
- [ ] **Concurrent addon compatibility:** Works alone -- verify it works alongside EpicMusicPlayer, Soundtrack, or other music addons that may call PlayMusic/StopMusic
- [ ] **TOC version:** Works on current TBC Anniversary patch -- verify the Interface number (20505) matches and update on patch day

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Dual music layering | LOW | Switch to CVar-disable approach; single code change, no architecture rewrite |
| Localization breakage | MEDIUM | Retrofit numeric map IDs into detection logic; requires touching all zone-check code paths |
| FileDataID/path confusion | LOW | Swap string paths for numeric IDs; lookup correct IDs from wow.tools |
| Loading screen silence | LOW | Add PLAYER_ENTERING_WORLD handler with one-frame delay; isolated change |
| StopMusic resuming game music | LOW | Remove StopMusic calls, use direct PlayMusic replacement; localized code change |
| CVar not restored on disconnect | MEDIUM | Add PLAYER_LOGOUT handler; also add a "restore defaults" slash command for manual recovery |
| Wrong TOC version | LOW | Update the Interface number in the .toc file; takes 30 seconds |
| Volume mismatch | LOW | Adjust FileDataID selections or add volume normalization option |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Dual music layering | Phase 1: Core Implementation | Test in Nagrand -- only one music track audible at a time, no drum loop bleed-through |
| Music resets on loading screen | Phase 1: Core Implementation | Hearth out of Nagrand, fly back -- correct music resumes within 1-2 seconds |
| Localization breakage | Phase 1: Core Implementation | Change WoW client language to deDE -- addon still activates in Nagrand |
| FileDataID vs file path | Phase 1: Core Implementation (first day) | PlayMusic call with FileDataID produces audible music on TBC Anniversary client |
| StopMusic resuming buggy music | Phase 1: Core Implementation | Transition between Nagrand subzones -- no drum loop burst between tracks |
| OnUpdate performance | Phase 1: Core Implementation | /run print(GetAddOnCPUUsage("FixNagrandMusic")) shows minimal CPU usage |
| CVar restoration | Phase 1: Core Implementation | Leave Nagrand -- game music in other zones plays normally |
| Player settings respected | Phase 2: Polish | Disable music in game settings -- addon does not override the player's choice |
| Subzone-specific tracks | Phase 2: Polish | Walk through Halaa, Telaar, Garadar -- each plays appropriate music |
| Loading screen edge cases | Phase 2: Polish | Test dungeon exit, BG exit, hearth, death/graveyard scenarios |
| Addon compatibility | Phase 2: Polish | Install alongside EpicMusicPlayer -- no conflicts or crashes |
| TOC version maintenance | Ongoing | Verify on each TBC Anniversary patch day |

## Sources

- [PlayMusic API -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_PlayMusic) -- HIGH confidence (official wiki, version-tagged for BC Anniversary 2.5.5)
- [PlaySoundFile API -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_PlaySoundFile) -- HIGH confidence (official wiki)
- [PlaySound API -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_PlaySound) -- HIGH confidence (official wiki)
- [ZONE_CHANGED event -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/ZONE_CHANGED) -- HIGH confidence (official wiki)
- [GetSubZoneText API -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_GetSubZoneText) -- HIGH confidence (official wiki)
- [GetZoneText API -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_GetZoneText) -- HIGH confidence (official wiki)
- [MuteSoundFile API -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_MuteSoundFile) -- HIGH confidence (official wiki, version-tagged for BC Anniversary 2.5.5)
- [TOC format -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/TOC_format) -- HIGH confidence (official wiki, TBC suffix documented)
- [Nagrand music bug report (US forums)](https://us.forums.blizzard.com/en/wow/t/tbc-nagrand-music-bug/993365) -- MEDIUM confidence (community report, confirms bug exists)
- [Nagrand music bug report (EU forums)](https://eu.forums.blizzard.com/en/wow/t/nagrand-music-bug-pls-fix-blizzard/606156) -- MEDIUM confidence (community report, corroborates US report, February 2026 confirmed active)
- [StopMusic behavior -- WoWInterface forums](https://www.wowinterface.com/forums/showthread.php?t=57109) -- MEDIUM confidence (community, corroborated by official wiki)
- [Localizing an addon -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Localizing_an_addon) -- HIGH confidence (official wiki)
- [OnUpdate throttling -- GitHub gist](https://gist.github.com/Choonster/eb07bbd750776d1254fc) -- MEDIUM confidence (community best practice, widely cited)
- [WoW sound file database -- fondlez/wow-sounds](https://github.com/fondlez/wow-sounds) -- MEDIUM confidence (community database covering TBC 2.4.3 era)
- [Soundtrack addon -- CurseForge](https://www.curseforge.com/wow/addons/soundtrack) -- MEDIUM confidence (reference implementation for zone music replacement patterns)
- [LibBabble-SubZone-3.0 -- WowAce](https://www.wowace.com/projects/libbabble-subzone-3-0) -- LOW confidence (may or may not be maintained for TBC Anniversary)
- [C_Map.GetBestMapForUnit -- wowpedia](https://wowpedia.fandom.com/wiki/API_C_Map.GetBestMapForUnit) -- HIGH confidence (confirmed available in TBC Classic via community usage)

---
*Pitfalls research for: WoW addon zone music fix (TBC Classic Anniversary -- FixNagrandMusic)*
*Researched: 2026-02-18*
