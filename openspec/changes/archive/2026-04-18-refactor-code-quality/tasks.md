# Implementation Tasks

## Phase 1: Test File Consolidation (ARKIVERET 2026-04-17)

> **Overhalet af `refactor-test-suite` Fase 2** — se
> `docs/superpowers/plans/2026-04-17-refactor-test-suite-phase1.md`
> og `dev/audit-output/test-classification.yaml`.
>
> Tasks bevaret for historisk reference. Udfør IKKE.

Goal: Reduce 146 test files → ~100 files by consolidating redundant test clusters. Maintain all 1196 test cases.

### Phase 1a: Delete True Stub Files (Day 1-2)

- [ ] 1a.1 Delete stub files with 0 tests:
  - [ ] test-autodetect-engine.R (724 LOC, 0 tests)
  - [ ] test-event-bus-full-chain.R (524 LOC, 0 tests)
  - [ ] test-event-listener-integration.R (654 LOC, 0 tests)
- [ ] 1a.2 Create `tests/testthat/archived/README.md` with archival notes
- [ ] 1a.3 Move ancient historical files (test-fase*.R, test-phase*.R, test-qic-*.R)
- [ ] 1a.4 Verify: `testthat::test_dir()` still runs all 1196+ tests with no regressions

### Phase 1b: Merge Overlapping Test Clusters (Day 3-5)

**Priority 1 - Autodetect (Merge 4 files → 1 canonical):**
- [ ] 1b.1 Extract tests from test-autodetect-core.R, test-autodetect-algorithms.R, test-auto-detection.R
- [ ] 1b.2 Merge into test-autodetect-unified-comprehensive.R with clear section comments
- [ ] 1b.3 Delete source test files (core, algorithms, auto-detection)
- [ ] 1b.4 Keep test-autodetect-tidyverse-integration.R (separate concern)

**Priority 2 - Cache (Merge 3 files → 2 canonical):**
- [ ] 1b.5 Extract tests from test-cache-initialization.R
- [ ] 1b.6 Consolidate into test-cache-data-signature-bugs.R
- [ ] 1b.7 Review overlap between cache-reactive-lazy-evaluation.R and cache-invalidation-sprint3.R
- [ ] 1b.8 Delete redundant file (if high overlap)

**Priority 3 - Event System (Merge 2 files → 1 canonical):**
- [ ] 1b.9 Extract tests from test-event-driven-reactive.R
- [ ] 1b.10 Merge into test-event-system-observers.R
- [ ] 1b.11 Keep separate: test-event-system-emit.R, test-event-listener-integration.R

**Priority 4 - Critical Fixes (Merge 2 files → 1 canonical):**
- [ ] 1b.12 Extract tests from test-critical-fixes.R
- [ ] 1b.13 Consolidate into test-critical-fixes-regression.R
- [ ] 1b.14 Keep separate: test-critical-fixes-security.R, test-critical-fixes-integration.R

- [ ] 1b.15 Verify after each merge: Tests pass, count unchanged

### Phase 1c: Review "Empty" Test Files (Day 6)

- [ ] 1c.1 Count actual tests in: test-fct_ai_improvement_suggestions.R, test-edge-cases-comprehensive.R, test-generateSPCPlot-comprehensive.R, test-file-operations.R, test-mod-spc-chart-integration.R, test-wizard.R
- [ ] 1c.2 Consolidate or archive: Move <5 test files to archive if obsolete, merge if overlap
- [ ] 1c.3 Document decisions in tests/testthat/README.md

- [ ] 1c.4 **Phase 1 completion check:**
  - [ ] 13-18 test files deleted/archived
  - [ ] 4-6 test files merged with section comments
  - [ ] All 1196+ tests pass
  - [ ] Test run time reduced (estimated 5-10%)

---

## Phase 2: Refactor Large R Source Files (Week 3-5)

Goal: Split 4 largest files (6686 LOC total) into ~25 smaller, focused files (<500 LOC each).

