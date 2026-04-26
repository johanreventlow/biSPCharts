## 1. Baseline-audit

- [ ] 1.1 Kør `dev/audit_tests.R` (eller ny variant) → baseline-rapport: antal tests per fil, antal assertions per fil, skip-kategorier
- [ ] 1.2 Gem baseline i `dev/audit-output/test-baseline-pre-consolidation.json`
- [ ] 1.3 Kør `covr::package_coverage()` → baseline-coverage (%)

## 2. testServer-migration (issue #230)

<!-- DEFERRED: testServer-migration er høj-risiko, håndteres separat. Se issue #230 -->

- [ ] 2.1 Identificér alle `skip("TODO: #230 testServer-migration")`-forekomster
- [ ] 2.2 Prioritér top 5 vigtigste server-funktioner at migrere:
  - `mod_spc_chart_server` (chart-rendering flow)
  - `mod_export_server` (PNG/PDF flow)
  - `mod_landing_server` (upload flow)
  - `main_app_server` (session init/cleanup)
  - `utils_server_events_*` (event-handlers)
- [ ] 2.3 Implementér testServer-tests for hver, slet tilsvarende skip-stubs
- [ ] 2.4 Dokumentér i issue #230 hvilke dele der ikke kan migreres + hvorfor

## 3. Konsolidér duplicate test-filer

- [ ] 3.1 Logging: merge `test-logging-{debug-cat,precedence,standardization,system}.R` → `test-logging.R`
- [ ] 3.2 E2E: merge `test-e2e-{workflows,user-workflows}.R` → `test-e2e-workflows.R`
- [ ] 3.3 Critical-fixes: analyser forskellen mellem `integration`, `regression`, `security` — merge hvis overlap
- [ ] 3.4 Cache: merge `test-cache-{collision-fix,data-signature-bugs,invalidation-sprint3}.R` → `test-cache.R`
- [ ] 3.5 For hver merge: dokumentér i PR hvilke tests blev beholdt vs. slettet som duplikat
- [ ] 3.6 Verificér coverage ikke reduceres efter merge

## 4. Erstat placeholder-tests

- [ ] 4.1 Find alle: `grep -rn "expect_true(TRUE)\|expect_no_error" tests/testthat/`
- [ ] 4.2 For hver: beslut (a) skriv reel assertion, (b) slet (overflødig), (c) konvertér til `skip("TODO: #<issue>")` med åbent issue
- [ ] 4.3 Gem audit-rapport i `dev/audit-output/placeholder-tests-audit.md`
- [ ] 4.4 Forudsæt nul `expect_true(TRUE)` efter implementation

## 5. Nye tests for kritiske filer

- [ ] 5.1 Opret `tests/testthat/test-state-management.R`:
  - Event-counter-increment pattern
  - Observer-trigger-matrix (emit X → observer Y receives)
  - state-init struktur
  - reset/cleanup scenarios
- [ ] 5.2 Opret `tests/testthat/test-app-server-main.R`:
  - Session-initialisering
  - Emit-API oprettes korrekt
  - session$onSessionEnded cleanup
- [ ] 5.3 Opret `tests/testthat/test-utils-event-context-handlers.R`:
  - Context-routing-regler
  - Alle registrerede events har matchende handler
  <!-- NOTE: test-state-management-hierarchical.R dækker allerede task 5.1 —
       se Phase 5 commit for dokumentation. Task 5.6 nedenfor er deferred. -->
- [ ] 5.4 Opret `tests/testthat/test-spc-chart-full-flow.R`:
  <!-- DEFERRED: kræver testServer-migration (Phase 2) -->
  - Upload test-CSV → autodetect → chart-type → render → eksport (via testServer)

<!-- DEFERRED: Task 5.6 (anhoej derivation pure tests): kræver extract-anhoej-derivation-pure
     (ikke deployed). Se openspec/changes/extract-anhoej-derivation-pure. -->

## 6. Udvid audit-script

- [ ] 6.1 Opdatér `dev/audit_tests.R` til at tælle assertions per fil
- [ ] 6.2 Rapportér top 5 filer med flest skip()-kald
- [ ] 6.3 Rapportér top 5 filer med færrest assertions per test_that
- [ ] 6.4 Tilføj CI-step der poster rapporten som PR-kommentar

## 7. Validering

- [ ] 7.1 Kør fuld test-suite — alle tests skal passere
- [ ] 7.2 Kør `covr::package_coverage()` → verificér at coverage er ≥ baseline
- [ ] 7.3 Kør skip-inventory-step (fra `harden-ci-quality-gates`) → verificér TODO-skips er reduceret
  <!-- DEFERRED: kræver harden-ci-quality-gates workflow (arkiveret men CI-steps afventer?) -->
- [ ] 7.4 Kør `openspec validate consolidate-test-suite-gaps --strict`

Tracking: GitHub Issue #322 (paraply), #230 (testServer-migration)
