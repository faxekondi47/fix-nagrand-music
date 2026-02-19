# Architecture: v1.1 Smooth Transitions Integration

**Domain:** Music transition fixes and suppression for existing WoW TBC Classic Anniversary addon
**Researched:** 2026-02-19
**Confidence:** HIGH for fade system, MEDIUM for MuteSoundFile on zone music
**Scope:** How 3 new features integrate with existing 407 LOC single-file architecture

---

## Existing Architecture (v1.0 Baseline)

The current addon is a single file (`FixNagrandMusic.lua`, 398 LOC) with these logical sections:

```
Section 1:  MUSIC DATA          (lines 6-39)     -- NAGRAND_TRACKS, TRACK_PATHS, constants
Section 2:  STATE VARIABLES     (lines 41-48)    -- currentTrackID, isActive, lastTimeOfDay, etc.
Section 3:  UTILITY FUNCTIONS   (lines 50-81)    -- print helpers, version, updateSubzone
Section 4:  ZONE DETECTION      (lines 83-95)    -- isInNagrand()
Section 5:  DAY/NIGHT DETECTION (lines 97-105)   -- isDayTime()
Section 6:  MUSIC PLAYBACK      (lines 107-179)  -- playNagrandMusic(), stopNagrandMusic()
Section 7:  DAY/NIGHT MONITOR   (lines 181-210)  -- startDayNightTimer (C_Timer.After chain)
Section 8:  ACTIVATION          (lines 212-243)  -- activateAddon(), deactivateAddon()
Section 9:  EVENT HANDLERS      (lines 245-329)  -- handlers table, ZONE_CHANGED_*, etc.
Section 10: FRAME SETUP         (lines 331-344)  -- CreateFrame, OnEvent, RegisterEvent
Section 11: SLASH COMMANDS      (lines 346-397)  -- /fng, /fng toggle, /fng debug
```

### Key Existing State

| Variable | Type | Purpose |
|----------|------|---------|
| `currentTrackID` | number/nil | FileDataID of currently playing track |
| `isActive` | boolean | Whether addon is managing music |
| `lastTimeOfDay` | boolean/nil | Last known day/night for transition detection |
| `savedMusicCVar` | string/nil | User's original Sound_EnableMusic value |
| `currentSubzone` | string/nil | Current subzone name |

### Key Existing Functions

| Function | Lines | Purpose | Modification needed? |
|----------|-------|---------|---------------------|
| `stopNagrandMusic()` | 171-179 | Calls StopMusic(), resets state | YES -- replace with fade-out |
| `deactivateAddon()` | 234-243 | Calls stopNagrandMusic(), restores CVar | YES -- must handle async fade |
| `handlers.ZONE_CHANGED_NEW_AREA()` | 276-290 | Detects zone exit, calls deactivateAddon | YES -- needs delayed stop for walking exit |
| `handlers.PLAYER_ENTERING_WORLD()` | 313-324 | Login/reload/instance transition | YES -- needs fade on hearthstone exit |
| `playNagrandMusic()` | 133-166 | Plays correct track | NO -- unchanged |
| `activateAddon()` | 215-231 | Entry point for Nagrand | NO -- unchanged |
| `isInNagrand()` | 86-95 | Zone detection | NO -- unchanged |

---

## v1.1 Features and Integration Points

### Feature 1: Smooth Fade-Out (Hearthstone Exit Fix)

**Problem:** `StopMusic()` cuts audio instantly since WoW patch 2.2. When hearthstoning out of Nagrand, the abrupt cutoff is jarring.

**Solution:** Gradually ramp `Sound_MusicVolume` CVar from current value to 0 over ~2 seconds using an OnUpdate-driven frame, then call `StopMusic()` and restore the original volume.

**API Surface (verified):**

| API | Availability | Behavior |
|-----|-------------|----------|
| `GetCVar("Sound_MusicVolume")` | TBC Classic 2.5.5 -- YES | Returns string "0" to "1" (float) |
| `SetCVar("Sound_MusicVolume", value)` | TBC Classic 2.5.5 -- YES | Sets music volume, takes effect immediately |
| `frame:SetScript("OnUpdate", func)` | TBC Classic 2.5.5 -- YES | Called every frame, receives `elapsed` (seconds since last frame) |

