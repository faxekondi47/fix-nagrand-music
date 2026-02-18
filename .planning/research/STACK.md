# Stack Research

**Domain:** WoW addon development (TBC Classic Anniversary music fix)
**Researched:** 2026-02-18
**Confidence:** MEDIUM -- core stack is well-established, but TBC Anniversary client specifics (FileDataID vs path support, C_Map availability) need in-game validation

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Lua 5.1 (WoW sandbox) | 5.1 (Blizzard custom) | Addon scripting language | The only option. WoW runs a custom Lua 5.1 sandbox with no io/os access. All addon logic is written in Lua. |
| WoW TOC format | Interface 20505 | Addon manifest/loader | Required metadata file that registers the addon with the client. TBC Classic Anniversary uses Interface version 20505 (patch 2.5.5). |
| WoW XML (optional) | N/A | UI frame definitions | Not needed for this addon -- we have no custom UI. All logic is event-driven Lua with no visible frames. |

### WoW API -- Music Control

| API Function | Purpose | Why Recommended | Confidence |
|--------------|---------|-----------------|------------|
| `PlayMusic(sound)` | Play music on loop to Music channel | Core function for overriding broken zone music. Accepts FileDataID (number) or addon file path (string). Fades out built-in zone music when called. Loops until `StopMusic()` is called. | HIGH |
| `StopMusic()` | Stop addon-played music | Stops only music started by `PlayMusic()`, does NOT affect built-in zone music. Use when player leaves Nagrand to let normal music resume. | HIGH |
| `PlaySoundFile(sound [, channel])` | Play a one-shot sound | Alternative to PlayMusic -- plays once without looping. Accepts FileDataID or addon path. Returns `willPlay, soundHandle`. Use "Music" channel to route through music volume. Less suitable than PlayMusic for continuous zone music. | HIGH |

### WoW API -- Zone Detection

| API Function | Purpose | Why Recommended | Confidence |
|--------------|---------|-----------------|------------|
| `GetZoneText()` | Returns current zone name (e.g. "Nagrand") | Primary zone detection. Use to check if player is in Nagrand. Fires with `ZONE_CHANGED_NEW_AREA` event. | HIGH |
| `GetSubZoneText()` | Returns current subzone name (e.g. "Garadar", "Halaa") | Subzone-level detection for playing different music tracks in different parts of Nagrand. Returns empty string if no subzone. | HIGH |
| `GetMinimapZoneText()` | Returns minimap zone text | Equals `GetSubZoneText()` if in a subzone, otherwise equals `GetZoneText()`. Useful fallback. | HIGH |
| `C_Map.GetBestMapForUnit("player")` | Returns current UiMapID | Available in TBC Classic Anniversary (modern client). Nagrand Outland UiMapID = 477. More reliable than string comparison for zone detection. | MEDIUM -- needs in-game verification |

### WoW Events

| Event | When It Fires | Use Case | Confidence |
|-------|---------------|----------|------------|
| `ZONE_CHANGED_NEW_AREA` | Player enters a new major zone | Detect entering/leaving Nagrand. No payload args -- call `GetZoneText()` inside handler. | HIGH |
| `ZONE_CHANGED` | Player moves between subzones | Detect subzone changes within Nagrand to switch music tracks. Call `GetSubZoneText()` inside handler. | HIGH |
| `ZONE_CHANGED_INDOORS` | Player enters/exits indoor area | May fire in Nagrand caves or buildings. Handle alongside ZONE_CHANGED. | HIGH |
| `PLAYER_ENTERING_WORLD` | Login/reload/instance transition | Initialize addon state on first load. Check if already in Nagrand. | HIGH |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| VS Code + sumneko Lua (LuaLS) | IDE with Lua 5.1 language server | Primary editor. Provides IntelliSense, diagnostics, type annotations. Use Lua 5.1 runtime setting. |
| Ketho/vscode-wow-api | WoW API annotations for LuaLS | Third-party LuaLS addon that provides autocomplete for WoW API functions, events, widgets, CVars, enums. Supports Classic flavors. |
| Septh/vscode-wow-bundle | TOC + Lua syntax highlighting | WoW-specific syntax grammar for `.toc` files and Lua with WoW API coloring. |
| BugSack + BugGrabber | In-game error display | Essential for testing. BugGrabber captures Lua errors; BugSack displays them with full stack traces. Install both in your WoW client during development. |
| `/reload` command | Reload UI in-game | Fastest iteration cycle: edit Lua file, save, `/reload` in game. No restart needed. |
| `/run` command | Execute Lua in-game | Quick testing: `/run print(GetZoneText(), GetSubZoneText())` to verify API behavior. |

