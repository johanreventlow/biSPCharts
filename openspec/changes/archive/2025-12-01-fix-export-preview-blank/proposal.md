# Proposal: Fix Export Preview Blank Screen

**ID:** fix-export-preview-blank
**Type:** bugfix
**Status:** completed
**Priority:** high
**GitHub Issue:** #96

## Problem Statement

Efter migration til BFHcharts v0.3.0 export API (commit `05fd60b`) viser export preview på eksport-siden en tom hvid skærm i stedet for SPC chart preview.

## Root Cause Analysis

**Identificeret årsag:** `return()` statements inde i `safe_operation()` code blocks fungerer ikke korrekt i R.

Problemet:
1. `safe_operation()` evaluerer `code` blokken med `force(code)`
2. `return()` statements inde i code blokken returnerer `NULL` til `safe_operation`, ikke den forventede værdi
3. Dette skyldes R's semantik for `return()` i `force()` evaluering

Fejlen var udbredt i flere funktioner:
- `build_export_plot()` i `mod_export_server.R`
- `compute_spc_results_bfh()` i `fct_spc_bfh_service.R`
- `transform_bfh_output()` i `fct_spc_bfh_service.R`
- `call_bfh_chart()` i `fct_spc_bfh_service.R`
- `map_params_to_bfhchart()` i `fct_spc_bfh_service.R`
- Flere andre utility funktioner

## Solution Implemented

### Fix Pattern
Erstat alle `return(value)` statements i `safe_operation()` code blocks med bare værdien:

```r
# FØR (fejlagtigt):
safe_operation(
  operation_name = "...",
  code = {
    result <- compute_something()
    return(result)  # ❌ Returnerer NULL!
  },
  fallback = NULL
)

# EFTER (korrekt):
safe_operation(
  operation_name = "...",
  code = {
    result <- compute_something()
    result  # ✅ Returnerer result korrekt
  },
  fallback = NULL
)
```

### Files Modified

| File | Change |
|------|--------|
| `R/mod_export_server.R` | Fjernet `return()` i `build_export_plot()` og PDF preview code blocks |
| `R/fct_spc_bfh_service.R` | Fjernet `return()` i 6+ funktioner med `safe_operation()` |

### Early Return Pattern
For funktioner der kræver early exits (som `add_comment_annotations()`), brug conditional flow:

```r
# FØR (early returns - virker ikke):
if (some_condition) {
  return(default_value)
}
# continue...

# EFTER (conditional flow):
should_process <- TRUE
result <- default_value

if (some_condition) {
  should_process <- FALSE
}

if (should_process) {
  result <- compute_result()
}

result  # Returnér til sidst
```

## Verification

Test bekræfter at fix virker:
```
✅ compute_spc_results_bfh returned successfully
  - is_null: FALSE
  - names: plot, qic_data, metadata, bfh_qic_result
  - has_plot: TRUE
  - plot_class: ggplot2::ggplot, ggplot, ggplot2::gg, S7_object, gg

✅ SUCCESS: Plot object was returned correctly!
```

## Acceptance Criteria

- [x] Export preview viser SPC chart korrekt
- [x] `compute_spc_results_bfh()` returnerer komplet resultat
- [x] Alle `safe_operation()` code blocks returnerer korrekt
- [x] R kode parser korrekt

## Learning

**Kritisk R-semantik:** Brug ALDRIG `return()` inde i `safe_operation()` code blocks. R's `force()` evaluering håndterer ikke `return()` som forventet.

**Best Practice:** Dokumentér denne begrænsning i `safe_operation()` funktionens docstring og tilføj kommentarer i koden.

## Related

- **Parent:** OpenSpec change `migrate-to-bfhcharts-export`
- **Commit:** `05fd60b` (refactor(export): migrate to BFHcharts v0.3.0 export API)
- **Branch:** `refactor/bfhcharts-export-migration`