**New component: Volume Fade System**

```lua
-- New state variables (Section 2)
local fadeState = nil           -- { startVolume, targetVolume, duration, elapsed, callback }
local savedMusicVolume = nil    -- user's original Sound_MusicVolume before fade
local fadeFrame = nil           -- dedicated frame for OnUpdate fade tick

-- New function: startFadeOut (new Section 6b)
local function startFadeOut(duration, callback)
    -- Save current volume
    savedMusicVolume = tonumber(GetCVar("Sound_MusicVolume")) or 1.0
    if savedMusicVolume <= 0 then
        -- Volume already at 0, just execute callback
        if callback then callback() end
        return
    end
    fadeState = {
        startVolume = savedMusicVolume,
        targetVolume = 0,
        duration = duration,
        elapsed = 0,
        callback = callback,
    }
    -- Enable OnUpdate on the fade frame
    fadeFrame:SetScript("OnUpdate", fadeOnUpdate)
end

-- New function: fadeOnUpdate (new Section 6b)
local function fadeOnUpdate(self, elapsed)
    if not fadeState then
        self:SetScript("OnUpdate", nil)
        return
    end
    fadeState.elapsed = fadeState.elapsed + elapsed
    local progress = fadeState.elapsed / fadeState.duration
    if progress >= 1 then
        -- Fade complete
        SetCVar("Sound_MusicVolume", tostring(fadeState.targetVolume))
        local callback = fadeState.callback
        fadeState = nil
        self:SetScript("OnUpdate", nil)
        if callback then callback() end
    else
        -- Linear interpolation
        local vol = fadeState.startVolume + (fadeState.targetVolume - fadeState.startVolume) * progress
        SetCVar("Sound_MusicVolume", tostring(vol))
    end
end

-- New function: cancelFade (new Section 6b)
local function cancelFade()
    if fadeState then
        fadeState = nil
        fadeFrame:SetScript("OnUpdate", nil)
    end
    -- Restore saved volume
    if savedMusicVolume then
        SetCVar("Sound_MusicVolume", tostring(savedMusicVolume))
        savedMusicVolume = nil
    end
end
```

**Existing function modifications:**

`stopNagrandMusic()` -- Replace immediate StopMusic with fade-out:

```lua
-- BEFORE (v1.0):
local function stopNagrandMusic()
    if not isActive then return end
    StopMusic()
    currentTrackID = nil
    isActive = false
    lastTimeOfDay = nil
end

-- AFTER (v1.1):
local function stopNagrandMusic()
    if not isActive then return end
    -- Mark inactive immediately to prevent re-triggers
    isActive = false
    lastTimeOfDay = nil
    currentTrackID = nil
    -- Fade out over 2 seconds, then hard stop
    startFadeOut(2.0, function()
        StopMusic()
        -- Restore original volume after stop
        if savedMusicVolume then
            SetCVar("Sound_MusicVolume", tostring(savedMusicVolume))
            savedMusicVolume = nil
        end
    end)
end
```

`deactivateAddon()` -- Now handles async completion:

```lua
-- No structural change needed -- it already calls stopNagrandMusic()
-- which now fades. The CVar restore at line 239-242 must move into
-- the fade callback or be guarded to run after fade completes.
```

**Critical concern:** If the player enters a new zone while fade is still running, `activateAddon()` could be called during fade. The fade system must support cancellation -- `cancelFade()` restores volume immediately and clears state.

**Confidence:** HIGH -- `SetCVar("Sound_MusicVolume")` is well-documented, used by multiple production addons (AI VoiceOver, Volumizer), and confirmed available in TBC Classic Anniversary. OnUpdate frame approach is the standard WoW pattern for per-frame updates.

### Feature 2: Zone Transition Fix (Walking Out of Nagrand)

**Problem:** When walking/flying out of Nagrand, `StopMusic()` stops our track and the game briefly plays the bugged Orgrimmar drums before the destination zone music takes over.

**Root cause:** The zone music system has the bugged drum tracks queued. When we release control via `StopMusic()`, they play for a moment before the new zone's music replaces them.

