---
created: 2026-02-19T07:15:55.954Z
title: Research disabling Orgrimmar music as addon option
area: core
files:
  - FixNagrandMusic/FixNagrandMusic.lua
---

## Problem

The root cause of both the walking-out and hearthstone transition issues is the faulty Orgrimmar drum music that WoW's built-in zone music system plays in Nagrand. Rather than only overriding it while in Nagrand, it may be desirable to give users the option to completely disable/suppress the Orgrimmar music so it never plays at all.

## Solution

Research WoW addon API capabilities:
- Can `MuteSoundFile()` target the specific Orgrimmar drum FileDataIDs? (Available since 7.3, needs TBC Classic Anniversary verification)
- Can CVar manipulation (`Sound_ZoneMusicNoDelay`, `Sound_EnableMusic`) selectively suppress zone music?
- Is there a way to hook into the zone music system to intercept and block specific tracks?
- What are the UX implications -- should this be a toggle in the addon's settings panel (Phase 2 UI)?

If feasible, this could be a cleaner solution than the current "override with PlayMusic()" approach and would also fix the transition issues in the other two todos.
