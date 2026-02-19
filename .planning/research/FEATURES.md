# Feature Research: Smooth Music Transitions

**Domain:** WoW TBC Classic Anniversary addon -- music transition polish and optional suppression
**Researched:** 2026-02-19
**Confidence:** HIGH (API behavior verified with official docs; implementation patterns verified from shipped addons)

## Context

FixNagrandMusic v1.0 ships a working Nagrand music fix with zone detection, day/night variants, and Orgrimmar drum suppression. Three user-facing issues remain:

1. **Hearthstone exit cuts music abruptly** -- `StopMusic()` is instant (no fade since WoW patch 2.2). Using Hearthstone triggers `PLAYER_ENTERING_WORLD`, addon detects not-in-Nagrand, calls `StopMusic()`, music vanishes mid-note.
2. **Walking out of Nagrand triggers brief Orgrimmar drums** -- when the player crosses the zone boundary on foot/mount, `ZONE_CHANGED_NEW_AREA` fires, addon calls `StopMusic()`, and the game's built-in (bugged) zone music briefly reasserts the Orgrimmar drums before the destination zone's correct music takes over.
3. **No option to suppress Orgrimmar music entirely** -- power users who find the drums annoying everywhere (not just Nagrand) have no toggle to mute them globally.

These are polish features for a v1.1/v2.0 milestone. The core fix works; this is about making transitions feel native.

## Table Stakes

Features users expect from a "smooth transitions" update. Missing these makes the update feel pointless.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| Fade-out on zone exit (hearthstone) | The #1 most noticeable rough edge. Every music app fades out; abrupt silence is jarring. Users expect "smooth" to mean smooth. | MEDIUM | Modifies `stopNagrandMusic()` path | Requires CVar-based volume ramping (see Technical Analysis below). No native fade API exists post-patch 2.2. |
| Fade-out on zone exit (walking/flying) | Same as hearthstone, but for continuous movement. Equally jarring when walking across the Nagrand/Zangarmarsh border. | MEDIUM | Same fade mechanism as hearthstone case, but must also handle the Orgrimmar drum burst (see below) | Shares implementation with hearthstone fade. |
| No Orgrimmar drum burst on walk-out | The brief flash of wrong music actively undermines trust in the addon. Users will think the fix is broken if they hear drums when leaving. | HIGH | Requires solving the StopMusic-to-zone-music race condition | This is the hardest problem. See "Transition Race Condition" in Technical Analysis. |
| Volume restoration after fade | If the addon ramps `Sound_MusicVolume` down for a fade, it MUST restore the user's original volume. Silently zeroing someone's music volume is a critical bug. | LOW | Required by fade-out implementation | Save CVar before fade, restore after. The addon already has `savedMusicCVar` pattern for `Sound_EnableMusic`. |
| Fade works with any user volume | The fade must be relative to the user's current music volume, not hardcoded. A user at 30% volume should fade 30% to 0%, not 100% to 0%. | LOW | Required by fade-out implementation | Read `GetCVar("Sound_MusicVolume")` before starting fade. |

## Differentiators

