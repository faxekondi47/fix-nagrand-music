# Pitfalls Research

**Domain:** WoW addon -- music transitions, fade-out, and suppression (TBC Classic Anniversary, v1.1)
**Researched:** 2026-02-19
**Confidence:** MEDIUM-HIGH (official WoW API wiki docs verified for core APIs; CVar-based fade technique verified via community usage patterns; MuteSoundFile behavior confirmed on warcraft.wiki.gg with TBC Classic availability tags)

## Critical Pitfalls

### Pitfall 1: StopMusic Instant Cut Causes Jarring Hearthstone Exit

**What goes wrong:**
When a player hearthstones out of Nagrand, `StopMusic()` fires in `deactivateAddon()` and the music cuts instantly with zero fade. This is the primary UX complaint from v1.0 -- an abrupt silence that feels like a bug, followed by the destination zone's music starting cold.

**Why it happens:**
Since Patch 2.2, `StopMusic()` stops music immediately with no fade. Before 2.2 it faded out, but this behavior was removed. There is no `StopMusic(fadeDuration)` parameter. The WoW API provides no built-in way to fade out addon-played music. The only way to simulate a fade-out is to progressively reduce `Sound_MusicVolume` via `SetCVar` before calling `StopMusic()`.

**How to avoid:**
Implement a CVar-based volume fade-out:
1. Save the user's current `Sound_MusicVolume` value via `GetCVar("Sound_MusicVolume")`
2. Use `C_Timer.NewTicker` to progressively reduce `Sound_MusicVolume` in steps (e.g., 10 steps over 1.5 seconds)
3. After the fade completes, call `StopMusic()` and immediately restore `Sound_MusicVolume` to the saved value
4. The ticker must be cancellable (store the handle) so rapid zone changes can abort an in-progress fade

**Warning signs:**
- Music cuts instantly when leaving Nagrand by any method (hearthstone, flight path, walking)
- Testing only with walking exits (slow) and missing the hearthstone case (loading screen interrupts)
- Volume restoration happens before `StopMusic()`, causing a brief loud burst

**Phase to address:**
Phase 1 (Fade-out implementation) -- this is the single most impactful UX improvement for v1.1.

---

### Pitfall 2: Volume Fade Clobbers the User's Music Volume Setting

**What goes wrong:**
The addon reduces `Sound_MusicVolume` to 0 for a fade-out, then the player disconnects, crashes, or `/quit` fires before the restore callback executes. The player's music volume is now permanently stuck at 0 across all zones and characters.

**Why it happens:**
`SetCVar("Sound_MusicVolume", ...)` writes to the game's persistent configuration. If the addon sets the volume to 0.0 during a fade and the client closes before restoration, the game saves that value. On next login, the player has no music anywhere. This is especially dangerous because `PLAYER_LOGOUT` is not guaranteed to fire on crashes or Alt-F4. Even when it does fire, the fade ticker may still be partway through execution.

**How to avoid:**
1. Save the original volume in `SavedVariables` BEFORE starting any fade: `FixNagrandMusicDB.savedMusicVolume = GetCVar("Sound_MusicVolume")`
2. On `ADDON_LOADED`, check if `savedMusicVolume` is non-nil -- if so, a fade was interrupted. Restore the volume immediately: `SetCVar("Sound_MusicVolume", FixNagrandMusicDB.savedMusicVolume)`
3. Clear `savedMusicVolume` from SavedVariables only AFTER successful restoration
4. On `PLAYER_LOGOUT`, cancel any active fade ticker and restore volume before the client saves state

```lua
-- Recovery on next login
function handlers.ADDON_LOADED(addonName)
    if addonName ~= "FixNagrandMusic" then return end
    -- ... existing init ...
    if FixNagrandMusicDB.savedMusicVolume then
        SetCVar("Sound_MusicVolume", FixNagrandMusicDB.savedMusicVolume)
        FixNagrandMusicDB.savedMusicVolume = nil
    end
end
```

**Warning signs:**
- During testing, manually kill the WoW process during a fade -- does volume restore on next login?
- Only testing clean exits (logout button) and never testing crashes/Alt-F4
- Volume restore logic only lives in the fade completion callback with no failsafe

**Phase to address:**
Phase 1 (Fade-out implementation) -- the failsafe must ship with the fade feature, never as a separate follow-up.

---

