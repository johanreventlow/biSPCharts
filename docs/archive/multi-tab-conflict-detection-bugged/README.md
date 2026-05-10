# Multi-tab conflict detection (ARKIVERET — KENDT BUG)

**Status:** Arkiveret 2026-05-10. Aldrig merget til develop. Indeholder kendt bug.

## Hvorfor arkiveret

Denne OpenSpec-proposal blev udarbejdet i Cycle B (2026-05-09) som deferred work efter at have addresseret de 3 main reactive-state-persistence-fund. Codex fanget under bonus-review at proposal har **runtime-broken specification**.

## Codex bonus-fund (2026-05-09)

> The new requirement defines legacy and forward-incompatible payloads using `schema_version`, but the current persistence contract stores the schema in `version` (`LOCAL_STORAGE_SCHEMA_VERSION` is written as `version` in the saved app state).
>
> If engineers implement tests and migration logic from this spec, real 3.0 localStorage payloads will not match the documented migration path; they may be treated as missing/unknown version and cleared or skipped rather than migrated. That is exactly the data-loss class this change is meant to prevent.

## Konkret bug

`spec.md` linje 47-55 bruger field-navn `schema_version` i alle scenarios — men real persistence-payload (`R/utils_local_storage.R::autoSaveAppState()`) bruger `version`-key.

Implementation per spec ville:
1. Tjekke `payload$schema_version` (returns NULL fordi field hedder `version`)
2. Behandle alle eksisterende 3.0-payloads som "unknown schema"
3. Clear/skip migration → silent data-loss
4. (Ironisk: præcis det denne change skulle FORHINDRE)

## Hvis aktivering ønskes senere

**FORETRUKKET:** Re-create proposal fra scratch med korrekt `version`-key. Bedre end at fixe bug i denne arkiverede version (kontekst-ændringer kan kræve helt nye specs).

**ALTERNATIV:** Hvis du genbruger denne proposal:
1. Find/replace `schema_version` → `version` i alle 3 filer
2. Verificer mod faktisk `LOCAL_STORAGE_SCHEMA_VERSION`-konstant + `autoSaveAppState`-payload-shape
3. Tilføj fixture-test der bygger en real 3.0-payload (ej hand-written pseudo-payload) og kører gennem migration
4. Re-run Codex adversarial-review for at fange yderligere drift

## Reference

- Cycle B reconciled report: `docs/reviews/02-reactive-state-persistence.md`
- Codex bonus-finding dokumenteret: `docs/reviews/03-observability-gates.md` (cycle F off-target Codex-pass)
- Memory-entry: `~/.claude/projects/<project>/memory/feedback_post_merge_ci_gotchas.md`
- Cycle G H_NEW: addresserede AI-disable via eksplicit feature-flag (parallel pattern for hvad multi-tab kunne lære fra)

## Filer i denne mappe

- `proposal.md` — Cycle B udkast med `schema_version`-bug
- `spec.md` — Session-persistence requirement med field-mismatch
- `tasks.md` — Implementation-tasks der ville have opdaget bug ved første test-run