### Packaging & Distribution

| Tool | Purpose | Notes |
|------|---------|-------|
| BigWigsMods/packager | Addon packaging + upload | Industry standard. Generates zip, uploads to CurseForge/WoWInterface/Wago/GitHub Releases from git tags. Use v2 GitHub Action. |
| GitHub Actions | CI/CD pipeline | Trigger packaging on git tag push. BigWigsMods/packager@v2 handles everything. |
| `.pkgmeta` or `pkgmeta.yaml` | Packager configuration | Defines package name, externals (libraries), ignored files. Place in repo root. Use spaces not tabs. |

## File Structure

```
FixNagrandMusic/
  FixNagrandMusic.toc          -- Addon manifest (required, must match folder name)
  FixNagrandMusic.lua          -- Main addon logic
  .pkgmeta                     -- Packager config (for CurseForge releases)
  README.md                    -- GitHub readme
  LICENSE                      -- License file
  .github/
    workflows/
      release.yml              -- GitHub Actions workflow for packaging
```

### TOC File Format

```toc
## Interface: 20505
## Title: FixNagrandMusic
## Notes: Fixes the bug where Orgrimmar music plays in Nagrand instead of the correct zone music.
## Author: YourName
## Version: @project-version@
## X-Category: Audio & Video

FixNagrandMusic.lua
```

Key TOC details:
- `## Interface: 20505` -- TBC Classic Anniversary (patch 2.5.5)
- TOC file name MUST match the addon folder name exactly
- `@project-version@` is replaced by BigWigsMods packager with the git tag
- The `_TBC.toc` suffix convention exists for multi-flavor addons, but since this addon is TBC-only, the base `.toc` name is sufficient

### GitHub Actions Workflow

```yaml
name: Package and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: BigWigsMods/packager@v2
        with:
          args: -g bcc
        env:
          CF_API_KEY: ${{ secrets.CF_API_KEY }}
          GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
```

The `-g bcc` flag tells the packager this is a Burning Crusade Classic addon.

## Critical Technical Notes

### PlayMusic Behavior -- File Path vs FileDataID

**This is the most important uncertainty in the stack.**

TBC Classic Anniversary runs on a **modern retail-based client engine**, not the original 2.4.3 client. This has major implications:

- **Retail (post-8.2.0):** `PlayMusic()` only accepts FileDataIDs (numbers), not internal file paths
- **Original TBC Classic (pre-Anniversary):** `PlayMusic()` accepted file paths like `"Sound\\Music\\ZoneMusic\\..."`
- **TBC Classic Anniversary:** UNKNOWN which behavior applies. The modern engine suggests FileDataIDs should work. File paths may or may not work.

**Recommendation:** Support BOTH approaches with a fallback. Try FileDataID first; if it fails, try file path. Test in-game early in development.

```lua
-- Approach 1: FileDataID (modern client)
PlayMusic(607665)  -- Example ID, needs verification

-- Approach 2: File path (legacy client)
PlayMusic("Sound\\Music\\ZoneMusic\\Nagrand\\NagrandWalk1.mp3")  -- Example, needs verification

-- Approach 3: Addon-bundled file path (always works)
PlayMusic("Interface\\AddOns\\FixNagrandMusic\\music\\NagrandDay.ogg")
```

**IMPORTANT:** The actual Nagrand music FileDataIDs and file paths need to be discovered. Options:
1. Use wow.tools file database to search for Nagrand music files
2. Use Leatrix Sounds addon in-game to browse/search Nagrand zone music
3. Extract from game data files and inspect ZoneMusic.dbc

### Music Override Behavior

When `PlayMusic()` is called:
1. Built-in zone music **fades out**
2. The specified music **loops continuously**
3. Music stops when `StopMusic()` is called, UI is reloaded, or on logout
4. After `StopMusic()`, the game's built-in zone music **should resume** (this needs verification -- the official docs do not explicitly confirm resumption behavior)

### Zone Event Race Condition

`ZONE_CHANGED_NEW_AREA` has a known race condition: it can fire before or after `GetZoneText()` updates, because the event is sometimes throttled to prevent rapid zone channel switching. **Mitigation:** Add a short `C_Timer.After(0.5, callback)` delay before reading zone text, or verify the zone text in a repeated check.