**Solution options (in order of recommendation):**

**Option A: Delayed stop with fade (RECOMMENDED)**

Keep our music playing for a short period after zone exit, fading it out. By the time our track stops, the destination zone's music system has already asserted itself and the bugged drums never get a window.

Integration with Feature 1: This uses the same fade system. Instead of immediately calling `deactivateAddon()` on zone exit, delay it:

```lua
-- Modified ZONE_CHANGED_NEW_AREA handler
function handlers.ZONE_CHANGED_NEW_AREA()
    C_Timer.After(0, function()
        if isInNagrand() then
            if not isActive then
                activateAddon()
            end
        else
            if isActive then
                -- Don't deactivate immediately -- fade first
                -- The fade gives destination zone music time to assert
                deactivateAddon()  -- now internally fades via stopNagrandMusic()
            end
        end
    end)
end
```

This works because `stopNagrandMusic()` (modified in Feature 1) now fades over 2 seconds. During those 2 seconds, our Nagrand music is still playing (just getting quieter), so the bugged drums never get an audible window. By the time volume hits 0 and `StopMusic()` executes, the destination zone music has had 2 seconds to take over.

**Option B: MuteSoundFile suppression (see Feature 3)**

If the fade alone does not prevent the drum burst (e.g., drums play on top of our fading track), `MuteSoundFile` can permanently silence the drum FileDataIDs. This is complementary, not a replacement.

**Confidence:** MEDIUM -- The theory is sound (fade masks the transition), but whether 2 seconds is enough for destination zone music to assert needs in-game testing. The fade duration may need tuning.

### Feature 3: MuteSoundFile Orgrimmar Suppression (Optional Setting)

**Problem:** The root cause of the Nagrand bug is specific Orgrimmar/drum music FileDataIDs that incorrectly play. Users may want to mute these globally.

**API Surface (verified):**

| API | Availability | Behavior |
|-----|-------------|----------|
| `MuteSoundFile(sound)` | Added in 2.5.1 -- TBC Classic 2.5.5 YES | Accepts FileDataID (number). Mutes the sound file globally. Persists through `/reload` and relog but NOT client restart. |
| `UnmuteSoundFile(sound)` | Added in 2.5.1 -- TBC Classic 2.5.5 YES | Reverses MuteSoundFile. Same persistence behavior. |

**Orgrimmar Music FileDataIDs (from Wowhead TBC sound database):**

| Sound Entry | FileDataID | Track |
|-------------|-----------|-------|
| Zone-Orgrimmar (2901) | 53198 | orgrimmar01-zone |
| Zone-Orgrimmar (2901) | 53200 | orgrimmar02-zone |
| Zone Music Day Orgrimmar City (2902) | 53197 | orgrimmar01-moment |

**IMPORTANT NOTE:** These are the correct Orgrimmar music tracks, not necessarily the bugged tracks. The bug in Nagrand might be caused by:
1. These exact Orgrimmar zone music tracks being incorrectly assigned to Nagrand subzones in AreaTable/ZoneMusicTable
2. Different tracks entirely (ogre drum combat music, Halaa PvP music, etc.)

**The specific FileDataIDs causing the bug need in-game identification.** Method: Enter Nagrand without the addon, enable `/fng debug`, and use a sound sniffer addon or `/dump` to identify what's actually playing.

**Integration approach -- new setting in SavedVariables:**

```lua
-- Section 1: Add mute data
local ORGRIMMAR_MUTE_IDS = {
    53197,  -- orgrimmar01-moment
    53198,  -- orgrimmar01-zone
    53200,  -- orgrimmar02-zone
    -- Additional IDs added after in-game identification
}

-- Section 2: Add state
-- FixNagrandMusicDB.muteOrgrimmar (boolean, default false)

-- New functions (Section 6c or similar)
local function applyMutes()
    if not FixNagrandMusicDB.muteOrgrimmar then return end
    for _, id in ipairs(ORGRIMMAR_MUTE_IDS) do
        MuteSoundFile(id)
    end
end

local function removeMutes()
    for _, id in ipairs(ORGRIMMAR_MUTE_IDS) do
        UnmuteSoundFile(id)
    end
end
```

