-- FixNagrandMusic
-- Fixes the bug where Orgrimmar drum music plays in Nagrand instead of the
-- correct TBC zone music. Detects Nagrand, plays the right tracks with
-- day/night variants, handles loading screens and subzone transitions.

-- === SECTION 1: MUSIC DATA ===

-- Source: Wowhead TBC sound database
-- Day: https://www.wowhead.com/tbc/sound=9012/zone-nagrandday
-- Night: https://www.wowhead.com/tbc/sound=9013/zone-nagrandnight
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
}

-- FileDataID to file path lookup for status display (UI-01)
-- No runtime API exists to resolve FileDataID to path; hardcoded from Wowhead TBC sound database
local TRACK_PATHS = {
    [53585] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkDay01.mp3",
    [53586] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkDay02.mp3",
    [53587] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkDay03.mp3",
    [53588] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkNight01.mp3",
    [53589] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkNight02.mp3",
    [53590] = "Sound\\Music\\ZoneMusic\\Nagrand\\NA_GeneralWalkNight03.mp3",
}

-- UiMapID for Nagrand (Outland). Needs in-game validation -- may be 477.
local NAGRAND_MAP_ID = 107

-- Fallback zone text detection (proper noun, likely same across locales)
local NAGRAND_ZONE_TEXT = "Nagrand"

-- === SECTION 2: STATE VARIABLES ===

local currentTrackID = nil     -- currently playing FileDataID
local isActive = false         -- whether addon is actively managing music
local lastTimeOfDay = nil      -- last known day/night state (true = day)
local savedMusicCVar = nil     -- user's original Sound_EnableMusic value
local currentSubzone = nil     -- current subzone name from GetSubZoneText() (MFIX-02, used by Phase 2 UI-01)

-- === SECTION 3: UTILITY FUNCTIONS ===

local FNG_PREFIX = "|cFF00CC66FNG|r: "

local function printError(msg)
    print(FNG_PREFIX .. "|cFFFF0000" .. msg .. "|r")
end

local function printInfo(msg)
    print(FNG_PREFIX .. msg)
end

local function printDebug(msg)
    if FixNagrandMusicDB and FixNagrandMusicDB.debug then
        print(FNG_PREFIX .. "|cFFFFFF00[DEBUG] " .. msg .. "|r")
    end
end

local function getAddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local version = C_AddOns.GetAddOnMetadata("FixNagrandMusic", "Version")
        if version and not version:find("@") then
            return version
        end
    end
    return "dev"
end

-- Update the tracked subzone name (MFIX-02)
local function updateSubzone()
    currentSubzone = GetSubZoneText() or ""
end

-- === SECTION 4: ZONE DETECTION (MFIX-01, MFIX-02) ===

-- Dual-method detection: numeric map ID (locale-safe) with zone text fallback
local function isInNagrand()
    -- Primary: locale-safe numeric method
    if C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID == NAGRAND_MAP_ID then
            return true
        end
    end
    -- Fallback: zone text comparison ("Nagrand" is a proper noun)
    return GetZoneText() == NAGRAND_ZONE_TEXT
end

-- === SECTION 5: DAY/NIGHT DETECTION (MFIX-03) ===

