# Phase 3: Packaging and Release - Research

**Researched:** 2026-02-19
**Domain:** CI/CD pipeline, WoW addon packaging, CurseForge distribution
**Confidence:** HIGH

## Summary

Phase 3 packages the feature-complete FixNagrandMusic addon for distribution via GitHub Actions CI/CD. The ecosystem has a well-established, de facto standard toolchain: BigWigsMods/packager (v2.5.1, released 2025-12-02) handles packaging, version substitution, changelog generation, and simultaneous upload to CurseForge and GitHub Releases -- all in a single action step. The addon already has the `@project-version@` placeholder in its .toc file, meaning the version flow from git tag to .toc to in-game messages is already wired. Luacheck (via lunarmodules/luacheck@v1 GitHub Action) provides Lua linting with a WoW-specific `.luacheckrc`. The .pkgmeta file needs only a minimal configuration since the addon has no external dependencies.

The critical insight is that BigWigsMods/packager handles nearly everything: it replaces `@project-version@` in all files during packaging, auto-generates a changelog from commits between tags, creates a GitHub Release with the zip attached, and uploads to CurseForge with the correct game version detected from the .toc `## Interface:` line. The pipeline is simpler than it might appear -- the heavy lifting is already built into the packager.

**Primary recommendation:** Use BigWigsMods/packager@v2 as the single packaging/release tool, add lunarmodules/luacheck@v1 as a pre-packaging lint step, and keep the .pkgmeta minimal (just `package-as` and `ignore`).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### README content
- Casual & friendly tone -- conversational, approachable, like a community addon post
- Brief explanation of the bug (1-2 sentences on why Orgrimmar drums play in Nagrand)
- Keep it short: install instructions, usage (`/fng` commands), and that's it
- No troubleshooting/FAQ section -- issues go to GitHub Issues
- No screenshots or media -- it's a background audio fix, nothing visual to show

#### CurseForge listing
- Short elevator pitch (2-3 sentences) -- what it does, how to use, done
- Not a mirror of the README -- tighter, punchier
- Target TBC Classic Anniversary only (the bug is version-specific)
- Category: Audio & Video
- CurseForge API token available for automated uploads

#### Release versioning
- SemVer (major.minor.patch) -- first release is 1.0.0
- CI auto-updates the Version field in .toc from the git tag before packaging
- In-game addon messages must also display the correct version (sourced from git tag, not hardcoded)
- Auto-generate changelog from conventional commits for each release

#### Pipeline scope
- Trigger: git tag push (e.g., v1.0.0) -- no manual dispatch
- Full pipeline: tag push -> Lua lint -> package -> GitHub release + CurseForge upload
- Lua syntax validation (luacheck or similar) runs before packaging
- Release zip contains addon folder only (FixNagrandMusic/ with .toc and .lua) -- no README in zip