**Where to call `applyMutes()`:**
- In `handlers.PLAYER_LOGIN()` -- mutes must be re-applied every client session
- In `handlers.PLAYER_ENTERING_WORLD()` -- belt-and-suspenders, ensures mutes survive instance transitions
- In the toggle slash command when user enables the setting

**Where to call `removeMutes()`:**
- In the toggle slash command when user disables the setting
- NOT on logout (mutes auto-clear on client restart anyway)

**Slash command extension:**

```lua
-- Add to Section 11:
-- /fng mute    -- toggles Orgrimmar music muting
elseif command == "mute" then
    FixNagrandMusicDB.muteOrgrimmar = not FixNagrandMusicDB.muteOrgrimmar
    if FixNagrandMusicDB.muteOrgrimmar then
        applyMutes()
        printInfo("Orgrimmar music muted")
    else
        removeMutes()
        printInfo("Orgrimmar music unmuted")
    end
```

**Confidence:** MEDIUM -- `MuteSoundFile` is confirmed available in TBC Classic 2.5.5, and the Warcraft Wiki states it works on "all internal game sounds." Whether it effectively suppresses zone music tracks (which go through the ZoneMusic.dbc -> SoundEntries.dbc pipeline rather than direct PlaySoundFile calls) needs in-game verification. The MuteSoundFile addon on CurseForge and the GitHub gist for muting zone music suggest it does work, but direct confirmation for TBC Classic Anniversary is needed.

---

## Updated System Architecture (v1.1)

```
+------------------------------------------------------------------+
|                         Event Layer                               |
|  ZONE_CHANGED_NEW_AREA | ZONE_CHANGED | PLAYER_ENTERING_WORLD    |
+------------------------------------------------------------------+
         |                      |                    |
         v                      v                    v
+------------------------------------------------------------------+
|                   Zone Detection (unchanged)                      |
|  isInNagrand() | updateSubzone()                                  |
+------------------------------------------------------------------+
         |
         v
+------------------------------------------------------------------+
|                   Music Controller (modified)                     |
|  playNagrandMusic() -- unchanged                                  |
|  stopNagrandMusic() -- now triggers fade instead of StopMusic()   |
|  activateAddon()    -- adds cancelFade() guard                    |
|  deactivateAddon()  -- now async (fade callback cleans up)        |
+------------------------------------------------------------------+
         |                              |
         v                              v
+-------------------------+    +---------------------------+
|  Volume Fade System     |    |  MuteSoundFile Suppressor |
|  (NEW)                  |    |  (NEW, optional)          |
|                         |    |                           |
|  startFadeOut()         |    |  applyMutes()             |
|  fadeOnUpdate()         |    |  removeMutes()            |
|  cancelFade()           |    |  ORGRIMMAR_MUTE_IDS       |
|                         |    |                           |
|  Uses: OnUpdate frame,  |    |  Uses: MuteSoundFile(),   |
|  SetCVar(MusicVolume)   |    |  UnmuteSoundFile()        |
+-------------------------+    +---------------------------+
```

---

## Detailed Modification Map

### Files Changed

Only one file: `FixNagrandMusic/FixNagrandMusic.lua`

No new files, no TOC changes (unless adding a new setting to SavedVariablesPerCharacter, which is already `FixNagrandMusicDB` -- no change needed).

### Section-by-Section Changes

| Section | Current LOC | Change Type | What Changes |
|---------|-------------|-------------|--------------|
| 1: MUSIC DATA | 6-39 | ADD | `ORGRIMMAR_MUTE_IDS` table (Feature 3) |
| 2: STATE | 41-48 | ADD | `fadeState`, `savedMusicVolume`, `fadeFrame` variables |
| 3: UTILITY | 50-81 | NONE | No changes |
| 4: ZONE DETECTION | 83-95 | NONE | No changes |
| 5: DAY/NIGHT | 97-105 | NONE | No changes |
| 6: MUSIC PLAYBACK | 107-179 | MODIFY | `stopNagrandMusic()` uses fade; ADD new Section 6b for fade system |
| 7: DAY/NIGHT MONITOR | 181-210 | NONE | No changes |
| 8: ACTIVATION | 212-243 | MODIFY | `activateAddon()` calls `cancelFade()`; `deactivateAddon()` handles async |
| 9: EVENT HANDLERS | 245-329 | MODIFY | `ADDON_LOADED` adds muteOrgrimmar default; `PLAYER_LOGIN` calls `applyMutes()` |
| 10: FRAME SETUP | 331-344 | ADD | Create `fadeFrame` for OnUpdate |
| 11: SLASH COMMANDS | 346-397 | ADD | `/fng mute` command |

