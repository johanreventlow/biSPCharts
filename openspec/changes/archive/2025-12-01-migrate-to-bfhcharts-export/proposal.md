# Proposal: Migrate to BFHcharts Export API

**Status:** completed
**Issue:** #95
**Created:** 2025-12-01
**Updated:** 2025-12-01
**Author:** Claude

## Why

BFHcharts v0.3.0 now includes export functionality (`bfh_export_png()`, `bfh_export_pdf()`) that duplicates code in SPCify. Maintaining two implementations causes maintenance burden, inconsistency risk, and violates DRY principles. This migration consolidates export logic in BFHcharts as the single source of truth.

## Problem Statement

SPCify currently has ~850 lines of duplicate export code that duplicates BFHcharts v0.3.0 functionality:
- `R/fct_export_png.R` (280 lines) - PNG export via ggsave()
- `R/fct_export_typst.R` (576 lines) - PDF export via Typst/Quarto

This causes:
1. **Maintenance burden:** Two codebases to maintain for same functionality
2. **Inconsistency risk:** Features/fixes applied to one but not the other
3. **Code duplication:** Violates DRY principle

## Proposed Solution

Delete duplicate export functions and delegate to BFHcharts v0.3.0:

| Current SPCify | BFHcharts Replacement |
|----------------|----------------------|
| `generate_png_export()` | `BFHcharts::bfh_export_png()` |
| `export_spc_to_typst_pdf()` | `BFHcharts::bfh_export_pdf()` |
| `create_typst_document()` | Internal to BFHcharts |
| `compile_typst_to_pdf()` | Internal to BFHcharts |

**Keep unchanged:**
- `R/fct_export_powerpoint.R` - Not in BFHcharts
- `R/utils_server_export.R` - Utility functions still needed
- `R/utils_export_validation.R` - Validation helpers

## Technical Requirements

### API Compatibility Challenge

BFHcharts export functions require `bfh_qic_result` objects (S3 class), not raw ggplot:

```r
# BFHcharts API:
bfh_export_png(x, output, ...)  # x must be bfh_qic_result
bfh_export_pdf(x, output, ...)  # x must be bfh_qic_result
```

**Solution:** Modify SPCify's plot generation to store the full `bfh_qic_result` object in `app_state$visualization$result` instead of just the ggplot.

### Dimension Conversion

SPCify uses **inches**, BFHcharts uses **mm**:
```r
width_mm <- width_inches * 25.4
height_mm <- height_inches * 25.4
```

### Metadata Mapping

SPCify metadata structure is compatible with BFHcharts:
```r
metadata <- list(
  hospital = get_hospital_name_for_export(),
  department = input$export_department,
  title = input$export_title,
  analysis = input$pdf_improvement,
  data_definition = input$pdf_description,
  author = Sys.getenv("USER"),
  date = Sys.Date()
)
```

## Impact Analysis

### Dependencies
- Update `BFHcharts (>= 0.3.0)` in DESCRIPTION
- Remove unused Typst template imports

### Files Modified
1. `R/mod_export_server.R` - Replace export calls with BFHcharts functions
2. `R/fct_spc_bfh_service.R` or equivalent - Store full `bfh_qic_result`
3. `DESCRIPTION` - Update BFHcharts version requirement

### Files Removed
1. `R/fct_export_png.R` - Now in BFHcharts
2. `R/fct_export_typst.R` - Now in BFHcharts
3. `inst/templates/typst/` - Use BFHcharts templates

### Breaking Changes
**None for end users** - This is internal refactoring. The Shiny UI and download handlers remain unchanged from user perspective.

## Success Criteria

- [x] SPCify export module uses BFHcharts export functions
- [x] All existing export tests pass
- [x] PNG export workflow works in Shiny app
- [x] PDF export workflow works in Shiny app
- [x] PowerPoint export unchanged
- [x] devtools::check() passes
- [x] ~850 lines of code removed

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Different API signatures | Dimension conversion wrapper in mod_export_server.R |
| bfh_qic_result requirement | Store full result in app_state |
| Test failures | Update tests for new function signatures |
| Typst template location change | BFHcharts includes templates |

## Estimated Effort

- **Phase 1 (Prep):** 30 min
- **Phase 2 (PNG migration):** 1-2 hours
- **Phase 3 (PDF migration):** 2-3 hours
- **Phase 4 (Cleanup):** 1 hour
- **Phase 5 (Release):** 30 min

**Total:** 5-7 hours

## Related

- GitHub Issue: #95
- BFHcharts v0.3.0 release
- BFHcharts GitHub Issue #59