### Claude's Discretion
- Exact GitHub Actions workflow structure
- luacheck configuration
- Changelog formatting and commit parsing rules
- CurseForge metadata file format and fields beyond what's specified

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PKG-02 | GitHub Actions workflow using BigWigsMods/packager@v2 for automated releases | BigWigsMods/packager@v2.5.1 is the de facto standard. Triggers on tag push, handles packaging + GitHub Release + CurseForge upload. lunarmodules/luacheck@v1 runs lint before packaging. Full workflow template documented below. |
| PKG-03 | .pkgmeta file configured for CurseForge TBC Classic Anniversary distribution | Minimal .pkgmeta with `package-as` and `ignore`. Game version auto-detected from .toc `## Interface: 20505`. CurseForge project ID set via `## X-Curse-Project-ID` in .toc or `-p` CLI arg. |
| PKG-04 | README.md with installation instructions, usage, and known limitations | Pure documentation task. No tooling research needed -- follows user's locked decisions on tone and content. |
</phase_requirements>

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| BigWigsMods/packager | v2 (latest: v2.5.1) | Packages addon zip, creates GitHub Release, uploads to CurseForge | De facto standard for WoW addon CI/CD. Used by BigWigs, LittleWigs, Auctionator, and hundreds of addons. Single action handles packaging + multi-platform upload. |
| lunarmodules/luacheck | v1 (latest: v1.2.0) | Lua static analysis and linting | Standard Lua linter. Official GitHub Action available. Supports Lua 5.1 (WoW's runtime) with custom globals. |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| actions/checkout | v4 | Clone repository in CI | Required before any other step. Must use `fetch-depth: 0` for full history (needed for changelog generation and tag detection). |

### Alternatives Considered

None. BigWigsMods/packager is the single standard tool for WoW addon packaging. There are no realistic alternatives worth considering -- the entire WoW addon ecosystem uses it or the underlying release.sh script directly.

## Architecture Patterns

### Recommended File Structure (New Files)

```
fix-nagrand-music/
├── .github/
│   └── workflows/
│       └── release.yml          # GitHub Actions workflow
├── .luacheckrc                   # Luacheck configuration
├── .pkgmeta                      # BigWigsMods packager metadata
├── README.md                     # User-facing documentation
└── FixNagrandMusic/
    ├── FixNagrandMusic.toc       # (existing, already has @project-version@)
    └── FixNagrandMusic.lua       # (existing, already reads version via GetAddOnMetadata)
```

### Pattern 1: Version Flow (Single Source of Truth)

**What:** Git tag is the sole version source. The packager replaces `@project-version@` in all files during the build. The Lua code reads the substituted value at runtime.

**When to use:** Always -- this is how the BigWigsMods packager works.

**How it works:**
1. Developer pushes tag `v1.0.0`
2. Packager strips the `v` prefix (configurable) and substitutes `@project-version@` -> `1.0.0` in all packaged files
3. `.toc` file `## Version: @project-version@` becomes `## Version: 1.0.0`
4. Lua code `C_AddOns.GetAddOnMetadata("FixNagrandMusic", "Version")` returns `"1.0.0"`
5. In-game messages display correct version automatically

**Current state:** The addon already implements this pattern:
- `.toc` line 6: `## Version: @project-version@`
- `FixNagrandMusic.lua` lines 68-75: `getAddonVersion()` reads metadata, falls back to `"dev"` if `@project-version@` is still present (unpackaged dev build)

**No code changes needed** for version flow -- it is already wired correctly.

### Pattern 2: Tag-Triggered Release Pipeline

**What:** A single GitHub Actions workflow triggers on tag push, runs lint, packages, and uploads.

**When to use:** Every release.

**Example workflow structure:**
```yaml
# Source: BigWigsMods/packager wiki + verified research
name: Package and release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write    # Required for creating GitHub Releases

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lunarmodules/luacheck@v1

  release:
    runs-on: ubuntu-latest
    needs: lint        # Only package if lint passes
    env:
      CF_API_KEY: ${{ secrets.CF_API_KEY }}
      GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # Full history for changelog + tag detection
      - uses: BigWigsMods/packager@v2
```

### Pattern 3: Minimal .pkgmeta for Simple Addons

**What:** Addons without external library dependencies need only `package-as` and `ignore`.

**When to use:** When the addon is self-contained (no LibStub, no Ace3, no external libs).

**Example:**
```yaml
# Source: BigWigsMods/packager wiki
package-as: FixNagrandMusic

ignore:
  - .github
  - .luacheckrc
  - README.md
  - .planning
```

**Key points:**
- Files beginning with `.` (like `.pkgmeta`, `.gitignore`) are always ignored by the packager automatically -- do not list them
- The `ignore` directive excludes files from the packaged zip
- `package-as` determines the addon folder name inside the zip
- No `externals`, `move-folders`, or `enable-nolib-creation` needed for this addon

### Pattern 4: CurseForge Project Configuration

**What:** CurseForge project ID can be embedded in the .toc file or passed as a CLI argument.

**Two approaches:**
1. **In .toc file** (preferred for single-project addons):
   ```toc
   ## X-Curse-Project-ID: 123456
   ```
2. **In workflow args** (alternative):
   ```yaml
   - uses: BigWigsMods/packager@v2
     with:
       args: -p 123456
   ```

**Game version detection:** The packager reads `## Interface: 20505` from the .toc and maps it to the correct CurseForge game version (TBC Classic / Burning Crusade Classic). The `gameVersionTypeId` for TBC Classic Anniversary on CurseForge is 73246.

**No `-g` flag needed** when the .toc has the correct `## Interface:` value. The packager auto-detects TBC Classic from Interface 20505.

### Anti-Patterns to Avoid

- **Manual version bumping:** Never edit the Version field in .toc manually. The `@project-version@` placeholder is the correct approach -- already in place.
- **Separate CurseForge upload action:** Don't use a separate `itsmeow/curseforge-upload` or similar action. BigWigsMods/packager handles the upload natively via `CF_API_KEY` env var.
- **Hardcoded version in Lua:** Never put a version string literal in the Lua code. The existing `getAddonVersion()` correctly reads from .toc metadata.
- **`fetch-depth: 1` (shallow clone):** The packager needs full git history for tag detection and changelog generation. Always use `fetch-depth: 0`.
- **Including README in the zip:** The user explicitly decided against this. Use `ignore` in .pkgmeta to exclude it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Addon zip packaging | Custom zip script | BigWigsMods/packager@v2 | Handles .toc parsing, version substitution, ignore rules, multi-platform upload |
| Changelog generation | Custom commit parser | BigWigsMods/packager built-in | Packager auto-generates changelog from commits between previous tag and current tag |
| CurseForge upload | curl to CurseForge API | BigWigsMods/packager built-in | Handles API auth, game version detection, file metadata automatically |
| GitHub Release creation | gh CLI or actions/create-release | BigWigsMods/packager built-in | Creates release and attaches zip artifact via GITHUB_OAUTH env var |
| Lua linting | Custom syntax check | lunarmodules/luacheck@v1 | Standard tool with WoW-aware configuration support |
| Version substitution | sed/awk in CI script | BigWigsMods/packager built-in | Replaces `@project-version@` and other keywords automatically during packaging |

**Key insight:** The BigWigsMods/packager is a comprehensive tool that replaces 4-5 separate CI steps. Resist the urge to build custom solutions for any packaging/release concern -- the packager almost certainly handles it.

## Common Pitfalls

### Pitfall 1: Shallow Clone Breaks Changelog and Version Detection
**What goes wrong:** Packager cannot find previous tags or generate accurate changelogs.
**Why it happens:** `actions/checkout@v4` defaults to `fetch-depth: 1` (only the commit that triggered the workflow).
**How to avoid:** Always set `fetch-depth: 0` in the checkout step.
**Warning signs:** Changelog shows all commits ever, or version detection fails silently.

### Pitfall 2: Missing GITHUB_TOKEN Write Permissions
**What goes wrong:** Packager fails to create GitHub Release with a 403 error.
**Why it happens:** Default GITHUB_TOKEN permissions may be read-only in newer repos (GitHub changed defaults).
**How to avoid:** Add `permissions: contents: write` at the workflow or job level. The BigWigsMods wiki notes: "The automatically-generated GITHUB_TOKEN secret must be configured with read-write permissions."
**Warning signs:** Workflow succeeds at packaging but fails at release creation.

### Pitfall 3: Forgetting to Create CurseForge Project First
**What goes wrong:** Upload fails because there's no target project on CurseForge.
**Why it happens:** CurseForge project must exist before the first automated upload.
**How to avoid:** Manually create the project on CurseForge before tagging the first release. Note the project ID for .toc or workflow args.
**Warning signs:** 404 or "project not found" error during CF upload step.

### Pitfall 4: CF_API_KEY Not Set as Repository Secret
**What goes wrong:** CurseForge upload silently skipped or fails with auth error.
**Why it happens:** The `CF_API_KEY` env var is referenced but the secret doesn't exist in the repo.
**How to avoid:** Create the secret at https://github.com/faxekondi47/fix-nagrand-music/settings/secrets/actions with a token from https://wow.curseforge.com/account/api-tokens.
**Warning signs:** Packager logs show "CF_API_KEY not set, skipping CurseForge upload."

### Pitfall 5: Luacheck Fails on WoW Global Functions
**What goes wrong:** Luacheck reports errors for every WoW API function (CreateFrame, PlayMusic, etc.).
**Why it happens:** Luacheck doesn't know about WoW's global environment by default.
**How to avoid:** Create a `.luacheckrc` file that declares all WoW API globals used by the addon as `read_globals`.
**Warning signs:** Dozens of "accessing undefined global" warnings on the first run.

### Pitfall 6: Tag Format Mismatch
**What goes wrong:** Workflow doesn't trigger, or version string has unexpected `v` prefix.
**Why it happens:** The packager strips the `v` prefix from tags like `v1.0.0` for `@project-version@`. If the tag trigger pattern doesn't match, nothing happens.
**How to avoid:** Use `tags: - "v*"` as the trigger pattern. Always tag with `v` prefix (e.g., `v1.0.0`). The packager outputs `1.0.0` (without `v`).
**Warning signs:** Pushing a tag doesn't start the workflow, or version shows as `v1.0.0` instead of `1.0.0`.

## Code Examples

### Complete .luacheckrc for FixNagrandMusic

```lua
-- Luacheck configuration for FixNagrandMusic
-- Source: Verified against luacheck docs and WoW addon community patterns

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
```

### Complete .pkgmeta for FixNagrandMusic

```yaml
package-as: FixNagrandMusic

ignore:
  - .github
  - .luacheckrc
  - .planning
  - README.md
```

### Complete GitHub Actions Workflow

```yaml
name: Package and release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Clone project
        uses: actions/checkout@v4

      - name: Luacheck
        uses: lunarmodules/luacheck@v1

  release:
    runs-on: ubuntu-latest
    needs: lint
    env:
      CF_API_KEY: ${{ secrets.CF_API_KEY }}
      GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - name: Clone project
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Package and release
        uses: BigWigsMods/packager@v2
```

### .toc Additions (CurseForge metadata)

```toc
## X-Curse-Project-ID: REPLACE_WITH_ACTUAL_ID
```

This line should be added to the existing `FixNagrandMusic.toc`. The project ID must be obtained after creating the project on CurseForge.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual zip + CurseForge web upload | BigWigsMods/packager@v2 in GitHub Actions | 2020+ (widespread adoption) | Fully automated release on tag push |
| release.sh run locally | GitHub Action wraps release.sh | 2020 (v1), 2022+ (v2) | No local tooling needed |
| Separate upload actions for each platform | Single packager handles CF + GitHub + WoWI + Wago | Always (packager feature) | One action step, multiple platforms |
| mpeterv/luacheck (archived) | lunarmodules/luacheck (active fork) | 2021 | mpeterv is unmaintained, lunarmodules is the active continuation |

**Deprecated/outdated:**
- `mpeterv/luacheck` GitHub repo: Archived. Use `lunarmodules/luacheck` instead.
- `actions/create-release`: Deprecated. BigWigsMods/packager creates releases natively.
- Separate CurseForge upload actions (e.g., `itsmeow/curseforge-upload`): Unnecessary when using BigWigsMods/packager.

## Open Questions

1. **CurseForge Project ID**
   - What we know: The project must be created on CurseForge before the first release. The ID goes in `.toc` as `## X-Curse-Project-ID`.
   - What's unclear: The actual numeric ID -- depends on when the project is created on CurseForge.
   - Recommendation: Create the CurseForge project as a prerequisite step before the first `git tag` push. Use a placeholder in the .toc during development, replace with actual ID before tagging v1.0.0.

2. **Packager Changelog Format with Conventional Commits**
   - What we know: BigWigsMods/packager auto-generates a changelog from all commits between the previous tag and current tag. It does not parse conventional commit prefixes (`feat:`, `fix:`, etc.) -- it simply lists commit messages.
   - What's unclear: Whether the built-in changelog format satisfies the user's "auto-generate changelog from conventional commits" requirement, or whether a separate tool is needed.
   - Recommendation: The packager's built-in changelog (commit list between tags) is standard and sufficient for WoW addon releases. Since the project already uses conventional commit messages, the changelog will naturally reflect the change types. Adding a separate conventional-changelog parser would add complexity for marginal benefit. If the user wants a more structured CHANGELOG.md, this could be a `manual-changelog` in .pkgmeta pointing to a separately generated file -- but this is likely overkill for a v1.0.0 release.

## Sources

### Primary (HIGH confidence)
- [BigWigsMods/packager README](https://github.com/BigWigsMods/packager) - Full feature documentation, CLI args, .pkgmeta fields, version substitution, build type keywords
- [BigWigsMods/packager Wiki: GitHub Actions workflow](https://github.com/BigWigsMods/packager/wiki/GitHub-Actions-workflow) - Complete workflow YAML template with env vars
- [BigWigsMods/packager Wiki: Preparing the PackageMeta File](https://github.com/BigWigsMods/packager/wiki/Preparing-the-PackageMeta-File) - .pkgmeta field reference
- [BigWigsMods/packager Releases](https://github.com/BigWigsMods/packager/releases) - Latest version v2.5.1 (2025-12-02)
- [lunarmodules/luacheck GitHub Action](https://github.com/marketplace/actions/luacheck) - Action v1.2.0, usage documentation
- [luacheck Configuration docs](https://luacheck.readthedocs.io/en/stable/config.html) - .luacheckrc format reference
- [CurseForge: Preparing the PackageMeta File](https://support.curseforge.com/en/support/solutions/articles/9000197952-preparing-the-packagemeta-file) - Official CurseForge .pkgmeta docs

### Secondary (MEDIUM confidence)
- [Wowpedia: Using the BigWigs Packager with GitHub Actions](https://wowpedia.fandom.com/wiki/Using_the_BigWigs_Packager_with_GitHub_Actions) - Community-verified workflow patterns
- [Luacheck boilerplate for WoW addons](https://gist.github.com/LenweSaralonde/13a217b5d7186f9218ae62736e2bff90) - Community .luacheckrc template
- [WoW addon .luacheckrc examples](https://github.com/NoobTaco/NoobTacoUI/blob/main/.luacheckrc) - Real-world config
- CurseForge TBC Classic Anniversary gameVersionTypeId: 73246 - Verified from CurseForge search URL parameters
- [GitHub Docs: Controlling GITHUB_TOKEN permissions](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token) - Permissions reference

### Tertiary (LOW confidence)
- None. All findings verified with primary or secondary sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - BigWigsMods/packager is the undisputed standard, confirmed by README, wiki, releases, and widespread ecosystem usage
- Architecture: HIGH - Workflow pattern verified from official wiki, version flow confirmed by inspecting existing addon code
- Pitfalls: HIGH - Shallow clone, permissions, and luacheck globals issues are well-documented in official docs and community sources
- .pkgmeta format: HIGH - Confirmed from both BigWigsMods wiki and CurseForge official docs
- Changelog: MEDIUM - Packager's built-in changelog confirmed, but its exact format with conventional commits is inferred (not tested)

**Research date:** 2026-02-19
**Valid until:** 2026-04-19 (stable ecosystem, BigWigsMods/packager updates infrequently)
