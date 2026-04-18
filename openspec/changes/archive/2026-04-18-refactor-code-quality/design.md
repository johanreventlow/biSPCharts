# Design Document: Code Quality Refactoring

## Context

**Problem:** biSPCharts codebase exhibits three interconnected code quality issues:

1. **Test redundancy** (146 files, 35K LOC)
   - Overlapping test clusters testing same functionality
   - Stub files (0 tests, 600+ LOC each)
   - Difficult to maintain test suite, high false negative risk

2. **Large source files** (6686 LOC in 4 files)
   - fct_spc_bfh_service.R: 2200 LOC (11 functions, 3 logical groups)
   - utils_server_event_listeners.R: 1791 LOC (1 orchestrator + 6 registration functions)
   - fct_file_operations.R: 1366 LOC
   - mod_export_server.R: 1335 LOC
   - Difficulty: code navigation, testing isolation, understanding dependencies

3. **Fragmented configuration** (8 layers)
   - Env vars, YAML, getOption(), package env, constants, inline values, function defaults
   - Conflicting precedence
   - Difficult to override at runtime, test at different configurations

**Constraints:**
- Production app with 1196+ test cases (must maintain all)
- 98 reactiveValues + 87 observers (must preserve reactive dependencies)
- All public API must remain unchanged
- No breaking changes to user behavior

**Stakeholders:**
- Development team (maintenance burden reduction)
- Tests (improved isolation, faster execution)
- Future contributors (clarity of code structure)

## Goals

**Goals:**
- Reduce test file count 146 → ~100 (delete 20-30% of files, consolidate clusters)
- Reduce LOC per R file to max 500-600 (split 4 large files into ~25 smaller files)
- Unify configuration system (single source of truth, clear precedence)
- Maintain all test coverage and pass rates
- Maintain 100% public API stability
- Improve code maintainability without changing behavior

**Non-Goals:**
- Rewriting algorithms or business logic
- Adding new features or capabilities
- Changing UI/UX
- Performance optimizations beyond refactoring benefits

## Decisions

### Decision 1: Consolidation over Deletion
**What:** Keep all 1196 tests; consolidate into fewer files with clear organization.
**Why:** Tests are valuable regression coverage. Deleting tests loses institutional knowledge and increases regression risk.
**Alternatives considered:**
- Delete "old" or "redundant" tests → Risk of losing coverage
- Archive all tests → Loss of visibility
- Keep as-is → Maintenance burden continues

### Decision 2: Functional Decomposition for File Splitting
**What:** Split large files based on logical function groups (facades, parameters, I/O, computation).
**Why:** Improves testability and module clarity. Each file has single responsibility.
**Alternatives considered:**
- Split by reactive vs pure functions → Mixes concern separation
- Keep as-is → Large files difficult to navigate
- Split alphabetically → No semantic value

### Decision 3: Centralized Accessor Functions for Configuration
**What:** Create `get_*` functions for constants; gradual migration from direct constant access.
**Why:** Allows future runtime override (YAML, env vars) without code changes. Single point for validation/caching.
**Alternatives considered:**
- Full YAML migration immediately → Large scope, high risk
- Keep direct constant access → No flexibility, hard to override
- Reactive config getters → Premature complexity

### Decision 4: Event System Preservation During Refactoring
**What:** Maintain existing event architecture (event bus, emit API, observer priorities) without changes.
**Why:** Event system is complex, well-tested, and critical. Changing it adds risk without benefit.
**Alternatives considered:**
- Refactor event system simultaneously → Scope explosion, high risk
- Simplify event system → Loses current guardrails against reactive storms

### Decision 5: Test-First Refactoring
**What:** For Phase 2 (file splitting), write tests for new modules BEFORE moving code.
**Why:** Ensures tests pass before and after move; detects issues immediately.
**Workflow:**
1. Create new file with skeleton
2. Move subset of functions
3. Update imports
4. Run tests immediately (should pass)
5. Repeat for next subset

## Risks & Mitigations

### Risk 1: Reactive Chain Breakage (Phase 2c: mod_spc_chart_server.R split)
**Severity:** HIGH (breaks core visualization)
**Probability:** MEDIUM (98 reactiveValues + 87 observers = high complexity)

**Symptoms:** 
- Circular reactive dependencies (infinite loops, app freeze)
- Missing reactive triggers (stale outputs)
- Race conditions (inconsistent state)

**Mitigations:**
- Test reactive chains extensively before & after split
- Use explicit `reactive()` and `observeEvent()` with clear dependencies
- Add logging for reactive trace events (`log_debug("[REACTIVE]", ...)`)
- Run integration tests multiple times to catch race conditions
- Manual app testing: upload → chart → export workflow
- **Fallback:** Keep mod_spc_chart_server.R as-is if issues arise

### Risk 2: Event Ordering Bugs (Phase 2d: utils_server_event_listeners.R split)
**Severity:** HIGH (breaks data processing pipeline)
**Probability:** MEDIUM (inter-event dependencies not fully mapped)

**Symptoms:**
- Events fire in wrong order (data not ready when expected)
- Observer priorities ignored or inverted
- Data loss or corruption due to missed updates

**Mitigations:**
- Map all event dependencies before splitting (create dependency graph)
- Test event ordering explicitly: emit events, verify observer execution order
- Preserve original priority system; don't change observer priorities during refactoring
- Add event ordering tests: test-event-ordering-comprehensive.R
- Manual workflow testing: full app workflow multiple times
- **Fallback:** Keep orchestrator function if ordering issues detected