Features that make this update genuinely valuable beyond "the bare minimum works."

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| Optional Orgrimmar music suppression | Power users can silence the bugged Orgrimmar drums globally, not just in Nagrand. Clean addon option, not a workaround. | MEDIUM | New `FixNagrandMusicDB.muteOrgrimmar` setting, slash command extension | Uses `MuteSoundFile()` API (available since TBC Classic 2.5.1). Must call on every login and UI reload since mutes do not persist across client restarts. |
| Configurable fade duration | Let users control how long the fade takes (e.g., 0.5s, 1s, 2s). Some prefer quick, some prefer cinematic. | LOW | Requires fade mechanism to exist first | Default to 1.5 seconds (matches WoW's built-in PlayMusic fade-in feel). Store in `FixNagrandMusicDB.fadeDuration`. |
| Debug logging for transitions | Extend existing debug mode to log fade progress, volume changes, and transition states. Essential for diagnosing "I hear drums when walking out" reports. | LOW | Existing debug infrastructure | Add `printDebug()` calls in fade ticker and transition logic. |
| Graceful degradation if CVar is protected | If a future WoW patch restricts `SetCVar("Sound_MusicVolume")` in combat or other contexts, the addon should fall back to instant stop rather than erroring. | LOW | pcall wrapper around SetCVar | Defensive coding. Not currently needed but good practice. |

## Anti-Features

Features to explicitly NOT build for this milestone.

| Anti-Feature | Why It Seems Useful | Why Avoid | What to Do Instead |
|--------------|---------------------|-----------|-------------------|
| Cross-fade (overlap old and new music) | Cinematic feel, like a real soundtrack | WoW only has one PlayMusic channel. Cannot play two addon music tracks simultaneously. Cross-fade is physically impossible with the API. | Fade-out to silence, let destination zone music fade-in naturally (WoW handles this). |
| Fade-in when entering Nagrand | Symmetry with fade-out | PlayMusic already fades in built-in zone music naturally when called. Adding a manual CVar ramp-up on entry would fight with PlayMusic's built-in behavior and could cause volume jumps. | Let PlayMusic's native fade-in behavior handle entry. It already works well in v1.0. |
| Suppress all zone music bugs globally | "Fix every zone, not just Nagrand" | Massive scope expansion. Each zone needs research, FileDataID mapping, and testing. Turns a focused fix into a general-purpose music addon. | Keep scope to Nagrand. If users request other zones, that is a separate addon or a deliberate major version. |
| Music selection per subzone | "Let me pick which Nagrand track plays in Garadar" | Turns the addon from a bug fix into a music customization tool. Soundtrack addon already does this. | The addon restores intended behavior. Random track selection within the correct day/night pool is faithful to original design. |
| Suppression of non-Orgrimmar music | "Can I also mute Stormwind music?" | Feature creep. The Orgrimmar suppression is justified because it is the root cause of the bug this addon fixes. Generalizing to arbitrary music muting is a different product. | Point users to the MuteSoundFile addon for general sound muting. |
| GUI options panel for fade settings | "Add a slider for fade duration" | Overkill for one setting. Adds UI framework dependencies. Slash commands are the established pattern. | `/fng fade 1.5` slash command is sufficient. |

## Technical Analysis

### Fade-Out via CVar Volume Ramping

**The approach:** Since `StopMusic()` is instant (no fade post-patch 2.2) and there is no `FadeMusic()` API, the only way to achieve a fade-out is to gradually ramp `Sound_MusicVolume` CVar from the user's current value down to 0, then call `StopMusic()`, then restore the CVar.

**Proven pattern:** The wow-voiceover addon (mrthinger/wow-voiceover) implements exactly this via `SlideVolume()`:
- Uses a frame `OnUpdate` handler for smooth per-frame interpolation
- Calculates a rate: `(target - current) / duration`
- Each frame: `next = current + rate * elapsed`
- Uses `SetCVar("Sound_MusicVolume", next)` each frame
- Epsilon threshold (`0.01`) for completion detection
- Callback on completion (for calling `StopMusic()` and restoring CVar)

**Confidence:** HIGH -- This is a shipped addon using this exact technique. The VoiceOver addon specifically notes that on WoW 2.4.3 (TBC client baseline), toggling CVars causes music to fade gradually (~0.4-0.5s), suggesting the CVar approach is well-supported on this client version.

**Implementation choice: OnUpdate vs C_Timer.After**

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| Frame `OnUpdate` handler | Smooth per-frame updates, elapsed-time-aware, proven pattern from VoiceOver addon | Slightly more code (need a frame), runs every frame while active | **Use this.** Fade is a short-duration, frame-rate-sensitive operation. |
| `C_Timer.After` chain | Simpler code, already used in the addon | Timer resolution is limited (~16ms minimum), chaining creates many closures, not elapsed-time-aware | Not suitable for smooth interpolation. |
| `C_Timer.NewTicker` | Repeating timer, cleaner than After chain | Same resolution issues as After, not frame-synced | Better than After chain but still inferior to OnUpdate for visual/audio smoothness. |

**Recommendation:** Use a dedicated hidden frame with an `OnUpdate` script for the fade. Only set the script when fading (set to nil when idle to avoid per-frame cost when not fading). This matches the VoiceOver addon pattern and keeps CPU cost to zero when not actively fading.

### Transition Race Condition (Walk-Out Drum Burst)

**The problem sequence:**
1. Player walks from Nagrand into Zangarmarsh
2. `ZONE_CHANGED_NEW_AREA` fires
3. Addon detects not-in-Nagrand, calls `StopMusic()`
4. WoW's built-in zone music system reasserts its queued track
5. Because of the Nagrand bug, the queued track is Orgrimmar drums
6. Drums play briefly until Zangarmarsh's zone music takes over

**Why this is hard:** `StopMusic()` only stops addon-played music. The moment it runs, the built-in zone music system is free to play whatever it wants -- and what it wants to play (in this bugged state) is Orgrimmar drums. There is a window between `StopMusic()` and the destination zone music asserting itself.

**Solution approaches ranked:**

| Approach | How It Works | Feasibility | Drawback |
|----------|-------------|-------------|----------|
| **Delayed StopMusic with fade** | Start a CVar volume fade when leaving Nagrand. Call `StopMusic()` at the end of the fade (e.g., 1.5s later). By then, the destination zone's music system has likely asserted. | HIGH | If destination music is slower than the fade, there could be a brief overlap where both are "playing" (addon track at 0 volume, zone music starting). This is actually fine -- the addon track is inaudible at that point. |
| **MuteSoundFile on Orgrimmar tracks** | Mute the Orgrimmar drum FileDataIDs (53197, 53198, 53200) so they can never play. | MEDIUM | MuteSoundFile resets on client restart. Must re-apply on every `PLAYER_ENTERING_WORLD`. Also, this is a more aggressive intervention -- it prevents Orgrimmar music from playing even when the player is actually in Orgrimmar. Better as an opt-in feature. |
| **Keep PlayMusic running briefly** | Do not call `StopMusic()` immediately. Let the addon music continue for 1-2 seconds after leaving Nagrand, then fade and stop. | HIGH | The addon music would play for a moment in the destination zone. But with the fade, users would hear a smooth transition from Nagrand music to destination music, which actually feels natural. |
| **Play a silent track** | Call `PlayMusic()` with a known-silent FileDataID to bridge the gap. | LOW | No reliable silent FileDataID exists in the game data. Creating addon sound files adds packaging complexity. |

**Recommendation:** Combine approaches 1 and 3. When leaving Nagrand:
1. Do NOT call `StopMusic()` immediately
2. Start a CVar volume fade (1.5s default)
3. At fade completion, call `StopMusic()` and restore CVar
4. By the time the fade finishes, the destination zone's music has had 1.5s to assert itself, eliminating the drum burst window

This is the cleanest solution. The user hears Nagrand music fade out smoothly as they cross the border, and by the time it reaches silence, the correct destination music is already playing.

### MuteSoundFile for Orgrimmar Suppression

**API:** `MuteSoundFile(fileDataID)` / `UnmuteSoundFile(fileDataID)`
**Availability:** Added in patch 2.5.1 (TBC Classic). Available in TBC Classic Anniversary.
**Persistence:** Muted files persist through `/reload` and relog, but reset on client restart.
**Scope:** Works on "all internal game sounds, addon sounds and sounds played manually."

**Orgrimmar music FileDataIDs (from Wowhead TBC sound database):**
- `53197` -- orgrimmar01-moment.mp3 (Zone Music Day Orgrimmar City, sound ID 2902)
- `53198` -- orgrimmar01-zone.mp3 (Zone-Orgrimmar, sound ID 2901)
- `53200` -- orgrimmar02-zone.mp3 (Zone-Orgrimmar, sound ID 2901)

**Confidence on MuteSoundFile working on zone music:** MEDIUM. The API documentation says it works on "all internal game sounds." Zone music files are internal game sounds. Multiple addons (MuteSoundFile, Mute Annoying WoW Sounds) use this API to mute various game sounds. However, no source explicitly confirms or denies that it works on the built-in zone music system's playback. This needs in-game testing before committing to this feature.

**UX consideration:** Suppressing Orgrimmar music means no music plays when the user is actually in Orgrimmar. This should be opt-in with clear messaging: "/fng mute-org -- Suppress Orgrimmar drum music everywhere (including in Orgrimmar)."

### Event Timing During Hearthstone

**Hearthstone sequence:**
1. Player casts Hearthstone in Nagrand
2. Cast completes, loading screen appears
3. `PLAYER_ENTERING_WORLD` fires (during/after loading screen)
4. `ZONE_CHANGED_NEW_AREA` fires
5. Zone data becomes available (potentially after a 1-frame delay)

The addon already defers zone checks by one frame via `C_Timer.After(0, ...)` in both `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA` handlers. The fade-out approach works here: when either handler detects not-in-Nagrand, start the fade rather than calling `StopMusic()` instantly.

**Edge case:** During a loading screen, the player cannot hear audio anyway. The music effectively "pauses" during loading. The abrupt stop only matters perceptually after the loading screen clears. Starting the fade on `PLAYER_ENTERING_WORLD` (which fires as the loading screen ends) gives the user a smooth audible fade from the moment they can hear again.

## Feature Dependencies

```
[Fade-out on zone exit]
    requires [CVar volume ramping mechanism]
    requires [Volume save/restore]
    modifies [stopNagrandMusic() / deactivateAddon()]

[No Orgrimmar drum burst on walk-out]
    requires [Fade-out on zone exit] (delayed StopMusic solves the race)
    modifies [ZONE_CHANGED_NEW_AREA handler timing]

[Fade works with any user volume]
    requires [CVar volume ramping mechanism]
    built into the fade implementation (not separate)

[Volume restoration after fade]
    requires [CVar volume ramping mechanism]
    modifies [deactivateAddon() cleanup path]

[Optional Orgrimmar music suppression]
    independent of fade mechanism
    requires [MuteSoundFile API availability confirmed in-game]
    requires [Orgrimmar FileDataID identification]
    requires [New FixNagrandMusicDB field + slash command]
    modifies [PLAYER_ENTERING_WORLD handler to re-apply mutes]

[Configurable fade duration]
    requires [Fade-out on zone exit]
    requires [New FixNagrandMusicDB field + slash command]

[Debug logging for transitions]
    requires [Existing debug infrastructure]
    enhances [Fade-out on zone exit]
    enhances [Optional Orgrimmar music suppression]
```

### Dependency Notes

- **Fade-out solves two problems at once:** Both the hearthstone cut and the walk-out drum burst are fixed by the same delayed-StopMusic-with-fade approach. These are not separate features from an implementation perspective.
- **Orgrimmar suppression is independent:** The MuteSoundFile approach stands alone. It does not depend on the fade mechanism and could ship separately or together.
- **Fade duration config is pure sugar:** The fade works with a hardcoded default. Making it configurable is low-effort once the mechanism exists but is not required.

## MVP Recommendation for This Milestone

### Must Ship

1. **CVar volume fade-out mechanism** -- OnUpdate-based frame with save/restore. This is the foundation for all transition improvements.
2. **Delayed StopMusic on zone exit** -- Start fade on zone exit detection, call StopMusic at fade completion. Fixes both hearthstone abruptness and walk-out drum burst in one change.
3. **Volume restoration guarantee** -- Always restore `Sound_MusicVolume` after fade, even if the fade is interrupted (e.g., player re-enters Nagrand mid-fade).

### Should Ship

4. **Optional Orgrimmar music suppression** -- Via `MuteSoundFile()` with `/fng mute-org` toggle. Contingent on in-game verification that MuteSoundFile works on zone music tracks.
5. **Debug logging for fade/transition states** -- Extend existing debug mode.

### Defer

6. **Configurable fade duration** -- Ship with 1.5s default. Add configurability if users request it.
7. **Graceful degradation for protected CVars** -- Add pcall wrapper only if issues are reported.

## Complexity Assessment

| Feature | Lines of Code (Est.) | Risk | Notes |
|---------|---------------------|------|-------|
| CVar fade mechanism | 40-60 LOC | LOW | Well-understood pattern from VoiceOver addon. OnUpdate + rate + epsilon. |
| Delayed StopMusic integration | 20-30 LOC | MEDIUM | Must handle edge cases: re-entering Nagrand during fade, logout during fade, toggle-off during fade. |
| Volume save/restore | 10-15 LOC | LOW | Extend existing `savedMusicCVar` pattern. |
| Orgrimmar MuteSoundFile | 25-35 LOC | MEDIUM | API availability is HIGH confidence, but effectiveness on zone music is MEDIUM confidence. Needs in-game test. |
| Slash command extensions | 10-20 LOC | LOW | Extend existing pattern. |
| Debug logging additions | 10-15 LOC | LOW | Add printDebug calls. |
| **Total** | **~115-175 LOC** | | Modest addition to the existing ~400 LOC addon. |

## Sources

- [Warcraft Wiki: StopMusic API](https://warcraft.wiki.gg/wiki/API_StopMusic) -- HIGH confidence. Confirms StopMusic is instant post-patch 2.2, only affects PlayMusic-played tracks.
- [Warcraft Wiki: PlayMusic API](https://warcraft.wiki.gg/wiki/API_PlayMusic) -- HIGH confidence. Confirms PlayMusic fades built-in zone music, loops until stopped.
- [Warcraft Wiki: MuteSoundFile API](https://warcraft.wiki.gg/wiki/API_MuteSoundFile) -- HIGH confidence. Added in 2.5.1, works on all internal game sounds, resets on client restart.
- [Warcraft Wiki: ZONE_CHANGED_NEW_AREA](https://warcraft.wiki.gg/wiki/ZONE_CHANGED_NEW_AREA) -- HIGH confidence. Fires on major zone boundary crossing.
- [Warcraft Wiki: C_Timer.After](https://warcraft.wiki.gg/wiki/API_C_Timer.After) -- HIGH confidence. Duration 0 = next frame.
- [Warcraft Wiki: OnUpdate handler](https://warcraft.wiki.gg/wiki/UIHANDLER_OnUpdate) -- HIGH confidence. Per-frame callback with elapsed time.
- [wow-voiceover SlideVolume implementation](https://github.com/mrthinger/wow-voiceover/blob/master/AI_VoiceOver/Compatibility.lua) -- MEDIUM confidence. Shipped addon implementing CVar volume fade via OnUpdate. Confirms the pattern works in TBC-era clients.
- [Wowhead TBC: Zone-Orgrimmar sound 2901](https://www.wowhead.com/tbc/sound=2901/zone-orgrimmar) -- MEDIUM confidence. FileDataIDs 53198, 53200 for Orgrimmar zone music.
- [Wowhead TBC: Zone Music Day Orgrimmar City sound 2902](https://www.wowhead.com/tbc/sound=2902/zone-music-day-orgrimmar-city) -- MEDIUM confidence. FileDataID 53197 for Orgrimmar day music.
- [CurseForge: Soundtrack addon fade behavior](https://www.curseforge.com/wow/addons/soundtrack) -- LOW confidence. Mentions volume-based fade loop lowering by 0.01 increments. Confirms general approach but implementation quality unclear.
- [CurseForge: MuteSoundFile addon](https://www.curseforge.com/wow/addons/mutesoundfile) -- MEDIUM confidence. Confirms MuteSoundFile API is widely used for muting game sounds.

---
*Feature research for: FixNagrandMusic smooth transitions milestone*
*Researched: 2026-02-19*
