# Phase 1: Core Music Fix - Research

**Researched:** 2026-02-18
**Domain:** WoW TBC Classic Anniversary addon -- zone music override via Lua API
**Confidence:** MEDIUM-HIGH

## Summary

Phase 1 fixes the Nagrand music bug by detecting the player's zone/subzone, suppressing the buggy built-in music, and playing the correct Nagrand tracks using `PlayMusic()` with FileDataIDs. The research found concrete answers to most implementation questions: the 6 Nagrand FileDataIDs (53585-53590) are confirmed via Wowhead's TBC sound database, the WoW API surface is well-documented and available in TBC Classic Anniversary (2.5.5), and the bug's root cause is strongly suggested to be a zone music priority issue where Halaa/ogre drum music overrides the general Nagrand tracks across the entire zone.

Day/night detection is implemented via `GetGameTime()` returning server hours (0-23). WoW's music system uses separate day and night sound entries in ZoneMusic.dbc, with 3 day tracks (FileDataIDs 53585-53587) and 3 night tracks (53588-53590). The exact day/night breakpoint hours are not definitively documented in any official source, but community convention and the Soundtrack addon pattern use `GetGameTime()` with addon-defined cutoffs. A reasonable approach is 6:00-17:59 for day and 18:00-5:59 for night, matching common WoW addon conventions and the approximate sunrise/sunset times (5:30 AM / 9:00 PM reported by community sources).

The biggest implementation risk is the "dual music layering" problem -- whether the buggy drum music re-asserts itself over `PlayMusic()` after subzone transitions. Three mitigation strategies are available: (1) re-call `PlayMusic()` on every zone event, (2) use `SetCVar("Sound_EnableMusic", 0)` to kill built-in music, (3) use `MuteSoundFile()` to silence the specific drum FileDataIDs. All three approaches use APIs confirmed available in TBC Classic Anniversary. The correct strategy can only be determined by in-game testing.

**Primary recommendation:** Build a single-file addon (FixNagrandMusic.lua + .toc) using event-driven architecture, `PlayMusic()` with FileDataIDs for playback, random track rotation matching Blizzard's native behavior, and `GetGameTime()` for day/night detection. Validate FileDataIDs and PlayMusic suppression behavior in-game before writing production code.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Track-to-subzone mapping
- Claude researches Blizzard's original intended music for each Nagrand subzone and maps tracks accordingly
- If adjacent subzones share the same track, don't restart it -- let it keep playing uninterrupted
- Unnamed open areas (no subzone text) handled at Claude's discretion based on original Blizzard behavior
- Track rotation vs fixed assignment: Claude decides based on how Blizzard's music system normally works
- No user-specific subzone vibes needed -- "just make it correct Nagrand music"

#### Music transitions
- Transition behavior between subzones: match how Blizzard's built-in zone music system works natively
- Indoor/outdoor behavior: match Blizzard's original intent for how zone music handles buildings
- Subzone border flickering (debounce): match Blizzard's native behavior -- Claude researches if this is a real problem and handles accordingly
- Key rule: if same track plays in adjacent subzones, do NOT restart it -- seamless continuation

#### Day/night variants
- Phase 1 WILL detect game time and play matching day/night variants (user explicitly wants this)
- Music switches when day turns to night even while standing still -- responsive to time changes
- Dawn/dusk breakpoints: match WoW's built-in day/night cycle definitions exactly
- If the 6 FileDataIDs don't cleanly split into day/night, Claude decides whether to force the distinction or play all tracks regardless

#### Entry experience
- Entry timing: match how music would naturally start if the Nagrand bug didn't exist
- Loading screen recovery: match normal zone behavior -- Claude picks the most reliable approach
- Exit cleanup: Claude decides the most reliable cleanup approach based on API behavior
- Error handling: if the addon can't determine the correct track, show a visible error message in player chat

### Claude's Discretion