### Phase 2a: Split fct_spc_bfh_service.R (2200 → 900 LOC) (Week 3)

- [ ] 2a.1 Create R/fct_spc_bfh_facade.R (200 LOC)
  - [ ] Move main function: `compute_spc_results_bfh()`
  - [ ] Move: `resolve_bfh_chart_title()`
  - [ ] Create imports section for new submodules

- [ ] 2a.2 Create R/fct_spc_bfh_params.R (500 LOC)
  - [ ] Move: `map_to_bfh_params()` and internal helpers
  - [ ] Move: `normalize_scale_for_bfh()`
  - [ ] Include roxygen documentation

- [ ] 2a.3 Create R/fct_spc_bfh_invocation.R (300 LOC)
  - [ ] Move: `call_bfh_chart()` with error handling
  - [ ] Move: `validate_chart_type_bfh()`
  - [ ] Include BFHcharts API documentation

- [ ] 2a.4 Create R/fct_spc_bfh_output.R (400 LOC)
  - [ ] Move: `transform_bfh_output()`
  - [ ] Move: `add_comment_annotations()`
  - [ ] Move: `extract_anhoej_metadata()` helper

- [ ] 2a.5 Create R/fct_spc_bfh_signals.R (300 LOC)
  - [ ] Move: `calculate_combined_anhoej_signal()`
  - [ ] Move: `classify_error_source()`
  - [ ] Move: `compute_anhoej_metadata_local()`

- [ ] 2a.6 Update files importing from fct_spc_bfh_service.R
  - [ ] mod_spc_chart_server.R: Update imports
  - [ ] Verify imports still work

- [ ] 2a.7 Update test file: test-spc-bfh-service.R
  - [ ] Split into: test-spc-bfh-facade.R, test-spc-bfh-params.R, test-spc-bfh-output.R
  - [ ] Run SPC tests: `testthat::test_dir('tests/testthat', filter='spc|bfh')`

### Phase 2b: Split mod_export_server.R (1335 → 500 LOC) (Week 4)

- [ ] 2b.1 Create R/utils_export_helpers.R (100 LOC)
  - [ ] Move: `normalize_mapping()`, `build_export_plot()`

- [ ] 2b.2 Create R/mod_export_analysis.R (150 LOC)
  - [ ] Move: Auto-analysis generation observer
  - [ ] Move: Text field synchronization logic

- [ ] 2b.3 Create R/mod_export_ai.R (300 LOC)
  - [ ] Move: AI suggestion button state management
  - [ ] Move: AI suggestion generation observer
  - [ ] Move: Suggestion caching and error handling

- [ ] 2b.4 Create R/mod_export_download.R (200 LOC)
  - [ ] Move: PDF, PNG, PPT, Excel download handlers

- [ ] 2b.5 Update mod_export_server.R (400 LOC)
  - [ ] Keep main module server function
  - [ ] Import new sub-modules
  - [ ] Add clear separation comments

- [ ] 2b.6 Update test file: test-mod_export.R
  - [ ] Split into: test-mod-export-main.R, test-mod-export-ai.R, test-mod-export-analysis.R
  - [ ] Run export tests: `testthat::test_dir('tests/testthat', filter='export')`

### Phase 2c: Split mod_spc_chart_server.R (1330 → 400 LOC) (Week 4-5)

**WARNING: High complexity due to reactive chains. Test thoroughly.**

- [ ] 2c.1 Create R/mod_spc_chart_state.R (200 LOC)
  - [ ] Move: Data cache initialization
  - [ ] Move: `module_data_reactive()` function
  - [ ] Move: Viewport dimension tracking, state helpers

- [ ] 2c.2 Create R/mod_spc_chart_config.R (200 LOC)
  - [ ] Move: `chart_config_raw()` reactive
  - [ ] Move: `chart_config()` debounced reactive
  - [ ] Move: `column_config_reactive()` function
  - [ ] Move: `spc_inputs` building

