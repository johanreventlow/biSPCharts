# Phase 2c: Reactive Dependency Map for mod_spc_chart_server.R

**File:** `R/mod_spc_chart_server.R` (1330 LOC)

**Purpose:** Document exact reactive chains before splitting to prevent race conditions and circular dependencies.

---

## Reactive Chain Flow

```
INPUT LAYER (Module Arguments)
├─ data_reactive
├─ column_config_reactive
├─ chart_type_reactive
├─ target_value_reactive
├─ target_text_reactive
├─ centerline_value_reactive
├─ skift_config_reactive
├─ frys_config_reactive
├─ chart_title_reactive (optional)
├─ y_axis_unit_reactive (optional)
├─ kommentar_column_reactive (optional)
└─ app_state (centralized state)

         ↓↓↓ (no direct dependencies)

STATE LAYER (app_state initialization & updates)
└─ app_state$events$visualization_update_needed (0L)
└─ app_state$visualization$module_cached_data
└─ app_state$visualization$module_data_cache
└─ app_state$visualization$viewport_dims

         ↓↓↓

CORE REACTIVES (in dependency order)
┌─────────────────────────────────────────────────────────────┐
│ 1. module_data_reactive()                          (Line 180) │
│    Dependencies: app_state$data$current_data                  │
│    Dependencies: app_state$ui$hide_anhoej_rules               │
│    Purpose: Provide filtered data to rest of chain            │
│    Cache: app_state$visualization$module_data_cache           │
│    Trigger: observeEvent(app_state$events$..., once=FALSE)   │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. chart_config_raw()                              (Line 217) │
│    Dependencies: module_data_reactive()                       │
│    Dependencies: column_config_reactive()                     │
│    Dependencies: chart_type_reactive()                        │
│    Purpose: Extract raw chart configuration                  │
│    Reads: app_state$columns (auto-detect results)            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. data_ready()                                    (Line 266) │
│    Dependencies: module_data_reactive()                       │
│    Purpose: Boolean check if data is valid for plotting      │
│    Validates: nrow > 0, required columns present             │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. spc_inputs_raw()                                (Line 281) │
│    Dependencies: module_data_reactive()                       │
│    Dependencies: chart_config_raw()                           │
│    Dependencies: data_ready()                                 │
│    Dependencies: target_value_reactive()                      │
│    Dependencies: target_text_reactive()                       │
│    Dependencies: centerline_value_reactive()                  │
│    Dependencies: y_axis_unit_reactive()                       │
│    Dependencies: skift_config_reactive()                      │
│    Dependencies: frys_config_reactive()                       │
│    Dependencies: kommentar_column_reactive()                  │
│    Dependencies: chart_title_reactive()                       │
│    Purpose: Build complete parameter object for BFHcharts    │
│    Output: list(x, y, chart_type, notes, target, ...)       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. spc_results()                                   (Line 403) │
│    Dependencies: spc_inputs_raw() → calls isolate()          │
│    Dependencies: app_state$visualization$viewport_dims       │
│    Purpose: Call BFHcharts + Anhøj rules computation        │
│    Cache: Uses bindCache(cache_key) with size=1             │
│    Key: paste(spc_inputs, viewport_dims)                     │
│    SPC Engine: compute_spc_results_bfh()                     │
│    Returns: list(plot, data, metadata)                       │
│    Side Effect: Sets app_state via emit$set_plot_state()    │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. spc_plot()                                      (Line 664) │
│    Dependencies: spc_results()                                │
│    Purpose: Extract plot object from spc_results             │
│    Returns: ggplot2 object ready to render                   │
└─────────────────────────────────────────────────────────────┘
                           ↓

OUTPUT LAYER (Rendering)
├─ output$spc_plot_actual = renderPlot(spc_plot())  (Line 774)
├─ output$plot_ready = reactive(TRUE/FALSE)         (Line 873)
├─ output$plot_info = renderUI(...)                 (Line 879)
├─ output$plot_status_boxes = renderUI(...)         (Line 919)
├─ output$anhoej_rules_boxes = renderUI(...)        (Line 961)
├─ output$data_quality_box = renderUI(...)          (Line 1287)
└─ output$report_status_box = renderUI(...)         (Line 1303)
```

---

## Observer Flow

```
OBSERVER 1: Viewport Dimensions
─────────────────────────────────────────────────
Location: Line 94
Priority: Default (medium)
Trigger: session$clientData[[...]] changes
Action: 
  ├─ Read width/height from client
  ├─ Validate (width > 100, height > 100)
  └─ set_viewport_dims(app_state, width, height)
Side Effect: 
  └─ Updates app_state$visualization$viewport_dims → triggers spc_results() recompute

OBSERVER 2: Data Update Event
──────────────────────────────────────────────────
Location: Line 103
Priority: Default (medium)
Trigger: observeEvent(app_state$events$visualization_update_needed, ...)
Action:
  ├─ Read new data from app_state$data$current_data
  ├─ Apply hide_anhoej_rules attribute
  ├─ Filter non-empty rows
  └─ Cache in app_state$visualization$module_data_cache
Side Effect:
  └─ module_data_reactive() → triggers spc_inputs_raw() → spc_results() recompute

OBSERVER 3: Cache Invalidation Monitor
──────────────────────────────────────────────────
Location: Line 688
Priority: Default (medium)
Trigger: Depends on spc_results() via reactiveVal
Action:
  ├─ Monitor plot state changes
  └─ Handle cache invalidation timing
Side Effect:
  └─ Ensures spc_results() cache doesn't persist stale data
```