### Estimated LOC Impact

| Component | New LOC | Rationale |
|-----------|---------|-----------|
| Volume Fade System | ~50 | fadeState, startFadeOut, fadeOnUpdate, cancelFade, fadeFrame setup |
| stopNagrandMusic modification | +5, -3 | Replace StopMusic() with startFadeOut() call |
| activateAddon guard | +3 | cancelFade() on re-entry |
| MuteSoundFile suppressor | ~25 | ORGRIMMAR_MUTE_IDS, applyMutes, removeMutes |
| ADDON_LOADED/PLAYER_LOGIN changes | +5 | Default for muteOrgrimmar, applyMutes call |
| Slash command extension | +10 | /fng mute handler |
| **Total** | **~95 LOC added** | Bringing total from ~398 to ~493 |

---

## Data Flow Changes

### v1.0: Zone Exit Flow (current)

```
ZONE_CHANGED_NEW_AREA -> not in Nagrand
    -> deactivateAddon()
        -> stopNagrandMusic()
            -> StopMusic()          <-- INSTANT CUT (jarring)
            -> reset state
        -> restore CVar
```

### v1.1: Zone Exit Flow (proposed)

```
ZONE_CHANGED_NEW_AREA -> not in Nagrand
    -> deactivateAddon()
        -> stopNagrandMusic()
            -> isActive = false     <-- state cleared immediately
            -> startFadeOut(2.0)    <-- begins gradual volume reduction
                -> OnUpdate ticks for ~2 seconds
                -> SetCVar("Sound_MusicVolume", decreasing...)
                -> fade complete callback:
                    -> StopMusic()              <-- now silent, no jarring cut
                    -> restore original volume  <-- user's setting back to normal
        -> currentSubzone = nil
        -> savedMusicCVar restore (if needed)
```

### Re-entry During Fade (Edge Case)

```
Fade is running (leaving Nagrand)...
    Player re-enters Nagrand (turned around at border)
        -> ZONE_CHANGED_NEW_AREA -> in Nagrand
            -> activateAddon()
                -> cancelFade()        <-- immediately restores volume
                -> playNagrandMusic()  <-- starts new track at full volume
```

### MuteSoundFile Flow (Feature 3)

```
PLAYER_LOGIN (every session)
    -> if FixNagrandMusicDB.muteOrgrimmar then
        -> applyMutes()  -- calls MuteSoundFile(id) for each drum track
    -> end

/fng mute (user toggle)
    -> flip FixNagrandMusicDB.muteOrgrimmar
    -> if enabled: applyMutes()
    -> if disabled: removeMutes()

Client restart
    -> mutes auto-clear (MuteSoundFile does not persist across restarts)
    -> PLAYER_LOGIN re-applies them
```

---

## Patterns to Follow

### Pattern: OnUpdate Frame for Time-Based Effects

**What:** Use a dedicated invisible frame with OnUpdate script for per-frame volume interpolation.
**Why this pattern:** WoW has no built-in volume fade API. OnUpdate gives frame-accurate timing. The dedicated frame ensures we can cleanly enable/disable the handler without affecting the main event frame.
**Why NOT C_Timer.NewTicker:** A ticker at 0.05s (20Hz) would produce audible stepping in volume changes. OnUpdate runs at display frame rate (60+ Hz), giving smoother interpolation.

```lua
-- Dedicated frame, separate from the event handler frame
local fadeFrame = CreateFrame("Frame")
-- OnUpdate is nil by default -- zero overhead when not fading
-- Set OnUpdate only during active fade, clear when done
```