- [ ] 2c.3 Create R/mod_spc_chart_compute.R (300 LOC)
  - [ ] Move: SPC computation pipeline (inputs → results → plot)
  - [ ] Move: Cache integration and checking
  - [ ] Move: BFHchart API calls (via facade)
  - [ ] Move: Result transformation

- [ ] 2c.4 Create R/mod_spc_chart_observers.R (150 LOC)
  - [ ] Move: Viewport dimension observer
  - [ ] Move: Configuration change watchers
  - [ ] Move: State update handlers

- [ ] 2c.5 Create R/mod_spc_chart_ui.R (350 LOC)
  - [ ] Move: All output$* assignments
  - [ ] Move: renderPlot, renderUI for SPC plot
  - [ ] Move: Anhoej rules boxes rendering

- [ ] 2c.6 Update mod_spc_chart_server.R (250 LOC)
  - [ ] Keep main `visualizationModuleServer()` function
  - [ ] Import all sub-modules
  - [ ] Orchestrate initialization
  - [ ] Add dependency documentation

- [ ] 2c.7 Update test files
  - [ ] Split test-mod-spc-chart-*.R into separate files per module
  - [ ] Run tests: `testthat::test_dir('tests/testthat', filter='spc.*chart|visualization')`
  - [ ] Verify reactive chain tests still pass

- [ ] 2c.8 **Manual verification:**
  - [ ] Start app locally: `library(biSPCharts); run_app()`
  - [ ] Upload data, verify chart renders
  - [ ] Verify responsive updates, no race conditions
  - [ ] Check viewport dimension tracking

### Phase 2d: Split utils_server_event_listeners.R (1791 → 100 orchestrator + 7 modules) (Week 5)

**WARNING: Highest complexity due to inter-event dependencies. Test event ordering carefully.**

- [ ] 2d.1 Create R/utils_server_events_data.R (100 LOC)
  - [ ] Move: `register_data_lifecycle_events()` function
  - [ ] Move: Data update context handling, cache invalidation

- [ ] 2d.2 Create R/utils_server_events_autodetect.R (120 LOC)
  - [ ] Move: `register_autodetect_events()` function
  - [ ] Move: `notify_autodetect_results()` helper

- [ ] 2d.3 Create R/utils_server_events_ui.R (150 LOC)
  - [ ] Move: `register_ui_sync_events()` function
  - [ ] Move: UI update logic

- [ ] 2d.4 Create R/utils_server_events_navigation.R (300 LOC)
  - [ ] Move: `register_navigation_events()` function
  - [ ] Move: Session lifecycle handlers

- [ ] 2d.5 Create R/utils_server_events_chart.R (600 LOC)
  - [ ] Move: `register_chart_type_events()` function
  - [ ] Move: Column selection observers (6 observers consolidated)
  - [ ] Move: Y-axis update logic

- [ ] 2d.6 Create R/utils_server_wizard_gates.R (150 LOC)
  - [ ] Move: `setup_wizard_gates()` function
  - [ ] Move: Wizard state management, step validation

- [ ] 2d.7 Create R/utils_server_paste_data.R (200 LOC)
  - [ ] Move: `setup_paste_data_observers()` function
  - [ ] Move: Data paste handling, encoding detection

- [ ] 2d.8 Update R/utils_server_event_listeners.R (100 LOC)
  - [ ] Keep ONLY: `setup_event_listeners()` function
  - [ ] Import all event registration modules
  - [ ] Call each register_*_events() function
  - [ ] Add comment showing event ordering and priorities

- [ ] 2d.9 Create test files per event type
  - [ ] test-event-system-data-lifecycle.R
  - [ ] test-event-system-autodetect.R
  - [ ] test-event-system-ui.R
  - [ ] test-event-system-navigation.R
  - [ ] test-event-system-chart.R
  - [ ] test-wizard-gates.R
  - [ ] test-paste-data-handlers.R

