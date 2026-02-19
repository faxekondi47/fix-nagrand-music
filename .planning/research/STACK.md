# Technology Stack: Smooth Music Transitions & Suppression

**Project:** FixNagrandMusic v2.0 -- Smooth Transitions Milestone
**Researched:** 2026-02-19
**Confidence:** HIGH for API availability; MEDIUM for optimal fade tuning (needs in-game testing)

**Scope:** New APIs and patterns for v2.0 features only. Does NOT re-research v1.0 validated capabilities (PlayMusic, StopMusic, zone detection, C_Timer.After, SavedVariablesPerCharacter, etc.).

---

## Recommended Stack

No new dependencies. All required APIs are available in the existing TBC Classic Anniversary (2.5.5, Interface 20505) environment.

### New APIs Required

| API | Signature | Purpose | BC Anniversary? | Confidence |
|-----|-----------|---------|-----------------|------------|
| `MuteSoundFile` | `MuteSoundFile(sound)` | Mute specific Orgrimmar drum FileDataIDs | YES (2.5.5 badge) | HIGH |
| `UnmuteSoundFile` | `UnmuteSoundFile(sound)` | Reverse muting when feature toggled off | YES (2.5.5 badge) | HIGH |
| `C_Timer.NewTicker` | `ticker = C_Timer.NewTicker(seconds, callback [, iterations])` | Repeating timer for fade-out animation | YES (2.5.5 badge) | HIGH |
| `SetCVar("Sound_MusicVolume", v)` | `SetCVar(name, value)` | Ramp volume down for fade-out | YES (all versions) | HIGH |
| `GetCVar("Sound_MusicVolume")` | `value = GetCVar(name)` | Read current volume to save/restore | YES (all versions) | HIGH |

### APIs Already in Use (No Changes Needed)

| API | Current v1.0 Usage | v2.0 Change |
|-----|-------------------|-------------|
| `StopMusic()` | Called immediately on zone exit | Called at END of fade (delayed) |
| `PlayMusic(fileDataID)` | Playing Nagrand tracks | No change |
| `C_Timer.After(seconds, callback)` | Deferred zone checks, day/night timer | No change |
| `GetCVar("Sound_EnableMusic")` | Check if music is enabled | No change |

---

## API Details

### 1. MuteSoundFile / UnmuteSoundFile

**Confirmed available in BC Anniversary (2.5.5)** via warcraft.wiki.gg version badges showing: Midnight (12.0.1), MoP Classic (5.5.3), BC Anniversary (2.5.5), Classic Era (1.15.8).

```lua
MuteSoundFile(sound)    -- sound: number|string (FileDataID or addon file path)
UnmuteSoundFile(sound)  -- sound: number|string (FileDataID or addon file path)
-- No return values.
```

**Behavior:**
- Mutes/unmutes a specific sound file by FileDataID. The muted file produces no audio when the game attempts to play it.
- Persists through `/reload` and relogging. Does NOT persist through full client restart.
- Must re-mute on every `PLAYER_LOGIN` (not `PLAYER_ENTERING_WORLD` -- login only, not reload).
- Works on all internal game sounds, addon sounds, and sounds played by PlaySoundFile().
- Added in Patch 8.2.0 (retail), backported to Classic in 2.5.1 / 1.14.0.

**Orgrimmar drum FileDataIDs to mute:**

| FileDataID | File Path | Sound Kit |
|------------|-----------|-----------|
| 53198 | Sound\Music\CityMusic\Orgrimmar\orgrimmar01-zone.mp3 | Zone-Orgrimmar (ID 2901) |
| 53200 | Sound\Music\CityMusic\Orgrimmar\orgrimmar02-zone.mp3 | Zone-Orgrimmar (ID 2901) |
| 53197 | Sound\Music\CityMusic\Orgrimmar\orgrimmar01-moment.mp3 | Zone Music Day Orgrimmar City (ID 2902) |

