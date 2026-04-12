# Test Organization & Consolidation

This directory contains the test suite for biSPCharts using testthat.

## Phase 1 Consolidation (Completed)

### Files Consolidated (Phase 1a-1b)
- Deleted 3 stub test files (test-autodetect-engine.R, test-event-bus-full-chain.R, test-event-listener-integration.R)
- Merged 8 tests from smaller files into canonical test files:
  - 3 tests from test-anhoej-results-update.R → test-anhoej-rules.R
  - 2 tests from test-no-autodetect-on-table-edit.R → test-autodetect-unified-comprehensive.R
  - 3 tests from test-dropdown-loop-prevention.R → test-event-system-observers.R

### Small Test Files (Phase 1c - Retained)
The following small test files are retained as they test unique architectural requirements:

**Namespace & Architecture:**
- test-namespace-integrity.R (1 test) - Validates NAMESPACE exports
- test-dependency-namespace.R (1 test) - Validates namespace usage patterns

**Configuration & Standards:**
- test-branding-globals.R (1 test) - Hospital branding constants
- test-logging-debug-cat.R (1 test) - Logging standards compliance
- test-config_chart_types.R (7 tests) - Chart type configuration

## Test Organization by Topic

### Core Features
- **SPC Charting**: test-spc-bfh-service.R, test-spc-cache-integration.R, test-spc-plot-generation-comprehensive.R
- **Auto-Detection**: test-autodetect-tidyverse-integration.R, test-autodetect-unified-comprehensive.R
- **Event System**: test-event-system-emit.R, test-event-system-observers.R

### Data Management
- **Cache**: test-cache-collision-fix.R, test-cache-data-signature-bugs.R, test-cache-invalidation-sprint3.R, test-cache-reactive-lazy-evaluation.R, test-spc-cache-integration.R
- **File Operations**: test-file-operations.R, test-fct_spc_file_save_load.R
- **Anhøj Rules**: test-anhoej-metadata-local.R, test-anhoej-results-update.R, test-anhoej-rules.R

### UI & Interaction
- **Chart UI**: test-mod-spc-chart-integration.R, test-generateSPCPlot-comprehensive.R
- **Export**: test-mod_export.R
- **Wizard**: test-wizard.R

### Quality & Standards
- **Error Handling**: test-bfh-error-handling.R
- **Logging**: test-logging-system.R
- **Architecture**: test-namespace-integrity.R, test-dependency-namespace.R

## Test Format

- Primary: `test_that()` blocks from testthat package
- Alternative: `describe()`/`it()` blocks for more structured tests (used in comprehensive test files)

## Running Tests

```r
# All tests
testthat::test_dir('tests/testthat')

# Specific test file
testthat::test_file('tests/testthat/test-spc-bfh-service.R')

# Pattern-based
testthat::test_dir('tests/testthat', pattern = 'spc')
```

## Coverage Goals

- Overall: ≥90% code coverage
- Critical paths: 100% coverage
- SPC computation pipeline: 100%
- State management: 100%
- Error handling: 100%

---
Last updated: Phase 1 consolidation complete (120 test files, 1196+ test cases)
