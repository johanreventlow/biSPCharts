# Phase 2c: Detailed Execution Plan

**File:** `R/mod_spc_chart_server.R` (1330 LOC)  
**Target:** Split into 6 focused modules  
**Risk Level:** MEDIUM (mitigated by incremental extraction + 54-test baseline)  
**Timeline:** 5-7 stages, ~2-3 hours per stage  

---

## Pre-Refactoring Status

✅ **Dependency Map Created:** `docs/PHASE_2C_REACTIVE_DEPENDENCY_MAP.md`
✅ **Baseline Tests Created:** `tests/testthat/test-phase-2c-reactive-chain.R`
✅ **Baseline Tests Pass:** 54/54 (100%)
✅ **Worktree Ready:** `phase-2c-spc-chart` branch prepared

---

## Stage 1: Extract Data Management → `mod_spc_chart_state.R`

**Risk Level:** 🟢 LOW  
**Estimated Time:** 1-1.5 hours  
**Test Impact:** No new tests needed (baseline covers)

### Files to Extract (from lines 9-184)

```r
# From mod_spc_chart_server.R → extract to mod_spc_chart_state.R
├─ safe_max() helper function
├─ get_module_data() function  
└─ module_data_reactive() reactive (lines 180-184)
```

### Implementation Steps

1. **Create new file** `R/mod_spc_chart_state.R`
2. **Copy these elements:**
   - safe_max function (lines 18-33)
   - State initialization comments
   - get_module_data function (lines 50-74)
   - module_data_reactive function (lines 180-184)
3. **Add roxygen docs** for exported functions
4. **Update mod_spc_chart_server.R:**
   - Remove extracted functions
   - Add: `source("R/mod_spc_chart_state.R")` or import via devtools::load_all()
5. **Run tests:** `test_file('tests/testthat/test-phase-2c-reactive-chain.R')`
6. **Commit:** `refactor(spc-chart): extract data management to mod_spc_chart_state.R`

### Verification Checklist

- [ ] New file compiles without errors
- [ ] module_data_reactive() works with app_state
- [ ] get_module_data() applies filters correctly
- [ ] safe_max() handles edge cases (empty, all-NA, infinite)
- [ ] Baseline tests still pass (54/54)
- [ ] No changes to public API

---

## Stage 2: Extract Configuration Building → `mod_spc_chart_config.R`

**Risk Level:** 🟢 LOW  
**Estimated Time:** 1-1.5 hours  
**Depends On:** Stage 1 complete

### Files to Extract (lines 217-265)

```r
# From mod_spc_chart_server.R → extract to mod_spc_chart_config.R
└─ chart_config_raw() reactive (lines 217-265)
```

### Implementation Steps

1. **Create new file** `R/mod_spc_chart_config.R`
2. **Copy:** chart_config_raw reactive with roxygen docs
3. **Update dependencies in chart_config_raw:**
   - Depends: module_data_reactive() → import from state module
   - Depends: column_config_reactive() → comes from module arguments
4. **Run tests:** Verify baseline still passes
5. **Commit:** `refactor(spc-chart): extract config building to mod_spc_chart_config.R`

### Verification Checklist

- [ ] chart_config_raw builds correct structure
- [ ] Handles NULL inputs gracefully
- [ ] Fallback to "run" chart type when NULL
- [ ] Column extraction works correctly
- [ ] Baseline tests pass (54/54)

---

## Stage 3: Extract SPC Input Preparation → `mod_spc_chart_inputs.R`

**Risk Level:** 🟡 MEDIUM  
**Estimated Time:** 1.5-2 hours  
**Depends On:** Stages 1-2 complete

### Files to Extract (lines 266-402)

```r
# From mod_spc_chart_server.R → extract to mod_spc_chart_inputs.R
├─ data_ready() reactive (lines 266-280)
└─ spc_inputs_raw() reactive (lines 281-402)
```

### Why MEDIUM Risk

- Builds complete parameter object
- Depends on many upstream reactives
- Uses isolate() to break chain
- Complex parameter mapping

### Implementation Steps

1. **Create new file** `R/mod_spc_chart_inputs.R`
2. **Copy:**
   - data_ready() reactive
   - spc_inputs_raw() reactive with all parameter building logic
3. **Import upstream dependencies:**
   - module_data_reactive (from state)
   - chart_config_raw (from config)
   - All input reactives (passed as arguments)
4. **Verify isolate() usage:**
   - spc_inputs_raw must isolate spc_config_raw to avoid circular chain
5. **Run tests:** Check baseline + new integration tests
6. **Commit:** `refactor(spc-chart): extract SPC input building to mod_spc_chart_inputs.R`

### Verification Checklist

- [ ] data_ready correctly validates requirements
- [ ] spc_inputs_raw builds complete list
- [ ] All optional parameters handled (target_value, centerline, etc.)
- [ ] isolate() breaks dependencies correctly
- [ ] Parameters validated before return
- [ ] Baseline tests pass (54/54)
- [ ] Manual: Chart still renders after extraction

---