-- Returns true during daytime hours (6:00 - 17:59 server time)
-- Breakpoints: 6:00 dawn, 18:00 dusk (community convention, closest
-- approximation of WoW's built-in day/night cycle for music)
local function isDayTime()
    local hours = GetGameTime()
    return hours >= 6 and hours < 18
end

-- === SECTION 6: MUSIC PLAYBACK (MFIX-03, MFIX-04, MFIX-05, MFIX-09) ===

-- Returns a random track FileDataID from the appropriate time-of-day pool
local function getRandomTrack()
    local pool = isDayTime() and NAGRAND_TRACKS.day or NAGRAND_TRACKS.night
    return pool[math.random(#pool)]
end

-- Returns true if the given track belongs to the current time-of-day pool
local function isTrackInCurrentPool(trackID)
    if trackID == nil then
        return false
    end
    local pool = isDayTime() and NAGRAND_TRACKS.day or NAGRAND_TRACKS.night
    for _, id in ipairs(pool) do
        if id == trackID then
            return true
        end
    end
    return false
end

-- Play the correct Nagrand music track.
-- IMPORTANT: Does NOT call StopMusic() before PlayMusic() -- calling
-- PlayMusic() directly replaces the current track and auto-fades the
-- buggy built-in zone music without a gap where drums could re-assert.
local function playNagrandMusic()
    -- Respect toggle state (UI-02)
    if FixNagrandMusicDB and not FixNagrandMusicDB.enabled then
        return
    end

    -- Track the current subzone on every music evaluation (MFIX-02)
    updateSubzone()

    -- Respect user's music setting (MFIX-04 pitfall 5)
    if GetCVar("Sound_EnableMusic") ~= "1" then
        printInfo("Music is disabled in your settings. Enable it to hear the fix.")
        return
    end

    -- If a track from the correct time-of-day pool is already playing,
    -- do not restart it (MFIX-05 seamless subzone transitions)
    if currentTrackID and isTrackInCurrentPool(currentTrackID) then
        return
    end

    -- Pick a new random track from the appropriate pool
    local newTrack = getRandomTrack()
    if not newTrack then
        printError("Could not determine correct track for Nagrand.")
        return
    end

    -- Play the track -- this auto-fades buggy drum music (MFIX-04)
    PlayMusic(newTrack)
    currentTrackID = newTrack
    isActive = true
    lastTimeOfDay = isDayTime()
end

-- Stop addon-played music and reset state.
-- StopMusic() only stops addon-played music; built-in zone music resumes
-- naturally for other zones.
local function stopNagrandMusic()
    if not isActive then
        return
    end
    StopMusic()
    currentTrackID = nil
    isActive = false
    lastTimeOfDay = nil
end

-- === SECTION 7: DAY/NIGHT MONITORING (MFIX-03) ===

-- Forward declaration for the self-sustaining timer
local startDayNightTimer

-- Checks every 60 seconds if day/night has changed. If it has, switches
-- to a track from the new time-of-day pool. Stops when addon deactivates
-- (isActive becomes false).
startDayNightTimer = function()
    if not isActive then
        return  -- Stop the timer chain when not in Nagrand
    end

    local isDay = isDayTime()
    if lastTimeOfDay ~= nil and lastTimeOfDay ~= isDay then
        -- Day/night transition occurred -- switch to new pool
        local newTrack = getRandomTrack()
        if newTrack then
            -- Play directly without StopMusic() to avoid drum gap
            PlayMusic(newTrack)
            currentTrackID = newTrack
        else
            printError("Could not determine correct track after day/night transition.")
        end
    end
    lastTimeOfDay = isDay

    -- Schedule next check in 60 seconds
    C_Timer.After(60, startDayNightTimer)
end

-- === SECTION 8: ACTIVATION/DEACTIVATION (MFIX-06, MFIX-08) ===

-- Activate the addon when entering Nagrand
local function activateAddon()
    -- Respect toggle state (UI-02)
    if FixNagrandMusicDB and not FixNagrandMusicDB.enabled then
        return
    end

    -- Save user's current music setting before any potential changes
    savedMusicCVar = GetCVar("Sound_EnableMusic")

    -- Attempt to play music (handles disabled-music case internally)
    playNagrandMusic()

    -- Start the day/night monitoring timer only if music is actually playing
    if isActive then
        startDayNightTimer()
    end
end

-- Deactivate the addon when leaving Nagrand or logging out
local function deactivateAddon()
    stopNagrandMusic()
    currentSubzone = nil

    -- Restore CVar if we modified it
    if savedMusicCVar and savedMusicCVar ~= GetCVar("Sound_EnableMusic") then
        SetCVar("Sound_EnableMusic", savedMusicCVar)
    end
    savedMusicCVar = nil
end

-- === SECTION 9: EVENT HANDLERS (MFIX-01, MFIX-06, MFIX-07, MFIX-08) ===

local frame
local handlers = {}

-- SavedVariables initialization (UI-05)
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
    frame:UnregisterEvent("ADDON_LOADED")
end

-- Login notification (UI-04)
function handlers.PLAYER_LOGIN()
    local version = getAddonVersion()
    local msg = "FixNagrandMusic v" .. version .. " loaded"
    if not FixNagrandMusicDB.enabled then
        msg = msg .. " (disabled)"
    end
    printInfo(msg)
end

-- Major zone change: entering or leaving Nagrand
function handlers.ZONE_CHANGED_NEW_AREA()
    -- Defer by one frame to ensure zone data is current
    C_Timer.After(0, function()
        printDebug("ZONE_CHANGED_NEW_AREA: " .. (GetZoneText() or "?") .. " / " .. (GetSubZoneText() or ""))
        if isInNagrand() then
            if not isActive then
                activateAddon()
            end
        else
            if isActive then
                deactivateAddon()
            end
        end
    end)
end

-- Subzone change within Nagrand: re-assert PlayMusic to suppress any
-- drum re-triggering from the zone music system (MFIX-05, MFIX-09)
function handlers.ZONE_CHANGED()
    printDebug("ZONE_CHANGED: " .. (GetZoneText() or "?") .. " / " .. (GetSubZoneText() or ""))
    if isActive then
        playNagrandMusic()
    end
    -- Do nothing outside Nagrand (MFIX-06)
end

-- Indoor/outdoor transition: same as ZONE_CHANGED.
-- Nagrand has no separate indoor music, so we just re-assert the track.
function handlers.ZONE_CHANGED_INDOORS()
    printDebug("ZONE_CHANGED_INDOORS: " .. (GetZoneText() or "?") .. " / " .. (GetSubZoneText() or ""))
    if isActive then
        playNagrandMusic()
    end
    -- Do nothing outside Nagrand (MFIX-06)
end

-- Loading screen recovery: login, reload, instance transitions (MFIX-07)
function handlers.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    -- Defer by one frame to ensure zone data is updated after loading screen
    C_Timer.After(0, function()
        if isInNagrand() then
            activateAddon()
        else
            if isActive then
                deactivateAddon()
            end
        end
    end)
end

-- Cleanup on logout (MFIX-08)
function handlers.PLAYER_LOGOUT()
    deactivateAddon()
end

-- === SECTION 10: FRAME SETUP ===

frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, event, ...)
    if handlers[event] then
        handlers[event](...)
    end
end)

-- Register all events that have handlers
for event in pairs(handlers) do
    frame:RegisterEvent(event)
end

-- === SECTION 11: SLASH COMMANDS (UI-01, UI-02, UI-03) ===

local function showStatus()
    if not FixNagrandMusicDB.enabled then
        printInfo("Disabled")
        return
    end
    if not isActive then
        printInfo("Enabled | Not in Nagrand")
        return
    end
    local path = TRACK_PATHS[currentTrackID] or "No track playing"
    local subzone = currentSubzone
    if not subzone or subzone == "" then
        subzone = "open area"
    end
    printInfo("Enabled | " .. subzone .. " | " .. path)
end

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

local function toggleDebug()
    FixNagrandMusicDB.debug = not FixNagrandMusicDB.debug
    if FixNagrandMusicDB.debug then
        printInfo("Debug mode ON")
    else
        printInfo("Debug mode OFF")
    end
end

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
