# Phase 2: User Interface - Research

**Researched:** 2026-02-19
**Domain:** WoW TBC Classic Anniversary addon -- slash commands, SavedVariables, chat output, TOC metadata
**Confidence:** HIGH

## Summary

Phase 2 adds a user-facing control layer on top of Phase 1's working music fix: slash commands (`/fng`, `/fng toggle`, `/fng debug`), a login notification with version, and persisted settings via SavedVariablesPerCharacter. The research found all required WoW APIs are confirmed available in TBC Classic Anniversary 2.5.5, and the implementation patterns are well-established and straightforward.

The core technical areas are: (1) slash command registration via `SlashCmdList` and `SLASH_XXX` globals, (2) SavedVariablesPerCharacter persistence with `ADDON_LOADED` initialization, (3) `C_AddOns.GetAddOnMetadata` for reading the version from the TOC at runtime, and (4) color escape sequences for styled chat output. All of these use standard WoW addon patterns with no libraries needed.

The main integration consideration is how Phase 2's new toggle/debug state and event handling meshes with Phase 1's existing event-driven architecture. The current code uses a `handlers` table keyed by event name, and Phase 2 needs to add `ADDON_LOADED` and `PLAYER_LOGIN` handlers to this table, plus integrate an `enabled` state check into the existing activation/deactivation flow. Since the addon is a single file with clear section organization, this is a surgical addition.

**Primary recommendation:** Add slash command registration, SavedVariablesPerCharacter initialization, and login notification directly into the existing `FixNagrandMusic.lua` file. Use a hardcoded FileDataID-to-path lookup table (6 entries) for the status display. Change the TOC from `SavedVariables` to `SavedVariablesPerCharacter` since toggle/debug are per-character settings.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Status display (`/fng`)
- Minimal one-liner format, not multi-line
- Context-aware: in Nagrand show track + subzone; outside Nagrand say "Not in Nagrand" or similar
- Show the actual file path for the current track (e.g. `Sound\Music\TBC\NagrandDay1.mp3`), not a friendly name
- No version number in status output -- version belongs at login only

#### Chat output style
- Prefix all addon messages with colored `|cFF00CC66FNG|r:` (short green "FNG")
- Debug messages use yellow text with `[DEBUG]` tag to stand out from normal messages
- Debug mode prints zone and subzone change events only -- no music calls, no timer ticks, not a firehose
- No silent mode -- toggle and debug are sufficient, messages are minimal anyway