- Exact subzone-to-track mapping (research Blizzard's original data)
- Track distribution strategy across 35+ subzones
- Whether to rotate tracks or use fixed assignments per subzone
- Debounce/timing for subzone border transitions
- Indoor music handling approach
- Exit cleanup method (StopMusic, CVar restore, etc.)
- Fallback behavior for unnamed areas
- Whether FileDataIDs support day/night split

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MFIX-01 | Addon detects when player enters Nagrand using locale-safe method (numeric map ID or zone text) | `C_Map.GetBestMapForUnit("player")` returns UiMapID for Nagrand (needs in-game validation for exact ID -- 107 in retail UiMap system). Fallback: `GetZoneText() == "Nagrand"` (proper noun, likely same across locales). Both APIs confirmed available in TBC Anniversary 2.5.5. |
| MFIX-02 | Addon detects player's current subzone within Nagrand via GetSubZoneText() | `GetSubZoneText()` returns localized subzone name or "" for open areas. Fires alongside `ZONE_CHANGED` event. 37 subzones documented. No subzone-level map IDs available -- must use string comparison for subzone detection. |
| MFIX-03 | Correct Nagrand music track plays for each subzone (day/night variants using FileDataIDs 53585-53590) | FileDataIDs confirmed via Wowhead TBC sound database: Day tracks (Sound ID 9012): 53585, 53586, 53587. Night tracks (Sound ID 9013): 53588, 53589, 53590. Intro track (Sound ID 10623): 53584. Clean 3-day/3-night split confirmed. `PlayMusic(fileDataID)` loops until StopMusic(). Blizzard's native system rotates randomly with silence intervals. |
| MFIX-04 | Buggy Orgrimmar drum music is suppressed while in Nagrand (PlayMusic auto-fade or CVar fallback) | `PlayMusic()` auto-fades built-in zone music. If drums persist: Strategy B uses `SetCVar("Sound_EnableMusic", 0/1)` toggle. Strategy C uses `MuteSoundFile()` to silence specific drum FileDataIDs. All APIs confirmed available in TBC Anniversary. |
| MFIX-05 | Music transitions smoothly between Nagrand subzones (no silence gaps or drum bursts) | Research finding: all Nagrand subzones use the same ZoneMusic entry (Zone-NagrandDay/Night). No subzone-specific overrides in original Blizzard data. Therefore: do NOT restart music on subzone transitions -- let it keep playing. Only change track on day/night switch. Calling `PlayMusic(newTrack)` directly replaces current track without needing StopMusic first. |
| MFIX-06 | Addon does nothing outside Nagrand (zero interference with other zones) | Gate all logic behind zone check. Call `StopMusic()` + restore CVar on zone exit. `StopMusic()` only stops addon-played music, built-in zone music resumes naturally for other zones. |
| MFIX-07 | Music restarts correctly after loading screens via PLAYER_ENTERING_WORLD handler | `PLAYER_ENTERING_WORLD` fires on login, reload, and instance transitions. Use `C_Timer.After(0, callback)` one-frame delay to ensure zone data is current, then re-check zone and restart music. Args: `isInitialLogin`, `isReloadingUi`. |
| MFIX-08 | Addon cleans up on zone exit, logout, and disconnect (StopMusic, restore CVar if modified) | `PLAYER_LOGOUT` fires before SavedVariables save. `ZONE_CHANGED_NEW_AREA` fires on zone exit. Call `StopMusic()` in both. If CVar was modified, restore original value from saved state. |
| MFIX-09 | Empty subzone areas (open grassland with no subzone name) play default Nagrand general tracks | `GetSubZoneText()` returns "" for open areas. Since all subzones map to the same Nagrand general tracks, the empty subzone case is handled identically -- keep playing current track. |
| PKG-01 | Correct .toc file with Interface 20505, addon metadata, and SavedVariables declaration | Interface version 20505 for TBC Classic Anniversary (2.5.5). TOC file name must match addon folder name. `@project-version@` token replaced by BigWigsMods packager. SavedVariables declaration needed even in Phase 1 for future compatibility. |

</phase_requirements>

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| Lua 5.1 (WoW sandbox) | 5.1 (Blizzard custom) | Addon scripting | The only option. WoW runs a sandboxed Lua 5.1 with no io/os access. |
| WoW TOC format | Interface 20505 | Addon manifest | Required for client to load the addon. 20505 = TBC Classic Anniversary (2.5.5). |
| `PlayMusic(fileDataID)` | API since 1.0 | Music playback | Plays on Music channel, loops until StopMusic(). Auto-fades built-in zone music. Accepts FileDataID (number). |
| `StopMusic()` | API since 1.0 | Stop addon music | Stops immediately (no fade since patch 2.2). Only stops addon-played music, not built-in. |
| `GetGameTime()` | API since 1.0 | Day/night detection | Returns server hours (0-23) and minutes (0-59). Available in TBC Anniversary. |
| `GetZoneText()` / `GetSubZoneText()` | API since 1.0 | Zone detection | Returns localized zone/subzone names. Available in all WoW versions. |
| `C_Map.GetBestMapForUnit("player")` | API since 8.0.1 / backported to 2.5.x | Locale-safe zone detection | Returns numeric UiMapID. Confirmed available in TBC Anniversary 2.5.5. |
| `ZONE_CHANGED` / `ZONE_CHANGED_NEW_AREA` / `PLAYER_ENTERING_WORLD` | Events since 1.0 | State change detection | Core events for zone transitions, loading screens, login. No payload on ZONE_CHANGED. |
| `C_Timer.After(seconds, callback)` | API since 6.0.2 / backported to 2.5.x | Delayed callbacks | For one-frame delay after loading screens. More efficient than OnUpdate. |

### Supporting

| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| `SetCVar("Sound_EnableMusic", 0/1)` | API since 1.0 | Built-in music suppression | Fallback if PlayMusic auto-fade doesn't reliably suppress the buggy drums. |
| `GetCVar("Sound_EnableMusic")` | API since 1.0 | Read user's music preference | Check before activating -- if user disabled music, addon should do nothing. |
| `MuteSoundFile(fileDataID)` | API since 8.2.0 / 2.5.1 | Mute specific sound files | Alternative suppression: mute the specific drum FileDataIDs. Persists through /reload but not client restart. |
| `UnmuteSoundFile(fileDataID)` | API since 8.2.5 / 2.5.1 | Unmute muted sounds | Cleanup: unmute any muted sounds on addon deactivation. |
| `ZONE_CHANGED_INDOORS` | Event since 2.0.3 | Indoor detection | Fires when entering/leaving indoor areas. Available in TBC Anniversary 2.5.5. |
| `PLAYER_LOGOUT` | Event since 1.0 | Cleanup on logout | Fires before SavedVariables save. Use to restore CVar and stop music. |

### Not Needed

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Ace3 / LibStub | Massive overkill. This addon is ~100-200 lines of Lua. | Raw WoW API |
| XML frame definitions | No UI. The addon is invisible. | `CreateFrame("Frame")` in Lua |
| `C_Timer.NewTicker` for polling | Wasteful. Zone changes are events. | Event-driven: ZONE_CHANGED events |
| Custom .ogg/.mp3 files | The music exists in game data. Bundling it creates size/licensing issues. | FileDataIDs referencing game's own music files |
| LibBabble-SubZone | Overkill for one zone. "Nagrand" is a proper noun, likely unchanged across locales. | `C_Map.GetBestMapForUnit()` for zone, `GetSubZoneText()` for subzone |

## Architecture Patterns

### Recommended Project Structure

```
FixNagrandMusic/
  FixNagrandMusic.toc          -- Addon manifest (Interface 20505, metadata)
  FixNagrandMusic.lua          -- All addon logic in a single file
```

**Rationale:** This addon is small enough (~150-250 lines) for a single file. Multiple files add complexity without benefit. The music data table, zone detection, music controller, and event handler all fit cleanly in one file with clear section comments. The TOC file is the only other required file.

### Pattern 1: Event-Driven Frame Handler

**What:** Standard WoW addon pattern. Hidden frame registers events, dispatches through a table-keyed handler.
**When to use:** Always -- this is the canonical WoW addon architecture.

```lua
-- Source: warcraft.wiki.gg standard pattern
local frame = CreateFrame("Frame")
local handlers = {}

function handlers.ZONE_CHANGED_NEW_AREA()
    -- Major zone change (entering/leaving Nagrand)
end

function handlers.ZONE_CHANGED()
    -- Subzone change within Nagrand
end

function handlers.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    -- Login, reload, instance transition
end

function handlers.PLAYER_LOGOUT()
    -- Cleanup before logout
end

frame:SetScript("OnEvent", function(self, event, ...)
    if handlers[event] then
        handlers[event](...)
    end
end)

for event in pairs(handlers) do
    frame:RegisterEvent(event)
end
```

### Pattern 2: Random Track Rotation (Matching Blizzard's Native Behavior)

**What:** WoW's built-in music system picks a random track from a pool weighted by frequency, plays it, waits a random silence interval, then picks another. The addon should replicate this behavior.
**When to use:** For playing Nagrand music tracks. This matches the native system and fulfills the "feel like the bug never existed" requirement.

```lua
-- Source: wowdev.wiki DB/ZoneMusic structure analysis
local NAGRAND_TRACKS = {
    day = { 53585, 53586, 53587 },   -- NA_GeneralWalkDay01-03
    night = { 53588, 53589, 53590 }, -- NA_GeneralWalkNight01-03
}

local function isDayTime()
    local hours = GetGameTime()
    return hours >= 6 and hours < 18
end

local function getRandomTrack()
    local pool = isDayTime() and NAGRAND_TRACKS.day or NAGRAND_TRACKS.night
    return pool[math.random(#pool)]
end
```

### Pattern 3: State Tracking to Avoid Unnecessary Restarts

**What:** Track what is currently playing and don't restart it unnecessarily. Critical for the "same track plays in adjacent subzones" requirement.
**When to use:** On every zone event, to decide whether to change the track.

```lua
local currentTrackID = nil
local isActive = false

local function playNagrandMusic()
    local newTrack = getRandomTrack()
    if currentTrackID == newTrack then
        return  -- Already playing this track, don't restart
    end
    PlayMusic(newTrack)
    currentTrackID = newTrack
    isActive = true
end

local function stopNagrandMusic()
    if isActive then
        StopMusic()
        currentTrackID = nil
        isActive = false
    end
end
```

### Pattern 4: Day/Night Time Monitoring

**What:** Periodically check game time and switch tracks when day/night transitions occur, even while standing still.
**When to use:** Required by user decision -- music must switch responsively to time changes.

```lua
-- Check every 60 seconds if day/night state has changed
local lastTimeOfDay = nil

local function checkDayNightTransition()
    if not isActive then return end
    local isDay = isDayTime()
    if lastTimeOfDay ~= nil and lastTimeOfDay ~= isDay then
        -- Day/night changed while standing still
        local newTrack = getRandomTrack()
        PlayMusic(newTrack)
        currentTrackID = newTrack
    end
    lastTimeOfDay = isDay
    C_Timer.After(60, checkDayNightTransition)
end
```

### Anti-Patterns to Avoid

- **Calling StopMusic() before PlayMusic() within Nagrand:** Creates a gap where buggy drums can re-assert. Call `PlayMusic(newTrack)` directly -- it replaces the current track.
- **Polling with OnUpdate:** Runs 60+ times/second. Use events for zone changes, C_Timer.After for periodic day/night checks.
- **Restarting music on every ZONE_CHANGED:** Most subzone transitions don't need a track change. Check if the current track is still appropriate before calling PlayMusic again.
- **Hardcoding file paths instead of FileDataIDs:** Fragile across client versions. FileDataIDs are the modern, robust approach.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Zone detection | Custom coordinate checking | `GetZoneText()` + `C_Map.GetBestMapForUnit()` | WoW API handles this exactly. Coordinate-based detection is fragile. |
| Music looping | Manual timer-based re-triggering | `PlayMusic()` which loops automatically | PlayMusic loops natively until StopMusic. No need for custom loop logic. |
| Day/night detection | Complex astronomical calculations | `GetGameTime()` with simple hour threshold | Server time is deterministic. Simple hour comparison is correct. |
| Delayed callbacks | `OnUpdate` frame with elapsed time tracking | `C_Timer.After(seconds, callback)` | C_Timer.After is more efficient and the standard pattern since WoD. |
| Music suppression | Custom sound engine manipulation | `PlayMusic()` auto-fade + `SetCVar` fallback | PlayMusic already fades built-in music. SetCVar is the nuclear option. |

**Key insight:** WoW's API provides exactly the primitives needed. Every "build from scratch" instinct should be replaced with an API call.

## Common Pitfalls

### Pitfall 1: Dual Music Layering (PlayMusic Doesn't Suppress Drums)

**What goes wrong:** PlayMusic plays the correct Nagrand track, but the buggy drum music from the zone system plays simultaneously underneath.
**Why it happens:** WoW's zone music system re-triggers on subzone boundaries. PlayMusic fades it once, but the system can restart it.
**How to avoid:** Three-tier strategy:
1. **Primary:** Call `PlayMusic()` on every ZONE_CHANGED event to re-assert control
2. **Fallback A:** If drums persist, add `SetCVar("Sound_EnableMusic", 0)` before PlayMusic, then re-enable
3. **Fallback B:** Use `MuteSoundFile()` to silence the specific drum FileDataIDs
**Warning signs:** Faint drums under the replacement music; music "fighting" between tracks.
**Confidence:** MEDIUM -- cannot be resolved without in-game testing.

### Pitfall 2: Music Resets on Loading Screens

**What goes wrong:** After a loading screen (dungeon, hearthing, BG), addon music stops. Player returns to Nagrand and hears silence or buggy drums.
**Why it happens:** PlayMusic stops after any loading screen. PLAYER_ENTERING_WORLD fires, but zone APIs may not be updated yet in the same frame.
**How to avoid:** Register `PLAYER_ENTERING_WORLD`. Use `C_Timer.After(0, callback)` to defer zone check by one frame. Then re-check zone and restart music.
**Warning signs:** Silence after hearthing back to Nagrand; "addon stopped working" after dungeons.
**Confidence:** HIGH -- well-documented behavior with known solution.

### Pitfall 3: StopMusic Resumes Buggy Music

**What goes wrong:** Calling StopMusic() during a subzone transition within Nagrand causes the buggy drum music to re-appear briefly before the new PlayMusic call takes effect.
**Why it happens:** StopMusic only stops addon music. After it runs, the game's zone music system resumes (with the buggy drums). Even a single-frame gap is audible.
**How to avoid:** Never call StopMusic within Nagrand unless immediately leaving the zone. For track changes, call PlayMusic(newTrack) directly -- it replaces the current track without an intermediate silence.
**Warning signs:** Brief drum bursts during subzone transitions.
**Confidence:** HIGH -- documented behavior of StopMusic API.

### Pitfall 4: UiMapID Uncertainty

**What goes wrong:** The addon uses the wrong UiMapID for Nagrand, causing it to never detect the zone or to detect the wrong zone.
**Why it happens:** WorldMapAreaID (477) was deprecated in 8.0.1 and replaced by UiMapID. The new UiMapID for Nagrand appears to be 107 based on retail data. But TBC Classic Anniversary's hybrid engine might use either system.
**How to avoid:** Test `C_Map.GetBestMapForUnit("player")` in Nagrand on day one. Use the confirmed value. Implement `GetZoneText() == "Nagrand"` as a parallel fallback.
**Warning signs:** Addon never activates when entering Nagrand.
**Confidence:** MEDIUM -- requires in-game validation.

### Pitfall 5: Not Respecting User's Music Preference

**What goes wrong:** Player has music disabled in WoW settings. Addon re-enables it by modifying the CVar or playing music anyway.
**Why it happens:** Addon doesn't check `GetCVar("Sound_EnableMusic")` before activating.
**How to avoid:** On zone entry, check `GetCVar("Sound_EnableMusic") == "1"` before playing any music. If the player has music disabled, the addon should do nothing (or print a message suggesting they enable music).
**Warning signs:** Music plays for users who intentionally disabled it.
**Confidence:** HIGH -- straightforward check.

## Code Examples

### Complete Music Data Table

```lua
-- Source: Wowhead TBC sound database
-- https://www.wowhead.com/tbc/sound=9012/zone-nagrandday
-- https://www.wowhead.com/tbc/sound=9013/zone-nagrandnight
local NAGRAND_TRACKS = {
    day = {
        53585,  -- Sound\Music\ZoneMusic\Nagrand\NA_GeneralWalkDay01.mp3
        53586,  -- Sound\Music\ZoneMusic\Nagrand\NA_GeneralWalkDay02.mp3
        53587,  -- Sound\Music\ZoneMusic\Nagrand\NA_GeneralWalkDay03.mp3
    },
    night = {
        53588,  -- Sound\Music\ZoneMusic\Nagrand\NA_GeneralWalkNight01.mp3
        53589,  -- Sound\Music\ZoneMusic\Nagrand\NA_GeneralWalkNight02.mp3
        53590,  -- Sound\Music\ZoneMusic\Nagrand\NA_GeneralWalkNight03.mp3
    },
    intro = 53584,  -- Sound\Music\ZoneMusic\Nagrand\NA_DiamondIntroUni01.mp3
}
```

### Zone Detection with Dual-Method Safety

```lua
-- Source: warcraft.wiki.gg API docs
-- Primary: numeric map ID (locale-safe)
-- Fallback: zone text string comparison
local NAGRAND_MAP_ID = 107  -- UiMapID, MUST be validated in-game (could be 477)
local NAGRAND_ZONE_TEXT = "Nagrand"

local function isInNagrand()
    -- Try locale-safe numeric method first
    if C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID == NAGRAND_MAP_ID then
            return true
        end
    end
    -- Fallback to zone text (works because "Nagrand" is a proper noun)
    return GetZoneText() == NAGRAND_ZONE_TEXT
end
```

### Day/Night Detection

```lua
-- Source: warcraft.wiki.gg API_GetGameTime
-- WoW's built-in day/night for music uses ZoneMusic.dbc AMB_DAY/AMB_NIGHT
-- Exact breakpoints are not publicly documented.
-- Research finding: community convention and lighting transitions suggest
-- approximately 6:00 for dawn and 18:00 for dusk.
-- Recommendation: Use 6:00-17:59 = day, 18:00-5:59 = night
local function isDayTime()
    local hours = GetGameTime()
    return hours >= 6 and hours < 18
end
```

### Loading Screen Recovery

```lua
-- Source: warcraft.wiki.gg PLAYER_ENTERING_WORLD
function handlers.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    -- Defer by one frame to ensure zone data is updated
    C_Timer.After(0, function()
        if isInNagrand() then
            playNagrandMusic()
        else
            stopNagrandMusic()
        end
    end)
end
```

### Cleanup on Zone Exit and Logout

```lua
-- Source: warcraft.wiki.gg API_StopMusic, PLAYER_LOGOUT
local savedMusicCVar = nil

local function activateAddon()
    -- Save user's current music setting before any CVar changes
    savedMusicCVar = GetCVar("Sound_EnableMusic")
    -- Only proceed if user has music enabled
    if savedMusicCVar ~= "1" then
        print("|cFFFF6600FixNagrandMusic:|r Music is disabled in your settings. Enable it to hear the fix.")
        return
    end
    playNagrandMusic()
end

local function deactivateAddon()
    stopNagrandMusic()
    -- Restore CVar if we changed it
    if savedMusicCVar and savedMusicCVar ~= GetCVar("Sound_EnableMusic") then
        SetCVar("Sound_EnableMusic", savedMusicCVar)
    end
    savedMusicCVar = nil
end

function handlers.PLAYER_LOGOUT()
    deactivateAddon()
end
```

### Error Handling with Chat Output

```lua
-- Source: user requirement -- visible error messages in chat
local function printError(msg)
    print("|cFFFF0000FixNagrandMusic Error:|r " .. msg)
end

local function printInfo(msg)
    print("|cFF00FF00FixNagrandMusic:|r " .. msg)
end
```

### TOC File

```toc
## Interface: 20505
## Title: FixNagrandMusic
## Notes: Fixes the bug where Orgrimmar drum music plays in Nagrand instead of the correct zone music.
## Author: [author]
## Version: @project-version@
## X-Category: Audio & Video
## SavedVariables: FixNagrandMusicDB

FixNagrandMusic.lua
```

## Research Findings: Discretion Areas

### 1. Subzone-to-Track Mapping (Discretion)

**Finding:** All Nagrand subzones use the SAME ZoneMusic entry in Blizzard's data. The AreaTable.dbc assigns a single ZoneMusic ID to the parent zone (Nagrand, ID 3518), and subzones inherit it unless they have their own override. Research found NO evidence of per-subzone music overrides in Nagrand.

**What this means:**
- Zone-NagrandDay (Sound ID 9012) and Zone-NagrandNight (Sound ID 9013) apply to ALL subzones
- Garadar (Horde town) does NOT have its own music entry in the Nagrand data
- Telaar (Alliance town) does NOT have its own music entry in the Nagrand data
- Halaa does NOT have its own distinct music entry -- but the bug may be related to Halaa's area somehow triggering the wrong music system behavior

**Recommendation:** Play the same Nagrand general tracks everywhere. All 37+ subzones get the same pool of 3 day + 3 night tracks. This matches Blizzard's original data exactly.

**Confidence:** HIGH for the general case. MEDIUM for whether specific subzones like Warmaul Hill or Halaa had separate ZoneMusic entries that are not visible in the available data.

### 2. Track Rotation Strategy (Discretion)

**Finding:** Blizzard's ZoneMusic system uses random track selection with weighted probability (SoundEntries.dbc `Freq` field) and silence intervals between tracks (ZoneMusic.dbc `SilenceIntervalMin`/`SilenceIntervalMax`).

**Recommendation:** Use `math.random(#pool)` to select from the 3 available tracks. Since `PlayMusic()` loops a single track until stopped, do NOT implement silence intervals -- that would require complex timer management. Instead, keep the current track looping until a day/night transition or zone exit occurs. This is simpler and more reliable than trying to replicate the full ZoneMusic.dbc rotation behavior (which would require PlaySoundFile + custom timers for silence gaps + re-triggering).

**Alternative considered:** Using `PlaySoundFile()` to play once, then scheduling another track after a silence interval. Rejected because: (1) doesn't loop automatically, (2) complex timer management, (3) silence gaps could allow buggy drums to re-appear.

**Confidence:** HIGH -- PlayMusic looping is the right tool for this job.

### 3. Debounce for Subzone Border Transitions (Discretion)

**Finding:** Since ALL Nagrand subzones play the same music, subzone border flickering is a non-issue. The addon should NOT restart music on ZONE_CHANGED events within Nagrand. It only needs to react when:
- Entering Nagrand (ZONE_CHANGED_NEW_AREA)
- Leaving Nagrand (ZONE_CHANGED_NEW_AREA)
- After loading screens (PLAYER_ENTERING_WORLD)
- Day/night transitions (periodic GetGameTime check)

**Recommendation:** No debounce needed. Register ZONE_CHANGED for future-proofing (in case subzone-specific music is added later), but the handler should be a no-op unless the track actually needs to change. The `currentTrackID` state variable prevents unnecessary restarts.

**Confidence:** HIGH.

### 4. Indoor Music Handling (Discretion)

**Finding:** ZONE_CHANGED_INDOORS fires when entering/leaving indoor areas. In Nagrand, indoor areas include some buildings in Garadar, Telaar, and caves. Blizzard's original behavior is to continue playing zone music indoors -- there is no separate indoor music for Nagrand subzones.

**Recommendation:** Register ZONE_CHANGED_INDOORS but treat it the same as ZONE_CHANGED -- check if still in Nagrand, keep playing. No special indoor handling needed.

**Confidence:** HIGH.

### 5. Exit Cleanup Method (Discretion)

**Finding:** Two cleanup approaches:
- **StopMusic() only:** Simplest. Stops addon music, lets built-in zone music resume for the new zone. No CVar modification to undo.
- **StopMusic() + CVar restore:** Needed only if the CVar approach was used to suppress drums. Must restore to the user's original setting, not hardcoded "1".

**Recommendation:** Use StopMusic() as the primary cleanup. Only modify and restore CVar if the PlayMusic-only approach fails to suppress drums (determined by in-game testing). Always save the user's original CVar value before modifying it.

For PLAYER_LOGOUT: call StopMusic() and restore CVar. This ensures no music leaks into the character select screen.

**Confidence:** HIGH.

### 6. Whether FileDataIDs Support Day/Night Split (Discretion)

**Finding:** YES, the 6 FileDataIDs cleanly split into day and night:
- **Day (Sound ID 9012):** 53585, 53586, 53587 (NA_GeneralWalkDay01-03)
- **Night (Sound ID 9013):** 53588, 53589, 53590 (NA_GeneralWalkNight01-03)

The naming convention is unambiguous: "Day" vs "Night" (note: the Night files are actually spelled "NA_GeneralWalKnight" in the game data, with "Knight" not "KNight" -- but this is just a file name, irrelevant to playback).

**Recommendation:** Implement the day/night split as designed. 3 day tracks during daytime, 3 night tracks during nighttime.

**Confidence:** HIGH -- confirmed via Wowhead TBC sound database and fondlez/wow-sounds file listings.

### 7. Day/Night Breakpoint Hours (Discretion)

**Finding:** WoW's built-in ZoneMusic.dbc uses `AMB_DAY` (index 0) and `AMB_NIGHT` (index 1) to separate day/night music pools. The exact hour breakpoints where the client switches between these pools are NOT documented in any official source.

Community evidence:
- Sunrise visual effect at approximately 5:30 AM server time
- Sunset visual effect at approximately 9:00 PM (21:00) server time
- The Soundtrack addon community recommends using `GetGameTime()` with self-defined cutoff hours
- No API exists to query the client's internal day/night state for music purposes
- Private server emulators (TrinityCore, AzerothCore) do not expose these breakpoints in publicly documented configuration

**Recommendation:** Use 6:00-17:59 for day, 18:00-5:59 for night. This is conservative (safe side of sunrise/sunset) and matches the most common convention in WoW addon development. The user's requirement is to "match WoW's built-in day/night cycle definitions exactly" -- since the exact definitions are not publicly available, use the closest approximation that community testing supports.

**Confidence:** LOW for "exact match." HIGH for "reasonable approximation." This is flagged as an open question that can only be fully resolved by in-game observation of when the built-in music system switches between day and night pools.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| File path strings in PlayMusic | FileDataIDs (numbers) | Retail 8.2.0 (2019). TBC Anniversary uses modern engine. | Use numbers, not strings. File paths may still work in TBC Anniversary but are deprecated. |
| WorldMapAreaID 477 | UiMapID (107 on retail, needs TBC Anniversary validation) | Retail 8.0.1 (2018). | Must validate which ID system TBC Anniversary uses. |
| Manual OnUpdate throttling | C_Timer.After() | WoD 6.0.2 (2014), backported to Classic | Use C_Timer.After for all delayed callbacks. |
| No MuteSoundFile API | MuteSoundFile(fileDataID) available | Retail 8.2.0, backported to 2.5.1 | New option for selectively muting the buggy drum tracks. |

## Open Questions

1. **Exact Nagrand UiMapID in TBC Anniversary**
   - What we know: WorldMapAreaID was 477. Retail UiMapID is 107. TBC Anniversary uses a modern engine.
   - What's unclear: Which value C_Map.GetBestMapForUnit returns on the TBC Anniversary client.
   - Recommendation: Test in-game with `/run print(C_Map.GetBestMapForUnit("player"))` in Nagrand. Implement both IDs with OR logic until validated. Use GetZoneText as fallback.

2. **Does PlayMusic reliably suppress the buggy drums?**
   - What we know: PlayMusic auto-fades built-in zone music. The drums may be re-triggered by the zone music system on subzone transitions.
   - What's unclear: Whether re-calling PlayMusic on every ZONE_CHANGED event is sufficient, or if the CVar/MuteSoundFile approach is needed.
   - Recommendation: Test in-game on day one. Walk through multiple subzone transitions with PlayMusic active. Listen for drum bleed-through.

3. **Exact day/night breakpoint hours**
   - What we know: AMB_DAY and AMB_NIGHT indices exist in ZoneMusic.dbc. Visual sunrise ~5:30, sunset ~21:00. No API to query internal day/night state.
   - What's unclear: The exact server hour when the client switches between day and night music pools.
   - Recommendation: Use 6/18 as breakpoints. If testing reveals a mismatch with built-in behavior, adjust to 5/21 or other values.

4. **Does the intro music (FileDataID 53584) need to play on first entry?**
   - What we know: Intro-NagrandDiamond (Sound ID 10623, FileDataID 53584) exists. ZoneIntroMusicTable in AreaTable.dbc has a field for intro music.
   - What's unclear: Whether this intro plays once on zone entry and then switches to general zone music, or if it's only triggered by specific Oshu'gun proximity.
   - Recommendation: Skip intro music in Phase 1 for simplicity. Play general zone music immediately on entry. Add intro support later if testing reveals it matters.

5. **Interface version 20505 vs 20504**
   - What we know: TBC Classic Anniversary launched as 2.5.5 with Interface 20505. Earlier TBC Classic was 20504.
   - What's unclear: Whether the current live client still uses 20505 or has incremented.
   - Recommendation: Use 20505. Verify with `/dump (select(4, GetBuildInfo()))` in-game.

## Sources

### Primary (HIGH confidence)
- [warcraft.wiki.gg: API PlayMusic](https://warcraft.wiki.gg/wiki/API_PlayMusic) -- PlayMusic signature, FileDataID support, zone music fade behavior, TBC Anniversary availability
- [warcraft.wiki.gg: API StopMusic](https://warcraft.wiki.gg/wiki/API_StopMusic) -- StopMusic behavior (immediate, addon-only), TBC Anniversary availability
- [warcraft.wiki.gg: API GetGameTime](https://warcraft.wiki.gg/wiki/API_GetGameTime) -- Returns hours/minutes, available since 1.0, TBC Anniversary confirmed
- [warcraft.wiki.gg: API C_Map.GetBestMapForUnit](https://warcraft.wiki.gg/wiki/API_C_Map.GetBestMapForUnit) -- Returns UiMapID, available in TBC Anniversary 2.5.5
- [warcraft.wiki.gg: API MuteSoundFile](https://warcraft.wiki.gg/wiki/API_MuteSoundFile) -- Available in TBC Anniversary 2.5.5, mutes by FileDataID, persists through /reload only
- [warcraft.wiki.gg: API UnmuteSoundFile](https://warcraft.wiki.gg/wiki/API_UnmuteSoundFile) -- Available in TBC Anniversary 2.5.1+
- [warcraft.wiki.gg: ZONE_CHANGED](https://warcraft.wiki.gg/wiki/ZONE_CHANGED) -- No payload, fires on subzone change
- [warcraft.wiki.gg: ZONE_CHANGED_INDOORS](https://warcraft.wiki.gg/wiki/ZONE_CHANGED_INDOORS) -- No payload, fires indoor/outdoor, TBC Anniversary 2.5.5
- [warcraft.wiki.gg: PLAYER_ENTERING_WORLD](https://warcraft.wiki.gg/wiki/PLAYER_ENTERING_WORLD) -- Args: isInitialLogin, isReloadingUi. TBC Anniversary confirmed.
- [warcraft.wiki.gg: PLAYER_LOGOUT](https://warcraft.wiki.gg/wiki/PLAYER_LOGOUT) -- Fires before SavedVariables save, TBC Anniversary confirmed
- [warcraft.wiki.gg: API C_Timer.After](https://warcraft.wiki.gg/wiki/API_C_Timer.After) -- Delay callback, available in TBC Anniversary 2.5.5
- [warcraft.wiki.gg: WorldMapAreaID](https://warcraft.wiki.gg/wiki/WorldMapAreaID) -- Nagrand = 477, deprecated in favor of UiMapID
- [warcraft.wiki.gg: UiMapID](https://warcraft.wiki.gg/wiki/UiMapID) -- Nagrand = 107 (retail). UiMapID replaced WorldMapAreaID.
- [Wowhead TBC: Sound 9012 Zone-NagrandDay](https://www.wowhead.com/tbc/sound=9012/zone-nagrandday) -- FileDataIDs 53585-53587
- [Wowhead TBC: Sound 9013 Zone-NagrandNight](https://www.wowhead.com/tbc/sound=9013/zone-nagrandnight) -- FileDataIDs 53588-53590
- [Wowhead TBC: Sound 10623 Intro-NagrandDiamond](https://www.wowhead.com/tbc/sounds/zone-music) -- FileDataID 53584
- [wowdev.wiki: DB/ZoneMusic](https://wowdev.wiki/DB/ZoneMusic) -- ZoneMusic table structure, AMB_DAY/AMB_NIGHT, SilenceInterval fields
- [wowdev.wiki: DB/SoundEntries](https://wowdev.wiki/DB/SoundEntries) -- SoundEntries structure, Freq weighting, multi-file support
- [wowdev.wiki: DB/AreaTable](https://wowdev.wiki/DB/AreaTable) -- AreaTable structure, ZoneMusic field (column 9), subzone inheritance
- [fondlez/wow-sounds (GitHub)](https://github.com/fondlez/wow-sounds) -- Complete TBC 2.4.3 sound file listings confirming Nagrand music paths

### Secondary (MEDIUM confidence)
- [us.forums.blizzard.com: TBC Nagrand Music Bug](https://us.forums.blizzard.com/en/wow/t/tbc-nagrand-music-bug/993365) -- Bug description: 30s drum loop, briefly correct music, then drums resume. Coordinates 71.8, 37.7 near Zangarmarsh border.
- [eu.forums.blizzard.com: Nagrand music bug pls fix](https://eu.forums.blizzard.com/en/wow/t/nagrand-music-bug-pls-fix-blizzard/606156) -- Bug persists Feb 2026. /console reloadui briefly fixes it. Drums may be tied to Ring of Blood activity.
- [us.forums.blizzard.com: Is Nagrand music busted](https://us.forums.blizzard.com/en/wow/t/is-nagrand-music-busted/2250797) -- Bug still active in TBC Anniversary (2026)
- [AzerothCore wiki: areatable](https://www.azerothcore.org/wiki/areatable) -- AreaTable column structure, ZoneMusic = column 9
- [WoWInterface: Soundtrack day/night](https://www.wowinterface.com/forums/archive/index.php/t-57536.html) -- No built-in API for day/night state; must use GetGameTime with self-defined cutoffs

### Tertiary (LOW confidence)
- Community convention for day/night breakpoints (6:00/18:00) -- Multiple addon developers use this, but no official confirmation
- UiMapID 107 for Nagrand -- Confirmed in retail UiMapID list, but TBC Anniversary client may differ
- ZoneMusic silence intervals for Nagrand -- Exact values not found in any publicly accessible source

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All APIs confirmed available in TBC Anniversary via warcraft.wiki.gg version tags
- Architecture: HIGH -- Canonical WoW addon patterns, well-established event-driven model
- Music data: HIGH -- FileDataIDs confirmed via Wowhead, file paths confirmed via fondlez/wow-sounds
- Day/night detection: MEDIUM -- GetGameTime available, but exact breakpoints not officially documented
- Drum suppression: MEDIUM -- PlayMusic fade documented, but persistence across subzone transitions unverified
- Zone detection: MEDIUM -- C_Map API available, but exact UiMapID for TBC Anniversary Nagrand unvalidated
- Pitfalls: HIGH -- All critical pitfalls documented with mitigation strategies

**Research date:** 2026-02-18
**Valid until:** 2026-03-20 (30 days -- stable domain, WoW API rarely changes mid-expansion)
