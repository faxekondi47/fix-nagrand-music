# Phase 1: Core Music Fix - Context

**Gathered:** 2026-02-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Player enters Nagrand and hears the correct TBC music in every subzone, with no Orgrimmar drum bleed-through, surviving loading screens and cleaning up on exit. Includes zone detection, music playback, drum suppression, subzone transitions, loading screen resilience, cleanup on exit, and TOC file. User interface and packaging are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Track-to-subzone mapping
- Claude researches Blizzard's original intended music for each Nagrand subzone and maps tracks accordingly
- If adjacent subzones share the same track, don't restart it — let it keep playing uninterrupted
- Unnamed open areas (no subzone text) handled at Claude's discretion based on original Blizzard behavior
- Track rotation vs fixed assignment: Claude decides based on how Blizzard's music system normally works
- No user-specific subzone vibes needed — "just make it correct Nagrand music"

### Music transitions
- Transition behavior between subzones: match how Blizzard's built-in zone music system works natively
- Indoor/outdoor behavior: match Blizzard's original intent for how zone music handles buildings
- Subzone border flickering (debounce): match Blizzard's native behavior — Claude researches if this is a real problem and handles accordingly
- Key rule: if same track plays in adjacent subzones, do NOT restart it — seamless continuation

### Day/night variants
- Phase 1 WILL detect game time and play matching day/night variants (user explicitly wants this)
- Music switches when day turns to night even while standing still — responsive to time changes
- Dawn/dusk breakpoints: match WoW's built-in day/night cycle definitions exactly
- If the 6 FileDataIDs don't cleanly split into day/night, Claude decides whether to force the distinction or play all tracks regardless

### Entry experience
- Entry timing: match how music would naturally start if the Nagrand bug didn't exist
- Loading screen recovery: match normal zone behavior — Claude picks the most reliable approach
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

</decisions>

<specifics>
## Specific Ideas

- Strong recurring preference: "match Blizzard's original behavior" — the addon should feel like the bug never existed, not like a custom music mod
- Day/night detection is in scope for Phase 1 (originally deferred as ADV-02, but user wants it now)
- Error visibility: player should see a chat message if something goes wrong with track detection, not silent failure
- Same-track continuity: never restart a track unnecessarily when crossing subzone boundaries

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-core-music-fix*
*Context gathered: 2026-02-18*