## Stage 4: Extract SPC Computation → `mod_spc_chart_compute.R`

**Risk Level:** 🟡 MEDIUM  
**Estimated Time:** 2-2.5 hours  
**Depends On:** Stages 1-3 complete  
**CRITICAL:** This is the core computation layer

### Files to Extract (lines 403-663)

```r
# From mod_spc_chart_server.R → extract to mod_spc_chart_compute.R
├─ spc_results() reactive (lines 403-511)
├─ spc_plot() reactive (lines 664-671)
└─ Cache invalidation observer (lines 688-760)
```

### Why CRITICAL

- Calls BFHcharts API
- Computes Anhøj rules
- Uses bindCache
- Sets app_state via emit

### Implementation Steps

1. **Create new file** `R/mod_spc_chart_compute.R`
2. **Copy:**
   - spc_results() reactive - complete computation pipeline
   - spc_plot() reactive - plot extraction
   - Cache observer block
3. **Update dependencies:**
   - Import spc_inputs_raw from inputs module
   - Import emit API from app_state
   - Keep app_state access for emit calls
4. **Verify caching:**
   - bindCache still works correctly
   - Cache key still valid
   - Cache size limit respected
5. **Run tests:** Full baseline + manual chart generation
6. **Commit:** `refactor(spc-chart): extract SPC computation to mod_spc_chart_compute.R`

### Verification Checklist

- [ ] BFHcharts called correctly
- [ ] Anhøj metadata present in result
- [ ] Cache hits prevent recomputation
- [ ] emit$set_plot_state() updates app_state
- [ ] spc_plot extracts plot correctly
- [ ] Baseline tests pass (54/54)
- [ ] **Manual Test:** Upload data, verify chart renders
- [ ] **Manual Test:** Change chart type, verify quick update (cache hit)
- [ ] **Manual Test:** Change Y column, verify recompute (cache miss)

---

## Stage 5: Extract Observers & Side Effects → `mod_spc_chart_observers.R`

**Risk Level:** 🟡 MEDIUM  
**Estimated Time:** 1.5-2 hours  
**Depends On:** Stages 1-4 complete  
**CRITICAL:** Observer order and priorities matter

### Files to Extract (lines 94-100, 103-179, 688-760)

```r
# From mod_spc_chart_server.R → extract to mod_spc_chart_observers.R
├─ Viewport observer (lines 94-100)
├─ Data update observeEvent (lines 103-179)
├─ Cache monitor observer (lines 688-760)
└─ Event emit coordination
```

### Why CRITICAL

- Observer firing order affects state consistency
- Priorities prevent race conditions
- Guards check in_progress flags
- Multiple events must fire in correct sequence

### Implementation Steps

1. **Create new file** `R/mod_spc_chart_observers.R`
2. **Copy each observer:**
   - Viewport observer (priority: default)
   - Data update observeEvent (priority: HIGH)
   - Cache monitor observer (priority: default)
3. **Verify observer priorities:**
   - Data update: OBSERVER_PRIORITIES$HIGH (must fire first)
   - Others: default or medium
4. **Verify guard conditions:**
   - Each observer checks in_progress flag
   - Each observer validates req()
5. **Run tests:** Baseline + manual sequential operations
6. **Commit:** `refactor(spc-chart): extract observers to mod_spc_chart_observers.R`

### Verification Checklist

- [ ] All observers present and correct
- [ ] Event firing order is correct
- [ ] Guard conditions functional
- [ ] req() validations work
- [ ] No missed isolate() calls
- [ ] Baseline tests pass (54/54)
- [ ] **Manual Test:** Upload file → auto-detect → chart renders (in order)
- [ ] **Manual Test:** Change settings → no race conditions
- [ ] **Manual Test:** Switch tabs → state preserved

---

## Stage 6: Extract Output Rendering → `mod_spc_chart_ui.R`

**Risk Level:** 🟢 LOW  
**Estimated Time:** 1-1.5 hours  
**Depends On:** Stages 1-5 complete

### Files to Extract (lines 774-1303)

```r
# From mod_spc_chart_server.R → extract to mod_spc_chart_ui.R
├─ output$spc_plot_actual (renderPlot)
├─ output$plot_ready (reactive output)
├─ output$plot_info (renderUI)
├─ output$plot_status_boxes (renderUI)
├─ output$anhoej_rules_boxes (renderUI)
├─ output$data_quality_box (renderUI)
└─ output$report_status_box (renderUI)
```

### Why LOW Risk

- Depends only on upstream reactives
- No complex logic
- No state updates
- Simple reactive reads

### Implementation Steps

1. **Create new file** `R/mod_spc_chart_ui.R`
2. **Copy all output statements** with roxygen docs
3. **Update dependencies:**
   - Import spc_plot from compute module
   - Import spc_results for metadata access
   - Import module_data_reactive for quality checks
4. **Run tests:** Baseline + rendering verification
5. **Commit:** `refactor(spc-chart): extract rendering to mod_spc_chart_ui.R`

### Verification Checklist

