# Specification: export-api

## Overview

This specification defines how SPCify uses BFHcharts functions for PDF export functionality. It governs the API contract between SPCify and BFHcharts to ensure stable, maintainable integration.

## MODIFIED Requirements

### Requirement: SPCify SHALL use BFHcharts public API functions

SPCify SHALL use only exported public API functions from BFHcharts, NOT internal functions accessed via `:::` operator.

**Rationale:**
- Follows R package best practices
- Provides API stability guarantees via semantic versioning
- Enables proper error handling and validation
- Prevents breakage from BFHcharts internal refactoring

#### Scenario: Extract SPC statistics using public API

**Given** a qic result with summary data
**When** SPCify needs to extract SPC statistics
**Then** SPCify SHALL call `BFHcharts::bfh_extract_spc_stats()`
**And** SPCify SHALL NOT use `BFHcharts:::extract_spc_stats()`

**Implementation:**
```r
# CORRECT - Public API
stats <- BFHcharts::bfh_extract_spc_stats(result$summary)

# WRONG - Internal function (forbidden)
# stats <- BFHcharts:::extract_spc_stats(result$summary)
```

**Validation:**
- Code review: No `:::` accessor for BFHcharts functions
- Function returns expected list structure
- Error handling works (invalid input rejected)

#### Scenario: Merge metadata using public API

**Given** user-provided metadata and chart title
**When** SPCify needs to merge metadata with defaults
**Then** SPCify SHALL call `BFHcharts::bfh_merge_metadata()`
**And** SPCify SHALL NOT use `BFHcharts:::merge_metadata()`

**Implementation:**
```r
# CORRECT - Public API
merged <- BFHcharts::bfh_merge_metadata(metadata, chart_title)

# WRONG - Internal function (forbidden)
# merged <- BFHcharts:::merge_metadata(metadata, chart_title)
```

**Validation:**
- Code review: No `:::` accessor for BFHcharts functions
- Function returns expected merged metadata
- User values override defaults correctly

### Requirement: SPCify SHALL require minimum BFHcharts version

SPCify DESCRIPTION SHALL specify `BFHcharts (>= 0.4.0)` to ensure public API availability.

**Rationale:**
- BFHcharts 0.4.0 exports `bfh_extract_spc_stats()` and `bfh_merge_metadata()`
- Earlier versions do not export these functions
- Prevents runtime errors from missing exports

#### Scenario: DESCRIPTION specifies correct version

**Given** SPCify DESCRIPTION file
**When** BFHcharts dependency is specified
**Then** version requirement SHALL be `BFHcharts (>= 0.4.0)`

**Implementation:**
```
Imports:
    BFHcharts (>= 0.4.0),
    ...
```

**Validation:**
- DESCRIPTION file contains correct version requirement
- Package installation checks for BFHcharts >= 0.4.0
- Error on load if BFHcharts < 0.4.0

## Implementation Notes

**Files to modify:**
- `DESCRIPTION` - Update BFHcharts version requirement
- `R/utils_server_export.R:376` - Replace `:::extract_spc_stats` with `::bfh_extract_spc_stats`
- `R/utils_server_export.R:379` - Replace `:::merge_metadata` with `::bfh_merge_metadata`

**Migration pattern:**
```r
# Before (line 376)
stats <- BFHcharts:::extract_spc_stats(result$summary)

# After (line 376)
stats <- BFHcharts::bfh_extract_spc_stats(result$summary)

# Before (line 379)
merged_metadata <- BFHcharts:::merge_metadata(metadata, result$config$chart_title)

# After (line 379)
merged_metadata <- BFHcharts::bfh_merge_metadata(metadata, result$config$chart_title)
```

**Testing strategy:**
1. Unit test: Verify function calls work
2. Integration test: Generate PDF end-to-end
3. Visual test: Inspect PDF output for correctness
4. Error test: Verify validation errors propagate

## Validation

**Code review checklist:**
- ✅ No `BFHcharts:::` usage in codebase
- ✅ DESCRIPTION requires BFHcharts >= 0.4.0
- ✅ PDF export generates successfully
- ✅ SPC statistics appear in PDF
- ✅ Metadata appears in PDF

**Automated tests:**
- ✅ `devtools::check()` passes
- ✅ All existing tests still pass
- ✅ No regressions in PDF generation

**Manual testing:**
- ✅ Generate PDF from live SPC chart
- ✅ Verify metadata correct in output
- ✅ Verify statistics correct in output

## Dependencies

**R packages:**
- BFHcharts (>= 0.4.0) - provides public API functions

**Deployment dependencies:**
- BFHcharts 0.4.0 must be deployed before SPCify deployment
- Shiny app restart required after deployment

## Future Considerations

**Potential enhancements:**
- Monitor BFHcharts API stability over versions
- Subscribe to BFHcharts release notifications
- Add integration tests for API contract

**Not in scope for this change:**
- UI changes (no user-visible impact)
- New features (purely refactoring)
- Performance optimization (behavior identical)