- [ ] 2d.10 **Manual verification:**
  - [ ] Full workflow: upload → autodetect → chart generation → export
  - [ ] Event ordering: Verify no race conditions
  - [ ] Observer priorities: Verify correct sequence
  - [ ] Run: `testthat::test_dir('tests/testthat', filter='event|wizard|paste')`

- [ ] 2d.11 **Phase 2 completion check:**
  - [ ] 4 large files split into ~25 smaller files
  - [ ] Total LOC per file: max 500-600
  - [ ] All imports updated in dependent files
  - [ ] All 1196+ tests pass
  - [ ] No reactive bugs introduced
  - [ ] Manual app testing completed

---

## Phase 3: Configuration Consolidation (Week 6)

Goal: Unify fragmented configuration system, add accessor functions for constants.

### Phase 3a: Unify Logging Configuration (Day 1-2)

- [ ] 3a.1 Add function to R/utils_logging.R: `get_effective_log_level()`
  - [ ] Priority 1: Environment variable (SPC_LOG_LEVEL)
  - [ ] Priority 2: Golem config YAML
  - [ ] Priority 3: Default ("INFO")

- [ ] 3a.2 Update all log_debug/log_info/log_warn/log_error calls
  - [ ] Replace scattered `Sys.getenv("SPC_LOG_LEVEL")` checks
  - [ ] Call `get_effective_log_level()` instead

- [ ] 3a.3 Update initialization in R/zzz.R
  - [ ] Remove redundant log level setting
  - [ ] Document precedence in comment

- [ ] 3a.4 Update global.R development harness
  - [ ] Add comment showing precedence
  - [ ] Show example env var override

- [ ] 3a.5 Tests: Verify log level precedence (test-logging-standardization.R)
  - [ ] Run: `testthat::test_file('tests/testthat/test-logging-system.R')`

### Phase 3b: Add Accessor Functions for Performance Constants (Day 3-5)

- [ ] 3b.1 Create R/config_performance_getters.R (150 LOC)
  - [ ] `get_debounce_delay(operation)` — DEBOUNCE_DELAYS accessor
  - [ ] `get_operation_timeout(operation)` — OPERATION_TIMEOUTS accessor
  - [ ] `get_performance_threshold(metric)` — PERFORMANCE_THRESHOLDS accessor
  - [ ] `get_cache_config(setting)` — CACHE_CONFIG accessor

- [ ] 3b.2 Update files using constants directly (~15-20 files)
  - [ ] Search and replace: DEBOUNCE_DELAYS$ → get_debounce_delay(...)
  - [ ] Search and replace: OPERATION_TIMEOUTS$ → get_operation_timeout(...)
  - [ ] Search and replace: PERFORMANCE_THRESHOLDS$ → get_performance_threshold(...)
  - [ ] Affected files: mod_spc_chart_server.R, mod_export_server.R, utils_server_*.R

- [ ] 3b.3 Add future YAML support to getters
  - [ ] Include comments showing how to extend with golem-config.yml later
  - [ ] Show fallback pattern: YAML → constant → default

- [ ] 3b.4 Tests: Verify getter fallback behavior
  - [ ] Run: `testthat::test_dir('tests/testthat', filter='config')`

### Phase 3c: Add Accessor Functions for UI Constants (Day 5-6)

- [ ] 3c.1 Create R/config_ui_getters.R (100 LOC)
  - [ ] `get_ui_column_width(column_type)` — UI_COLUMN_WIDTHS accessor
  - [ ] `get_ui_height(section)` — UI_HEIGHTS accessor
  - [ ] `get_ui_style(style_name)` — UI_STYLES accessor

- [ ] 3c.2 Update UI files (~10-15 files) with new getters
  - [ ] mod_spc_chart_ui.R: Column widths, heights
  - [ ] app_ui.R: Layout widths
  - [ ] Other UI-building files

- [ ] 3c.3 Document future responsive design capability
  - [ ] Add comment showing reactive usage pattern

- [ ] 3c.4 Tests: Verify UI rendering
  - [ ] Run: `testthat::test_dir('tests/testthat', filter='ui')`
  - [ ] Manual: Verify app UI builds without errors

