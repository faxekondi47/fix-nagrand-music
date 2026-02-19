# Phase 2: User Interface - Context

**Gathered:** 2026-02-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Slash commands (`/fng`), chat output, toggle on/off, debug mode, login notification, and persisted settings (SavedVariables). No new music logic, no new zone detection, no packaging — just the user-facing control layer on top of Phase 1's core fix.

</domain>

<decisions>
## Implementation Decisions

### Status display (`/fng`)
- Minimal one-liner format, not multi-line
- Context-aware: in Nagrand show track + subzone; outside Nagrand say "Not in Nagrand" or similar
- Show the actual file path for the current track (e.g. `Sound\Music\TBC\NagrandDay1.mp3`), not a friendly name
- No version number in status output — version belongs at login only

### Chat output style
- Prefix all addon messages with colored `|cFF00CC66FNG|r:` (short green "FNG")
- Debug messages use yellow text with `[DEBUG]` tag to stand out from normal messages
- Debug mode prints zone and subzone change events only — no music calls, no timer ticks, not a firehose
- No silent mode — toggle and debug are sufficient, messages are minimal anyway

### Toggle behavior (`/fng toggle`)
- Toggle OFF in Nagrand: StopMusic() immediately, bugged Orgrimmar music takes over
- Toggle ON in Nagrand: start playing correct Nagrand music right away (don't wait for next event)
- Confirmation message: simple "FNG: Enabled" / "FNG: Disabled" — no extra context
- Only `/fng toggle` command, no `/fng on` or `/fng off` aliases

### Login notification
- Every login, not just first time — standard WoW addon behavior
- Format: `FNG: FixNagrandMusic v{version} loaded` with same green prefix as all messages
- Show persisted state if disabled: `FNG: FixNagrandMusic v{version} loaded (disabled)`
- Always shows when addon is enabled (normal case): just "loaded" with no state qualifier

### Claude's Discretion
- SavedVariables structure and variable naming
- Exact WoW color escape codes for debug yellow
- How to read version from TOC metadata
- Error handling for edge cases (e.g. SavedVariables not yet loaded)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Keep everything minimal and clean. The addon is narrowly scoped and the UI should match that — no bloat.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-user-interface*
*Context gathered: 2026-02-19*
