# Tasks — Harden Test-Suite Regression Gate

Tracking: GitHub master-issue #228. Sub-issues: #229 (Fase 1), #230 (Fase 2), #231 (Fase 3), #232 (Fase 4).

Hver fase er en selvstændig leverance. Fase 1 blokker fase 2. Fase 3 og 4
kan parallelliseres efter fase 2.

---

## 1. Fase 1 — Saneringsbunden: Gør suiten grøn

Målsætning: `Rscript dev/publish_prepare.R manifest` passerer uden
`--skip-tests` og uden nye skips tilføjet.

### 1.1 Udfør #203 inventory-PR-plan (kategori A–F)

- [x] 1.1.1 **PR A1** — Fjernede logging-helpers (`sanitize_log_details`,
      `log_with_throttle`) i `test-bfh-error-handling.R` (#222 `9f4b0c0`).
- [x] 1.1.2 **PR A2** — Fjernede cache-helpers (`get_cache_stats`,
      `get_spc_cache_stats`) i `test-spc-cache-integration.R` (#222 `9f4b0c0`).
- [x] 1.1.3 **PR B1** — Opdater branding-konstant-tests (HOSPITAL_COLORS,
      HOSPITAL_NAME) til `get_hospital_branding()` accessor (#223 `fcfb76e`).
- [x] 1.1.4 **PR C1** — `testthat` 3.x cleanup: fjern `info = "..."` fra
      `expect_gt/gte/lt/lte/eq/neq` (#220 `eb791c8`).
- [x] 1.1.5 **PR D1** — Chrome-tests: `test-app-basic.R` slettet (stub,
      AppDriver unavailable; migreres til Fase 4 e2e) — commit `41e6fa7`.
      `test-visualization-server.R` håndteret i tidligere #203-arbejde.
- [x] 1.1.6 **PR E1** — Reactive context-fejl i tests: `shiny::isolate({})`
      (#224 `ec606ea`, #225 `a14a529`).
- [x] 1.1.7 **PR F1** — Rename `claudespc` → `biSPCharts` i testfiler
      (#221 `3bf14a1`).
- [x] 1.1.8 **PR A3** — Catch-all restende fjernede funktioner:
      - `validate_date_column` — test-blok fjernet i `test-data-validation.R`
        (funktionen fjernet i `remove-legacy-dead-code §4.5`, arkiveret
        2026-04-18). Ingen direkte erstatning; dato-validering i
        kolonneparser/auto-detection. **DENNE ÆNDRING.**
      - `skip_on_ci_if_slow` — allerede erstattet med
        `testthat::skip_on_ci()` i `test-input-debouncing-comprehensive.R`
        via #225 `a14a529`. Verificeret.
      - Øvrige funktioner i audit (`sanitize_log_details`,
        `log_with_throttle`, `get_cache_stats`, `get_spc_cache_stats`)
        håndteret i PR A1/A2 (#222 `9f4b0c0`).

### 1.2 Håndtér TODO Fase 4-skips (92 kald)

- [x] 1.2.1 Liste alle `skip("TODO Fase 4")`-kald via
      `grep -rn 'skip(\"TODO' tests/testthat/` og opret tabel i
      `docs/test-suite-inventory-203.md` (pr. fil, pr. test_that).
      **Status 2026-04-19:** 92 skip-kald i 15 filer kortlagt med
      kategori-fordeling E=41, D=21, B=10, A=8, C=7, F=5. Tabellen
      inkluderer blok-linjenumre og beslutningsmatrix pr. kategori.
      Se `docs/test-suite-inventory-203.md` § "Inventory af skip('TODO')-kald".
- [ ] 1.2.2 For hver: beslut (a) reparér mod ny API, (b) slet testen, eller
      (c) wrap med `skip("Ny feature X — se issue #NN")` + opret issue.
      Ingen `skip("TODO")` tilbage uden issue-reference.
      **Batch 4 (kategori E m/nyoprettede issues, 2026-04-19):**
      31 kat E skips grupperet i 6 konsoliderede sub-grupper og sporet
      via nye GitHub-issues #240-#245 + 1 skip re-labelet til #213:
      - **#240** (12 skips): `compute_spc_results_bfh()` input-validering
        i `test-spc-bfh-service.R`. Manglende-argument + data-shape.
      - **#241** (5 skips): `generateSPCPlot()` edge case fejl-håndtering
        for tom/NA/enkelt-rækket/nul-nævner data.
      - **#242** (3 skips): `format_scaled_number`, `format_unscaled_number`,
        `format_time_with_unit` edge case afrunding + dansk format.
      - **#243** (2 skips): `resolve_y_unit`/`detect_unit_from_data` percent-
        detection. Relateret til #238 (samme BFHcharts 0.8.0-rod-årsag).
      - **#244** (2 skips): `sanitize_user_input()` SQL injection + path
        traversal. Inkluderer pragmatisk threat-model-vurdering.
      - **#245** (6 skips): SPC-plot geom-assertions (layer size) +
        data-transformation edge cases (character x→factor, run chart
        ucl/lcl, time transformation).
      - **#213** (1 skip): `parse_danish_target` backwards-compat re-labelet.
      **Nu tilbage:** 26 skip("TODO")-kald i 6 filer (fra 57).

      **Batch 3 (kategori E m/eksisterende issue-refs, 2026-04-19):**
      10 skips re-labelet til at referere eksisterende issues:
      - `test-cache-reactive-lazy-evaluation.R` (2 skips) →
        `skip("Afventer fix i create_cached_reactive ... — se #212")`.
      - `test-parse-danish-target-unit-conversion.R` (8 skips) →
        `skip("Afventer parse_danish_target unit-awareness refactor — se #213 (...)")`.
      Alle tidligere `TODO Fase 3`-markers fjernet. test_that-titler
      opdateret fra "TODO Fase 3: ..." til "#213: ..." for klarhed.
      **Nu tilbage:** 57 skip("TODO")-kald i 10 filer (fra 67).

      **GitHub issue-oprydning 2026-04-19:**
      - #234 (PR A3 catch-all) lukket som completed — dækket af
        commit `1614c1c` (§1.1.8).
      - #235 (`get_qic_chart_type` fallback) kommenteret om
        supplerende berørte linjer i `test-data-validation.R:107-109`.

      **Batch 2 (kategori C, 2026-04-19):** 7 skips re-labelet fra
      `skip("TODO Fase 4: ... reactive context ...")` til
      `skip("testServer-migration — se harden-test-suite §2.3 (#230)")`.
      Tests bevaret som reference-materiale for §2.3 testServer-kontrakter.
      Berørte filer:
      - `test-critical-fixes-security.R` (1: observer priorities)
      - `test-mod-spc-chart-comprehensive.R` (1: reactive updates)
      - `test-state-management-hierarchical.R` (5: nested reactive,
        flushReact, reactive chains, backward compat, clinical workflow)
      **Nu tilbage:** 67 skip("TODO")-kald i 12 filer (fra 74).

      **Batch 1 (kategori A+B, 2026-04-19):** 18 skips håndteret.
      92 → 74 skip-kald tilbage i 12 filer (fra 15). Detaljer:
      - `test-config_chart_types.R` — 2 dangling skip() fjernet
        (tests allerede komplette; skips var vestigielle). Assertions bevaret.
      - `test-config_export.R` — 3 test-blokke slettet
        (EXPORT_PDF_CONFIG, EXPORT_PNG_CONFIG eksisterer ikke som
        separate konstanter; konfig er inline i render-funktioner).
      - `test-autodetect-unified-comprehensive.R` — 4 test-blokke slettet
        (`appears_date`, `appears_numeric`, `detect_columns_with_cache`
        erstattet af unified autodetect i `R/fct_autodetect_helpers.R`).
      - `test-parse-danish-target-unit-conversion.R` — 2 test-blokke
        slettet (`detect_y_axis_scale`, `convert_by_unit_type` aldrig
        implementeret — tests validerede kun `exists()`).
      - `test-reactive-batching.R` — 7 test-blokke slettet (`is_batch_pending`
        og `clear_all_batches` state-inspection-helpers aldrig
        implementeret; kun `schedule_batched_update` findes).
      **Rest (kategori C+D+E+F = 74 skips):** kræver dybere analyse —
      R-bug issues (E=41), API-struktur-analyse (D=21), testServer-migration
      (C=7), BFHcharts-cross-repo (F=5). Fortsættes i separate batches.
- [ ] 1.2.3 Særligt for `test-spc-bfh-service.R` (19 skips): eskalér hver
      skip-rationale — disse er SPC-kerne.

### 1.3 Fjern stub-filer og artefakter

- [x] 1.3.1 Audit-stubs revurderet 2026-04-19: 5 af 9 er grønne efter A1-F1
      (test-branding-globals.R, test-clean-qic-call-args.R,
      test-dependency-namespace.R, test-namespace-integrity.R,
      test-ui-token-management.R). test-run-app.R skipper kun (acceptabel).
      Konkret handling:
      - `test-app-basic.R` slettet (AppDriver unavailable) — commit `41e6fa7`
      - `test-denominator-field-toggle.R` fikset (fjernet assertions for
        ikke-supporterede chart types) — commit `f67f8a9`
      - `tests/performance/test_data_load_performance.R` fikset (renamet
        "DEBUGGING:" → "Debug-info:" for at undgå false positive) — commit
        `fdab691`
- [x] 1.3.2 `tests/testthat/_problems/` (20 filer) slettet lokalt. Allerede
      i `.gitignore` fra tidligere — ingen commit krævet.
- [x] 1.3.3 `tests/testthat/archived/` → `tests/_archive/testthat-legacy/`
      flyttet (commit `177e704`). README.md opdateret med ny path.
- [x] 1.3.4 `.gitignore` indeholder allerede `tests/testthat/_problems/`,
      `tests/testthat/logs/`, `Rplots.pdf` fra tidligere arbejde (verificeret).

### 1.4 Verifikation — suite grøn

- [ ] 1.4.1 Kør `Rscript dev/audit_tests.R --timeout=120`; verificér
      `summary.broken-missing-fn = 0`, `green-partial ≤ 5`.
- [ ] 1.4.2 Kør `devtools::test(stop_on_failure = TRUE)` — exit 0.
      **Status 2026-04-19:** 10+ fejl forbliver fra kategori G "post-audit"
      (ikke introduceret af §1.3-arbejdet). Eksempler:
      `test-100x-mismatch-prevention.R` (5 fails — run chart target line,
      scales), `test-app-initialization.R`, `test-bfh-error-handling.R:246`
      (logging format), `test-cache-data-signature-bugs.R:192`,
      `test-critical-fixes-integration.R` (cross-component reactive).
      Kræver §1.1.8 (PR A3) + ny PR for runtime-regressions.
- [ ] 1.4.3 Opdatér `docs/superpowers/specs/2026-04-17-test-audit-report.md`
      med ny kategorifordeling.
- [x] 1.4.4 `NEWS.md`-entry tilføjet under "Interne ændringer (Fase 1
      saneringsarbejde, #228/#229)" med fil-liste, commits og rationale.
- [ ] 1.4.5 Fjern `--skip-tests`-flag fra `dev/publish_prepare.R` hvis det
      stadig eksisterer (sanity check mod eksisterende spec-requirement).

**Acceptkriterium fase 1:** `devtools::test()` grøn + audit 0 fails.

---

## 2. Fase 2 — Kvalitet: Fjern falsk tryghed

Målsætning: ingen test redefinerer produktionsfunktioner; kritiske moduler
har reel reactive-dækning.

### 2.1 Eliminér syntetiske tests

- [ ] 2.1.1 Audit: find alle testfiler hvor produktionsfunktion redefineres
      inline (`grep -n "^  resolve_\|^  determine_\|^  handle_"`
      tests/testthat/). Konkret kendt: `test-event-system-observers.R`.
- [ ] 2.1.2 For hver: erstat lokal redefinition med kald til
      `biSPCharts::`-eksporteret eller intern funktion via `:::`.
- [ ] 2.1.3 Fjern eller omskriv tests der tester kopierede hjælpefunktioner
      (antal skal komme til 0 via audit-script).
- [ ] 2.1.4 Audit `tests/integration/` — identificér tests der kun
      manipulerer `app_state` og verificerer samme felter. Kandidater til
      omskriv eller sletning: `test-full-data-workflow.R`,
      `test-session-lifecycle.R` (delvis).

### 2.2 Ekstraher observer-handlers til testbare toplevel-funktioner

- [ ] 2.2.1 Kandidat-liste (kritiske observer-kæder, jf. design.md AD-5):
      - `R/mod_spc_chart_observers.R`: viewport, cache-update,
        guard-respekt
      - `R/utils_server_event_listeners.R`: data_updated,
        auto_detection_completed, ui_sync_needed-kæderne
      - `R/utils_server_events_autodetect.R`: freeze/unfreeze-logik
- [ ] 2.2.2 For hver: ekstrakt handler som `handle_<event>_<context>()`;
      `observeEvent()`-kald reduceres til passering af app_state.
- [ ] 2.2.3 Skriv unit-tests for hver handler (ikke testServer): given app_state X,
      efter handler-kald verificér state Y.

### 2.3 testServer-kontrakter for kritiske moduler

- [ ] 2.3.1 `visualizationModuleServer`: minimum 4 tests — (a) data_updated
      → output$plot_object populated, (b) null-data → warnings gemt, (c)
      guard-flag respekteret ved samtidige events, (d) debounce — to events
      inden for window → kun én render.
- [ ] 2.3.2 `mod_export_server`: happy path PNG + PDF download, fejl i
      BFHcharts-export → graceful degradation.
- [ ] 2.3.3 `mod_landing_server`: auto-restore flow, session-state
      transitions.
- [ ] 2.3.4 Fjern `skip("TODO Fase 4: create_chart_manager")` og venner i
      `test-mod-spc-chart-comprehensive.R` — erstat med ægte tests eller
      slet blokkene.

### 2.4 Kanoniske mocks

- [ ] 2.4.1 Opret `tests/testthat/helper-mocks.R` med mocks for:
      `BFHllm::bfhllm_spc_suggestion`, `BFHcharts::create_spc_chart`,
      `pins::board_*`, `gert::git_*`, Gemini `httr2::req_perform`,
      `input$local_storage_*`-messages.
- [ ] 2.4.2 Split `tests/testthat/helper.R` i `helper-bootstrap.R`,
      `helper-fixtures.R`, `helper-mocks.R`. Fjern MockAppDriver.
- [ ] 2.4.3 Kontrakttest: for hver mock, verificér at `formals()` matcher
      real API (fejl → tvinger mock-opdatering).
- [ ] 2.4.4 Migrér eksisterende `mockery::stub`-kald til
      `testthat::local_mocked_bindings()`.

### 2.5 Negative asserts-løft

- [ ] 2.5.1 Mål: negative asserts (`expect_error/warning/message`) ≥ 10 %
      af total asserts (aktuel: 2 %).
- [ ] 2.5.2 Gennemgå hver `safe_operation()` i `R/` — for hver: verificér
      at mindst én test rammer fallback-path.
- [ ] 2.5.3 Tilføj explicit fejltests for: BFHllm utilgængelig, Gemini
      timeout, localStorage quota-exceeded, malformet CSV med mixed
      encoding, data med kun NA, data med 1 række.

**Acceptkriterium fase 2:** Audit-script `no-synthetic-tests = 0`; alle
kritiske mod_*_server har ≥1 testServer-test; negative asserts ≥ 10 %.

---

## 3. Fase 3 — Lokale gates: Pre-push + determinisme

Målsætning: push til remote kan ikke ske med rød test; rng er deterministisk.

### 3.1 Pre-push git-hook

- [ ] 3.1.1 Opret `dev/git-hooks/pre-push` (bash-wrapper):
      kører `Rscript -e "devtools::test(stop_on_failure = TRUE)"` +
      `Rscript -e "lintr::lint_package()"`; afviser push ved fejl.
- [ ] 3.1.2 Opret `dev/install_git_hooks.R` som installerer symlink
      `.git/hooks/pre-push` → `dev/git-hooks/pre-push`.
- [ ] 3.1.3 Tilføj tjek i `.Rprofile` (projekt-niveau): hvis
      `.git/hooks/pre-push` ikke er installeret, log warning ved R-start.
- [ ] 3.1.4 Dokumentér i `CLAUDE.md` §6 (pre-commit-tjekliste) og
      `docs/CONFIGURATION.md`.
- [ ] 3.1.5 Mål: total pre-push-tid < 5 min. Hvis ikke: del i "hurtig
      pre-push" (unit + lint) og "fuld pre-push" (alt) med flag.

### 3.2 Determinisme

- [ ] 3.2.1 Opret custom lintr-regel `seed_rng_linter` der flagger
      `rnorm/runif/sample/rpois` uden omsluttende `withr::with_seed()`
      eller `set.seed()` i samme `test_that`.
- [ ] 3.2.2 Tilføj reglen til `.lintr` config; kør lintr-fuld-baseline.
- [ ] 3.2.3 Fiks alle findings (114 kald i 37 filer) — prioriteret top 10
      største testfiler først.
- [ ] 3.2.4 Konvertér store test-datasæt (>50 rækker) til `.rds`-fixtures i
      `tests/testthat/fixtures/`.

### 3.3 Ét canonical test-entrypoint

- [ ] 3.3.1 Audit divergens mellem `tests/testthat.R` (`test_check()`) og
      `tests/run_*.R` (source-baseret). Dokumentér forskellene.
- [ ] 3.3.2 Beslut canonical: pkgload-baseret via `testthat::test_dir()`
      med `load_package = "source"`.
- [ ] 3.3.3 Konsolidér `tests/run_*.R` til tynde wrappers omkring
      canonical entrypoint + tag-filter (`unit`/`performance`/`integration`).
- [ ] 3.3.4 `dev/publish_prepare.R` bruger canonical entrypoint.

**Acceptkriterium fase 3:** Push med rød test fejler; lintr-regel fanger
rng uden seed; unit- og publish-gate-kørsel giver identisk testresultat.

---

## 4. Fase 4 — Udvidet publish-gate: E2E + coverage

Målsætning: publish blokeres hvis coverage falder eller E2E fejler.

### 4.1 Headless shinytest2-suite

- [ ] 4.1.1 Opret `tests/e2e/` med separat entrypoint (ikke auto-discovered
      af testthat default).
- [ ] 4.1.2 Definér 5-10 navngivne happy-path-tests (estimated max 10):
      - `upload → autodetect → p-chart → export PNG`
      - `upload → autodetect → run-chart → export PDF`
      - `upload → vælg kolonner manuelt → i-chart`
      - `upload → schema-migration (session restore) → plot`
      - `upload → tom dato-kolonne → fejlbesked vises`
      - `upload → wizard gate blocks export uden data`
- [ ] 4.1.3 Commit screenshot-baselines til
      `tests/testthat/_snaps/e2e-*/`.
- [ ] 4.1.4 `dev/publish_prepare.R` tilføjer E2E-sektion:
      - `skip_if_not(shinytest2::detect_chrome())` → warn hvis
        Chrome mangler
      - retry × 2 ved flaky fejl
      - generous `wait_for_idle` timeouts

### 4.2 Coverage-threshold i publish-gate

- [ ] 4.2.1 Udvid `tests/coverage.R`:
      - Kør ved publish
      - Exit 1 hvis samlet coverage < 80 %
      - Exit 1 hvis kritiske paths < 95 %
      - Output HTML til `coverage/index.html`
- [ ] 4.2.2 Baseline-måling første gang: dokumentér aktuel % i
      `tests/coverage.R` som startpunkt.
- [ ] 4.2.3 Threshold-stigning: +5 % per release indtil target nået.
      Dokumentér progression i `NEWS.md`.
- [ ] 4.2.4 Exclude-liste dokumenteres eksplicit (fx `zzz.R`, `golem_utils.R`).

### 4.3 Publish-gate integration

- [ ] 4.3.1 `dev/publish_prepare.R manifest`-fase kører i rækkefølge:
      1. `lintr::lint_package()`
      2. `devtools::test(stop_on_failure = TRUE)` via canonical entrypoint
      3. E2E-suite via `source("tests/e2e/run_e2e.R")`
      4. `covr::package_coverage()` med threshold-check
      5. `rsconnect::writeManifest()`
- [ ] 4.3.2 Hver fase logger struktureret output til
      `dev/audit-output/publish-gate-<timestamp>.log`.
- [ ] 4.3.3 Fejl i trin 1-4 stopper med klar fejlbesked og exit 1.

**Acceptkriterium fase 4:** Publish-gate fejler kontrolleret ved (a) rødt
test-output, (b) covr < threshold, (c) E2E-fejl. Manifest genereres kun ved
alle trin grønne.

---

## 5. Dokumentation

- [ ] 5.1 Opdater `CLAUDE.md` §6 (pre-commit-tjekliste) med pre-push
      referencer.
- [ ] 5.2 Opdater `tests/README.md` med ny struktur (e2e/, _archive/).
- [ ] 5.3 Opdater `openspec/project.md` §Testing Strategy med:
      - Determinisme-regel
      - Canonical entrypoint
      - Publish-gate som autoritativ
- [ ] 5.4 Opdater `docs/CONFIGURATION.md` med git-hooks-installation.
- [ ] 5.5 Nyt ADR: `docs/adr/ADR-NNN-test-regression-gate-design.md` der
      dokumenterer CI-fravalget og pre-push/publish-gate som kompensation.

---

## 6. Governance og validering

### 6.1 GitHub issue-struktur (beslutning 10: B) — DONE 2026-04-19

- [x] 6.1.1 Oprettet **master-issue** #228: `[OpenSpec] harden-test-suite-regression-gate`
      med proposal.md som body; labels
      `openspec-proposal,technical-debt,infrastructure`
      (testing-label eksisterer ikke i repoet — erstattet med infrastructure).
- [x] 6.1.2 Oprettet **4 sub-issues**:
      - #229 — `[Fase 1/4] harden-test-suite: Saneringsbunden — ryd testgæld (fuldt scope)`
      - #230 — `[Fase 2/4] harden-test-suite: Kvalitet — testServer-kontrakter + kanoniske mocks`
      - #231 — `[Fase 3/4] harden-test-suite: Lokale gates — pre-push-hook + determinisme`
      - #232 — `[Fase 4/4] harden-test-suite: Publish-gate — E2E + coverage-threshold`
- [x] 6.1.3 Sub-issues linked til master (#228) via task-list i master-body
      og `Part of #228`-reference i hver sub.
- [x] 6.1.4 Opdatér `proposal.md` §Related med master + 4 sub-issue-numre.
- [x] 6.1.5 Opdatér `tasks.md`-referencer (denne sektion).

### 6.2 OpenSpec-validering

- [ ] 6.2.1 Kør `openspec validate harden-test-suite-regression-gate --strict`
      og resolver evt. issues.
- [ ] 6.2.2 Bekræft at spec-deltas refererer eksisterende
      `test-infrastructure`-capability korrekt.
- [ ] 6.2.3 Request maintainer-approval før implementation starter
      (stage 2).

### 6.3 Arkivering

- [ ] 6.3.1 Efter alle faser deployeret: `openspec archive
      harden-test-suite-regression-gate` og opdatér spec i
      `openspec/specs/test-infrastructure/spec.md`.
