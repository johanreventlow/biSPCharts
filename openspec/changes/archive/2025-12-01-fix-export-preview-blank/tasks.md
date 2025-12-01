# Tasks: Fix Export Preview Blank Screen

**Tracking:** GitHub Issue #96
**Status:** completed

## Phase 1: Debug & Identify

- [x] 1.1 Tilføj debug logging i `call_bfh_chart()` efter `bfh_qic()` kald
- [x] 1.2 Tilføj debug logging i `transform_bfh_output()` før validation
- [x] 1.3 Kør app og observer console logs
- [x] 1.4 Identificer præcis fejlpunkt

**Resultat:** Fejlpunkt identificeret som `return()` statements i `safe_operation()` code blocks

## Phase 2: Implement Fix

- [x] 2.1 Fjern `return()` i `build_export_plot()` (mod_export_server.R:173)
- [x] 2.2 Fjern `return()` i PDF preview code block (mod_export_server.R:707)
- [x] 2.3 Fjern `return()` i `compute_spc_results_bfh()` (fct_spc_bfh_service.R:542)
- [x] 2.4 Fjern `return()` i `map_params_to_bfhchart()` (fct_spc_bfh_service.R:906)
- [x] 2.5 Fjern `return()` i `call_bfh_chart()` (fct_spc_bfh_service.R:1133)
- [x] 2.6 Fjern `return()` i `transform_bfh_output()` (fct_spc_bfh_service.R:1367)
- [x] 2.7 Refaktorér `add_comment_annotations()` til conditional flow pattern
- [x] 2.8 Fjern `return()` i `validate_chart_type_bfh()` (fct_spc_bfh_service.R:1639)
- [x] 2.9 Fjern `return()` i `calculate_combined_anhoej_signal()` (fct_spc_bfh_service.R:1712)
- [x] 2.10 Fjern `return()` i `resolve_bfh_chart_title()` og refaktorér til conditional flow

## Phase 3: Verify All Exports

- [x] 3.1 Test at R kode parser korrekt
- [x] 3.2 Test `compute_spc_results_bfh()` returnerer komplet objekt
- [x] 3.3 Verificer plot objekt er ikke NULL
- [x] 3.4 Verificer alle 4 felter i resultat (plot, qic_data, metadata, bfh_qic_result)

## Phase 4: Cleanup

- [x] 4.1 Behold debug logging som permanent diagnostic
- [x] 4.2 Tilføj NOTE kommentarer om `return()` begrænsning
- [x] 4.3 Opdater proposal.md med completion status
- [x] 4.4 Opdater tasks.md status til completed

---

## Root Cause

`return()` statements inde i `safe_operation()` code blocks returnerer `NULL` i stedet for den forventede værdi. Dette skyldes R's semantik for `return()` i `force()` evaluering.

## Solution Pattern

```r
# FORKERT - returnerer NULL:
safe_operation(code = {
  result <- compute()
  return(result)
})

# KORREKT - returnerer result:
safe_operation(code = {
  result <- compute()
  result
})
```

## Critical Files Modified

1. `R/mod_export_server.R` - `build_export_plot()`, PDF preview
2. `R/fct_spc_bfh_service.R` - 7+ funktioner med `safe_operation()`
