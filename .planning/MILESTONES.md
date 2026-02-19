# Milestones

## v1.0 MVP (Shipped: 2026-02-19)

**Phases completed:** 3 phases, 5 plans
**Lines of code:** 407 LOC (Lua + TOC)
**Timeline:** 2 days (2026-02-18 to 2026-02-19)
**Git range:** feat(01-01) to feat(03-01)

**Key accomplishments:**
1. Complete FixNagrandMusic addon with zone detection (UiMapID 107), music playback (6 FileDataIDs day/night), and Orgrimmar drum suppression via PlayMusic auto-fade
2. In-game validated: all core behavior confirmed working in live TBC Classic Anniversary client -- zero code changes needed post-validation
3. Subzone tracking via GetSubZoneText() for per-subzone music awareness
4. Slash commands (/fng, /fng toggle, /fng debug), login notification, and per-character persistent settings via SavedVariablesPerCharacter
5. GitHub Actions CI/CD pipeline with luacheck linting, zip packaging, and CurseForge API upload

**Delivered:** A WoW TBC Classic Anniversary addon that fixes the Nagrand music bug -- correct zone music plays in every subzone with smooth transitions, user controls, and automated publishing.

---

