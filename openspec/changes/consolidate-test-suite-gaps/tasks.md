## 1. Baseline-audit

- [x] 1.1 Kør `dev/audit_tests.R` (eller ny variant) → baseline-rapport via grep: total_test_files, total_skips, expect_true_TRUE_count, expect_no_error_count
- [x] 1.2 Gem baseline i `dev/audit-output/test-baseline-pre-consolidation.json`
- [ ] 1.3 Kør `covr::package_coverage()` → baseline-coverage (%) — SKIPPED (for langsom; fil-tælling brugt som proxy)

## 2. testServer-migration (issue #230)

<!-- DEFERRED: testServer-migration er høj-risiko, håndteres separat. Se issue #230 -->

- [x] 2.1 Identificér alle `skip("TODO: #230 testServer-migration")`-forekomster
- [x] 2.2 Prioritér top 5 vigtigste server-funktioner at migrere (udvidet til 11 tests i Phase 2):
  - `test-state-management-hierarchical.R` (6 tests)
  - `test-critical-fixes-security.R` (1 test: OBSERVER_PRIORITIES)
  - `test-mod-spc-chart-comprehensive.R` (1 test: reactive updates)
  - `test-autodetect-unified-comprehensive.R` (3 tests)
- [x] 2.3 Implementér testServer-tests for hver, slet tilsvarende skip-stubs (Phase 2 — se commit)
- [x] 2.4 Dokumentér i `test-pending-issue-230.R` hvilke tests der er migreret (historisk reference)

## 3. Konsolidér duplicate test-filer

- [x] 3.1 Logging: merge `test-logging-{debug-cat,precedence,standardization,system}.R` → `test-logging.R` (37 tests; `test-utils_logging.R` bevaret separat — regression-fokus #291)
- [x] 3.2 E2E: merge `test-e2e-{workflows,user-workflows}.R` → `test-e2e-workflows.R` (13 tests: Sektion A pure-R, Sektion B skip_on_ci UI-tests)
- [x] 3.3 Critical-fixes: `integration`/`regression`/`security` bevaret separat — ingen reel overlap bekræftet
- [x] 3.4 Cache: merge `test-cache-{collision-fix,data-signature-bugs,invalidation-sprint3}.R` → `test-cache.R` (25 tests; `test-spc-cache-integration.R`, `test-utils_performance_caching.R`, `test-utils_qic_caching.R` bevaret separat)
- [x] 3.5 Dokumenteret i commits hvilke tests bevaret vs. droppet som duplikat
- [x] 3.6 Verificeret: merged filer har mindst samme antal test_that()-blokke som originaler

## 4. Erstat placeholder-tests

- [x] 4.1 Fundet alle `expect_true(TRUE)` og `expect_no_error` via grep
- [x] 4.2 For hver: besluttet (a) reel assertion, (b) slet, eller (c) skip med issue-ref. 13→5 `expect_true(TRUE)` (5 rest er test-data strenge i test-audit-classifier.R, ikke assertions)
- [x] 4.3 Audit-rapport gemt i `dev/audit-output/placeholder-tests-audit.md`
- [x] 4.4 Nul `expect_true(TRUE)` som egentlige assertions tilbage

## 5. Nye tests for kritiske filer

- [x] 5.1 `test-state-management.R` SKIPPED — `test-state-management-hierarchical.R` dækker allerede event-counter, state-init, reset (7 tests verificeret)
- [x] 5.2 Oprettet `tests/testthat/test-app-server-main.R` (32 tests): `hash_session_token()` pure-function, `app_server`/`run_app` eksistens+signatur, `create_emit_api()` struktur og counter-increment, context-sanitering
- [x] 5.3 Oprettet `tests/testthat/test-utils-event-context-handlers.R` (43 tests): `classify_update_context()` alle 5 output-værdier + edge cases, `resolve_column_update_reason()` alle 4 branches
- [x] 5.4 Opret `tests/testthat/test-spc-chart-full-flow.R` (Phase 2b, #322 — 5 testServer-tests for SPC pipeline event orchestration)
- [x] 5.5 Dependency-integritetstest — ALLEREDE DONE: `test-dependency-guards.R` eksisterer og dækker `require_qicharts2`, `require_optional_package`, triple-colon lint (fra fix-dependency-namespace-guards)
- [ ] 5.6 Anhøj-regression-test `test-derive-anhoej-results.R`
  <!-- DEFERRED: blokeret af extract-anhoej-derivation-pure (ikke deployed). Se openspec/changes/extract-anhoej-derivation-pure -->

## 6. Udvid audit-script

- [x] 6.1 Opdateret `dev/audit_tests.R` + `dev/audit/static_analysis.R`: `count_assertions()` tæller `expect_`-kald per fil
- [x] 6.2 Rapporterer top 5 filer med flest `skip()`-kald (eksempel: `test-edge-cases-comprehensive.R` = 33 skips)
- [x] 6.3 Rapporterer top 5 filer med færrest assertions per `test_that`-blok (eksempel: `test-pending-issue-230.R` = 0.0)
- [ ] 6.4 CI-step der poster rapporten som PR-kommentar — SKIPPED (kræver separat workflow-ændring, out of scope)

## 7. Validering

- [ ] 7.1 Kør fuld test-suite — afventer CI på branch
- [ ] 7.2 Kør `covr::package_coverage()` → verificér coverage ≥ baseline — SKIPPED (for langsom lokalt)
- [ ] 7.3 Kør skip-inventory-step → verificér TODO-skips reduceret
  <!-- DEFERRED: harden-ci-quality-gates workflow-step afventer separat deployment -->
- [ ] 7.4 Kør `openspec validate consolidate-test-suite-gaps --strict`

Tracking: GitHub Issue #322 (paraply), #230 (testServer-migration)