**Confidence: MEDIUM** -- race condition is documented on WoWWiki but not on official warcraft.wiki.gg docs. Needs in-game testing.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `PlayMusic()` for looping zone music | `PlaySoundFile()` on "Music" channel | Only if PlayMusic has issues; PlaySoundFile does not loop so you would need manual re-triggering |
| `GetZoneText()` string comparison | `C_Map.GetBestMapForUnit()` map ID comparison | If string comparison causes localization issues (zone names differ by language). Map IDs are locale-independent. |
| Single `.lua` file | Multiple files (Core.lua, Music.lua, Events.lua) | Only if the addon grows beyond ~300 lines. For a simple music fix, one file is cleaner. |
| BigWigsMods/packager | Manual zip + CurseForge upload | Never -- manual packaging is error-prone and doesn't handle version tokens |
| VS Code + LuaLS | IntelliJ + EmmyLua | If you prefer IntelliJ. LuaLS has better WoW-specific annotations via Ketho's extension. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Ace3 / LibStub libraries | Massive overkill for a simple music fix addon. Ace3 is for complex addons with config UIs, databases, and slash commands. | Raw WoW API -- this addon needs ~50-100 lines of Lua total. |
| XML frame definitions | No UI elements needed. The addon runs entirely in the background. | `CreateFrame("Frame")` in Lua for event registration. |
| SavedVariables | No user configuration needed in v1. The addon has one job: fix the music. | Hardcoded music data. Add SavedVariables later if user config is needed. |
| `C_Timer.NewTicker` for polling | Polling zone text every N seconds wastes CPU. | Event-driven: register `ZONE_CHANGED`/`ZONE_CHANGED_NEW_AREA` and react to events. |
| Custom `.ogg`/`.mp3` music files bundled in addon | Bloats addon size, licensing issues with game audio, unnecessary when game already has the correct files. | Play the game's own music files via FileDataID or internal path. The music exists in the game data -- it is just not triggering for Nagrand. |

## Stack Patterns by Variant

**If FileDataIDs work in TBC Classic Anniversary (likely):**
- Use `PlayMusic(fileDataID)` with numeric IDs discovered via wow.tools
- Simplest approach, no file bundling needed
- Addon stays tiny (single .lua + .toc)

**If FileDataIDs do NOT work (fallback):**
- Use `PlayMusic("Sound\\Music\\ZoneMusic\\...")` with internal file paths
- Still no file bundling needed if the client supports internal paths
- If neither works, bundle `.ogg` files in the addon folder (last resort)

**If localization is a concern:**
- Use `C_Map.GetBestMapForUnit("player")` returning UiMapID 477 for Nagrand
- Avoids comparing against English zone name strings
- Works for all client languages

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| Interface 20505 | TBC Classic Anniversary (2.5.5) | Set `## Interface: 20505` in TOC. Client warns if mismatched but addon still loads with "Load out of date addons" enabled. |
| PlayMusic (FileDataID) | Modern client engine | TBC Anniversary uses modern engine; FileDataIDs should work. VERIFY IN-GAME. |
| PlayMusic (file path) | Legacy client only (pre-8.2.0) | May not work on Anniversary modern client. Do not rely on this alone. |
| C_Map.GetBestMapForUnit | TBC Classic (confirmed), Anniversary (likely) | Backported from retail 8.0.1. Community reports it works in TBC Classic. |
| GetZoneText / GetSubZoneText | All WoW versions since 1.0 | Fundamental API, always available. |
| ZONE_CHANGED events | All WoW versions since 1.0 | Fundamental events, always available. |
| BigWigsMods/packager@v2 | TBC Classic (`-g bcc` flag) | Explicitly supports BCC flavor for packaging and CurseForge upload. |

## Nagrand Zone Data Reference

### Zone Identification

| Method | Value | Notes |
|--------|-------|-------|
| `GetZoneText()` | `"Nagrand"` | English client. Other locales will differ. |
| Zone ID (AreaID) | 3518 | Internal zone identifier |
| UiMapID | 477 | For `C_Map.GetBestMapForUnit()`. MEDIUM confidence -- needs verification. |
| WorldMapAreaID | 477 | Deprecated in favor of UiMapID but same value. |

### Known Nagrand Subzones (from `GetSubZoneText()`)

Aeris Landing, Abandoned Armory, Ancestral Grounds, Arena Floor, The Barrier Hills, Burning Blade Ruins, Clan Watch, Elemental Plateau, Forge Camp: Fear, Forge Camp: Hate, Garadar, Halaa, Halaani Basin, The High Path, Kil'sorrow Fortress, Lake Sunspring, Laughing Skull Courtyard, Laughing Skull Ruins, The Low Path, Mag'hari Procession, Nesingwary Safari, Northwind Cleft, Oshu'gun, The Ring of Blood, The Ring of Trials, Skysong Lake, Southwind Cleft, Spirit Fields, Sunspring Post, Telaar, Telaari Basin, Throne of the Elements, The Twilight Ridge, Warmaul Hill, Windyreed Pass, Windyreed Village, Zangar Ridge