### Pitfall 3: Fade Timer Stacking From Rapid Zone Transitions

**What goes wrong:**
The player rapidly walks in and out of Nagrand (bouncing on the zone boundary), or hearthstones during a subzone transition. Multiple fade tickers start running simultaneously, each reducing volume independently. Volume drops to 0 almost instantly (not a smooth fade), or worse, one ticker tries to restore volume while another is still fading down, causing volume oscillation.

**Why it happens:**
`C_Timer.After` callbacks cannot be cancelled. If using `C_Timer.After` in a loop pattern (like the existing day/night timer), each call creates an independent timer with no handle to cancel. Even `C_Timer.NewTicker` requires explicit cancellation via the returned handle. If the handle is not stored and the old ticker is not cancelled before creating a new one, tickers stack.

**How to avoid:**
1. Use `C_Timer.NewTicker` (not chained `C_Timer.After` calls) so the ticker is cancellable
2. Store the ticker handle in a module-level variable: `local fadeOutTicker = nil`
3. Before starting any new fade, cancel the existing one:
   ```lua
   if fadeOutTicker and not fadeOutTicker:IsCancelled() then
       fadeOutTicker:Cancel()
   end
   ```
4. On any activation event (entering Nagrand), cancel any running fade-out and restore volume immediately -- the player is back in Nagrand, no fade needed
5. On `PLAYER_LOGOUT`, cancel ticker and restore volume synchronously

**Warning signs:**
- Walk back and forth across the Zangarmarsh/Nagrand border 5 times rapidly -- does volume behave correctly?
- Volume drops faster than the intended fade duration
- Debug output shows multiple "fade step" messages interleaved

**Phase to address:**
Phase 1 (Fade-out implementation) -- must be part of the initial fade design, not patched in later.

---

### Pitfall 4: Orgrimmar Music Burst on Walking Exit (Zone Boundary Race)

**What goes wrong:**
When walking out of Nagrand into Zangarmarsh/Terokkar, there is a 0.5-1 second burst of Orgrimmar drum music before the correct destination zone music starts. The addon calls `StopMusic()` on zone exit, which instantly stops the addon's Nagrand track, and the game's buggy Orgrimmar zone music reasserts in the gap before the new zone's music system takes over.

**Why it happens:**
`StopMusic()` only stops addon-played music. It does NOT stop built-in zone music. When addon music stops, the game's internal music system immediately tries to play whatever it thinks should be playing. In Nagrand, that is the buggy Orgrimmar drum loop. The game's zone music transition to the new zone takes a moment to kick in, creating a brief window where the drums play.

This is exacerbated by `ZONE_CHANGED_NEW_AREA` firing with a one-frame defer (the existing `C_Timer.After(0, ...)` pattern), which adds another frame of delay before deactivation logic runs.

**How to avoid:**
Two complementary strategies:
1. **Fade-out before StopMusic:** Do not call `StopMusic()` immediately. Start a volume fade-out first. By the time volume reaches 0, the destination zone's music system has already taken over, masking the drums.
2. **MuteSoundFile the Orgrimmar tracks:** Before calling `StopMusic()`, mute the specific Orgrimmar drum FileDataIDs. Unmute them after a short delay (1-2 seconds) once the zone transition is complete. This is a belt-and-suspenders approach.
3. **Consider NOT calling StopMusic at all when walking out.** If the destination zone's built-in music will auto-start anyway, just let `PlayMusic`'s internal behavior handle it. The game's zone music system will fade out the addon-played music when it asserts the new zone's tracks.

**Warning signs:**
- Brief drum burst audible when crossing zone boundaries on foot
- No drum burst when hearthing (loading screen masks it) -- only walking/flying exits
- Testing only hearthstone exits and declaring zone transitions "fixed"

**Phase to address:**
Phase 1 (Zone exit fix) -- this is the second primary v1.1 goal after fade-out.

---

### Pitfall 5: MuteSoundFile Does Not Persist Across Client Restarts

**What goes wrong:**
You implement Orgrimmar music suppression using `MuteSoundFile(fileDataID)` for the drum tracks. It works perfectly. The player logs out and back in -- suppression is gone. The player restarts their client -- suppression is completely gone. They think the feature is broken.