### Risk 3: Configuration System Regression (Phase 3: configuration consolidation)
**Severity:** MEDIUM (affects startup and runtime behavior)
**Probability:** LOW (getter functions are simple, additive change)

**Symptoms:**
- Missing configuration values (precedence broken)
- Infinite recursion (getter calls itself)
- API key environment variables not detected

**Mitigations:**
- Test each getter in isolation (unit tests)
- Test precedence explicitly (env var > YAML > default)
- Test fallback behavior when config missing
- Keep original constants accessible during transition
- **Fallback:** Revert to direct constant access if issues arise

### Risk 4: Performance Regression (startup, memory, rendering)
**Severity:** LOW (refactoring should not impact performance)
**Probability:** LOW (no algorithm changes)

**Symptoms:**
- Startup time >100ms (target: <100ms)
- Memory footprint increases (more objects in memory)
- Chart rendering slows down (>500ms for typical dataset)

**Mitigations:**
- Measure baseline startup/memory/render times before refactoring
- Measure again after each phase
- Use `system.time()` and `object.size()` for measurements
- Run `microbenchmark` for critical operations
- Investigate any slowdown before proceeding to next phase
- **Expected result:** No performance impact (just reorganization)

### Risk 5: Test Consolidation Loses Valuable Test Coverage
**Severity:** MEDIUM (reduces test visibility)
**Probability:** LOW (all test cases preserved)

**Symptoms:**
- Edge cases no longer tested (merged tests miss original intent)
- Test file organization too coarse (hard to find specific test)

**Mitigations:**
- Preserve all test cases when consolidating (delete redundant, keep unique)
- Use clear section comments (### SECTION: Purpose) in consolidated files
- Test file naming convention remains specific (test-autodetect-*.R not test-*.R)
- Run full test suite after consolidation; verify count unchanged
- **Expected result:** 1196 tests before, 1196 tests after

## Migration Plan

### Stage 1: Propose & Approve (Current)
1. Create OpenSpec proposal (done: this document + proposal.md)
2. Create tasks.md with atomic checkpoints
3. Create design.md with risk mitigations (this document)
4. Request approval before implementation starts

### Stage 2: Implement in Phases (4-6 weeks)
1. **Phase 1:** Test consolidation (safe, easy rollback if needed)
2. **Phase 2:** File splitting (higher risk, careful testing)
3. **Phase 3:** Configuration consolidation (low risk, straightforward)
4. **Phase 4:** Verification & cleanup (validation, no code changes)

**Commits:** One atomic commit per minor task (e.g., "test(consolidation): merge autodetect test clusters"), or one per phase depending on size.

### Stage 3: Archive & Deploy (After Phase 4)
1. Mark all tasks complete in tasks.md
2. Run final test suite: all 1196+ tests pass
3. Create archive commit with summary
4. Archive OpenSpec change: `openspec archive refactor-code-quality --yes`
5. Deploy to production

## Open Questions

1. **Phase 2 splitting approach:** Should each split file be in a separate commit, or bundle Phase 2a into one commit?
   - **Current approach:** One commit per sub-phase (2a, 2b, 2c, 2d)
   - **Rationale:** Atomic, easier to review, easier to rollback if issues

2. **Configuration YAML migration timeline:** When should we move from constants to YAML?
   - **Current approach:** Getters now, YAML migration later (Phase N+1)
   - **Rationale:** Reduce scope; Phase 3 is additive only

3. **Test file archival:** Should we keep archived test files for historical reference?
   - **Current approach:** Move to `tests/testthat/archived/` with README
   - **Rationale:** Preserves history for future learning, doesn't clutter main test dir

## Success Criteria

**Phase 1 complete when:**
- [ ] 13-18 test files deleted/archived
- [ ] 4-6 test files merged
- [ ] All 1196+ tests pass
- [ ] Test run time reduced (estimated 5-10%)

**Phase 2 complete when:**
- [ ] 4 large files split into ~25 smaller files
- [ ] All LOC per file ≤600 (target: 500)
- [ ] All imports updated
- [ ] All 1196+ tests pass
- [ ] No reactive bugs introduced
- [ ] Manual app testing passed

**Phase 3 complete when:**
- [ ] Logging config unified with clear precedence
- [ ] All constants have accessor functions
- [ ] YAML extension documented
- [ ] Configuration guide written

**Phase 4 complete when:**
- [ ] All tests pass (1196+)
- [ ] Code coverage ≥90%
- [ ] No linting errors
- [ ] Package check passes
- [ ] Performance verified
- [ ] Documentation updated

## Trade-offs

**Chosen:** Consolidate tests rather than delete
- **Pro:** Preserves all test cases, zero risk of regression
- **Con:** Still 100+ test files (room for improvement)

**Chosen:** Functional decomposition for file splitting
- **Pro:** Clear responsibility, testable modules
- **Con:** Requires careful dependency mapping

**Chosen:** Phased approach (4 phases over 4-6 weeks)
- **Pro:** Manageable scope, time for recovery between phases
- **Con:** Longer timeline, coordination needed

**Chosen:** Preserve all public API
- **Pro:** No breaking changes, backward compatible
- **Con:** Some internal restructuring constrained by API