#### Toggle behavior (`/fng toggle`)
- Toggle OFF in Nagrand: StopMusic() immediately, bugged Orgrimmar music takes over
- Toggle ON in Nagrand: start playing correct Nagrand music right away (don't wait for next event)
- Confirmation message: simple "FNG: Enabled" / "FNG: Disabled" -- no extra context
- Only `/fng toggle` command, no `/fng on` or `/fng off` aliases

#### Login notification
- Every login, not just first time -- standard WoW addon behavior
- Format: `FNG: FixNagrandMusic v{version} loaded` with same green prefix as all messages
- Show persisted state if disabled: `FNG: FixNagrandMusic v{version} loaded (disabled)`
- Always shows when addon is enabled (normal case): just "loaded" with no state qualifier

### Claude's Discretion

- SavedVariables structure and variable naming
- Exact WoW color escape codes for debug yellow
- How to read version from TOC metadata
- Error handling for edge cases (e.g. SavedVariables not yet loaded)

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UI-01 | `/fng` slash command displays addon status (enabled/disabled, current subzone, current track) | `SlashCmdList` + `SLASH_XXX` globals -- standard pattern, confirmed available in all WoW versions. Status reads from existing Phase 1 state variables (`isActive`, `currentSubzone`, `currentTrackID`). Track file path requires a hardcoded FileDataID-to-path lookup table (6 entries). |
| UI-02 | `/fng toggle` enables/disables the music fix without uninstalling | Toggle sets a persisted `enabled` boolean. When disabled: `StopMusic()` immediately, skip all zone event processing. When re-enabled in Nagrand: call `activateAddon()` to start music immediately. |
| UI-03 | `/fng debug` toggles debug mode printing zone/music events to chat | Debug prints inside existing zone event handlers (`ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED_INDOORS`). Only zone/subzone change events per user decision -- no music calls, no timer ticks. |
| UI-04 | Brief login notification confirms addon is loaded | `C_AddOns.GetAddOnMetadata("FixNagrandMusic", "Version")` reads `@project-version@` from TOC at runtime. Print in `PLAYER_LOGIN` handler (fires after `ADDON_LOADED`, before `PLAYER_ENTERING_WORLD`). |
| UI-05 | Toggle and debug state persisted across sessions via SavedVariablesPerCharacter | TOC change: `SavedVariables` -> `SavedVariablesPerCharacter`. Initialize defaults in `ADDON_LOADED` handler. Global variable `FixNagrandMusicDB` is a table with `enabled` and `debug` booleans. |

</phase_requirements>

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| `SlashCmdList` + `SLASH_XXX` globals | API since 1.0 | Slash command registration | The only way to create slash commands. No library needed. |
| `SavedVariablesPerCharacter` TOC directive | Since 1.0 | Per-character settings persistence | Built-in WoW persistence mechanism. Data survives logout/reload. |
| `ADDON_LOADED` event | Since 1.0 (1.13.2 Classic) | SavedVariables initialization | Fires after SavedVariables load. Earliest safe time to read persisted data. |
| `PLAYER_LOGIN` event | Since 1.0 | Login notification timing | Fires once per login/reload, after ADDON_LOADED, before PLAYER_ENTERING_WORLD. Ideal for login messages. |
| `C_AddOns.GetAddOnMetadata(name, field)` | 2.5.5 (65463) | Read TOC version at runtime | Returns the `## Version` field from the TOC file. Confirmed available in TBC Anniversary. |
| `|cAARRGGBB...|r` escape sequences | Since 1.0 | Colored chat output | Standard WoW text coloring. No library needed. |
| `print()` | Since 1.0 | Chat output | Outputs to the default chat frame. Standard for addon messages. |

### Supporting

| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| `string:match()` / `string:lower()` | Lua 5.1 | Slash command argument parsing | Parse subcommands from the `/fng` input string |
| `C_Timer.After(0, callback)` | 2.5.5 | Deferred login notification | If login message needs to fire after PLAYER_ENTERING_WORLD completes (unlikely, but available as fallback) |

### Not Needed

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Ace3 / AceConsole | Massive overkill for 3 slash commands | Raw `SlashCmdList` pattern |
| AceDB | Overkill for 2 boolean settings | Raw `SavedVariablesPerCharacter` with manual defaults |
| LibDataBroker / Minimap button | Out of scope per requirements | Slash commands only |
| XML frame definitions | No GUI elements in this phase | Lua-only approach |

## Architecture Patterns

### Integration with Existing Code Structure

The existing `FixNagrandMusic.lua` has 10 clearly commented sections. Phase 2 adds to this structure:

```
FixNagrandMusic.lua (existing sections + Phase 2 additions)
├── SECTION 1: MUSIC DATA          (existing, unchanged)
├── SECTION 2: STATE VARIABLES     (existing, add enabled/debug state)
├── SECTION 3: UTILITY FUNCTIONS   (existing, replace printError/printInfo with new FNG-prefixed versions)
├── SECTION 4: ZONE DETECTION      (existing, unchanged)
├── SECTION 5: DAY/NIGHT DETECTION (existing, unchanged)
├── SECTION 6: MUSIC PLAYBACK      (existing, add enabled guard)
├── SECTION 7: DAY/NIGHT MONITORING(existing, unchanged)
├── SECTION 8: ACTIVATION/DEACT    (existing, add enabled guard)
├── SECTION 9: EVENT HANDLERS      (existing, add debug prints, ADDON_LOADED, PLAYER_LOGIN)
├── SECTION 10: FRAME SETUP        (existing, unchanged)
└── SECTION 11: SLASH COMMANDS     (NEW -- slash command registration and handler)
```

### Pattern 1: Slash Command with Subcommand Dispatch

**What:** Register `/fng` as the single entry point, parse the first word as a subcommand.
**When to use:** Always for multi-command addons.

```lua
-- Source: warcraft.wiki.gg/wiki/Creating_a_slash_command
SLASH_FNG1 = "/fng"
SlashCmdList["FNG"] = function(msg)
    local command = msg:lower():match("^(%S+)") or ""
    if command == "toggle" then
        -- toggle logic
    elseif command == "debug" then
        -- debug logic
    else
        -- status display (default for empty or unknown input)
    end
end
```

**Key detail:** `msg` is the text AFTER `/fng `. So `/fng toggle` gives `msg = "toggle"`. `/fng` alone gives `msg = ""`.

### Pattern 2: SavedVariables Initialization with Defaults

**What:** Use `ADDON_LOADED` to initialize the global table with defaults if it does not exist yet (first-ever login) or if specific keys are missing (addon updated with new settings).
**When to use:** Always for addons with persisted settings.

```lua
-- Source: warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions
function handlers.ADDON_LOADED(addonName)
    if addonName ~= "FixNagrandMusic" then return end
    -- Initialize defaults if first load
    if FixNagrandMusicDB == nil then
        FixNagrandMusicDB = {}
    end
    if FixNagrandMusicDB.enabled == nil then
        FixNagrandMusicDB.enabled = true
    end
    if FixNagrandMusicDB.debug == nil then
        FixNagrandMusicDB.debug = false
    end
end
```

**Key detail:** Check each key individually with `== nil`, not just the table. This handles addon updates where new keys are added to a table that already exists from a previous version.

### Pattern 3: Login Notification in PLAYER_LOGIN

**What:** Print the addon loaded message at login time, after SavedVariables are available.
**When to use:** Standard pattern for addon load confirmation.

```lua
-- Source: warcraft.wiki.gg/wiki/AddOn_loading_process
function handlers.PLAYER_LOGIN()
    local version = C_AddOns.GetAddOnMetadata("FixNagrandMusic", "Version")
    local msg = "FixNagrandMusic v" .. (version or "?") .. " loaded"
    if not FixNagrandMusicDB.enabled then
        msg = msg .. " (disabled)"
    end
    printInfo(msg)
end
```

**Event order guarantee:** `ADDON_LOADED` fires before `PLAYER_LOGIN`, so `FixNagrandMusicDB` is guaranteed to be initialized when the login message prints.

### Pattern 4: Toggle with Immediate Effect

**What:** Toggle changes the persisted `enabled` state and immediately applies the effect (start/stop music).
**When to use:** Required by user decision -- toggle ON in Nagrand starts music right away.

```lua
local function toggleAddon()
    FixNagrandMusicDB.enabled = not FixNagrandMusicDB.enabled
    if FixNagrandMusicDB.enabled then
        printInfo("Enabled")
        if isInNagrand() then
            activateAddon()
        end
    else
        printInfo("Disabled")
        deactivateAddon()
    end
end
```

### Pattern 5: Debug Prints in Event Handlers

**What:** Conditional debug output that only fires when debug mode is on.
**When to use:** Inside zone event handlers only (per user decision).

```lua
local function printDebug(msg)
    if FixNagrandMusicDB and FixNagrandMusicDB.debug then
        print("|cFF00CC66FNG|r: |cFFFFFF00[DEBUG] " .. msg .. "|r")
    end
end

-- In zone event handlers:
function handlers.ZONE_CHANGED_NEW_AREA()
    printDebug("ZONE_CHANGED_NEW_AREA: " .. (GetZoneText() or "?") .. " / " .. (GetSubZoneText() or ""))
    -- existing logic...
end
```

### Anti-Patterns to Avoid

- **Checking FixNagrandMusicDB before ADDON_LOADED:** The global is `nil` until SavedVariables load. Any code that runs during file execution cannot access it.
- **Using `SavedVariables` (account-wide) for toggle/debug:** These are per-character settings. One character's debug mode should not affect another's.
- **Printing login message in ADDON_LOADED:** Chat frame may not be ready. `PLAYER_LOGIN` is the correct event for user-visible messages.
- **Calling `deactivateAddon()` when already not active:** The existing code guards against this (`if not isActive then return`), but the toggle should still call it unconditionally to ensure clean state.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Slash command parsing | Custom chat frame hook | `SlashCmdList` + `SLASH_XXX` globals | Standard WoW API. Always works. |
| Settings persistence | Custom file writing / LDB | `SavedVariablesPerCharacter` TOC directive | Built-in WoW mechanism. Handles serialization, file paths, character isolation. |
| TOC version reading | Hardcoded version string in Lua | `C_AddOns.GetAddOnMetadata("FixNagrandMusic", "Version")` | Reads from TOC at runtime. Works with `@project-version@` token replacement by packager. |
| FileDataID to path mapping | Runtime API lookup (none exists) | Hardcoded 6-entry lookup table | No runtime API to resolve FileDataID to file path in TBC Anniversary. Only 6 tracks -- a table is trivial and correct. |

**Key insight:** The entire Phase 2 uses zero external libraries. Everything is built-in WoW API plus standard Lua string operations.

## Common Pitfalls

### Pitfall 1: SavedVariables Not Yet Loaded During File Execution

**What goes wrong:** Code at file scope tries to read `FixNagrandMusicDB` and gets `nil`, then sets defaults that get overwritten when SavedVariables actually load.
**Why it happens:** Lua files execute before SavedVariables load. `ADDON_LOADED` has not fired yet.
**How to avoid:** All SavedVariables access must be inside `ADDON_LOADED` handler or later events. Never reference `FixNagrandMusicDB` at file scope.
**Warning signs:** Settings reset to defaults every login.
**Confidence:** HIGH -- well-documented timing behavior.

### Pitfall 2: TOC SavedVariables vs SavedVariablesPerCharacter Mismatch

**What goes wrong:** The current TOC declares `SavedVariables: FixNagrandMusicDB` (account-wide). If we change to `SavedVariablesPerCharacter`, any existing saved data from a prior account-wide file will NOT be picked up -- the client looks in a different directory.
**Why it happens:** `SavedVariables` stores in `WTF/Account/ACCOUNTNAME/SavedVariables/`. `SavedVariablesPerCharacter` stores in `WTF/Account/ACCOUNTNAME/RealmName/CharacterName/SavedVariables/`.
**How to avoid:** Since the addon has not yet been released and no users have existing SavedVariables data, simply change the TOC directive. No migration needed.
**Warning signs:** N/A -- this is a safe change for a pre-release addon.
**Confidence:** HIGH.

### Pitfall 3: Enabled Guard Must Cover All Entry Points

**What goes wrong:** Toggle OFF but music keeps playing because not all event handlers check the `enabled` flag.
**Why it happens:** Phase 1's event handlers (`ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `PLAYER_ENTERING_WORLD`) do not check an `enabled` flag -- they always process.
**How to avoid:** Add an `enabled` check at the top of the `activateAddon()` function (single guard point), since all zone event handlers ultimately call `activateAddon()` when entering Nagrand. Also add guard in `playNagrandMusic()` for subzone re-assertion events.
**Warning signs:** Music plays after `/fng toggle` disables the addon.
**Confidence:** HIGH.

### Pitfall 4: Debug Print in Deferred Callbacks Misses Zone Info

**What goes wrong:** `ZONE_CHANGED_NEW_AREA` and `PLAYER_ENTERING_WORLD` use `C_Timer.After(0, ...)` to defer their logic. If the debug print is inside the deferred callback, it shows the updated zone. If outside, it shows the previous zone.
**Why it happens:** The one-frame delay means zone APIs return different values before and after the deferral.
**How to avoid:** Place debug prints inside the deferred callback so they show the actual zone data being acted upon. This matches what the user wants to see -- the zone the addon is responding to.
**Warning signs:** Debug output shows wrong zone name.
**Confidence:** HIGH.

### Pitfall 5: `@project-version@` Token Not Replaced During Development

**What goes wrong:** During local development (not packaged by BigWigsMods), `C_AddOns.GetAddOnMetadata("FixNagrandMusic", "Version")` returns the literal string `"@project-version@"` instead of a version number.
**Why it happens:** The `@project-version@` token in the TOC is only replaced during the BigWigsMods packager release process.
**How to avoid:** Handle this gracefully. If the version string contains `@`, display `"dev"` or the raw string. This is cosmetic only and does not affect functionality.
**Warning signs:** Login message shows `v@project-version@`.
**Confidence:** HIGH.

### Pitfall 6: Chat Output Prefix Change Affects Existing Error Messages

**What goes wrong:** Phase 1 uses `"|cFFFF0000FixNagrandMusic Error:|r"` and `"|cFF00FF00FixNagrandMusic:|r"` for messages. Phase 2 changes the prefix to `"|cFF00CC66FNG|r:"`. If only new messages use the new prefix, the addon has inconsistent styling.
**Why it happens:** The Phase 1 `printError()` and `printInfo()` functions use the old prefix.
**How to avoid:** Update `printError()` and `printInfo()` to use the new `FNG` prefix. Add `printDebug()` as a new function. All three share the same `|cFF00CC66FNG|r:` prefix with different body styling.
**Warning signs:** Mix of "FixNagrandMusic:" and "FNG:" messages in chat.
**Confidence:** HIGH.

## Code Examples

Verified patterns from official sources:

### Slash Command Registration

```lua
-- Source: warcraft.wiki.gg/wiki/Creating_a_slash_command
SLASH_FNG1 = "/fng"
SlashCmdList["FNG"] = function(msg)
    local command = msg:lower():match("^(%S+)") or ""
    if command == "toggle" then
        toggleAddon()
    elseif command == "debug" then
        toggleDebug()
    else
        showStatus()
    end
end
```

### SavedVariablesPerCharacter Initialization

```lua
-- Source: warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions
-- TOC declares: ## SavedVariablesPerCharacter: FixNagrandMusicDB

function handlers.ADDON_LOADED(addonName)
    if addonName ~= "FixNagrandMusic" then return end
    if FixNagrandMusicDB == nil then
        FixNagrandMusicDB = {}
    end
    if FixNagrandMusicDB.enabled == nil then
        FixNagrandMusicDB.enabled = true
    end
    if FixNagrandMusicDB.debug == nil then
        FixNagrandMusicDB.debug = false
    end
    -- Unregister -- we only need this once
    frame:UnregisterEvent("ADDON_LOADED")
end
```

### Reading Version from TOC Metadata

```lua
-- Source: warcraft.wiki.gg/wiki/API_C_AddOns.GetAddOnMetadata
-- Available in TBC Anniversary 2.5.5 (65463)
local function getAddonVersion()
    local version = C_AddOns.GetAddOnMetadata("FixNagrandMusic", "Version")
    if not version or version:find("@") then
        return "dev"
    end
    return version
end
```

### Chat Output Functions (Updated Prefix)

```lua
-- User decision: prefix all messages with colored |cFF00CC66FNG|r:
-- User decision: debug uses yellow with [DEBUG] tag

local FNG_PREFIX = "|cFF00CC66FNG|r: "

local function printInfo(msg)
    print(FNG_PREFIX .. msg)
end

local function printError(msg)
    print(FNG_PREFIX .. "|cFFFF0000" .. msg .. "|r")
end

local function printDebug(msg)
    if FixNagrandMusicDB and FixNagrandMusicDB.debug then
        print(FNG_PREFIX .. "|cFFFFFF00[DEBUG] " .. msg .. "|r")
    end
end
```

### FileDataID to Path Lookup Table

```lua
-- No runtime API exists to resolve FileDataID to file path.
-- Hardcoded from Wowhead TBC sound database (confirmed in Phase 1 research).
local TRACK_PATHS = {
    [53585] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkDay01.mp3",
    [53586] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkDay02.mp3",
    [53587] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkDay03.mp3",
    [53588] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkNight01.mp3",
    [53589] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkNight02.mp3",
    [53590] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkNight03.mp3",
}
```

### Status Display (One-Liner, Context-Aware)

```lua
-- User decision: one-liner, context-aware, show file path not friendly name
local function showStatus()
    if not FixNagrandMusicDB.enabled then
        printInfo("Disabled")
        return
    end
    if not isActive then
        printInfo("Enabled | Not in Nagrand")
        return
    end
    local path = TRACK_PATHS[currentTrackID] or "unknown"
    local subzone = currentSubzone
    if not subzone or subzone == "" then
        subzone = "open area"
    end
    printInfo("Enabled | " .. subzone .. " | " .. path)
end
```

### Login Notification

```lua
-- User decision: every login, green FNG prefix, show (disabled) if off
function handlers.PLAYER_LOGIN()
    local version = getAddonVersion()
    local msg = "FixNagrandMusic v" .. version .. " loaded"
    if not FixNagrandMusicDB.enabled then
        msg = msg .. " (disabled)"
    end
    printInfo(msg)
end
```

### Toggle with Immediate Effect

```lua
-- User decision: toggle OFF stops music immediately, toggle ON starts immediately
local function toggleAddon()
    FixNagrandMusicDB.enabled = not FixNagrandMusicDB.enabled
    if FixNagrandMusicDB.enabled then
        printInfo("Enabled")
        -- If currently in Nagrand, start music right away
        if isInNagrand() then
            activateAddon()
        end
    else
        printInfo("Disabled")
        -- Stop music immediately
        deactivateAddon()
    end
end
```

## Discretion Recommendations

### 1. SavedVariables Structure and Variable Naming

**Recommendation:** Use a single global table `FixNagrandMusicDB` with two boolean keys:

```lua
FixNagrandMusicDB = {
    enabled = true,   -- addon active (default: true)
    debug = false,    -- debug output (default: false)
}
```

**Rationale:**
- Table-based: extensible if future phases add settings, without new TOC entries
- `FixNagrandMusicDB` matches the existing TOC declaration (already declared in Phase 1)
- Short key names (`enabled`, `debug`) -- no prefixing needed inside a table
- Defaults: enabled=true (addon should work on first install), debug=false (quiet by default)
- Change TOC from `SavedVariables` to `SavedVariablesPerCharacter` per UI-05 requirement

**Confidence:** HIGH -- standard WoW addon convention for small addons.

### 2. Exact WoW Color Escape Codes for Debug Yellow

**Recommendation:** Use `|cFFFFFF00` for debug yellow text.

- `FFFF00` = pure yellow (R=255, G=255, B=0)
- This is the standard yellow used in WoW system messages and debug output
- Alpha is always `FF` (fully opaque)
- Format: `|cFFFFFF00[DEBUG] message text|r`

**Alternative considered:** `FFD700` (gold) -- slightly warmer, used for gold currency. Rejected because pure yellow stands out better against the black chat background and is the conventional debug color.

**Confidence:** HIGH -- verified from warcraft.wiki.gg escape sequences documentation.

### 3. How to Read Version from TOC Metadata

**Recommendation:** Use `C_AddOns.GetAddOnMetadata("FixNagrandMusic", "Version")`.

- Confirmed available in TBC Anniversary 2.5.5 (patch 65463) per warcraft.wiki.gg
- The legacy `GetAddOnMetadata()` (without namespace) is deprecated and removed in 11.0.2, but still works in TBC Anniversary
- Prefer the new `C_AddOns` namespace to be forward-compatible
- Handle the `@project-version@` token: if the returned string contains `@`, display `"dev"` instead

**Confidence:** HIGH -- `C_AddOns.GetAddOnMetadata` confirmed available in 2.5.5 per warcraft.wiki.gg version tags.

### 4. Error Handling for Edge Cases

**Recommendation:**

- **SavedVariables not yet loaded:** Guard `printDebug()` with `FixNagrandMusicDB and FixNagrandMusicDB.debug` check. Since debug prints only fire in event handlers (which run after `ADDON_LOADED`), this is belt-and-suspenders safety.
- **C_AddOns not available:** Wrap in `if C_AddOns and C_AddOns.GetAddOnMetadata then` for safety. Fall back to `"?"` for version.
- **currentTrackID is nil in status display:** Show `"No track playing"` or similar instead of erroring.
- **FixNagrandMusicDB.enabled is nil at toggle time:** Should never happen after `ADDON_LOADED` sets defaults, but treat nil as true (addon enabled) to fail safe.

**Confidence:** HIGH -- defensive programming patterns.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `GetAddOnMetadata(name, field)` | `C_AddOns.GetAddOnMetadata(name, field)` | 10.1.0 / backported to 2.5.5 | Use `C_AddOns` namespace. Legacy function still works in TBC Anniversary but is deprecated. |
| `VARIABLES_LOADED` event | `ADDON_LOADED` event | Classic 1.13.2 | `ADDON_LOADED` is the canonical event for SavedVariables initialization. `VARIABLES_LOADED` is less reliable. |

**Deprecated/outdated:**
- `GetAddOnMetadata()` (without namespace): Deprecated in 10.1.0, removed in 11.0.2. Still works in TBC Anniversary 2.5.5 but prefer `C_AddOns.GetAddOnMetadata()`.

## Open Questions

1. **ADDON_LOADED `containsBindings` parameter in TBC Anniversary**
   - What we know: Patch 10.1.0 added a second parameter `containsBindings` to `ADDON_LOADED`. TBC Anniversary is 2.5.5.
   - What's unclear: Whether TBC Anniversary's `ADDON_LOADED` fires with one or two arguments.
   - Recommendation: Only use `addonName` (first arg). Ignore second parameter. No impact on implementation.

2. **Chat frame readiness during PLAYER_LOGIN**
   - What we know: `PLAYER_LOGIN` fires during the loading screen. Standard addons print login messages here successfully.
   - What's unclear: Whether the message is visible immediately or queued until the chat frame renders.
   - Recommendation: Use `PLAYER_LOGIN` as planned. If the message does not appear, fall back to printing in `PLAYER_ENTERING_WORLD` instead. This is LOW risk -- virtually all addons use `PLAYER_LOGIN` for this purpose.

## Sources

### Primary (HIGH confidence)
- [warcraft.wiki.gg: Creating a slash command](https://warcraft.wiki.gg/wiki/Creating_a_slash_command) -- SlashCmdList pattern, argument parsing, registration
- [warcraft.wiki.gg: Saving variables between game sessions](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions) -- SavedVariables/SavedVariablesPerCharacter, ADDON_LOADED timing, initialization pattern
- [warcraft.wiki.gg: API C_AddOns.GetAddOnMetadata](https://warcraft.wiki.gg/wiki/API_C_AddOns.GetAddOnMetadata) -- Function signature, TBC Anniversary 2.5.5 (65463) availability confirmed
- [warcraft.wiki.gg: API GetAddOnMetadata](https://warcraft.wiki.gg/wiki/API_GetAddOnMetadata) -- Legacy function, deprecation in 10.1.0, removal in 11.0.2
- [warcraft.wiki.gg: ADDON_LOADED](https://warcraft.wiki.gg/wiki/ADDON_LOADED) -- Event payload (addonName), SavedVariables timing, BC Anniversary confirmed
- [warcraft.wiki.gg: PLAYER_LOGIN](https://warcraft.wiki.gg/wiki/PLAYER_LOGIN) -- Fires before PLAYER_ENTERING_WORLD, no payload, BC Anniversary confirmed
- [warcraft.wiki.gg: AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process) -- Event sequence: ADDON_LOADED -> PLAYER_LOGIN -> PLAYER_ENTERING_WORLD
- [warcraft.wiki.gg: Escape sequences](https://warcraft.wiki.gg/wiki/Escape_sequences) -- `|cAARRGGBB` color syntax, `|r` reset, nested color behavior
- [warcraft.wiki.gg: TOC format](https://warcraft.wiki.gg/wiki/TOC_format) -- SavedVariables vs SavedVariablesPerCharacter directives, Interface 20505
- [warcraft.wiki.gg: FileDataID](https://warcraft.wiki.gg/wiki/FileDataID) -- No runtime API to resolve FileDataID to path; must use hardcoded lookup

### Secondary (MEDIUM confidence)
- [GitHub: ChocolateBar GetAddOnMetadata deprecation issue](https://github.com/Kiatra/ChocolateBar/issues/35) -- Confirms C_AddOns namespace works across all WoW versions including Classic flavors
- [Wowpedia: AddOn loading process](https://wowpedia.fandom.com/wiki/AddOn_loading_process) -- Cross-verification of event timing sequence

### Tertiary (LOW confidence)
- None -- all findings verified via primary sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All APIs confirmed available in TBC Anniversary 2.5.5 via warcraft.wiki.gg version tags
- Architecture: HIGH -- Surgical additions to existing Phase 1 code structure; patterns well-established
- Pitfalls: HIGH -- All critical timing issues (ADDON_LOADED, SavedVariables scope) documented with prevention strategies
- Discretion areas: HIGH -- Standard WoW addon conventions, no ambiguity

**Research date:** 2026-02-19
**Valid until:** 2026-03-21 (30 days -- stable domain, WoW API does not change mid-expansion)
