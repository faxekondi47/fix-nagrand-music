# Architecture Research: FixNagrandMusic WoW Addon

**Domain:** WoW TBC Classic Anniversary addon (zone music bug fix)
**Researched:** 2026-02-18
**Confidence:** MEDIUM -- Core API behavior verified through official docs; some music file IDs need in-game validation

## The Bug: What We Are Fixing

The Nagrand music bug is a longstanding issue across multiple WoW Classic releases (TBC Classic, WotLK Classic, and now TBC Classic Anniversary). The symptoms:

1. Player enters Nagrand and hears the correct iconic zone music briefly
2. Within seconds, the music is replaced by either **Orgrimmar drum loops** or **ogre war drum loops** (reports vary)
3. The drums play on a ~30-second loop, then correct music starts momentarily before drums resume
4. The cycle repeats indefinitely throughout the zone

**Root cause hypothesis (MEDIUM confidence):** The bug appears to be a music priority/queue issue in Blizzard's zone music system. Some subzones within Nagrand (likely Halaa or Ring of Blood) have music entries that incorrectly take priority over the general zone music. The "drums" heard are likely the Halaa PvP or ogre camp combat music overriding the peaceful ambient tracks.

**Our fix strategy:** Detect when the player is in Nagrand, suppress the built-in (buggy) music, and play the correct Nagrand tracks ourselves using `PlayMusic()`.