**Why it happens:**
`MuteSoundFile` state only persists through `/reload` and relogging (character select and back). It is cleared entirely when the WoW client process exits. This is documented on warcraft.wiki.gg: "Muting only persists through relogging and /reload, and have to be muted again after restarting the game client." There is no way to make it permanent.

**How to avoid:**
1. Store the user's suppression preference in `SavedVariables` (e.g., `FixNagrandMusicDB.suppressOrgrimmar = true`)
2. On `ADDON_LOADED` or `PLAYER_LOGIN`, if the preference is enabled, call `MuteSoundFile(fileDataID)` for each Orgrimmar drum track
3. Re-apply the mutes on every `PLAYER_ENTERING_WORLD` event as well (belt-and-suspenders for loading screen edge cases)
4. Document this behavior to users: "Suppression is automatically re-applied each session"

**Warning signs:**
- Feature works in testing (same session) but "breaks" after client restart
- No `ADDON_LOADED` handler to re-apply mutes
- Testing only with `/reload` and never with a full client restart

**Phase to address:**
Phase 2 (Orgrimmar suppression) -- the re-application on load is the core requirement, not an optimization.

---

### Pitfall 6: MuteSoundFile Silences Your Own PlayMusic Tracks

**What goes wrong:**
You mute the Orgrimmar drum FileDataIDs, but those same FileDataIDs overlap with or are identical to tracks used in other zones or by the game's music system in ways you did not expect. Worse: if MuteSoundFile mutes a FileDataID and your addon later tries to `PlayMusic()` with that same ID, the playback is silenced. The addon appears to do nothing.

**Why it happens:**
`MuteSoundFile` works on "all internal game sounds, addon sounds and sounds played manually by PlaySoundFile()." The documentation from warcraft.wiki.gg confirms: calling `MuteSoundFile(id)` then `PlaySoundFile(id)` results in silence. While this addon uses different FileDataIDs for Nagrand (53585-53590) vs Orgrimmar, the risk is:
- Incorrectly identifying which FileDataIDs to mute (wrong IDs)
- Muting IDs that overlap with sounds used in other contexts
- A SoundKitID mapping to multiple FileDataIDs (random selection), where muting one does not mute all variants

**How to avoid:**
1. Identify the EXACT FileDataIDs for the Orgrimmar drum tracks that play in Nagrand (from Wowhead or wow.tools). These must be verified in-game.
2. Cross-reference against the Nagrand track IDs (53585-53590) to confirm zero overlap
3. When muting, mute only the specific FileDataIDs, not SoundKitIDs
4. Provide an `UnmuteSoundFile` cleanup path that runs when the user disables suppression
5. Test in Orgrimmar itself after enabling suppression -- does the city lose its music? (This may be desired or undesired depending on the feature scope.)

**Warning signs:**
- After enabling suppression, some zone has unexpected silence
- Suppression "works" in Nagrand but causes side effects in Orgrimmar
- Using SoundKitIDs instead of FileDataIDs with MuteSoundFile

**Phase to address:**
Phase 2 (Orgrimmar suppression) -- requires careful FileDataID research before implementation.

---

### Pitfall 7: Breaking Existing v1.0 Behavior While Adding v1.1 Features

**What goes wrong:**
The v1.0 addon works correctly: detects Nagrand, plays correct music, handles subzones, recovers from loading screens. While adding fade-out, transition fixes, or suppression features, the developer modifies `deactivateAddon()`, `playNagrandMusic()`, or the event handlers in ways that break the core behavior. The "improved" addon no longer plays music at all, or plays it in the wrong zone, or fails to recover from loading screens.

**Why it happens:**
The v1.0 codebase has carefully balanced state management:
- `isActive` tracks whether the addon is managing music
- `currentTrackID` prevents unnecessary PlayMusic calls
- The `C_Timer.After(0, ...)` defer in zone event handlers ensures data is fresh
- `playNagrandMusic()` deliberately does NOT call `StopMusic()` before `PlayMusic()` to avoid drum gap

Modifying any of these patterns without understanding why they exist creates regressions. Common mistakes:
- Adding `StopMusic()` call before `PlayMusic()` "for cleanliness" -- reintroduces drum burst
- Changing event handler to wait for fade completion before re-activating -- misses loading screen recovery
- Adding state variables that get out of sync with `isActive`
- Modifying `PLAYER_ENTERING_WORLD` handler to skip re-activation during fades