---

## Critical Dependency Rules

✅ **SAFE PATTERNS (no risk of circular dependency):**
```r
# Reactive → Reactive (depends on upstream)
chart_config_raw <- reactive({
  data <- module_data_reactive()  # OK - reads downstream value
  chart_config_reactive()         # OK - reads input
})

# Observer → Reactive (sets state, doesn't read downstream)
observe({
  app_state$viewport <- new_value  # OK - doesn't trigger downstream
})

# Reactive → isolate() (breaks chain)
spc_results <- reactive({
  inputs <- isolate(spc_inputs_raw())  # OK - isolate breaks dependency
  compute(inputs)
})
```

❌ **DANGER PATTERNS (will cause infinite loops/race conditions):**
```r
# Circular dependency
reactive1 <- reactive({
  reactive2()  # Problem: if reactive2 depends on reactive1 → LOOP
})

# Observer writing to same reactive it depends on
observe({
  value <- reactive_data()
  reactive_data <- transform(value)  # WRONG - can't write to reactive it reads
})

# Multiple observers firing simultaneously
observeEvent(app_state$event1, { app_state$event2 <- T })
observeEvent(app_state$event2, { app_state$event1 <- T })  # LOOP
```

---

## Guard Conditions (Race Prevention)

**Every observer MUST check in_progress flag:**

```r
observeEvent(app_state$events$visualization_update_needed, {
  # Guard 1: Check if already processing
  if (app_state$data$processing) {
    log_debug("Skip: visualization already updating")
    return()
  }
  
  # Guard 2: Validate input exists
  req(app_state$data$current_data)
  
  # Guard 3: Perform update atomically
  app_state$visualization$module_data_cache <- filtered_data
})
```

---

## Debounce & Timing

**Reactive debounce:** None currently (spc_results has bindCache instead)
- Cache key: `paste(spc_inputs_hash, viewport_dims)`
- Cache size: 1 entry
- TTL: Session lifetime

**Observer timing:** No explicit debounce
- Viewport observer: Immediate (but screen typically doesn't resize rapidly)
- Data update observer: Immediate (but upstream already debounced)

---

## Phase 2c Extraction Plan

### Safe Extraction Order (Lower Risk → Higher Risk)

**Stage 1: Data Management (LOW RISK - isolated from compute)**
```
R/mod_spc_chart_state.R
  ├─ get_module_data() function
  ├─ module_data_reactive()
  ├─ data_ready() reactive
  └─ State initialization code
```

**Stage 2: Configuration Building (LOW RISK - reads, doesn't write)**
```
R/mod_spc_chart_config.R
  ├─ chart_config_raw() reactive
  ├─ Chart parameter validation
  └─ Configuration helpers
```

**Stage 3: SPC Computation (MEDIUM RISK - complex, but isolated)**
```
R/mod_spc_chart_compute.R
  ├─ spc_inputs_raw() reactive
  ├─ spc_results() reactive
  ├─ spc_plot() reactive
  ├─ BFHcharts facade calls
  └─ Cache management
```

**Stage 4: Viewport & Side Effects (MEDIUM RISK - manages state)**
```
R/mod_spc_chart_observers.R
  ├─ Viewport dimension observer
  ├─ Data update observer
  ├─ Cache invalidation observer
  └─ Event emit calls
```

**Stage 5: Output Rendering (LOW RISK - depends on above reactives)**
```
R/mod_spc_chart_ui.R
  ├─ output$spc_plot_actual
  ├─ output$plot_ready
  ├─ output$plot_info
  ├─ output$plot_status_boxes
  ├─ output$anhoej_rules_boxes
  ├─ output$data_quality_box
  └─ output$report_status_box
```

**Stage 6: Module Orchestration (FINAL - coordinates all above)**
```
R/mod_spc_chart_server.R (simplified)
  ├─ visualizationModuleServer() - main orchestrator
  ├─ Import all sub-modules
  ├─ Call module initialization functions
  └─ Register observers
```

---

## Test Strategy for Each Stage

| Stage | Test Type | Critical Check |
|-------|-----------|-----------------|
| 1. State | Unit + Integration | Data filtering, caching, attribute preservation |
| 2. Config | Unit | Parameter building, validation, edge cases |
| 3. Compute | Integration + Performance | Reactive chain, cache hits, Anhøj metadata |
| 4. Observers | Integration | Observer firing order, guard conditions |
| 5. Output | UI + Manual | Rendering, reactivity, error handling |
| 6. Orchestration | Full Module | End-to-end workflow, no regressions |

---

## Verification Checklist Before Proceeding

- [ ] This map is complete (all reactives, observers, outputs listed)
- [ ] All dependencies are correctly identified
- [ ] No circular dependencies exist
- [ ] Guard conditions are documented
- [ ] Extraction order is logical
- [ ] Tests are planned for each stage

---

**Created:** 2026-04-12  
**Status:** Ready for Phase 2c extraction (Stage 1-6 planned)  
**Risk Level:** MEDIUM (reactive chains) - mitigated by incremental extraction + comprehensive tests
