---
created: 2026-02-19T07:15:55.954Z
title: Fix abrupt music stop on hearthstone out of Nagrand
area: core
files:
  - FixNagrandMusic/FixNagrandMusic.lua:137-145
  - FixNagrandMusic/FixNagrandMusic.lua:195-204
  - FixNagrandMusic/FixNagrandMusic.lua:244-256
---

## Problem

When using Hearthstone to leave Nagrand, the music stops very abruptly. The flow is: Hearthstone cast -> loading screen -> `PLAYER_ENTERING_WORLD` fires -> addon detects not in Nagrand -> `deactivateAddon()` -> `stopNagrandMusic()` -> `StopMusic()` cuts the track instantly with no fade-out.

This creates a jarring audio experience compared to smooth zone transitions.

## Solution

Investigate whether WoW's API supports any form of fade-out before `StopMusic()`, or whether a short timer-based volume ramp-down (via `SetCVar("Sound_MusicVolume", ...)`) can smooth the transition before stopping. May need to restore volume CVar after the fade completes.
