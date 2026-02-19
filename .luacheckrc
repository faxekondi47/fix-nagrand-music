-- Luacheck configuration for FixNagrandMusic

std = "lua51"
max_line_length = false

exclude_files = {
    ".release",
}

-- Addon globals (writable)
globals = {
    "FixNagrandMusicDB",          -- SavedVariablesPerCharacter
    "SLASH_FNG1",                 -- Slash command registration
    "SlashCmdList",               -- WoW slash command table
}

-- WoW API globals (read-only) -- only what this addon actually uses
read_globals = {
    -- Frames
    "CreateFrame",
    "UIParent",

    -- Zone detection
    "C_Map",
    "GetZoneText",
    "GetSubZoneText",

    -- Music
    "PlayMusic",
    "StopMusic",

    -- Time
    "GetGameTime",

    -- Timer
    "C_Timer",

    -- Settings
    "GetCVar",
    "SetCVar",

    -- Addon metadata
    "C_AddOns",

    -- Output
    "print",
}
