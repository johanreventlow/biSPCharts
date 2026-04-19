# Harden Test-Suite Regression Gate

## Why

Test-suiten er stor (117 filer, 1.460 `test_that`-blokke, 4.355 asserts), men
fungerer ikke som en troværdig regressionsbeskyttelse. To uafhængige reviews
(Claude + Codex, april 2026) samt det eksisterende test-audit
(`docs/superpowers/specs/2026-04-17-test-audit-report.md`) og #203-inventory
(`docs/test-suite-inventory-203.md`) peger på samme rodårsager:

- **66 fejlende test-blokke og 180 skippede blokke fordelt på 30 filer.**
  Audit-kategorierne: 79 grønne filer, 27 grøn-delvist, 2 skipped-all, 9 stubs.
- **92 `skip("TODO Fase X (#203-followup)")`-kald** der reelt er permanent
  deaktiverede tests på kerneområder: `test-spc-bfh-service.R` (19),
  `test-autodetect-unified-comprehensive.R` (10),
  `test-mod-spc-chart-comprehensive.R` (8),
  `test-generateSPCPlot-comprehensive.R` (7), flere.
- **"Integrationstests" tester ikke integration.** `tests/integration/` og
  dele af `test-event-system-observers.R` genimplementerer produktionskoden
  inline og verificerer kopien — ikke app'ens faktiske adfærd.
- **Reaktiv kerne er utestet.** ~80 `observeEvent/observe`-kald i
  `R/mod_*.R` + `R/utils_server_*.R`; kun 13 testfiler bruger `testServer()`
  og hoved-moduletest har i praksis kun `expect_true(TRUE)`-asserts.
- **E2E er disabled som regressionsværn.** 7 shinytest2-filer, alle gated med
  `skip_on_ci()`; `_snaps/` er tomt. `MockAppDriver` i `helper.R` giver falsk
  tryghed ved at returnere hardcoded HTML.
- **2 % negative asserts** (89 af 4.355 `expect_*`-kald). Fejlstier er
  underdækkede.
- **Determinisme-brist:** 114 rng-kald (`rnorm/runif/sample`) i 37 filer,
  kun 34 `set.seed()`-kald i 4 filer → potentielt flaky.
- **Testgæld-artefakter i aktiv suite:** `tests/testthat/_problems/` (20
  filer), `tests/testthat/archived/` (19 filer), `Rplots.pdf`, `logs/`.

**CI-kontekst:** biSPCharts ligger i et privat repository uden GitHub
Actions-betaling til obligatoriske checks. CI-blocking er derfor **fravalgt
permanent**. Vores eneste tekniske regression-gate er publish-scriptet
(`dev/publish_prepare.R`) som allerede kører `devtools::test(stop_on_failure
= TRUE)` før manifest-generering. Men publish-gatens effekt begrænses af
testgælden — den kan kun stoppe deploy, ikke forhindre at gæld akkumuleres
mellem releases.

Vi skal derfor samle kvalitetssikringen om de gates vi kan kontrollere:
**lokale pre-push-hooks + styrket publish-gate + reel test-kvalitet**.

## What Changes

1. **Eliminér aktiv testgæld** — gennemfør #203-inventory'ens PR-plan A1-F1,
   udvid med oprydning af `_problems/`, `archived/` og 9 stubfiler, og
   håndtér de 92 `skip("TODO Fase 4")` enten ved reparation eller eksplicit
   slet/reference-til-issue.
2. **Erstat syntetiske tests med ægte adfærdstests** — fjern lokale
   redefinitioner af produktionsfunktioner i `test-event-system-observers.R`
   m.fl.; skriv `testServer()`-baserede kontrakttests for
   `visualizationModuleServer`, `mod_export_server`, `mod_landing_server` og
   `utils_server_event_listeners.R`.
3. **Introducér lokal pre-push-gate** — git-hook der kører `devtools::test()`
   + `lintr::lint_package()` før push til remote. Hook'en er opt-in men
   installeres via `dev/install_git_hooks.R` og dokumenteres som obligatorisk
   i pre-commit-tjeklisten.
4. **Udvid publish-gate med headless E2E og coverage** — tilføj shinytest2
   happy-path-suite (upload → autodetect → chart → export) kørt via
   `chromote` headless i `dev/publish_prepare.R`; tilføj
   `covr::package_coverage()` med threshold 80 % samlet, 95 % på kritiske
   paths (`state_management.R`, `utils_error_handling.R`,
   `fct_spc_bfh_*.R`).
5. **Determinisme-regel:** alle `rnorm/runif/sample/rpois`-kald skal være
   inden for `withr::with_seed()` eller lign.; enforce via custom lintr-regel.
6. **Kanoniske mocks** i `tests/testthat/helper-mocks.R` (BFHcharts, BFHllm,
   Gemini, pins, localStorage JS-bro); fjern MockAppDriver-fallbacken fra
   `helper.R`.