**How to avoid:**
1. Add new features as NEW code paths, do not modify existing working functions until the new path is tested
2. Add fade-out as a wrapper AROUND `deactivateAddon()`, not by modifying it:
   ```lua
   local function fadeOutAndDeactivate()
       startFadeOut(function()
           deactivateAddon()  -- existing function, unchanged
       end)
   end
   ```
3. Keep `activateAddon()` and `playNagrandMusic()` completely unchanged -- they work
4. Test the EXISTING behavior after every change: enter Nagrand, leave Nagrand, hearthstone, subzone transitions, day/night change
5. Suppress toggle should be additive -- muting sounds on top of existing behavior, not replacing it

**Warning signs:**
- After adding fade-out, the addon no longer plays music on entering Nagrand
- Subzone transitions within Nagrand trigger fade-outs (they should not)
- Loading screen recovery stops working
- Day/night timer stops working

**Phase to address:**
ALL phases -- regression testing after every change. This is not a one-phase concern.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using chained `C_Timer.After` for fade steps | No need to learn NewTicker API | Cannot cancel mid-fade; creates uncancellable callbacks that execute even after the addon state has changed | Never -- always use `C_Timer.NewTicker` with stored handle for cancellable operations |
| Not saving volume to SavedVariables before fade | Simpler code, fewer writes | Client crash during fade = permanently zeroed music volume | Never -- the failsafe costs 2 lines of code and prevents a catastrophic UX failure |
| Hardcoding Orgrimmar FileDataIDs without verification | Faster implementation | Wrong IDs = suppression does nothing, or mutes wrong sounds | Only during initial prototyping; must verify in-game before shipping |
| Muting all Orgrimmar music globally (not just in Nagrand) | Simpler -- no zone-scoping needed | Player loses Orgrimmar music everywhere, not just during the Nagrand bug | Acceptable IF explicitly presented as a user choice with clear description |
| Skipping fade-out on PLAYER_LOGOUT | Simpler cleanup code | Volume may not be restored if fade is in progress during logout | Never -- PLAYER_LOGOUT must cancel fade and restore volume synchronously |

## Integration Gotchas

Common mistakes when connecting new v1.1 features to the existing v1.0 codebase.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Fade-out + deactivateAddon | Replacing `deactivateAddon()` with fade logic, breaking the instant-cleanup path needed for logout/disable | Wrap: `fadeOutThenDeactivate()` calls fade, fade completion calls original `deactivateAddon()`. Keep `deactivateAddon()` as the instant-cleanup path for logout. |
| MuteSoundFile + PlayMusic | Assuming MuteSoundFile only affects zone music; it mutes ALL playback of that FileDataID including addon-initiated | Verify muted FileDataIDs do not overlap with any IDs used by PlayMusic in this addon |
| CVar volume fade + user audio settings | Reading `Sound_MusicVolume` once at addon load and using that as the "restore" value forever | Read the current value at the START of each fade. The user may have changed their volume since the last fade. |
| Zone exit fade + ZONE_CHANGED_NEW_AREA | Starting a 2-second fade on zone exit but the destination zone's music starts in 0.5 seconds, causing audible overlap | Keep fades short (1-1.5 seconds max). The fade simulates "music trailing off," not a dramatic cinematic transition. |
| Orgrimmar suppression toggle + isActive state | Checking `isActive` in the toggle handler -- suppression is a global preference, not tied to Nagrand activation | Suppression enable/disable should be independent of zone state. Mute/unmute immediately on toggle, regardless of current zone. |
| New SavedVariables fields + existing DB | Adding new fields without nil-checking in ADDON_LOADED -- existing users who upgrade have nil values | Initialize every new field with a default if nil, just like the existing `enabled` and `debug` fields |

## Performance Traps

Patterns that work in testing but cause problems in gameplay.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Fade ticker with too-small interval (e.g., 0.01s) | 100 SetCVar calls per second during fade; micro-stutters | Use 0.05-0.1s interval (10-20 steps for a 1-second fade). Volume changes are logarithmic; users cannot perceive 100 steps vs 15. | Immediately on low-end hardware; particularly noticeable during combat |
| Re-applying MuteSoundFile on every zone event | Unnecessary API calls on every ZONE_CHANGED | Apply once on ADDON_LOADED/PLAYER_LOGIN. Only re-apply on PLAYER_ENTERING_WORLD (loading screen recovery). | Not a performance issue but adds noise to debug output and is architecturally wrong |
| Storing fade state in closures, not module variables | Hard to debug; closure captures stale state | Use module-level variables (`local fadeOutTicker`, `local fadeOriginalVolume`) accessible to all functions | Debugging becomes impossible when fade behaves unexpectedly |

