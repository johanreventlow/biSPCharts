# Proposal: Unblock Publish Test-Gate

## Why

Publish-workflow til Posit Connect Cloud (`/publish-to-connect` slash-kommandoen)
bruger `devtools::test(stop_on_failure = TRUE)` som sikkerhedsgate før
`rsconnect::writeManifest()`. Gaten blokerer p.t. fordi test-suiten har betydelig
drift efter tidligere refaktoreringer.

Den automatiske test-audit (issue #203, rapport:
`docs/superpowers/specs/2026-04-17-test-audit-report.md`) viser at:

- **4 testfiler er `broken-missing-fn`** — kalder R-funktioner der ikke længere
  eksisterer i `R/` (17 unikke funktionsnavne fordelt på filerne)
- Et midlertidigt `--skip-tests`-flag er blevet tilføjet til
  `dev/publish_prepare.R` som nødpublish-mekanisme (commit 20b4724) — et
  **tydeligt anti-pattern** der skal fjernes så snart test-suiten er ren

De 4 broken filer er:

| Fil | Manglende funktioner |
|-----|---------------------|
| `test-panel-height-cache.R` | `clear_panel_height_cache` |
| `test-plot-diff.R` | 6 plot-diff-funktioner (bl.a. `apply_metadata_update`, `create_plot_state_snapshot`) |
| `test-utils_validation_guards.R` | 6 validation guards (bl.a. `validate_data_or_return`, `validate_column_exists`) |
| `test-validation-guards.R` | Overlap med `test-utils_validation_guards.R` |

## What Changes

Dette er **Change 1 af 2** i en to-trins strategi besluttet i brainstorm
2026-04-17 (se Audit-rapporten for detaljer):

- **Change 1 (denne):** Reetablér publish-gate hurtigt — fix de 4 broken filer
  via hybrid git-forensics-strategi og fjern `--skip-tests`-flaget
- **Change 2 (følger):** Omfattende test-suite-oprydning (green-partial fails,
  stubs, konsolidering) — brainstormes og planlægges efter Change 1 er mergeet

### Omfang af Change 1

1. **Git-forensics pr. manglende funktion** (~3 t):
   - Kør `git log --all --source --follow -S '<fn>' -- 'R/*.R'` pr. funktion
   - For hver: vælg én af følgende handlinger baseret på fund
     - Fundet under nyt navn → omdøb i testen
     - Slettet uden erstatning → slet `test_that`-blok med NEWS-note
     - Refaktoreret (signatur ændret) → opdatér signaturen
     - Uklart efter 10 min research → `skip("TODO: #203 follow-up — ...")`

2. **Fix pr. testfil** (~2 t):
   - `test-panel-height-cache.R` (1 funktion)
   - `test-plot-diff.R` (6 funktioner)
   - `test-utils_validation_guards.R` (6 funktioner)
   - `test-validation-guards.R` (overlap — overvej merge til ét canonical-fil)

3. **Reaktivér publish-gate** (~30 min):
   - Fjern `--skip-tests`-flag fra `dev/publish_prepare.R` (linjer 11, 252, 263,
     265, 297, 301, 310)
   - Fjern dokumentation af flag fra `.claude/commands/publish-to-connect.md`
     (linjer 59, 62)

4. **Dokumentation** (~30 min):
   - `NEWS.md`-entry jf. versioning-policy §C der lister fjernede/omdøbte/skippede tests
   - ADR hvis arkitekturbeslutninger blev truffet under forensics (fx "X-funktion konsolideret til Y")

5. **Verifikation** (~30 min):
   - Genkør test-audit: forvent `broken-missing-fn = 0`
   - `devtools::test(stop_on_failure = TRUE)` skal nu returnere exit 0
   - Kør `Rscript dev/publish_prepare.R manifest` (uden `--skip-tests`) → success

### Ingen breaking changes

Arbejdet rammer kun tests og dev-scripts. Ingen ændringer i `R/*.R` (public API)
medmindre git-forensics afslører at en manglende funktion skal gendannes — i så
fald dokumenteres det separat som bug-fix.

## Impact

**Affected capabilities:**
- `test-infrastructure` (ADDED Requirements: publish-gate enforcement, hybrid
  forensics-strategi for forældede tests)

**Affected code:**
- `tests/testthat/test-panel-height-cache.R`
- `tests/testthat/test-plot-diff.R`
- `tests/testthat/test-utils_validation_guards.R`
- `tests/testthat/test-validation-guards.R`
- `dev/publish_prepare.R`
- `.claude/commands/publish-to-connect.md`
- `NEWS.md`
- Evt. `docs/adr/ADR-NNN-*.md`

**Breaking changes:** Ingen. Dette er intern oprydning.

**Risk level:** Lav. Test-ændringer er isoleret fra produktionskode. Auditten
kører post-fix og verificerer at ingen regressions er opstået.

**Estimeret indsats:** 6-7 timer (single-session eller to halve dages arbejde).

## Related

- **Issue:** #203 (test-suite drift — publish-gate blokeret)
- **Audit-rapport:** `docs/superpowers/specs/2026-04-17-test-audit-report.md`
- **Audit-script:** `dev/audit_tests.R` (genkørbart værktøj)
- **Parallelt spor:** `openspec/changes/refactor-code-quality/` (Phase 2-4 om
  R-fil-split og config-konsolidering — Phase 1 arkiveres/erstattes af denne + Change 2)
- **Efterfølgende:** Change 2 "refactor-test-suite" (brainstormes efter Change 1)

Issue-tracking: GitHub issue oprettes via `gh issue create` efter proposalen
valideres med `openspec validate --strict`.
