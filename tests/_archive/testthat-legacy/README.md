# Archived Test Files

Files in this directory are from earlier development phases and have been superseded by more comprehensive tests.

## Categories

### Phase-Based Development (Phases 1-4)
- `test-fase*.R` - Phase-based development tests (4 files, 36 tests)
- `test-phase*.R` - Deprecated phase system tests (9 files, 31 tests)
- Reason: Development methodology changed to continuous integration; functionality now covered by feature-specific tests

### Legacy SPC Package Integration
- `test-qic-*.R` - Legacy qicharts2 integration tests (5 files, 64 tests)
- Reason: biSPCharts migrated from qicharts2 to BFHcharts for primary visualization. qicharts2 now used only for Anhøj rules metadata. Legacy integration tests superseded by BFHcharts-focused tests.

### Empty Stub Files
- `test-autodetect-engine.R` - Framework setup, 0 tests (deleted 2026-04-12)
- `test-event-bus-full-chain.R` - Duplicate framework, 0 tests (deleted 2026-04-12)
- `test-event-listener-integration.R` - Duplicate framework, 0 tests (deleted 2026-04-12)
- Reason: These files contained no test cases and duplicated test infrastructure from other files

## Recovery

If you need to reference old test cases from archived files:

1. Check git history: `git log --follow -- tests/_archive/testthat-legacy/`
2. View file at specific commit: `git show <commit>:tests/_archive/testthat-legacy/test-<name>.R`

Note: Filerne blev oprindeligt arkiveret i `tests/testthat/archived/` og flyttet
til `tests/_archive/testthat-legacy/` i 2026-04-19 for at komme ud af
testthat's auto-discovery-scope (jf. `harden-test-suite-regression-gate` §1.3.3).

All test logic has been preserved in current test files or was found to be redundant.

## When to Archive Files

Archive a test file when:
- ✅ It contains 0 actual test cases (test_that definitions)
- ✅ Its functionality is fully covered by other test files
- ✅ It's from an earlier development phase that's no longer active

Don't archive:
- ❌ Tests that cover unique behavior (even if similar to other tests)
- ❌ Performance or stress tests (even if long-running)
- ❌ Security or edge-case specific tests

---

**Last updated:** 2026-04-19 (Moved from `tests/testthat/archived/` → `tests/_archive/testthat-legacy/` for at komme ud af testthat-scope)
