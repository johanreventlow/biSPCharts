# SPCify (development version)

## Breaking Changes

### Migration to BFHcharts v0.3.0 Export API (Issue #95)

**BREAKING:** SPCify now delegates all PNG and PDF export to BFHcharts v0.3.0+ export functions. This migration eliminates ~850 lines of duplicate code and establishes BFHcharts as the single source of truth for export functionality.

**What Changed:**
- `generate_png_export()` removed → use `BFHcharts::bfh_export_png()`
- `export_spc_to_typst_pdf()` removed → use `BFHcharts::bfh_export_pdf()`
- `export_chart_for_typst()` removed → use `BFHcharts::bfh_export_png()`
- `create_typst_document()` removed (internal to BFHcharts)
- `compile_typst_to_pdf()` removed → use `BFHcharts::bfh_compile_typst()`

**Migration Guide:**

```r
# OLD (SPCify v0.1.x)
generate_png_export(
  plot_object = plot,
  width_inches = 10,
  height_inches = 7.5,
  dpi = 96,
  output_path = "chart.png"
)

# NEW (SPCify v0.2.0+)
# Note: BFHcharts uses mm, not inches
BFHcharts::bfh_export_png(
  bfh_result = bfh_result,  # bfh_qic_result object
  width_mm = 254,           # 10 inches * 25.4
  height_mm = 190.5,        # 7.5 inches * 25.4
  output_path = "chart.png"
)
```

**What Stays the Same:**
- PowerPoint export (`fct_export_powerpoint.R`) unchanged
- Export size presets (`EXPORT_SIZE_PRESETS`) unchanged
- `get_size_from_preset()` still available in SPCify
- Export UI and workflow unchanged for end users

**Dependencies:**
- **Requires:** `BFHcharts (>= 0.3.0)`

**Benefits:**
- Single source of truth for export logic (no duplicate code)
- Automatic feature updates from BFHcharts
- Reduced maintenance burden
- Consistent export behavior across BFH tools

## New Features

### PDF Layout Preview på Export-siden (Issue #56)

* Added real-time PDF layout preview functionality on export page
* Preview shows complete Typst PDF layout including:
  - Hospital branding and header
  - SPC statistics table (Anhøj rules)
  - Data definition section
  - Chart with metadata applied
* Server-side rendering approach using pdftools for 100% accurate preview
* Conditional UI: Shows PDF preview for PDF format, ggplot preview for PNG/PPTX
* Debounced preview generation (1000ms) for optimal performance
* Automatic fallback to ggplot preview when Quarto not available

**New Functions:**
- `generate_pdf_preview()` - Generate PNG preview of Typst PDF layout

**Technical Implementation:**
- Uses `pdftools::pdf_render_page()` to convert first PDF page to PNG
- Reuses existing `export_spc_to_typst_pdf()` infrastructure
- Conditional `imageOutput()` vs `plotOutput()` in UI based on format selection
- Preview reactive auto-updates when metadata changes (debounced)
- Graceful degradation when Quarto CLI not available

**Requirements:**
- pdftools >= 3.3.0
- Quarto >= 1.4 (for PDF preview - optional)

### Typst PDF Export (Issue #43)

* Added professional PDF export functionality using Typst typesetting system via Quarto
* New export format available in Export module alongside PNG and PowerPoint
* Generates A4 landscape PDFs with hospital branding (BFH template)
* Includes comprehensive metadata:
  - Hospital name and department
  - Chart title and analysis text
  - Data definition and technical details
  - SPC statistics (Anhøj rules: runs, crossings, outliers)
  - Author and date
* Template system supports:
  - Danish language throughout
  - Hospital logos and brand colors (Mari + Arial fonts)
  - Conditional rendering (SPC table and data definition sections)
  - Professional layout optimized for clinical reports

**New Functions:**
- `export_chart_for_typst()` - Export ggplot to PNG for Typst embedding (strips title/subtitle)
- `create_typst_document()` - Generate .typ files programmatically from R
- `compile_typst_to_pdf()` - Compile Typst to PDF via Quarto CLI
- `export_spc_to_typst_pdf()` - High-level orchestrator for complete workflow
- `extract_spc_statistics()` - Extract Anhøj rules from app_state
- `generate_details_string()` - Generate period/statistics summary
- `quarto_available()` - Check Quarto CLI availability (with RStudio fallback)
- `get_hospital_name_for_export()` - Get hospital name with fallback chain

**Chart Export Behavior:**
- Chart PNG embedded in PDF has title/subtitle removed to avoid duplication
- Title and subtitle are displayed in PDF header section instead
- Plot margins set to 0mm for tight embedding in PDF layout

**Technical Implementation:**
- Uses Quarto's bundled Typst CLI (>= v1.4, includes Typst 0.13+)
- Template files bundled in `inst/templates/typst/`
- Automatic template copying to temp directory for compilation
- Compatible with RStudio's bundled Quarto (macOS + Windows)
- Comprehensive test suite with Quarto availability detection

**Requirements:**
- Quarto >= 1.4 (for Typst support)
- Available via system installation or RStudio bundled version

## Bug Fixes

### Export Preview and safe_operation Return Pattern (Issues #93, #94, #96, #97)

* **Fixed blank export preview bug (#96):** Export preview now displays correctly after BFHcharts migration. Root cause was `return()` statements inside `safe_operation()` code blocks returning `NULL` instead of expected values.
* **Fixed 9 return pattern bugs across codebase:**
  - `R/mod_export_server.R`: Fixed preview generation and PDF preview path returns
  - `R/fct_spc_bfh_service.R`: Fixed 6 return patterns in BFH service functions
  - `R/utils_server_export.R`: Fixed 3 return patterns in export utilities
* **Refactored early returns:** Eliminated problematic early `return()` statements in helper functions called within `safe_operation()` blocks
* **Enhanced error handling:** Added Quarto exit status checking with informative error messages
* **Fixed PNG height validation bug (#97):** PNG export now correctly validates `height_mm` parameter (was incorrectly checking `width_mm` twice)
* **Aligned preview/export dimensions (#97):** PDF preview now uses same plot context configuration as PDF export for consistency
* **Fixed temp file leak (#97):** PDF preview temp files now cleaned up automatically using `reg.finalizer()`
* **Added comprehensive test coverage:** New test suite for `utils_server_export.R` functions

**Technical Details:**
- `safe_operation()` uses `force(code)` which changes R's return semantics
- Solution: Replace `return(value)` with assignments and implicit returns
- Added warning documentation to `safe_operation()` Roxygen comments

### Code Cleanup

* Removed legacy Typst test suite (`test-fct_export_typst.R`) that was blocking CI after BFHcharts migration
* Deleted obsolete manual pages for removed export functions

### Typst Template Fixes

* Fixed Typst template syntax errors in conditional rendering
* Fixed Quarto compilation strategy (now uses `quarto typst compile`)
* Fixed template path resolution for temp directory compilation

## Internal Changes

* Added comprehensive Roxygen2 documentation for all export functions
* Added template README with usage examples and troubleshooting
* Improved error messages for missing dependencies

---

# SPCify 0.1.0 (Initial Development)

* Initial package structure
* Basic SPC chart functionality
* Core modules: data upload, visualization, export
