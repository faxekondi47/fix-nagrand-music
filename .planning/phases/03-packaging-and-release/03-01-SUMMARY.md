---
phase: 03-packaging-and-release
plan: 01
subsystem: infra
tags: [github-actions, luacheck, bigwigs-packager, curseforge, ci-cd]

# Dependency graph
requires:
  - phase: 02-user-interface
    provides: "Feature-complete addon with slash commands and toggle"
provides:
  - "GitHub Actions CI/CD pipeline: tag push triggers lint, package, release"
  - "Luacheck config with WoW API globals whitelisted"
  - ".pkgmeta for BigWigsMods/packager zip packaging"
  - "CurseForge project ID metadata in .toc"
  - "README.md with installation and /fng usage instructions"
affects: []

# Tech tracking
tech-stack:
  added: [BigWigsMods/packager@v2, lunarmodules/luacheck@v1, actions/checkout@v4]
  patterns: [tag-triggered-release, lint-before-package]

key-files:
  created:
    - .github/workflows/release.yml
    - .luacheckrc
    - .pkgmeta
    - README.md
  modified:
    - FixNagrandMusic/FixNagrandMusic.toc

key-decisions:
  - "UIParent included in read_globals despite not being used -- matches research template, harmless"
  - "CurseForge project ID left as placeholder -- user creates project and fills in actual ID before first release"

patterns-established:
  - "Tag-triggered CI/CD: v* tag push -> lint -> package -> GitHub Release + CurseForge upload"

requirements-completed: [PKG-02, PKG-03, PKG-04]

# Metrics
duration: 2min
completed: 2026-02-19
---

# Phase 3 Plan 1: Packaging and Release Summary

**Tag-triggered CI/CD pipeline with luacheck lint, BigWigsMods/packager for GitHub Releases and CurseForge upload, plus user-facing README**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-19T08:25:23Z
- **Completed:** 2026-02-19T08:27:27Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Complete CI/CD pipeline: pushing a v* git tag triggers luacheck lint, then BigWigsMods/packager creates a GitHub Release with zip and uploads to CurseForge
- Luacheck configuration whitelists all WoW API globals used by FixNagrandMusic.lua for clean linting
- README with casual tone covering the Nagrand music bug, installation (CurseForge + manual), and all /fng commands

## Task Commits

Each task was committed atomically:

1. **Task 1: Create CI/CD pipeline and packaging config** - `0604f8d` (feat)
2. **Task 2: Write README with installation and usage instructions** - `5acd311` (feat)

## Files Created/Modified
- `.github/workflows/release.yml` - Tag-triggered release pipeline: lint -> package -> GitHub Release + CurseForge upload
- `.luacheckrc` - Lua 5.1 linting config with WoW API globals whitelisted
- `.pkgmeta` - BigWigsMods packager metadata, packages as FixNagrandMusic/ and excludes dev files
- `README.md` - User-facing docs with bug explanation, installation, and /fng commands
- `FixNagrandMusic/FixNagrandMusic.toc` - Added X-Curse-Project-ID placeholder for CurseForge uploads

## Decisions Made
- UIParent included in luacheck read_globals despite not being currently used -- matches the research template and is harmless to include
- CurseForge project ID left as REPLACE_WITH_ACTUAL_ID placeholder -- user must create the CurseForge project and fill in the numeric ID before the first tagged release

## Deviations from Plan

None - plan executed exactly as written.

## User Setup Required

External services require manual configuration before first release:

1. **Create CurseForge project** at https://wow.curseforge.com -> Start a Project -> select TBC Classic Anniversary, Category: Audio & Video
2. **Generate CurseForge API token** at https://wow.curseforge.com/account/api-tokens
3. **Add CF_API_KEY secret** to GitHub repo at https://github.com/faxekondi47/fix-nagrand-music/settings/secrets/actions
4. **Replace placeholder** in FixNagrandMusic.toc: change REPLACE_WITH_ACTUAL_ID to actual CurseForge project ID number

## Issues Encountered

None.

## Next Phase Readiness
- Addon is feature-complete and fully configured for CI/CD distribution
- User needs to complete the CurseForge setup steps above before the first `git tag v1.0.0` push
- No further phases planned -- project is ready for first release after user setup

## Self-Check: PASSED

All files verified present. All commit hashes verified in git log.

---
*Phase: 03-packaging-and-release*
*Completed: 2026-02-19*