Sources:
- [TBC: Nagrand Music Bug (US Forums)](https://us.forums.blizzard.com/en/wow/t/tbc-nagrand-music-bug/993365)
- [Orgrimmar music in Nagrand (US Forums)](https://us.forums.blizzard.com/en/wow/t/orgrimmar-music-in-nagrand/1028737)
- [Nagrand music bug, Pls fix Blizzard! (EU Forums)](https://eu.forums.blizzard.com/en/wow/t/nagrand-music-bug-pls-fix-blizzard/606156)
- [Is Nagrand music busted (US Forums, Feb 2026)](https://us.forums.blizzard.com/en/wow/t/is-nagrand-music-busted/2250797)

---

## WoW Music System Internals

### How Zone Music Works (HIGH confidence)

WoW's zone music system is driven by database tables baked into the client:

```
AreaTable (zone/subzone definitions)
    |
    v
ZoneMusicTable.dbc
    |-- ID
    |-- SetName (e.g., "Zone-NagrandDay")
    |-- SilenceIntervalMin[2]  (indexed by AMB_DAY=0, AMB_NIGHT=1)
    |-- SilenceIntervalMax[2]
    |-- Sounds[2]  --> foreign key to SoundEntries.dbc
    |
    v
SoundEntries.dbc
    |-- ID
    |-- SoundType (28 = "Zone Music Files")
    |-- Name
    |-- File[10] (up to 10 file references per entry)
    |-- Freq[10] (weighting/frequency for each file)
    |-- Volume
    |-- MinDistance / MaxDistance / DistanceCutoff
```

**Key behavior:** The client picks a random track from the SoundEntries file list (weighted by Freq), plays it, then waits a random silence interval before playing another. Day/night is determined by the in-game clock.

### Nagrand Music Entries (HIGH confidence -- from Wowhead TBC sound database)

**Zone-NagrandDay (Sound ID: 9012):**
| FileDataID | Track Name |
|------------|-----------|
| 53585 | NA_GeneralWalkDay01 |
| 53586 | NA_GeneralWalkDay02 |
| 53587 | NA_GeneralWalkDay03 |

**Zone-NagrandNight (Sound ID: 9013):**
| FileDataID | Track Name |
|------------|-----------|
| 53588 | NA_GeneralWalKnight01 |
| 53589 | NA_GeneralWalKnight02 |
| 53590 | NA_GeneralWalKnight03 |

**File path format (for TBC Classic):**
`Sound\Music\ZoneMusic\Nagrand\NA_GeneralWalkDay01.mp3`

Sources:
- [DB/ZoneMusic (wowdev.wiki)](https://wowdev.wiki/DB/ZoneMusic)
- [DB/SoundEntries (wowdev.wiki)](https://wowdev.wiki/DB/SoundEntries)
- [Wowhead TBC Zone Music](https://www.wowhead.com/tbc/sounds/zone-music)

### Sound Channels (HIGH confidence)

WoW has five independent sound channels:

| Channel | Purpose | Relevant? |
|---------|---------|-----------|
| **Master** | Overall volume | No |
| **Music** | Background music (zone music, PlayMusic) | YES -- primary |
| **SFX** | Sound effects | No |
| **Ambience** | Environmental sounds (wind, water, birds) | No |
| **Talking Head** | Dialog/speech | No |

`PlayMusic()` plays on the **Music** channel. When called, built-in zone music fades out automatically.

### Critical API Surface (HIGH confidence -- verified via Warcraft Wiki)

| API | Behavior | TBC Classic? |
|-----|----------|-------------|
| `PlayMusic(sound)` | Plays a music file on loop. Accepts FileDataID (number) or file path (string). Built-in zone music fades out when called. Loops until `StopMusic()`, `/reload`, or logout. | YES -- file paths still work in 2.5.x (removed in 8.2.0 retail only) |
| `StopMusic()` | Stops music started by `PlayMusic()`. Does NOT stop built-in zone music. Stops immediately (no fade since 2.2). | YES |
| `PlaySoundFile(sound, channel)` | Plays a sound file once (no loop) on specified channel. Returns willPlay, soundHandle. | YES |
| `SetCVar("Sound_EnableMusic", 0/1)` | Enables/disables the Music channel entirely. Affects both built-in and PlayMusic. | YES |
| `GetCVar("Sound_EnableMusic")` | Returns current music enabled state. | YES |
| `GetZoneText()` | Returns localized zone name (e.g., "Nagrand"). | YES |
| `GetSubZoneText()` | Returns localized subzone name (e.g., "Garadar") or "" if none. | YES |
| `GetRealZoneText()` | Returns actual zone/instance name. | YES |
| `C_Timer.After(seconds, callback)` | Schedules a callback after delay. | YES |

Sources:
- [PlayMusic (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/API_PlayMusic)
- [StopMusic (WoWWiki)](https://wowwiki-archive.fandom.com/wiki/API_StopMusic)
- [PlaySoundFile (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/API_PlaySoundFile)

### Zone Change Events (HIGH confidence)

| Event | When It Fires | Use Case |
|-------|---------------|----------|
| `ZONE_CHANGED_NEW_AREA` | Entering a new major zone (e.g., Terokkar -> Nagrand) | Detect entering/leaving Nagrand |
| `ZONE_CHANGED` | Moving between outdoor subzones (e.g., Garadar -> Halaa) | Detect subzone changes within Nagrand |
| `ZONE_CHANGED_INDOORS` | Moving indoors/outdoors within a zone | Not needed for Nagrand (outdoor zone) |
| `PLAYER_ENTERING_WORLD` | Login, reload, instance transition | Initialize state on login |

Source: [ZONE_CHANGED (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/ZONE_CHANGED)

---

## System Overview

```
+------------------------------------------------------------------+
|                         Event Layer                               |
|  ZONE_CHANGED_NEW_AREA | ZONE_CHANGED | PLAYER_ENTERING_WORLD    |
+------------------------------------------------------------------+
          |                      |                    |
          v                      v                    v
+------------------------------------------------------------------+
|                     Zone Detection Module                         |
|  GetZoneText()  |  GetSubZoneText()  |  IsInNagrand() flag       |
+------------------------------------------------------------------+
          |
          v
+------------------------------------------------------------------+
|                     Music Controller                              |
|  State Machine: INACTIVE | PLAYING | TRANSITIONING               |
|  PlayMusic() / StopMusic() / SetCVar() orchestration             |
+------------------------------------------------------------------+
          |
          v
+------------------------------------------------------------------+
|                     Music Data Table                              |
|  Subzone -> { dayTracks[], nightTracks[], FileDataIDs }           |
|  Fallback: Nagrand general tracks for unmapped subzones           |
+------------------------------------------------------------------+
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **Event Handler** | Registers WoW events, dispatches to zone detection | Single frame with `OnEvent` script, event routing table |
| **Zone Detector** | Determines if player is in Nagrand and which subzone | Compares `GetZoneText()` against "Nagrand", tracks state |
| **Music Controller** | Manages music playback lifecycle (start/stop/transition) | State machine, handles suppress/restore of built-in music |
| **Data Table** | Maps subzones to correct music track FileDataIDs/paths | Static Lua table, no runtime computation |
| **Config/SavedVars** | Persists user preferences (enable/disable, volume) | SavedVariables in TOC, defaults table |

---

## Recommended Project Structure

```
FixNagrandMusic/
|-- FixNagrandMusic.toc          # Addon metadata, load order
|-- Core.lua                     # Event handler, addon initialization
|-- ZoneDetection.lua            # Zone/subzone detection logic
|-- MusicController.lua          # Music playback state machine
|-- MusicData.lua                # Track data table (FileDataIDs, paths)
|-- Config.lua                   # SavedVariables, user settings (optional)
```

### Structure Rationale

- **Single-purpose files:** Each file owns one concern. Easy to modify MusicData without touching playback logic.
- **Flat structure:** This is a small, focused addon. No subdirectories needed. WoW addon loading order is defined in the TOC file.
- **MusicData.lua separate:** The track-to-subzone mapping is the part most likely to need adjustment/expansion. Isolating it makes iteration fast.
- **Config.lua optional for MVP:** Can be deferred -- the core fix works without user configuration.

---

## Data Flow

### Primary Flow: Zone Change -> Correct Music

```
[Player crosses zone boundary]
    |
    v
[ZONE_CHANGED_NEW_AREA or ZONE_CHANGED event fires]
    |
    v
[Event Handler dispatches to Zone Detector]
    |
    v
[Zone Detector checks: GetZoneText() == "Nagrand"?]
    |
    +-- NO --> [Music Controller: Deactivate]
    |              |
    |              v
    |          [StopMusic() -- stop our track if playing]
    |          [Restore Sound_EnableMusic if we changed it]
    |          [State -> INACTIVE]
    |
    +-- YES --> [Zone Detector: GetSubZoneText()]
                   |
                   v
                [Music Data: lookup subzone -> track list]
                   |
                   v
                [Music Controller: Activate]
                   |
                   v
                [Suppress built-in music (see strategy below)]
                   |
                   v
                [Select track from list (random or sequential)]
                   |
                   v
                [PlayMusic(trackID) -- loops automatically]
                   |
                   v
                [State -> PLAYING]
```

### Critical Decision: How to Suppress Built-in Music

There are two viable strategies for suppressing the buggy built-in music:

**Strategy A: PlayMusic Override (RECOMMENDED)**
```lua
-- PlayMusic() automatically fades out built-in zone music
PlayMusic(correctTrackID)
-- Built-in music fades out, our track plays on loop
-- When leaving Nagrand: StopMusic() -> built-in music resumes naturally
```

**Why recommended:** `PlayMusic()` is documented to automatically fade out built-in music. This is the simplest approach. When we call `StopMusic()` upon leaving Nagrand, the built-in zone music for the new zone will resume naturally.

**Risk:** The buggy drum music may fight back and override our `PlayMusic()` call. If the client's zone music system keeps re-triggering on subzone boundaries, it could interrupt our playback. This needs in-game testing.

**Strategy B: SetCVar Toggle (FALLBACK)**
```lua
-- Disable built-in music entirely while in Nagrand
local savedMusicSetting = GetCVar("Sound_EnableMusic")
SetCVar("Sound_EnableMusic", "0")  -- kills all music
-- Small delay to let it take effect
C_Timer.After(0.1, function()
    SetCVar("Sound_EnableMusic", "1")  -- re-enable
    PlayMusic(correctTrackID)  -- now only our track plays
end)
```

**Why fallback:** More aggressive. Briefly kills all music, then re-enables and immediately plays our track. The built-in music system may not re-trigger immediately, giving our track priority. However, it modifies user settings and could cause audible pops/glitches.

**Strategy C: PlaySoundFile on Music Channel (ALTERNATIVE)**
```lua
-- Play on Music channel but as a one-shot
PlaySoundFile(correctTrackID, "Music")
-- Does not loop -- need our own timer to replay
```

**Why not preferred:** Does not loop automatically. Requires tracking song duration and scheduling replays manually. More complex for no clear benefit.

### Subzone Transition Flow

```
[Player moves within Nagrand: Garadar -> Halaa]
    |
    v
[ZONE_CHANGED fires]
    |
    v
[Zone Detector: Still in Nagrand? YES]
    |
    v
[New subzone has different music mapping?]
    |
    +-- NO (same track group) --> [Keep playing, no change]
    |
    +-- YES --> [Music Controller: transition]
                   |
                   v
                [StopMusic()]
                [Select new track for subzone]
                [PlayMusic(newTrackID)]
```

---

## Nagrand Subzone Map

All 19+ subzones returned by `GetSubZoneText()` in Nagrand (from Explore Nagrand achievement, HIGH confidence):

| Subzone | Expected Music | Notes |
|---------|---------------|-------|
| Garadar | Nagrand General | Horde town |
| Telaar | Nagrand General | Alliance town |
| Halaa | Nagrand General (or PvP?) | PvP objective -- may have its own music causing the bug |
| Throne of the Elements | Nagrand General | Elemental area |
| Oshu'gun | Nagrand General | Sacred mountain |
| Spirit Fields | Nagrand General | Ancestral grounds |
| Lake Sunspring / Sunspring Post | Nagrand General | Lake area |
| Ancestral Grounds | Nagrand General | Ceremonial area |
| Laughing Skull Ruins | Nagrand General | Ogre ruins |
| Warmaul Hill | Nagrand General (or ogre drums?) | Ogre stronghold -- potential source of drum bug |
| Ring of Blood / Ring of Trials | Nagrand General (or combat?) | Arena -- another potential drum source |
| Forge Camp: Fear / Forge Camp: Hate | Nagrand General | Burning Legion camps |
| Burning Blade Ruins | Nagrand General | Ruins |
| Kil'sorrow Fortress | Nagrand General | Shadow Council base |
| The Twilight Ridge | Nagrand General | Edge zone |
| Clan Watch | Nagrand General | Mag'har outpost |
| Windyreed Pass / Village | Nagrand General | Broken settlement |
| Zangar Ridge | Nagrand General | Border area |
| Nesingwary Safari | Nagrand General | Hunting camp |
| Elemental Plateau | Nagrand General | Floating island |
| "" (empty string) | Nagrand General | Open areas with no subzone name |

**Important note:** For MVP, all subzones should map to the same Nagrand general music (day/night variants). The bug is that the WRONG music plays everywhere, not that subzones need different tracks. Subzone-specific music can be added later if desired.

---

## Architectural Patterns

### Pattern 1: Event-Driven Frame Handler

**What:** Standard WoW addon pattern. Create an invisible frame, register events, dispatch via table lookup.
**When to use:** Always -- this is the canonical WoW addon architecture.
**Trade-offs:** Simple, well-understood, zero overhead when no events fire.

```lua
local frame = CreateFrame("Frame")
local events = {}

function events:ZONE_CHANGED_NEW_AREA()
    -- handle major zone change
end

function events:ZONE_CHANGED()
    -- handle subzone change
end

function events:PLAYER_ENTERING_WORLD()
    -- handle login/reload
end

frame:SetScript("OnEvent", function(self, event, ...)
    if events[event] then
        events[event](self, ...)
    end
end)

for event in pairs(events) do
    frame:RegisterEvent(event)
end
```

### Pattern 2: State Machine for Music Controller

**What:** Track playback state explicitly to avoid double-plays, missed stops, or race conditions.
**When to use:** Whenever managing async resources (music playback) across event boundaries.
**Trade-offs:** Slightly more code, but prevents edge-case bugs that are hard to reproduce.

```lua
local State = {
    INACTIVE = "INACTIVE",       -- Not in Nagrand, doing nothing
    PLAYING = "PLAYING",         -- In Nagrand, our music is active
    TRANSITIONING = "TRANSITIONING"  -- Switching tracks (brief)
}

local currentState = State.INACTIVE
local currentTrack = nil

local function activate(trackID)
    if currentState == State.PLAYING and currentTrack == trackID then
        return  -- already playing this track
    end
    currentState = State.TRANSITIONING
    StopMusic()
    PlayMusic(trackID)
    currentTrack = trackID
    currentState = State.PLAYING
end

local function deactivate()
    if currentState == State.INACTIVE then
        return  -- already inactive
    end
    StopMusic()
    currentTrack = nil
    currentState = State.INACTIVE
end
```

### Pattern 3: Defensive Data Table with Fallback

**What:** Map subzones to tracks with a guaranteed fallback for unmapped subzones.
**When to use:** When the data set might be incomplete (unknown subzones, localization variations).
**Trade-offs:** Resilient to missing data, slightly more complex lookup.

```lua
local NAGRAND_TRACKS = {
    day = {
        53585,  -- NA_GeneralWalkDay01
        53586,  -- NA_GeneralWalkDay02
        53587,  -- NA_GeneralWalkDay03
    },
    night = {
        53588,  -- NA_GeneralWalKnight01
        53589,  -- NA_GeneralWalKnight02
        53590,  -- NA_GeneralWalKnight03
    },
}

-- For MVP: all subzones use the same tracks
-- Later: can add per-subzone overrides
local SUBZONE_OVERRIDES = {
    -- ["Halaa"] = { day = {...}, night = {...} },
}

local function getTracksForSubzone(subzone)
    return SUBZONE_OVERRIDES[subzone] or NAGRAND_TRACKS
end
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Polling with OnUpdate

**What people do:** Use `frame:SetScript("OnUpdate", func)` to check zone every frame.
**Why it is wrong:** Runs 60+ times per second. Wastes CPU for something that changes at most a few times per play session. WoW provides events specifically for zone changes.
**Do this instead:** Register for `ZONE_CHANGED` and `ZONE_CHANGED_NEW_AREA` events.

### Anti-Pattern 2: Hardcoding File Paths When FileDataIDs Work

**What people do:** Use string paths like `"Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkDay01.mp3"`.
**Why it is wrong:** File paths are fragile across WoW versions and were deprecated in retail 8.2.0. While TBC Classic 2.5.x still supports them, FileDataIDs (numbers like `53585`) are more robust and future-proof.
**Do this instead:** Use FileDataIDs as the primary reference. Keep file paths as comments for documentation.

### Anti-Pattern 3: Not Cleaning Up on Zone Exit

**What people do:** Start PlayMusic when entering Nagrand but forget to StopMusic when leaving.
**Why it is wrong:** Nagrand music continues playing in Terokkar, Zangarmarsh, etc. Player has to `/reload` to get correct music.
**Do this instead:** Always call `StopMusic()` in the deactivate path when `GetZoneText() ~= "Nagrand"`.

### Anti-Pattern 4: Ignoring the Empty Subzone Case

**What people do:** Only handle named subzones, ignore when `GetSubZoneText()` returns `""`.
**Why it is wrong:** Large portions of Nagrand are open grassland with no subzone name. Player would hear no music (or buggy music) while riding between areas.
**Do this instead:** Treat `""` (empty string) as "Nagrand General" and play the default tracks.

---

## Integration Points

### WoW Client Integration

| Integration | Mechanism | Gotchas |
|-------------|-----------|---------|
| Zone detection | Events + API calls | Localized strings -- "Nagrand" must match client language |
| Music playback | PlayMusic() / StopMusic() | PlayMusic loops forever; StopMusic only stops our music, not built-in |
| Built-in music suppression | PlayMusic auto-fades built-in | May not persist across subzone boundaries (needs testing) |
| User settings | SetCVar / GetCVar | Must restore original values when addon deactivates |
| Persistence | SavedVariables in TOC | Only available after ADDON_LOADED fires |
| Day/night detection | Game time API | `GetGameTime()` returns server hour; transition points ~6:00 and ~18:00 |

### Localization Concern (MEDIUM confidence)

`GetZoneText()` and `GetSubZoneText()` return **localized** strings. "Nagrand" in English may be different in other locales:

| Locale | Zone Name | Needs Verification |
|--------|-----------|-------------------|
| enUS/enGB | Nagrand | Confirmed |
| deDE | Nagrand | Likely same (proper noun) |
| frFR | Nagrand | Likely same |
| esES | Nagrand | Likely same |
| zhCN | Unknown | Needs verification |
| koKR | Unknown | Needs verification |

**Mitigation:** For MVP, hardcode "Nagrand" (English). Add a locale table later if needed. Most TBC Classic Anniversary players are on English clients. Alternatively, use zone ID via `C_Map.GetBestMapForUnit("player")` if available in TBC Classic (needs verification -- LOW confidence).

---

## Build Order (Dependencies)

Build in this order because each layer depends on the one before it:

### Phase 1: Data Table (MusicData.lua)
- Define the Nagrand track FileDataIDs (day and night)
- No dependencies, can be built and verified independently
- **Validation needed:** Test each FileDataID in-game with `/run PlayMusic(53585)` etc.

### Phase 2: Zone Detection (ZoneDetection.lua)
- Implement zone/subzone detection
- Register events, check GetZoneText
- Depends on: nothing (but will connect to Phase 3)
- **Validation:** `/run print(GetZoneText(), GetSubZoneText())` in Nagrand

### Phase 3: Music Controller (MusicController.lua)
- State machine: INACTIVE -> PLAYING -> INACTIVE
- PlayMusic/StopMusic orchestration
- Depends on: MusicData (for track selection), ZoneDetection (for triggers)

### Phase 4: Core Integration (Core.lua + TOC)
- Wire everything together
- Event frame creation and dispatch
- TOC file with correct Interface version
- Depends on: all above modules

### Phase 5: Polish (Config.lua, edge cases)
- SavedVariables for enable/disable toggle
- Day/night track selection
- Slash command (`/fnm` or `/fixnagrand`)
- Edge cases: flying over Nagrand, hearthstone out, death/ghost

---

## TOC File Structure

```toc
## Interface: 20504
## Title: FixNagrandMusic
## Notes: Fixes the Nagrand music bug by playing the correct zone music tracks
## Author: [author]
## Version: 1.0.0
## SavedVariables: FixNagrandMusicDB

MusicData.lua
ZoneDetection.lua
MusicController.lua
Config.lua
Core.lua
```

**Note on Interface version:** TBC Classic Anniversary launched Feb 5, 2026. The interface version needs to be verified in-game with `/dump (select(4, GetBuildInfo()))`. The value `20504` or `20505` is expected based on prior TBC Classic versions (MEDIUM confidence -- verify at runtime).

---

## Key Technical Questions Requiring In-Game Validation

These cannot be answered through documentation alone and need testing on a live TBC Classic Anniversary server:

| Question | Why It Matters | How to Test |
|----------|---------------|-------------|
| Do FileDataIDs 53585-53590 work with PlayMusic()? | Core functionality depends on this | `/run PlayMusic(53585)` in-game |
| Does PlayMusic() persist across subzone boundaries in Nagrand? | If not, need re-trigger logic | Walk between subzones while PlayMusic is active |
| Does the buggy drum music override PlayMusic()? | If yes, need Strategy B (SetCVar toggle) | Enter Nagrand with addon running, wait for drum trigger |
| What is the correct Interface version for TBC Anniversary? | TOC file must be correct or addon won't load | `/dump (select(4, GetBuildInfo()))` |
| Does `C_Map.GetBestMapForUnit` exist in TBC Classic? | Affects localization strategy | `/run print(C_Map.GetBestMapForUnit("player"))` |
| Is "Nagrand" the same string in all locales? | Affects zone detection | Check on non-English client |
| What happens to PlayMusic on death/ghost form? | Need to handle this edge case | Die in Nagrand, check if music continues |

---

## Sources

- [PlayMusic API (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/API_PlayMusic) -- HIGH confidence
- [StopMusic API (WoWWiki)](https://wowwiki-archive.fandom.com/wiki/API_StopMusic) -- HIGH confidence
- [PlaySoundFile API (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/API_PlaySoundFile) -- HIGH confidence
- [DB/ZoneMusic (wowdev.wiki)](https://wowdev.wiki/DB/ZoneMusic) -- HIGH confidence
- [DB/SoundEntries (wowdev.wiki)](https://wowdev.wiki/DB/SoundEntries) -- HIGH confidence
- [Wowhead TBC Zone Music](https://www.wowhead.com/tbc/sounds/zone-music) -- HIGH confidence (source of FileDataIDs)
- [Zone-NagrandDay (Wowhead)](https://www.wowhead.com/tbc/sound=9012/zone-nagrandday) -- HIGH confidence
- [Zone-NagrandNight (Wowhead)](https://www.wowhead.com/tbc/sound=9013/zone-nagrandnight) -- HIGH confidence
- [ZONE_CHANGED event (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/ZONE_CHANGED) -- HIGH confidence
- [TOC format (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/TOC_format) -- HIGH confidence
- [Explore Nagrand subzones (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/Explore_Nagrand) -- HIGH confidence
- [Nagrand music bug forums (multiple)](https://us.forums.blizzard.com/en/wow/t/tbc-nagrand-music-bug/993365) -- MEDIUM confidence (user reports)
- [Soundtrack addon (GitHub)](https://github.com/LunaCues/Soundtrack) -- MEDIUM confidence (reference architecture)
- [wow-sounds repository (GitHub)](https://github.com/fondlez/wow-sounds) -- MEDIUM confidence (file listings)

---
*Architecture research for: FixNagrandMusic WoW Addon*
*Researched: 2026-02-18*
