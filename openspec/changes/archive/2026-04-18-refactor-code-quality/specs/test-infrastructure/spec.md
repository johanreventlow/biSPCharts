## MODIFIED Requirements

### Requirement: Test File Organization

The test suite SHALL consolidate 146 test files into ~100 files by merging redundant test clusters and deleting stub files with zero test cases.

#### Scenario: Stub files deleted
- **WHEN** refactoring phase 1a completes
- **THEN** test files with 0 actual test cases are deleted (test-autodetect-engine.R, test-event-bus-full-chain.R, test-event-listener-integration.R)
- **AND** archived test files are moved to tests/testthat/archived/ with README

#### Scenario: Test clusters consolidated
- **WHEN** refactoring phase 1b completes
- **THEN** overlapping test files are merged into canonical files with clear section comments
- **AND** autodetect tests: 4 files merged into test-autodetect-unified-comprehensive.R
- **AND** cache tests: 3-5 files merged into 2 canonical files
- **AND** event system tests: consolidated into test-event-system-observers.R
- **AND** critical fixes tests: consolidated into test-critical-fixes-regression.R

#### Scenario: All tests pass after consolidation
- **WHEN** Phase 1c completes
- **THEN** all 1196+ test cases still pass (no regressions)
- **AND** test run time is reduced by estimated 5-10%

### Requirement: Test File Naming Convention

The test suite SHALL maintain consistent naming convention for test files to aid discoverability.

#### Scenario: Test file naming
- **WHEN** test files are organized
- **THEN** each test file follows pattern: `test-<feature>.R` or `test-<feature>-<variant>.R`
- **AND** test files are grouped by feature area (autodetect, cache, event system, etc.)
- **AND** archived historical test files are moved to tests/testthat/archived/ subdirectory

### Requirement: Test Coverage Preservation

The test suite SHALL preserve all test coverage targets during consolidation.

#### Scenario: Test count unchanged
- **WHEN** test consolidation completes
- **THEN** total test count remains 1196+ (all cases preserved)

#### Scenario: Coverage targets maintained
- **WHEN** Phase 1 completes
- **THEN** code coverage remains ≥90% (target: 95%+)
- **AND** 100% of critical paths covered (data load, plot generation, state sync)

## REMOVED Requirements

### Requirement: Stub test files
**Reason**: These files contain no test cases and duplicate test framework setup from other files. Removing them reduces noise and maintenance burden.
**Migration**: Test cases from these files have already been consolidated into canonical test files or are proven to be redundant.
- test-autodetect-engine.R (724 LOC, 0 tests)
- test-event-bus-full-chain.R (524 LOC, 0 tests)
- test-event-listener-integration.R (654 LOC, 0 tests)

### Requirement: Ancient historical test files
**Reason**: Phase-based test files (test-fase*.R, test-phase*.R) are from early development phases and have been superseded by more comprehensive tests.
**Migration**: Moved to tests/testthat/archived/ with README explaining their historical context.