**Critical notes:**
- MuteSoundFile targets individual FileDataIDs, not sound kit IDs. Each file in a sound kit must be muted separately.
- Muting is global -- it affects the files everywhere, not just in Nagrand. If the user enables this and visits actual Orgrimmar, those tracks will be silent there too. This trade-off must be communicated in the UI text.
- The three FileDataIDs above are from Wowhead's TBC sound database. The actual bugged tracks heard in Nagrand may come from different or additional FileDataIDs. Must validate in-game.

**Sources:**
- [warcraft.wiki.gg: MuteSoundFile](https://warcraft.wiki.gg/wiki/API_MuteSoundFile) -- HIGH confidence, BC Anniversary 2.5.5 badge confirmed
- [warcraft.wiki.gg: UnmuteSoundFile](https://warcraft.wiki.gg/wiki/API_UnmuteSoundFile) -- HIGH confidence, BC Anniversary 2.5.5 badge confirmed
- [Wowhead TBC: Zone-Orgrimmar (Sound 2901)](https://www.wowhead.com/tbc/sound=2901/zone-orgrimmar) -- HIGH confidence, FileDataIDs 53198, 53200
- [Wowhead TBC: Zone Music Day Orgrimmar City (Sound 2902)](https://www.wowhead.com/tbc/sound=2902/zone-music-day-orgrimmar-city) -- HIGH confidence, FileDataID 53197

### 2. StopMusic() -- Confirmed: No Fade Capability

```lua
StopMusic()  -- No parameters. No return value. Immediate stop since Patch 2.2.
```

- Before Patch 2.2: faded music out gradually.
- After Patch 2.2 (all current versions): stops immediately, no fade.
- No fade parameter exists. No way to make StopMusic fade.
- Smooth fade-out must be implemented via Sound_MusicVolume CVar ramping.

**Source:** [warcraft.wiki.gg: StopMusic](https://warcraft.wiki.gg/wiki/API_StopMusic) -- HIGH confidence

### 3. Sound_MusicVolume CVar

```lua
local volume = GetCVar("Sound_MusicVolume")  -- Returns string, e.g. "0.4"
SetCVar("Sound_MusicVolume", 0.3)            -- Accepts number or string
```

| Property | Value |
|----------|-------|
| Type | number (float) |
| Range | 0.0 to 1.0 |
| Default | 0.4 |
| Pretty name | MUSIC_VOLUME |
| Scope | Account-level, persisted in Config.wtf |

- Affects the entire Music channel: both PlayMusic() tracks AND built-in zone music.
- Changes take effect immediately (no engine interpolation).
- Addon MUST save the original value before fading and restore it after StopMusic().

**Related CVars (do NOT use for fade):**

| CVar | Type | Why Not |
|------|------|---------|
| `Sound_EnableMusic` | boolean | Binary on/off, not a volume ramp. Already used in v1.0 for CVar safety. |
| `Sound_ZoneMusicNoDelay` | boolean | Controls silence interval between zone music tracks ("Enable Music Looping"). Not volume-related. |
| `Sound_MasterVolume` | number | Affects ALL audio channels. Never touch this. |

**Source:** [GitHub: AdvancedInterfaceOptions cvars.lua](https://github.com/Stanzilla/AdvancedInterfaceOptions/blob/master/cvars.lua) -- HIGH confidence

### 4. C_Timer.NewTicker

**Confirmed available in BC Anniversary (2.5.5)** via warcraft.wiki.gg version badges.

```lua
local ticker = C_Timer.NewTicker(seconds, callback [, iterations])
-- seconds:    number  -- interval between ticks
-- callback:   function(ticker) -- receives ticker handle as argument
-- iterations: number (optional) -- omit for indefinite

ticker:Cancel()       -- Stops the ticker
ticker:IsCancelled()  -- Returns boolean
```

**Key behavior:**
- Timing accuracy is limited to frame rate (~16ms at 60 FPS).
- Errors in the callback do NOT halt the ticker.
- The optional `iterations` parameter provides automatic stop after N ticks.

**Source:** [warcraft.wiki.gg: C_Timer.NewTicker](https://warcraft.wiki.gg/wiki/API_C_Timer.NewTicker) -- HIGH confidence, BC Anniversary 2.5.5 badge confirmed

### 5. Frame OnUpdate (Alternative Timer)

```lua
frame:SetScript("OnUpdate", function(self, elapsed)
    -- elapsed = seconds since last frame
end)
frame:SetScript("OnUpdate", nil)  -- stop
```

Available in all WoW versions. Fires every frame. Most granular timing available.

**Source:** [WoWWiki: Using OnUpdate correctly](https://wowwiki-archive.fandom.com/wiki/Using_OnUpdate_correctly) -- MEDIUM confidence

---

## Timer Comparison for Fade Implementation

| Feature | C_Timer.NewTicker | Frame OnUpdate | C_Timer.After chain |
|---------|-------------------|----------------|---------------------|
| Repeating calls | Built-in | Manual | Manual recursion |
| Cancelable | `:Cancel()` method | `SetScript(nil)` | No handle |
| Fixed iterations | 3rd parameter | Manual counter | Manual counter |
| Timing resolution | ~1 frame | Every frame | ~1 frame |
| Frame-synced | No (timer-based) | Yes (guaranteed per-frame) | No |
| Lifecycle management | Good (handle + Cancel) | Manual (Hide/Show) | Poor (no handle) |
| Existing v1.0 usage | None | None | Yes (day/night, events) |
| CPU when idle | Zero (inactive) | Zero if frame Hidden | Zero (inactive) |

**Verdict: Use OnUpdate for fade-out.** For a 1.5-second volume ramp, OnUpdate provides the smoothest interpolation because it fires every frame and receives the exact `elapsed` delta for frame-rate-independent animation. The frame is Hidden when not fading, so there is zero CPU cost at idle. Use `C_Timer.NewTicker` if frame-synced smoothness proves unnecessary after testing (unlikely for a volume ramp, but the pattern is simpler).

Both approaches are valid. The choice depends on whether smoothness or simplicity is prioritized:
- **OnUpdate:** Smoothest fade, proven pattern in production addons (wow-voiceover uses this).
- **NewTicker:** Simpler lifecycle (`:Cancel()`, iteration count), slightly stepped volume at low FPS.

---

## Implementation Patterns

### Pattern A: OnUpdate-Based Volume Fade (Recommended)

```lua
local fadeFrame = CreateFrame("Frame")
local fadeState = nil  -- nil when not fading

fadeFrame:SetScript("OnUpdate", function(self, elapsed)
    if not fadeState then
        self:Hide()
        return
    end

    local s = fadeState
    s.elapsed = s.elapsed + elapsed

    -- Linear interpolation from startVolume to 0
    local progress = s.elapsed / s.duration
    if progress >= 1 then
        progress = 1
    end
    local volume = s.startVolume * (1 - progress)
    SetCVar("Sound_MusicVolume", volume)

    if progress >= 1 then
        -- Fade complete
        fadeState = nil
        self:Hide()
        StopMusic()
        SetCVar("Sound_MusicVolume", s.startVolume)
        if s.onComplete then s.onComplete() end
    end
end)
fadeFrame:Hide()  -- Zero CPU cost when idle

local function startFadeOut(duration, onComplete)
    -- Cancel any in-progress fade
    if fadeState then
        SetCVar("Sound_MusicVolume", fadeState.startVolume)
        fadeState = nil
    end

    fadeState = {
        startVolume = tonumber(GetCVar("Sound_MusicVolume")) or 0.4,
        duration = duration,
        elapsed = 0,
        onComplete = onComplete,
    }
    fadeFrame:Show()
end

local function cancelFade()
    if fadeState then
        SetCVar("Sound_MusicVolume", fadeState.startVolume)
        fadeState = nil
        fadeFrame:Hide()
    end
end
```

**Key design points:**
- Frame is Hidden when not fading (zero CPU cost at idle).
- Uses `elapsed` for frame-rate-independent interpolation.
- Restores original volume AFTER calling StopMusic().
- `cancelFade()` restores volume immediately -- essential for re-entering Nagrand mid-fade.

### Pattern B: NewTicker-Based Volume Fade (Alternative)

```lua
local fadeTicker = nil
local savedFadeVolume = nil

local function startFadeOut(duration, onComplete)
    if fadeTicker and not fadeTicker:IsCancelled() then
        fadeTicker:Cancel()
        if savedFadeVolume then
            SetCVar("Sound_MusicVolume", savedFadeVolume)
        end
    end

    savedFadeVolume = tonumber(GetCVar("Sound_MusicVolume")) or 0.4
    local steps = 20
    local interval = duration / steps
    local stepCount = 0

    fadeTicker = C_Timer.NewTicker(interval, function(self)
        stepCount = stepCount + 1
        local volume = savedFadeVolume * (1 - (stepCount / steps))
        if volume < 0.001 then volume = 0 end
        SetCVar("Sound_MusicVolume", volume)

        if stepCount >= steps then
            self:Cancel()
            StopMusic()
            SetCVar("Sound_MusicVolume", savedFadeVolume)
            savedFadeVolume = nil
            if onComplete then onComplete() end
        end
    end, steps)
end

local function cancelFade()
    if fadeTicker and not fadeTicker:IsCancelled() then
        fadeTicker:Cancel()
    end
    if savedFadeVolume then
        SetCVar("Sound_MusicVolume", savedFadeVolume)
        savedFadeVolume = nil
    end
end
```

### Pattern C: MuteSoundFile Orgrimmar Suppression

```lua
local ORGRIMMAR_TRACKS = { 53197, 53198, 53200 }

local function muteOrgrimmarMusic()
    for _, id in ipairs(ORGRIMMAR_TRACKS) do
        MuteSoundFile(id)
    end
end

local function unmuteOrgrimmarMusic()
    for _, id in ipairs(ORGRIMMAR_TRACKS) do
        UnmuteSoundFile(id)
    end
end

-- Call on PLAYER_LOGIN (not PLAYER_ENTERING_WORLD):
-- Mutes persist through /reload but NOT through client restart.
-- PLAYER_LOGIN fires only on fresh login, not on /reload.
```

---

## Integration with Existing v1.0 Code

### Current deactivateAddon() (FixNagrandMusic.lua lines 234-243):

```lua
local function deactivateAddon()
    if not isActive then return end
    StopMusic()
    currentTrackID = nil
    isActive = false
    lastTimeOfDay = nil
end
```

### Proposed v2.0 deactivateAddon():

```lua
local function deactivateAddon(instant)
    if not isActive then return end

    if instant or not FixNagrandMusicDB.fadeOut then
        -- Immediate stop (v1.0 behavior, used on logout/reload)
        cancelFade()  -- cancel any in-progress fade
        StopMusic()
        currentTrackID = nil
        isActive = false
        lastTimeOfDay = nil
    else
        -- Smooth fade-out (v2.0)
        isActive = false  -- Prevent re-activation during fade
        startFadeOut(1.5, function()
            currentTrackID = nil
            lastTimeOfDay = nil
        end)
    end
end
```

### Event handler changes:

| Event | Current Behavior | v2.0 Behavior |
|-------|-----------------|---------------|
| `ZONE_CHANGED_NEW_AREA` (leaving Nagrand) | `deactivateAddon()` | `deactivateAddon(false)` -- smooth fade |
| `PLAYER_LOGOUT` | `deactivateAddon()` | `deactivateAddon(true)` -- instant, no time for fade |
| `PLAYER_ENTERING_WORLD` (not in Nagrand) | `deactivateAddon()` | `deactivateAddon(true)` -- instant after loading screen |
| Re-enter Nagrand during fade | N/A | `cancelFade()` then `activateAddon()` |
| `PLAYER_LOGIN` | N/A | Apply MuteSoundFile if muteOrgrimmar setting enabled |

### New SavedVariables fields:

```lua
-- In ADDON_LOADED handler, add defaults:
if FixNagrandMusicDB.fadeOut == nil then
    FixNagrandMusicDB.fadeOut = true       -- Enable fade-out (default: on)
end
if FixNagrandMusicDB.muteOrgrimmar == nil then
    FixNagrandMusicDB.muteOrgrimmar = false  -- Mute Orgrimmar music (default: off)
end
```

### Fade-out recommended parameters:

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Duration | 1.5 seconds | Long enough to perceive, short enough to not delay transition |
| Volume curve | Linear | Simplest; logarithmic sounds more natural but adds complexity for marginal gain |
| Steps (NewTicker) | 20 | 75ms per step = smooth enough for volume ramp |

---

## Feature-to-API Mapping

| Feature | Primary API | Fallback | Notes |
|---------|-------------|----------|-------|
| Smooth fade-out on zone exit | `SetCVar("Sound_MusicVolume")` + OnUpdate | Same + `C_Timer.NewTicker` | Ramp volume to 0, then StopMusic, then restore |
| Zone exit Orgrimmar burst fix | Fade-out delays StopMusic (music stays active during fade) | `MuteSoundFile()` on Orgrimmar tracks | During fade, PlayMusic track blocks zone music from reasserting |
| Optional Orgrimmar suppression | `MuteSoundFile(fileDataID)` | None needed | Opt-in feature, default off |
| Hearthstone exit smoothing | Same fade-out mechanism | `deactivateAddon(true)` on PLAYER_ENTERING_WORLD | Loading screen kills music; fade only helps for walk/fly exits |

**Note on hearthstone:** When hearthing out of Nagrand, a loading screen occurs. PlayMusic audio stops during loading screens. The fade-out will not be audible if the loading screen appears before the fade completes. For hearthstone exits, the `PLAYER_ENTERING_WORLD` handler should call `deactivateAddon(true)` (instant) since the music is already gone. The smooth fade only benefits walk/fly zone exits where there is no loading screen.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Fade timing | OnUpdate with elapsed | C_Timer.NewTicker (20 steps) | OnUpdate is smoother (frame-synced). Both work; OnUpdate is the proven pattern for audio fade in production WoW addons. |
| Fade timing | OnUpdate with elapsed | C_Timer.After chain | No cancel handle, recursive pattern, harder to reason about. |
| Volume control | `SetCVar("Sound_MusicVolume")` | No alternative exists | Only way to control music volume from addon code. No FadeMusic() API. |
| Orgrimmar suppression | `MuteSoundFile(fileDataID)` | PlayMusic silent track bridge | No reliable silent FileDataID exists. MuteSoundFile is the surgical API. |
| Orgrimmar suppression | `MuteSoundFile(fileDataID)` | `SetCVar("Sound_EnableMusic", 0)` | Kills ALL music, not just Orgrimmar. Too aggressive. |
| Alpha animation | N/A -- not applicable | AnimationGroup Alpha | Alpha animations control frame opacity, not audio volume. Cannot animate a CVar. |

## What NOT to Add

| Avoid | Why |
|-------|-----|
| External libraries (Ace3, LibStub) | No new UI or config systems needed. Slash commands are sufficient. |
| Additional .lua files | Addon is a single file (407 LOC). Fade adds ~50-80 LOC. Still well within single-file territory. |
| Custom sound files (silent .ogg) | The fade-to-zero + delayed StopMusic approach does not need a silent audio file. |
| AnimationGroup for fading | WoW AnimationGroups animate widget properties (alpha, position, scale), not CVar values. |
| Sound_MasterVolume manipulation | Affects ALL audio channels, not just music. Never touch this. |

---

## In-Game Validation Required

These must be tested on a live TBC Classic Anniversary client:

| Test | Command | Expected Result | Why It Matters |
|------|---------|-----------------|----------------|
| MuteSoundFile works | `/run MuteSoundFile(53198)` in Orgrimmar | Zone music stops or changes | Confirms API functions in BC Anniversary |
| Correct Orgrimmar FileDataIDs | `/run MuteSoundFile(53198); MuteSoundFile(53200)` in Nagrand | Drum bug stops | Confirms these are the actual bugged tracks |
| UnmuteSoundFile reverses | `/run UnmuteSoundFile(53198)` after muting | Music returns | Confirms reversibility |
| Sound_MusicVolume range | `/run SetCVar("Sound_MusicVolume", 0)` | Music goes silent | Confirms CVar behavior |
| Volume restore after zero | `/run SetCVar("Sound_MusicVolume", 0); C_Timer.After(2, function() SetCVar("Sound_MusicVolume", 0.4) end)` | Music returns after 2s | Confirms restore works |
| CVar fade during PlayMusic | Start addon in Nagrand, then gradually ramp volume | Music fades smoothly | Confirms CVar affects PlayMusic volume |
| NewTicker cancel | `/run local t = C_Timer.NewTicker(1, function() print("tick") end); C_Timer.After(2.5, function() t:Cancel() end)` | Prints "tick" twice, stops | Confirms ticker cancel in BC Anniversary |
| Fade prevents Org burst | Walk out of Nagrand with fade enabled | No Orgrimmar drum burst | Confirms fade-during-exit blocks zone music reassertion |

---

## Sources

### Primary (HIGH confidence -- official wiki with version badges)
- [warcraft.wiki.gg: MuteSoundFile](https://warcraft.wiki.gg/wiki/API_MuteSoundFile) -- Signature, BC Anniversary 2.5.5 badge
- [warcraft.wiki.gg: UnmuteSoundFile](https://warcraft.wiki.gg/wiki/API_UnmuteSoundFile) -- Signature, BC Anniversary 2.5.5 badge
- [warcraft.wiki.gg: StopMusic](https://warcraft.wiki.gg/wiki/API_StopMusic) -- No fade since Patch 2.2
- [warcraft.wiki.gg: C_Timer.NewTicker](https://warcraft.wiki.gg/wiki/API_C_Timer.NewTicker) -- Signature, Cancel, BC Anniversary 2.5.5 badge
- [warcraft.wiki.gg: C_Timer.After](https://warcraft.wiki.gg/wiki/API_C_Timer.After) -- BC Anniversary 2.5.5 badge
- [warcraft.wiki.gg: PlayMusic](https://warcraft.wiki.gg/wiki/API_PlayMusic) -- Zone music fade behavior, looping

### Secondary (HIGH confidence -- verified CVar/FileDataID databases)
- [GitHub: AdvancedInterfaceOptions cvars.lua](https://github.com/Stanzilla/AdvancedInterfaceOptions/blob/master/cvars.lua) -- Sound_MusicVolume: number, range 0-1, default 0.4
- [Wowhead TBC: Zone-Orgrimmar (Sound 2901)](https://www.wowhead.com/tbc/sound=2901/zone-orgrimmar) -- FileDataIDs 53198, 53200
- [Wowhead TBC: Zone Music Day Orgrimmar City (Sound 2902)](https://www.wowhead.com/tbc/sound=2902/zone-music-day-orgrimmar-city) -- FileDataID 53197

### Tertiary (MEDIUM confidence -- community patterns and reference implementations)
- [WoWWiki: Using OnUpdate correctly](https://wowwiki-archive.fandom.com/wiki/Using_OnUpdate_correctly) -- OnUpdate elapsed pattern
- [WoWInterface: OnUpdate efficiency](https://www.wowinterface.com/forums/showthread.php?t=42390) -- Performance guidance
- [Blizzard Forums: Volume adjustment macros](https://us.forums.blizzard.com/en/wow/t/useful-volume-adjustment-macros-for-greater-immersion/1455069) -- SetCVar Sound_MusicVolume usage confirmation
- [CurseForge: MuteSoundFile addon](https://www.curseforge.com/wow/addons/mutesoundfile) -- Reference implementation for MuteSoundFile usage patterns

---
*Stack research for: FixNagrandMusic v2.0 -- smooth transitions, fade-out, and music suppression*
*Researched: 2026-02-19*
