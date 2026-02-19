# Phase 3: Packaging and Release - Context

**Gathered:** 2026-02-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Package the finished FixNagrandMusic addon for distribution via GitHub Actions CI/CD and CurseForge, with a user-facing README. The addon is feature-complete after Phase 2 -- this phase makes it installable and discoverable.

</domain>

<decisions>
## Implementation Decisions

### README content
- Casual & friendly tone -- conversational, approachable, like a community addon post
- Brief explanation of the bug (1-2 sentences on why Orgrimmar drums play in Nagrand)
- Keep it short: install instructions, usage (`/fng` commands), and that's it
- No troubleshooting/FAQ section -- issues go to GitHub Issues
- No screenshots or media -- it's a background audio fix, nothing visual to show

### CurseForge listing
- Short elevator pitch (2-3 sentences) -- what it does, how to use, done
- Not a mirror of the README -- tighter, punchier
- Target TBC Classic Anniversary only (the bug is version-specific)
- Category: Audio & Video
- CurseForge API token available for automated uploads

### Release versioning
- SemVer (major.minor.patch) -- first release is 1.0.0
- CI auto-updates the Version field in .toc from the git tag before packaging
- In-game addon messages must also display the correct version (sourced from git tag, not hardcoded)
- Auto-generate changelog from conventional commits for each release

### Pipeline scope
- Trigger: git tag push (e.g., v1.0.0) -- no manual dispatch
- Full pipeline: tag push -> Lua lint -> package -> GitHub release + CurseForge upload
- Lua syntax validation (luacheck or similar) runs before packaging
- Release zip contains addon folder only (FixNagrandMusic/ with .toc and .lua) -- no README in zip

### Claude's Discretion
- Exact GitHub Actions workflow structure
- luacheck configuration
- Changelog formatting and commit parsing rules
- CurseForge metadata file format and fields beyond what's specified

</decisions>

<specifics>
## Specific Ideas

- Version must flow from git tag into both .toc and in-game messages -- single source of truth, no manual bumps
- First release is 1.0.0 (addon is feature-complete and stable)

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 03-packaging-and-release*
*Context gathered: 2026-02-19*