**Confidence:** HIGH -- This is the standard WoW addon pattern for per-frame updates. The AI VoiceOver addon uses exactly this approach for music volume sliding.

### Pattern: State Guard for Async Operations

**What:** Clear `isActive` immediately when deactivation starts, before the async fade begins.
**Why:** Prevents zone change events from re-triggering playback logic during the fade window. All guards in the codebase check `isActive` first.

```lua
local function stopNagrandMusic()
    if not isActive then return end
    isActive = false          -- guard first
    currentTrackID = nil      -- clear track
    lastTimeOfDay = nil
    startFadeOut(2.0, function()
        StopMusic()
        restoreVolume()
    end)
end
```

### Pattern: Cancellable Fade

**What:** Any fade in progress can be cancelled instantly, restoring original volume.
**Why:** Player might re-enter Nagrand during fade, or toggle addon during fade.

---

## Anti-Patterns to Avoid

### Anti-Pattern: Fading with C_Timer.After Chain

**What someone might do:** Use sequential `C_Timer.After` calls to step volume down.

```lua
-- BAD: Audible stepping, timing drift, hard to cancel
C_Timer.After(0.2, function() SetCVar("Sound_MusicVolume", "0.8") end)
C_Timer.After(0.4, function() SetCVar("Sound_MusicVolume", "0.6") end)
-- etc.
```

**Why wrong:** Produces audible volume steps. Cannot be cancelled mid-sequence. Timing drifts accumulate. 5 steps = 5 closure allocations.
**Do instead:** OnUpdate with linear interpolation using `elapsed` delta.

### Anti-Pattern: Not Restoring Volume CVar

**What someone might do:** Fade volume to 0 and forget to restore it.

**Why wrong:** Player's music volume permanently stuck at 0 until they manually fix it in settings. Extremely confusing -- they'll think their game audio is broken.
**Do instead:** Always save volume before fade starts, always restore in both the completion callback AND the cancel path.

### Anti-Pattern: Modifying OnUpdate on the Event Frame

**What someone might do:** Add OnUpdate to the same frame that handles events.

**Why wrong:** OnUpdate runs every frame even when no fade is active. Must remember to nil it out. Mixing concerns makes bugs harder to trace.
**Do instead:** Use a separate frame for fade. Its OnUpdate is nil when not fading (zero cost).

---

## Build Order (Dependency-Driven)

The three features have these dependencies:

```
Feature 1: Smooth Fade-Out
    depends on: nothing new (uses existing WoW APIs)
    provides: fade system used by Feature 2

Feature 2: Zone Transition Fix
    depends on: Feature 1 (fade system)
    provides: clean zone exit (addresses drum burst)

Feature 3: MuteSoundFile Suppression
    depends on: nothing (independent of Features 1 & 2)
    provides: complementary drum suppression
```

### Recommended Build Order

**Phase 1: Volume Fade System + Hearthstone Fix (Feature 1)**
- Add fade state variables (Section 2)
- Add fadeFrame creation (Section 10)
- Add startFadeOut, fadeOnUpdate, cancelFade functions (new Section 6b)
- Modify stopNagrandMusic() to use fade
- Add cancelFade() guard in activateAddon()
- Estimated: 1 plan, ~55 LOC added
- **Test:** Hearthstone out of Nagrand -- should hear smooth 2-second fade instead of abrupt cut

**Phase 2: Zone Transition Fix (Feature 2)**
- Depends on Phase 1 (fade system already in place)
- The fade itself should fix the walking-out drum burst -- the 2-second fade keeps our music audible while destination zone music takes over
- May need to tune fade duration (2s may not be enough, or may be too long)
- If fade alone insufficient, consider adding a small delay before starting the fade on walking exit
- Estimated: 1 plan, ~5-15 LOC (mostly tuning, may be minimal code if Phase 1 already solves it)
- **Test:** Walk out of Nagrand into Terokkar/Zangarmarsh -- should hear smooth transition with no drum burst

**Phase 3: MuteSoundFile Suppression (Feature 3)**
- Independent of Phases 1-2, but built last because:
  - Requires in-game research to identify the correct FileDataIDs to mute
  - Is an optional setting, not a required fix
  - Phases 1-2 may fully solve the transition issues, making this lower priority
