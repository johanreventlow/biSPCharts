## Why

Code quality audit identified three major areas for improvement:

1. **Test redundancy**: 146 test files with overlapping test cases, including stub files with 0 tests but 600+ LOC each
2. **Large source files**: 4 files exceed 1300 LOC (fct_spc_bfh_service: 2200, utils_server_event_listeners: 1791, fct_file_operations: 1366, mod_export_server: 1335), making them difficult to maintain, test, and reason about
3. **Fragmented configuration**: Configuration scattered across 8 layers (env vars, YAML, getOption(), package env, constants, inline values, function defaults) with conflicting precedence

These issues compound maintenance burden, increase testing complexity, and create hidden coupling between modules.

> **⚠️ Phase 1 (Test Consolidation) ARKIVERET 2026-04-17:**
> Overhalet af audit-data (#203) der viser kun 9 reelle stubs, og disse er
> ved nærmere undersøgelse værdifulde policy-tests der IKKE skal slettes.
> Test-consolidation håndteres i nyt arbejdsstrøm `refactor-test-suite`
> Fase 2 baseret på `dev/audit-output/test-classification.yaml`.
>
> Phase 2-4 (R-fil-split, config) fortsætter uændret.

## What Changes

- **Phase 1 (Week 1-2):** Consolidate 146 test files → ~100 files by merging redundant clusters and deleting stub files. Preserve all 1196+ test cases.
- **Phase 2 (Week 3-5):** Split 4 largest R files (6686 LOC total) into ~25 smaller, focused files (<500 LOC each). Maintain module boundaries and reactive dependencies.
- **Phase 3 (Week 6):** Unify configuration system: centralize logging config, add accessor functions for performance and UI constants, document 8-layer precedence.
- **Phase 4 (Week 6-7):** Run comprehensive test suite, verify performance, update documentation. No breaking changes to public API.

## Impact

**Affected capabilities:**
- Test infrastructure (consolidation, archival)
- Code organization (file splitting, module clarity)
- Configuration management (unified system, accessor functions)

**Affected code:**
- `tests/testthat/` (Phase 1: delete 3 files, merge 4-6 clusters)
- `R/fct_spc_bfh_service.R` → 5 files (Phase 2a)
- `R/mod_export_server.R` → 5 files (Phase 2b)
- `R/mod_spc_chart_server.R` → 6 files (Phase 2c)
- `R/utils_server_event_listeners.R` → 8 files (Phase 2d)
- `R/utils_logging.R`, `R/config_*.R` (Phase 3)

**Breaking changes:** None. Refactoring is internal reorganization.

**Risk level:** Medium (reactive chains in mod_spc_chart_server.R require careful testing)

**Estimated effort:** 51-71 hours total (2 weeks full-time, 4-6 weeks part-time)

## Related

- Plan document: `.claude/plans/lovely-dancing-rabbit.md`
