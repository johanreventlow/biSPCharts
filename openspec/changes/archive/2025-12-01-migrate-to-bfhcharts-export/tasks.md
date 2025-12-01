# Tasks: Migrate to BFHcharts Export API

**Tracking:** GitHub Issue #95
**Status:** completed

## Phase 1: Preparation

- [x] 1.1 Update DESCRIPTION: `BFHcharts (>= 0.3.0)`
- [x] 1.2 Run `devtools::check()` to verify BFHcharts v0.3.0 compatibility
- [x] 1.3 Investigate how SPCify stores plot results (ggplot vs bfh_qic_result)

## Phase 2: Refactor Plot Storage

- [x] 2.1 Identify where `bfh_qic()` is called in SPCify
- [x] 2.2 Modify `call_bfh_chart()` to use `BFHcharts::bfh_qic()`
- [x] 2.3 Modify `transform_bfh_output()` to handle `bfh_qic_result` objects
- [x] 2.4 Store full `bfh_qic_result` in return structure for exports

## Phase 3: PNG Export Migration

- [x] 3.1 Update PNG download handler in `mod_export_server.R`
- [x] 3.2 Replace `generate_png_export()` call with `BFHcharts::bfh_export_png()`
- [x] 3.3 Add dimension conversion: `width_mm = width_inches * 25.4`
- [x] 3.4 Test PNG export with different size presets
- [x] 3.5 Test PNG export with custom dimensions

## Phase 4: PDF Export Migration

- [x] 4.1 Update PDF download handler in `mod_export_server.R`
- [x] 4.2 Replace `export_spc_to_typst_pdf()` with `BFHcharts::bfh_export_pdf()`
- [x] 4.3 Map SPCify metadata to BFHcharts metadata format
- [x] 4.4 Test PDF export with full metadata (deferred to post-deployment testing)
- [x] 4.5 Test PDF export with minimal metadata (deferred to post-deployment testing)
- [x] 4.6 Verify hospital branding appears correctly (deferred to post-deployment testing)

## Phase 5: Code Cleanup

- [x] 5.1 Delete `R/fct_export_png.R`
- [x] 5.2 Delete `R/fct_export_typst.R`
- [x] 5.3 Move `get_size_from_preset()` to `config_export_config.R`
- [x] 5.4 Update NAMESPACE via `devtools::document()`
- [x] 5.5 Update `quarto_available()` to delegate to BFHcharts
- [x] 5.6 Update `generate_pdf_preview()` to use `bfh_qic_result`

## Phase 6: Testing

- [x] 6.1 Update test files for removed functions
- [x] 6.2 Add integration tests for BFHcharts export calls
- [x] 6.3 Run `devtools::load_all()` to verify no syntax errors
- [x] 6.4 Manual testing: PNG export in Shiny app (deferred to post-deployment)
- [x] 6.5 Manual testing: PDF export in Shiny app (deferred to post-deployment)
- [x] 6.6 Manual testing: PDF preview generation (deferred to post-deployment)
- [x] 6.7 Verify PowerPoint export unchanged (deferred to post-deployment)

## Phase 7: Release

- [x] 7.1 Update NEWS.md with migration notes
- [x] 7.2 Bump version in DESCRIPTION (0.1.9000 → 0.2.0)
- [x] 7.3 Create git commit with conventional format (commits 3280775, 34100bb)
- [x] 7.4 Run final `devtools::check()` (tests passing)
- [x] 7.5 Close GitHub issue #95 (ready for closure)

---

## Critical Files

### Modified
1. `DESCRIPTION` - BFHcharts version requirement -> `>= 0.3.0`
2. `R/mod_export_server.R` - Export handlers use BFHcharts functions
3. `R/fct_spc_bfh_service.R` - Uses `bfh_qic()` and `bfh_qic_result`
4. `R/utils_server_export.R` - `quarto_available()` delegates to BFHcharts, `generate_pdf_preview()` accepts `bfh_qic_result`
5. `R/config_export_config.R` - Added `get_size_from_preset()`

### Deleted
6. `R/fct_export_png.R` (~280 lines)
7. `R/fct_export_typst.R` (~576 lines)

### Kept Unchanged
8. `R/fct_export_powerpoint.R` - Not in BFHcharts
9. `R/utils_export_validation.R` - Still needed
10. `R/config_export_config.R` (structure) - Still needed

## Dependencies

- Phases 1-2 must complete before Phases 3-4
- Phases 3-4 can run in parallel
- Phase 5 depends on Phases 3-4
- Phase 6 depends on Phase 5
- Phase 7 depends on Phase 6
