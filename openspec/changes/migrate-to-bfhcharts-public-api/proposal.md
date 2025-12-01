# migrate-to-bfhcharts-public-api

## Why

**Problem:** SPCify uses BFHcharts internal functions via `:::` accessor, breaking R package best practices and creating fragile coupling.

**Current situation:**
- SPCify calls `BFHcharts:::extract_spc_stats()` in `R/utils_server_export.R:376`
- SPCify calls `BFHcharts:::merge_metadata()` in `R/utils_server_export.R:379`
- Both functions are internal and not exported by BFHcharts
- This creates tight coupling and breaks with BFHcharts refactoring
- No API stability guarantees

**Impact:**
- Code is fragile and vulnerable to upstream changes
- Violates R package best practices (using `:::` for dependencies)
- Testing becomes difficult (can't mock internal functions easily)
- No semantic versioning guarantees for internal APIs

**BFHcharts v0.4.0 solution:**
BFHcharts now exports these functions as public API:
- `BFHcharts::bfh_extract_spc_stats()` - replaces `:::extract_spc_stats()`
- `BFHcharts::bfh_merge_metadata()` - replaces `:::merge_metadata()`

Both functions have comprehensive documentation, parameter validation, and semantic versioning guarantees.

## What Changes

**Migrate from internal to public API:**

1. **Update DESCRIPTION dependency**
   - Change: `BFHcharts (>= 0.3.6)` → `BFHcharts (>= 0.4.0)`
   - Rationale: Require version with public API exports

2. **Update function calls in `R/utils_server_export.R`**
   - Line 376: `BFHcharts:::extract_spc_stats()` → `BFHcharts::bfh_extract_spc_stats()`
   - Line 379: `BFHcharts:::merge_metadata()` → `BFHcharts::bfh_merge_metadata()`
   - Rationale: Use stable public API instead of internal functions

3. **Test PDF export functionality**
   - Verify: PDF generation works with new functions
   - Verify: Metadata appears correctly in exported PDFs
   - Verify: SPC statistics appear correctly in exported PDFs
   - Rationale: Ensure no regressions from API change

## Impact

**Affected specs:**
- `export-api` (PDF export functionality uses these functions)

**Affected code:**
- `DESCRIPTION` - BFHcharts version requirement
- `R/utils_server_export.R` - Function calls in `generate_pdf_preview()`

**User-visible changes:**
- ✅ None - internal implementation detail
- ✅ More stable PDF export (uses versioned public API)
- ✅ Better error messages (public API has validation)

**Breaking changes:**
- ⚠️ None - this is purely internal refactoring
- ⚠️ Requires BFHcharts >= 0.4.0 (deployment dependency)

**Compatibility:**
- Fully backward compatible (functions have identical behavior)
- Must deploy BFHcharts 0.4.0 before deploying this change
- No changes to SPCify user interface or behavior

## Alternatives Considered

**Alternative 1: Continue using `:::` accessor**
```r
# Keep existing code
stats <- BFHcharts:::extract_spc_stats(result$summary)
```
**Rejected because:**
- Violates R package best practices
- No API stability guarantees
- Fragile coupling to BFHcharts internals
- CRAN would reject this pattern

**Alternative 2: Copy functions into SPCify**
```r
# Duplicate extract_spc_stats logic in SPCify
spcify_extract_stats <- function(summary) {
  # Copy implementation from BFHcharts
}
```
**Rejected because:**
- Code duplication violates DRY principle
- Logic drift between packages over time
- Increases maintenance burden
- Doesn't solve root cause (dependency on BFHcharts data structure)

**Alternative 3: Ask BFHcharts to return stats in result**
```r
# Modify BFHcharts to include stats in bfh_qic_result
result$spc_stats <- list(runs = ..., crossings = ...)
```
**Rejected because:**
- Requires breaking change to BFHcharts data structure
- Other BFHcharts users don't need this
- SPCify-specific requirement shouldn't drive BFHcharts API
- Already solved by public API export

**Chosen approach: Use BFHcharts public API**
- ✅ Follows R package best practices
- ✅ API stability guarantees via semantic versioning
- ✅ No code duplication
- ✅ Minimal code changes (2 lines)
- ✅ Better error messages and validation
- ✅ BFHcharts already deployed (v0.4.0)

## Related

- SPCify GitHub Issue: [#98](https://github.com/johanreventlow/claude_spc/issues/98)
- BFHcharts GitHub Issue: [#64](https://github.com/johanreventlow/BFHcharts/issues/64) (deployed in v0.4.0)
- BFHcharts Commit: 866563f
- BFHcharts OpenSpec: `2025-12-01-export-spc-utility-functions` (archived)