## UX Pitfalls

Common user experience mistakes when adding transitions and suppression.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Fade-out too slow (3+ seconds) | Player is in the new zone hearing fading music from the old zone; feels wrong | 1-1.5 second fade. Quick enough to feel intentional, long enough to avoid abrupt cut. |
| Fade-out on subzone transitions within Nagrand | Music fades and restarts when walking between Nagrand subzones; feels broken | Fade-out ONLY on zone EXIT (Nagrand to not-Nagrand). Subzone transitions use existing PlayMusic replacement (no fade). |
| Orgrimmar suppression enabled by default | Player did not ask for this; their Orgrimmar music is gone and they do not know why | Default OFF. User must explicitly enable with `/fng suppress` or similar. |
| No way to disable suppression without /reload | Player enables suppression, regrets it, has no way to unmute until reload | `UnmuteSoundFile` exists and works immediately. Toggle should mute/unmute in real-time. |
| Fade-out plays during /fng toggle off | Player disables the addon via slash command and hears a weird fade instead of instant stop | `/fng toggle` should use instant stop (existing `deactivateAddon`), not the fade path. Fade is for organic zone exits only. |
| No chat feedback for suppression state | Player types `/fng suppress` and has no idea if it worked | Print "Orgrimmar music suppression: ON/OFF" with the muted track count |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Fade-out:** Works on zone exit -- verify it also works on hearthstone (loading screen interrupts the fade mid-way; volume must still be restored)
- [ ] **Fade-out:** Works once -- verify rapid zone boundary crossing does not stack faders (walk in/out of Nagrand 5x quickly)
- [ ] **Fade-out:** Works normally -- verify Alt-F4 during fade does not permanently zero volume (check SavedVariables recovery on next login)
- [ ] **Fade-out:** Volume restores correctly -- verify the RESTORED volume matches what the user had BEFORE the fade, not a hardcoded "1.0"
- [ ] **Fade-out:** Does not fire on subzone transitions -- verify walking between Telaar and Garadar does NOT trigger fade
- [ ] **Zone exit:** No drum burst on walking exit -- verify at Nagrand/Zangarmarsh border and Nagrand/Terokkar border
- [ ] **Zone exit:** Works with flying -- verify flying out of Nagrand at high speed triggers correct cleanup
- [ ] **MuteSoundFile:** Suppression re-applied after client restart (not just /reload)
- [ ] **MuteSoundFile:** Suppression does not silence this addon's own Nagrand music (FileDataID cross-check)
- [ ] **MuteSoundFile:** UnmuteSoundFile works immediately on toggle-off (no /reload required)
- [ ] **Regression:** Entering Nagrand still plays correct music (unchanged from v1.0)
- [ ] **Regression:** Subzone transitions within Nagrand still seamless (unchanged from v1.0)
- [ ] **Regression:** Loading screen recovery still works (PLAYER_ENTERING_WORLD handler)
- [ ] **Regression:** Day/night timer still works (C_Timer.After chain for 60-second checks)
- [ ] **Regression:** `/fng` status, toggle, debug commands still work
- [ ] **Regression:** Per-character SavedVariables still load correctly (new fields initialized with nil-checks)

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Volume stuck at 0 after crash | LOW | SavedVariables recovery on ADDON_LOADED restores saved volume; add `/fng resetvolume` escape hatch |
| Stacked fade tickers | LOW | Switch from C_Timer.After chain to C_Timer.NewTicker with stored handle; cancel before creating new |
| Drum burst on zone exit | MEDIUM | Add MuteSoundFile for drum tracks as belt-and-suspenders; or implement fade-out to mask the gap |
| MuteSoundFile muting wrong sounds | LOW | UnmuteSoundFile all previously muted IDs; re-research correct FileDataIDs |
| Regression in v1.0 behavior | LOW | Git diff against v1.0 tag; revert changes to core functions; add new features as wrappers instead |
| MuteSoundFile not available in TBC Classic Anniversary | MEDIUM | Fall back to CVar-based approach: set Sound_MusicVolume to 0 while in Nagrand, use PlaySoundFile on non-Music channel. Less clean but functional. |
| Fade causes taint in combat | LOW | Sound CVars are not combat-protected in TBC Classic; if they become protected, skip fade during combat and use instant stop |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| StopMusic instant cut (Pitfall 1) | Phase 1: Fade-out | Hearthstone out of Nagrand -- music fades smoothly over 1-1.5 seconds |
| Volume clobber on crash (Pitfall 2) | Phase 1: Fade-out | Kill WoW process during fade, relaunch -- volume restored on next login |
| Fade timer stacking (Pitfall 3) | Phase 1: Fade-out | Cross zone boundary 5x rapidly -- no volume oscillation, single smooth fade |
| Orgrimmar burst on walk exit (Pitfall 4) | Phase 1: Zone exit fix | Walk from Nagrand to Zangarmarsh -- no drum burst audible |
| MuteSoundFile non-persistence (Pitfall 5) | Phase 2: Suppression | Enable suppression, restart client, enter Nagrand -- still suppressed |
| MuteSoundFile silencing own tracks (Pitfall 6) | Phase 2: Suppression | Enable suppression, enter Nagrand -- correct music still plays |
| v1.0 regression (Pitfall 7) | All phases | Run full v1.0 test suite after each phase: enter/leave/subzone/loading/day-night/toggle |

