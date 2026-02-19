---
created: 2026-02-19T07:15:55.954Z
title: Fix Orgrimmar music playing when walking out of Nagrand
area: core
files:
  - FixNagrandMusic/FixNagrandMusic.lua:211-223
  - FixNagrandMusic/FixNagrandMusic.lua:137-145
  - FixNagrandMusic/FixNagrandMusic.lua:195-204
---

## Problem

When leaving Nagrand by walking or flying, the addon's music stops via `deactivateAddon()` and the game's built-in zone music system briefly reasserts the faulty Orgrimmar drum music before the correct destination zone music (e.g., Shattrath) takes over. The sequence is:

1. Player crosses zone boundary
2. `ZONE_CHANGED_NEW_AREA` fires -> addon deactivates -> `StopMusic()` stops addon track
3. Game's built-in zone music system plays its queued track (bugged Orgrimmar drums)
4. Eventually the correct destination zone music overrides

This results in a brief burst of wrong music during the transition.

## Solution

Investigate whether delaying `StopMusic()` or using `PlayMusic()` with a silence/destination track could bridge the gap. Alternatively, research whether keeping the addon music playing slightly longer (e.g., until destination zone music asserts) would prevent the Orgrimmar drums from appearing. May relate to the "disable Orgrimmar music" todo.