### Phase 3d: Document Configuration Precedence (Day 6-7)

- [ ] 3d.1 Create comprehensive docs/CONFIGURATION.md
  - [ ] Document all 8 configuration layers with priority
  - [ ] Show examples for each layer
  - [ ] Show environment detection flow
  - [ ] Provide troubleshooting guide

- [ ] 3d.2 Update CLAUDE.md
  - [ ] Add section linking to configuration documentation
  - [ ] Show how to customize at runtime

- [ ] 3d.3 Add code comments
  - [ ] Update R/zzz.R with initialization flow comments
  - [ ] Update R/app_run.R with environment detection comments

- [ ] 3d.4 **Phase 3 completion check:**
  - [ ] Logging config unified with clear precedence
  - [ ] Accessor functions for all constants
  - [ ] Future YAML extension documented
  - [ ] Configuration guide complete

---

## Phase 4: Cleanup & Verification (Week 6-7)

Goal: Verify all changes, run full test suite, document breaking changes (none expected).

### Phase 4a: Run Comprehensive Test Suite

- [ ] 4a.1 Run full test suite: `testthat::test_dir('tests/testthat')`
  - [ ] Verify: All 1196+ tests pass
  - [ ] Expected: 100% pass rate

- [ ] 4a.2 Run code coverage report
  - [ ] Verify: Coverage maintained or improved (≥85%)
  - [ ] Target: 90%+ critical path coverage

- [ ] 4a.3 Run code style checks
  - [ ] `styler::style_dir('R')`
  - [ ] `lintr::lint_dir('R')`
  - [ ] Verify: No new linting errors introduced

- [ ] 4a.4 Run package check: `devtools::check()`
  - [ ] Verify: No errors, warnings, or notes introduced

### Phase 4b: Breaking Changes Assessment

- [ ] 4b.1 Verify public API unchanged
  - [ ] NAMESPACE exports: Same functions, no new orphans
  - [ ] Function signatures: No changes to exported functions
  - [ ] Behavior: All public functions work as before

- [ ] 4b.2 Verify no behavior changes
  - [ ] All refactoring is internal reorganization
  - [ ] Performance should improve (no degradation expected)

### Phase 4c: Performance Verification

- [ ] 4c.1 Measure startup time
  - [ ] Baseline: Run `library(biSPCharts)` multiple times
  - [ ] Target: < 100ms (or equal to pre-refactor)
  - [ ] Record results in commit message

- [ ] 4c.2 Measure memory usage
  - [ ] Baseline: Memory footprint during startup
  - [ ] Target: Same (no new structures created)

- [ ] 4c.3 Measure reactive performance
  - [ ] Baseline: Chart rendering time with typical dataset
  - [ ] Target: Same or improved (no reactive storms introduced)

- [ ] 4c.4 **Phase 4 completion check:**
  - [ ] All tests pass
  - [ ] Code coverage maintained or improved
  - [ ] No linting errors
  - [ ] Package check passes
  - [ ] Performance verified
  - [ ] Documentation updated

---

## Overall Completion Criteria

- [ ] All 4 phases complete
- [ ] All 1196+ tests still pass
- [ ] Code coverage ≥90%
- [ ] No linting errors
- [ ] Package check passes with no issues
- [ ] No breaking changes to public API
- [ ] Performance verified (startup, memory, rendering)
- [ ] Documentation updated (CONFIGURATION.md, CLAUDE.md)
- [ ] Manual testing completed (full workflow verification)

---

## Timeline

```
Week 1-2:  Phase 1 - Test Consolidation (9-13 hours)
Week 3-5:  Phase 2 - Refactor Large Files (26-35 hours)
Week 6:    Phase 3 - Configuration Consolidation (10-14 hours)
Week 6-7:  Phase 4 - Cleanup & Verification (6-9 hours)
────────────────────────────────────────────────────
TOTAL:     51-71 hours (~2 weeks full-time, 4-6 weeks part-time)
```