- Add ORGRIMMAR_MUTE_IDS data (Section 1)
- Add applyMutes/removeMutes functions
- Add muteOrgrimmar default in ADDON_LOADED
- Add applyMutes call in PLAYER_LOGIN
- Add /fng mute slash command
- Estimated: 1 plan, ~35 LOC
- **Test:** Enable mute, walk through Nagrand without addon music active, verify drums never play

### Phase Ordering Rationale

1. **Fade system first** because it is a prerequisite for the zone transition fix and delivers immediate value (hearthstone fix).
2. **Zone transition fix second** because it may be "free" -- the fade system from Phase 1 likely solves it. This phase is primarily testing and tuning, with minimal new code.
3. **MuteSoundFile last** because it is independent, optional, requires in-game research for the correct FileDataIDs, and may be unnecessary if Phases 1-2 fully resolve the issues.

---

## Key Technical Questions Requiring In-Game Validation

| Question | Feature | Why It Matters | How to Test |
|----------|---------|---------------|-------------|
| Does SetCVar("Sound_MusicVolume") affect PlayMusic output in real time? | 1 | Fade system depends on this | `/run SetCVar("Sound_MusicVolume", "0.1")` while music plays |
| Is 2 seconds enough fade time to mask the zone transition? | 2 | Too short = drums audible; too long = Nagrand music lingers | Walk out of Nagrand, listen for drums during fade |
| Does MuteSoundFile work on zone music tracks in TBC Classic 2.5.5? | 3 | Core mechanism for Feature 3 | `/run MuteSoundFile(53198)` then enter Orgrimmar |
| What FileDataIDs are the actual bugged drums? | 3 | Must mute the correct files | Enter Nagrand without addon, use sound sniffer to identify |
| Does MuteSoundFile(id) persist through zone changes within a session? | 3 | Must not need re-application on every zone change | Mute, change zones, check if still muted |

---

## Sources

- [MuteSoundFile API (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/API_MuteSoundFile) -- HIGH confidence (added in 2.5.1, confirmed for BCC Anniversary 2.5.5)
- [UnmuteSoundFile API (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/API_UnmuteSoundFile) -- HIGH confidence (same availability)
- [StopMusic API (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/API_StopMusic) -- HIGH confidence (stops immediately post-2.2, no fade)
- [C_Timer.After (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/API_C_Timer.After) -- HIGH confidence (available in 2.5.5)
- [C_Timer.NewTicker (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/API_C_Timer.NewTicker) -- HIGH confidence (available in 2.5.5)
- [AI VoiceOver volume fade implementation (GitHub)](https://github.com/mrthinger/wow-voiceover/blob/master/AI_VoiceOver/Compatibility.lua) -- MEDIUM confidence (reference implementation using OnUpdate + SetCVar for music volume sliding)
- [Mute zone music gist (GitHub)](https://gist.github.com/robnadin/62ba9fcb3e6f5ea4ae6b009eaa53e2d3) -- MEDIUM confidence (confirms MuteSoundFile works on zone music in retail)
- [Orgrimmar Zone Music Day (Wowhead TBC)](https://www.wowhead.com/tbc/sound=2902/zone-music-day-orgrimmar-city) -- HIGH confidence (FileDataID 53197)
- [Zone-Orgrimmar (Wowhead TBC)](https://www.wowhead.com/tbc/sound=2901/zone-orgrimmar) -- HIGH confidence (FileDataIDs 53198, 53200)
- [MuteSoundFile addon (CurseForge)](https://www.curseforge.com/wow/addons/mutesoundfile) -- MEDIUM confidence (production addon using MuteSoundFile API, supports TBC Classic)
- [OnUpdate handler (WoWWiki)](https://wowwiki-archive.fandom.com/wiki/Using_OnUpdate_correctly) -- HIGH confidence (standard pattern)
- [Sound_MusicVolume CVar range](https://addonstudio.org/wiki/WoW:Console_variables) -- MEDIUM confidence (0.0 to 1.0, step 0.1)

---
*Architecture research for: FixNagrandMusic v1.1 Smooth Transitions*
*Researched: 2026-02-19*