## Sources

- [StopMusic API -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_StopMusic) -- HIGH confidence. Confirms post-Patch 2.2 instant stop (no fade). Confirms StopMusic only affects addon-played music.
- [PlayMusic API -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_PlayMusic) -- HIGH confidence. Confirms PlayMusic fades out built-in zone music. Loops until StopMusic/reload/logout.
- [MuteSoundFile API -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_MuteSoundFile) -- HIGH confidence. Confirms: persists through relog/reload but NOT client restart. Available since Patch 2.5.1 (TBC Classic). Accepts FileDataID or path. Works on all sounds including addon-played.
- [C_Timer.NewTicker API -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_C_Timer.NewTimer) -- HIGH confidence. Confirms Cancel()/IsCancelled() methods on returned handle. Errors in callback do not halt ticker.
- [C_Timer.After API -- wowpedia](https://wowpedia.fandom.com/wiki/API_C_Timer.After) -- HIGH confidence. Confirms 0-second duration defers to next frame. No cancel mechanism.
- [Console variables -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Console_variables) -- HIGH confidence. Sound_MusicVolume is a standard CVar. Secure CVars cannot be set in combat, but sound CVars are not documented as secure.
- [SetCVar -- wowpedia](https://wowpedia.fandom.com/wiki/Console_variables) -- MEDIUM confidence. Community confirms SetCVar works for Sound_MusicVolume from addon code. Combat restriction applies only to secure CVars.
- [Volume adjustment macros -- Blizzard forums](https://us.forums.blizzard.com/en/wow/t/useful-volume-adjustment-macros-for-greater-immersion/1455069) -- MEDIUM confidence. Community demonstrates step-reducing Sound_MusicVolume via SetCVar for fade effects.
- [WoWInterface -- C_Timer usage patterns](https://www.wowinterface.com/forums/showthread.php?t=49566) -- MEDIUM confidence. Community best practices for timer management.
- [MuteSoundFile addon -- CurseForge](https://www.curseforge.com/wow/addons/mutesoundfile) -- MEDIUM confidence. Reference implementation confirming MuteSoundFile re-application on login for persistence.
- [EpicMusicPlayer FAQ -- CurseForge](https://www.curseforge.com/wow/addons/epic-music-player) -- MEDIUM confidence. Documents Music channel behavior across loading screens, ambient channel workaround.
- [ZONE_CHANGED_NEW_AREA -- wowpedia](https://wowpedia.fandom.com/wiki/ZONE_CHANGED_NEW_AREA) -- HIGH confidence. Event fires on major zone changes.
- [PLAYER_ENTERING_WORLD -- warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/PLAYER_ENTERING_WORLD) -- HIGH confidence. Fires after every loading screen with isInitialLogin/isReloadingUi params.

---
*Pitfalls research for: WoW addon music transitions, fade-out, and suppression (TBC Classic Anniversary -- FixNagrandMusic v1.1)*
*Researched: 2026-02-19*