7. **Ét canonical test-entrypoint** — konsolidér `run_unit_tests.R`,
   `run_integration_tests.R`, `run_all_tests.R` + `testthat.R` så lokal og
   publish-gate kører samme load-path (ingen `source("global.R")` +
   `test_check()` divergens).
8. **Flyt testgæld-artefakter ud af aktiv suite** — `_problems/`,
   `archived/`, `logs/`, `Rplots.pdf` til `.gitignore` eller til
   `tests/_quarantine/` (ikke auto-discovered af testthat).

## Impact

- **Affected specs:** `test-infrastructure` (modificeret + udvidet).
- **Affected code:**
  - `tests/testthat/` (~30 filer repareres, 9 stubs + 20 _problems slettes,
    19 archived flyttes)
  - `tests/testthat/helper.R` (split i helper-bootstrap.R, helper-fixtures.R,
    helper-mocks.R)
  - `tests/integration/` (omdøbes til `tests/state-contracts/` eller
    omskrives til ægte testServer)
  - `dev/publish_prepare.R` (headless E2E + covr-gate)
  - `dev/install_git_hooks.R` (ny)
  - `.githooks/pre-push` (ny, symlink-target)
  - `dev/audit_tests.R` (udvides med kvalitetsmetrikker)
  - `NEWS.md` (entry for hver slettet/skippet test jf. versioning §C)
  - `CLAUDE.md` §6 pre-commit-tjekliste (pre-push reference)
- **Affected architecture:**
  - Moduler ekstraherer observer-handler-funktioner som top-level for
    testbarhed (`R/mod_spc_chart_observers.R`, `R/utils_server_event_listeners.R`).
  - Nyt konvention: `mod_*_server` returnerer eksplicit API for test-exposure.
- **Non-impact:**
  - CI-workflows (`.github/workflows/*.yaml`) forbliver uændrede — vi
    accepterer at CI er ikke-blokerende.
  - Branching-strategi uændret.

## Sequencing

Leveres i fire faser (se `tasks.md`). Afklaringsbeslutninger fra
planlægningssession 2026-04-19 er indarbejdet og markeret eksplicit:

1. **Fase 1 — Saneringsbunden, fuldt scope** (beslutning 1: A). Alle 66
   fejlende blokke + alle 92 `skip("TODO Fase 4")` håndteres. #203
   PR-plan A1-F1 + slet 9 stubs + slet `_problems/` + flyt `archived/`.
   Mål: publish-gate passerer uden `--skip-tests`.
2. **Fase 2 — Kvalitet med delvist overlap** (beslutning 2: C). 2.1
   (syntetiske tests — afgrænset til eksporterede/`:::`-funktioner, jf.
   beslutning 8: B) og 2.4 (kanoniske mocks) må starte parallelt med
   slutningen af Fase 1. 2.2-2.3 (observer-handler ekstraktion +
   testServer-kontrakter) venter til Fase 1 er 100% grøn.
3. **Fase 3 — Lokale gates** (parallel med Fase 2 efter Fase 1 er done):
   bash-wrapper + R-script pre-push-hook (beslutning 3: B), adaptiv
   friktion med timing-log (beslutning 4: C), `withr::with_seed`
   enforcement, canonical entrypoint.
4. **Fase 4 — Udvidet publish-gate**: `tests/e2e/` separat entrypoint
   (beslutning 5: A) + baseline-først coverage-threshold (beslutning 7:
   A). `tests/integration/` slettes; `setup-shinytest2.R` flyttes til
   `tests/e2e/helper-shinytest2.R` (beslutning 6: C).

TODO-skips hybridmodel (beslutning 9: C): stubfiler slettes ubetinget;
`skip("TODO")`-kald kræver `#NNN`-issue-reference — pre-push-hook
håndhæver det.

GitHub-tracking: master-issue + 4 sub-issues (beslutning 10: B) — én sub
per fase. Master lukkes når alle sub er lukkede.

## Related

- GitHub Issue (master): #228 — `[OpenSpec] harden-test-suite-regression-gate`
- GitHub Issue (Fase 1): #229 — Saneringsbunden (fuldt scope)
- GitHub Issue (Fase 2): #230 — Kvalitet (testServer + mocks)
- GitHub Issue (Fase 3): #231 — Lokale gates (pre-push + determinisme)
- GitHub Issue (Fase 4): #232 — Publish-gate (E2E + coverage)
- Foregående: `openspec/changes/archive/<unblock-publish-test-gate>` (skabte
  publish-gaten; denne change bygger ovenpå)
- #203 — Refactor test suite (inventory + PR-plan)
- `docs/superpowers/specs/2026-04-17-test-audit-report.md`
- `docs/test-suite-inventory-203.md`
- `docs/superpowers/specs/2026-04-17-refactor-test-suite-phase1-design.md` (+ phase2, phase3)