- [ ] All output statements present
- [ ] Rendering logic unchanged
- [ ] All dependencies correct
- [ ] Baseline tests pass (54/54)
- [ ] **Manual Test:** All boxes display correctly
- [ ] **Manual Test:** Status updates reflect state

---

## Stage 7: Create Orchestrator → Simplified `mod_spc_chart_server.R`

**Risk Level:** 🟢 LOW  
**Estimated Time:** 1 hour  
**Depends On:** Stages 1-6 complete

### Transformation

```r
# OLD: 1330 lines - single monolithic file
visualizationModuleServer <- function(id, ...) {
  # 1300 lines of inline code
}

# NEW: ~250 lines - orchestrator only
visualizationModuleServer <- function(id, ...) {
  moduleServer(id, function(input, output, session) {
    # Initialize sub-modules
    state_module <- initialize_spc_chart_state(app_state, ...)
    config_module <- initialize_spc_chart_config(app_state, ...)
    inputs_module <- initialize_spc_chart_inputs(app_state, ...)
    compute_module <- initialize_spc_chart_compute(app_state, ...)
    observe_module <- initialize_spc_chart_observers(app_state, ...)
    ui_module <- initialize_spc_chart_ui(app_state, ...)
  })
}
```

### Implementation Steps

1. **Simplify mod_spc_chart_server.R:**
   - Remove all extracted code
   - Keep only orchestration & imports
   - Add documentation showing dependency order
2. **Create initialization functions** (if needed):
   - Each sub-module may have setup code
3. **Add dependency comments:**
   ```r
   # Dependency order (required for correctness):
   # 1. mod_spc_chart_state (data loading)
   # 2. mod_spc_chart_config (parameter building)
   # 3. mod_spc_chart_inputs (SPC parameter construction)
   # 4. mod_spc_chart_compute (BFHcharts computation)
   # 5. mod_spc_chart_observers (event handlers)
   # 6. mod_spc_chart_ui (output rendering)
   ```
4. **Run full test suite:**
   - Baseline tests (54)
   - Integration tests
   - Manual end-to-end
5. **Commit:** `refactor(spc-chart): extract orchestrator logic from mod_spc_chart_server.R`

### Final Verification Checklist

- [ ] Original module function still works identically
- [ ] All tests pass (baseline 54 + integration)
- [ ] No public API changed
- [ ] **Manual Full Workflow:**
  - Upload CSV
  - Auto-detect columns
  - Verify chart renders
  - Change chart type
  - Export to PDF
  - Verify no errors/races
- [ ] Code review ready

---

## Testing Strategy Across All Stages

| Stage | Unit Tests | Integration Tests | Manual Tests |
|-------|-----------|-------------------|--------------|
| 1. State | ✅ Baseline 54 | Verify data filtering | None |
| 2. Config | ✅ Baseline 54 | Chart config building | None |
| 3. Inputs | ✅ Baseline 54 | Parameter validation | None |
| 4. Compute | ✅ Baseline 54 | BFHcharts integration | Chart renders ✅ |
| 5. Observers | ✅ Baseline 54 | Observer ordering | Multi-step workflow ✅ |
| 6. UI | ✅ Baseline 54 | Output rendering | All boxes display ✅ |
| 7. Orchestrator | ✅ Baseline 54 | End-to-end flow | Full app usage ✅ |

---

## Rollback Plan

If any stage introduces regression:

```bash
# Immediate exit from worktree
exit

# Reset worktree
git -C .claude/worktrees/phase-2c-spc-chart reset --hard origin/master

# Switch to main branch
git checkout master

# Analyze failure
git diff HEAD~1  # See what broke

# Document issue in KNOWN_ISSUES.md
# Restart with safer approach (smaller units, more tests)
```

---

## Success Criteria

✅ **Phase 2c Complete When:**

- [ ] All 7 stages complete
- [ ] 54 baseline tests pass (100%)
- [ ] 0 regressions in integration tests
- [ ] 0 regressions in manual testing
- [ ] Code review approved
- [ ] All commits atomic & properly described
- [ ] PHASE_2C_REACTIVE_DEPENDENCY_MAP.md updated if needed
- [ ] New module structure documented

---

## Estimated Timeline

| Stage | Time | Cumulative |
|-------|------|-----------|
| 1. State | 1-1.5h | 1-1.5h |
| 2. Config | 1-1.5h | 2-3h |
| 3. Inputs | 1.5-2h | 3.5-5h |
| 4. Compute | 2-2.5h | 5.5-7.5h |
| 5. Observers | 1.5-2h | 7-9.5h |
| 6. UI | 1-1.5h | 8-11h |
| 7. Orchestrator | 1h | 9-12h |
| **Testing & QA** | 1-2h | **10-14h** |

**Total: ~2 full workdays or 4 half-days spread across 1 week**

---

**Status:** Ready to begin Stage 1  
**Created:** 2026-04-12  
**Baseline:** 54/54 tests passing  
**Risk Mitigation:** Incremental extraction, comprehensive testing, worktree isolation