### Music FileDataIDs

**UNKNOWN -- needs discovery.** The specific FileDataIDs for Nagrand's correct zone music tracks must be found before implementation. Approaches:

1. **wow.tools** -- Search https://wow.tools/files/ for "nagrand" in the music paths
2. **Leatrix Sounds** addon -- Browse zone music in-game, filter by Nagrand
3. **ZoneMusic.dbc** extraction -- The database table mapping zones to music entries
4. **Wowhead sound database** -- https://www.wowhead.com/sounds/zone-music filtered to zone 3518

This is a **Phase 1 blocker** -- the addon cannot be built without knowing what music to play.

## Sources

- [warcraft.wiki.gg: TOC format](https://warcraft.wiki.gg/wiki/TOC_format) -- TOC field reference, flavor suffixes, Interface version 20505 (HIGH confidence)
- [warcraft.wiki.gg: API PlayMusic](https://warcraft.wiki.gg/wiki/API_PlayMusic) -- PlayMusic signature, FileDataID change in 8.2.0, zone music fade behavior (HIGH confidence)
- [warcraft.wiki.gg: API StopMusic](https://warcraft.wiki.gg/wiki/API_StopMusic) -- StopMusic only affects addon-played music (HIGH confidence)
- [warcraft.wiki.gg: API PlaySoundFile](https://warcraft.wiki.gg/wiki/API_PlaySoundFile) -- PlaySoundFile signature, channel parameter, format support (HIGH confidence)
- [warcraft.wiki.gg: API GetSubZoneText](https://warcraft.wiki.gg/wiki/API_GetSubZoneText) -- Subzone detection (HIGH confidence)
- [warcraft.wiki.gg: API GetZoneText](https://warcraft.wiki.gg/wiki/API_GetZoneText) -- Zone name retrieval (HIGH confidence)
- [warcraft.wiki.gg: ZONE_CHANGED_NEW_AREA](https://warcraft.wiki.gg/wiki/ZONE_CHANGED_NEW_AREA) -- Event docs, no payload (HIGH confidence)
- [warcraft.wiki.gg: Nagrand](https://warcraft.wiki.gg/wiki/Nagrand) -- Complete subzone list (HIGH confidence)
- [warcraft.wiki.gg: WorldMapAreaID](https://warcraft.wiki.gg/wiki/WorldMapAreaID) -- Nagrand WorldMapAreaID = 477 (HIGH confidence)
- [GitHub: BigWigsMods/packager](https://github.com/BigWigsMods/packager) -- Packaging tool, GitHub Actions usage, BCC support (HIGH confidence)
- [GitHub: Ketho/vscode-wow-api](https://github.com/Ketho/vscode-wow-api) -- VS Code WoW API annotations (HIGH confidence)
- [us.forums.blizzard.com: Orgrimmar music in Nagrand](https://us.forums.blizzard.com/en/wow/t/orgrimmar-music-in-nagrand/1028737) -- Bug confirmation, intermittent Org music in Nagrand (MEDIUM confidence)
- [us.forums.blizzard.com: Is Nagrand music busted](https://us.forums.blizzard.com/en/wow/t/is-nagrand-music-busted/2250797) -- Ongoing bug in TBC Anniversary (MEDIUM confidence)
- [eu.forums.blizzard.com: Nagrand music bug](https://eu.forums.blizzard.com/en/wow/t/nagrand-music-bug-pls-fix-blizzard/606156) -- EU reports of same bug (MEDIUM confidence)
- [CurseForge: BugSack](https://www.curseforge.com/wow/addons/bugsack) -- Error display addon for testing (HIGH confidence)
- [CurseForge: BugGrabber](https://www.curseforge.com/wow/addons/bug-grabber) -- Error capture addon for testing (HIGH confidence)
- [support.curseforge.com: Preparing PackageMeta](https://support.curseforge.com/en/support/solutions/articles/9000197952-preparing-the-packagemeta-file) -- .pkgmeta format reference (HIGH confidence)
- [Wowhead: Comprehensive Beginner's Guide](https://www.wowhead.com/guide/comprehensive-beginners-guide-for-wow-addon-coding-in-lua-5338) -- General addon development patterns (MEDIUM confidence)
- [WoWWiki: API GetZoneText race condition](https://wowwiki-archive.fandom.com/wiki/API_GetZoneText) -- ZONE_CHANGED_NEW_AREA race condition note (LOW confidence -- old source, needs verification)

---
*Stack research for: FixNagrandMusic (WoW TBC Classic Anniversary addon)*
*Researched: 2026-02-18*
