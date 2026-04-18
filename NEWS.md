# biSPCharts 0.2.0-dev (development)

## Interne ændringer (Fase 2 — test-suite konsolidering, #203)

* **Test-suite reduceret fra 121 til 113 filer** (-8) gennem archive, merge
  og rewrite. Total fail-count reduceret fra 302 til 292 (mål om <200 ikke
  opnået — flere tests blev SKIP med TODO til Fase 3 i stedet for fixes).
* **46 tests skipped med TODO-marker** (`TODO Fase 3: ... #203-followup`) pga.
  R-bugs afsløret under rewrite. Håndteres i Fase 3 eller som separate fixes.

### Arkiveret (3 filer — rewrite auto-downgrade uden R-target)

* `test-constants-architecture.R`
* `test-label-height-estimation.R`
* `test-npc-mapper.R`

### Merged (2 klustre + 1 special)

* **y-axis-kluster:** konsolideret `test-y-axis-formatting.R`,
  `test-y-axis-mapping.R`, `test-y-axis-model.R` ind i
  `test-y-axis-scaling-overhaul.R` med sektion-kommentarer
* **mod-spc-kluster:** konsolideret `test-mod-spc-chart-integration.R` ind i
  `test-mod-spc-chart-comprehensive.R`
* **label-placement-bounds** merged ind i `test-label-placement-core.R`
  efter salvage-rewrite (fixture-issue fixed, 18+6 tests bevaret)

### Rewritten (10 filer)

* **TDD (store):** `test-parse-danish-target-unit-conversion.R`,
  `test-utils-state-accessors.R`, `test-performance-benchmarks.R`
* **Salvage (mellem):** `test-plot-core.R`, `test-bfhcharts-integration.R`,
  `test-cache-collision-fix.R`, `test-cache-reactive-lazy-evaluation.R`,
  `test-e2e-workflows.R`, `test-file-upload.R`, `test-observer-cleanup.R`

### Manifest-sync

Manifest `dev/audit-output/test-classification.yaml` er synket (113 filer).
Audit-rapport re-genereret.

---

## Interne ændringer

* **Publish-gate oprydning (#203):** Fjernede 4 forældede testfiler med
  referencer til funktioner der var dead-code eller migreret. Resultat:
  audit-kategori `broken-missing-fn = 0`.
  - `test-panel-height-cache.R` slettet (orphan efter label-placement-migration
    til BFHcharts — `clear_panel_height_cache` migreret i commit d5724aa)
  - `test-plot-diff.R` slettet (orphan efter bevidst fjernelse af
    `utils_plot_diff.R` med 6 funktioner i commit 0d4041e)
  - `test-utils_validation_guards.R` + `test-validation-guards.R` slettet
    (orphans — `utils_validation_guards.R` med 7 funktioner bevidst fjernet
    som ubrugt abstraktionslag i commit 0d4041e)
  - `--skip-tests`-flag fjernet fra `dev/publish_prepare.R` (anti-pattern
    fra commit 20b4724 der maskerede test-fejl)

## Bemærkninger

* **Publish-gate er fortsat delvist blokeret:** Ca. 302 pre-existing failures
  fra green-partial testfiler (ikke relateret til denne oprydning). Håndteres
  separat i `refactor-test-suite` Change 2 Fase 3. Ved nødpublish inden Fase 3:
  maintainer kan køre `devtools::test(stop_on_failure = FALSE)` manuelt før
  `rsconnect::writeManifest()` og `deployApp()`, eller midlertidigt genindføre
  `--skip-tests`-flaget lokalt (se commit 20b4724 for reference) og revert
  efter deployment.

# biSPCharts (development version)

## Bug fixes

### Outlier-count i trin 3 preview og trin 2 value box

- **Trin 3 Typst-preview viser nu korrekt antal outliers i tabellen**
  "OBS. UDEN FOR KONTROLGRÆNSE". Tidligere blev `bfh_extract_spc_stats()`
  kaldt med `bfh_qic_result$summary` alene, hvilket altid returnerede
  `outliers_actual = NULL`, og rækken blev skjult. Vi kalder nu den nye
  S3-dispatch `bfh_extract_spc_stats(bfh_qic_result)` som udfylder
  outlier-tallet.
- **Trin 2 value box "OBS. UDEN FOR KONTROLGRÆNSE" er nu konsistent med
  tabellen.** `out_of_control_count` filtreres nu til seneste part
  (matcher `bfh_extract_spc_stats.bfh_qic_result()` i BFHcharts 0.7.0) via
  ny helper `count_outliers_latest_part()` i
  [R/mod_spc_chart_state.R](R/mod_spc_chart_state.R).

Kræver BFHcharts >= 0.7.1.

### Analysetekst præciseret (via BFHcharts 0.7.1)

Outlier-tekstem i PDF-analysen signalerer nu eksplicit at tallet kun omfatter
nylige observationer, f.eks. "2 af de seneste observationer ligger uden for
kontrolgrænserne". Tidligere kunne formuleringen forveksles med totalen i
PDF-tabellen. Tabel-tallet (total i seneste part) og tekst-tallet (seneste
6 obs) kan nu adskille sig, og teksten gør det klart at den kun beskriver
aktuelle outliers.

## Features

### Session Persistence via Browser localStorage (Issue #193)

Gen-aktiveret automatisk session persistence. Appen gemmer nu data og
indstillinger kontinuerligt i browserens `localStorage` hvert 2 sekund,
og genindlæser automatisk ved næste session start. Dette beskytter mod
tab af arbejde ved forbindelsestab, utilsigtet browser-luk eller crash.

**Hvad gemmes:**
- Rådata med fuld type-bevaring (numeric, integer, character, logical,
  Date, POSIXct med tidszone, factor med levels)
- Kolonne-mapping (x, y, n, skift, frys, kommentar)
- UI-indstillinger (titel, chart_type, target_value, centerline_value,
  y_axis_unit, indicator_description)
- Form-felter (unit_type, unit_select, unit_custom)

**Konfiguration** (via `inst/golem-config.yml`):
```yaml
session:
  auto_save_enabled: true
  auto_restore_session: true      # prod=true, dev/test=false
  save_interval_ms: 2000
  settings_save_interval_ms: 1000
```

**Fixes fra tidligere implementation:**
- Dobbelt JSON-encoding mellem R og JS rettet
- `autoSaveAppState()` scope bug — graceful disable virker nu
- Dead UI observers fjernet (`manual_save`, `show_upload_modal`, `save_status_display`)
- Restore-rækkefølge fix: metadata gendannes før `data_updated` event
- Race condition med auto-detect elimineret
- `setTimeout(500)` erstattet med `shiny:sessioninitialized` event
- JS → R fejl-kanal via `input$local_storage_save_result`

**Nyt UI:**
- Diskret save-status indikator i wizard-bjælken under paste-området
- Restore-notifikation ved automatisk genindlæsning

## Breaking Changes

### Migration to BFHllm Package (Issue #100, Phase 2)

**BREAKING:** biSPCharts now delegates all AI/LLM functionality to the standalone BFHllm package (v0.1.0+). This migration eliminates ~600 lines of embedded AI code and establishes BFHllm as the single source of truth for LLM integration and RAG functionality.

**What Changed:**
- AI functionality extracted to `BFHllm` package
- New integration layer: `R/utils_bfhllm_integration.R`
- `generate_improvement_suggestion()` now a thin wrapper delegating to BFHllm
- Removed files:
  - `R/utils_gemini_integration.R` → `BFHllm::bfhllm_chat()`
  - `R/utils_ai_cache.R` → `BFHllm::bfhllm_cache_shiny()`
  - `R/utils_ragnar_integration.R` → `BFHllm::bfhllm_query_knowledge()`
  - `R/config_ai_prompts.R` → `BFHllm::bfhllm_build_prompt()`
  - `inst/spc_knowledge/` → moved to BFHllm package
  - `inst/ragnar_store` → moved to BFHllm package
  - `data-raw/build_ragnar_store.R` → moved to BFHllm package

**Migration Guide:**

biSPCharts users: No changes needed - `generate_improvement_suggestion()` API remains the same.

For direct AI functionality usage:
```r
# OLD (biSPCharts v0.1.x)
# Direct calls to internal functions not supported

# NEW (biSPCharts v0.2.0+)
# Use BFHllm package directly for advanced use cases
library(BFHllm)
bfhllm_configure(provider = "gemini", model = "gemini-2.0-flash-exp")
suggestion <- bfhllm_spc_suggestion(spc_result, context, max_chars = 350)
```

**Dependencies:**
- **Requires:** `BFHllm (>= 0.1.0)`
- **Removed:** `ellmer`, `ragnar` (now indirect dependencies via BFHllm)

**Benefits:**
- Reusable AI infrastructure across multiple R packages
- Single source of truth for LLM/RAG integration
- Cleaner separation of concerns (biSPCharts focuses on SPC, BFHllm on AI)
- Independent versioning and testing of AI components
- Reduced biSPCharts maintenance burden (~600 lines removed)

### Migration to BFHcharts v0.3.0 Export API (Issue #95)

**BREAKING:** biSPCharts now delegates all PNG and PDF export to BFHcharts v0.3.0+ export functions. This migration eliminates ~850 lines of duplicate code and establishes BFHcharts as the single source of truth for export functionality.

**What Changed:**
- `generate_png_export()` removed → use `BFHcharts::bfh_export_png()`
- `export_spc_to_typst_pdf()` removed → use `BFHcharts::bfh_export_pdf()`
- `export_chart_for_typst()` removed → use `BFHcharts::bfh_export_png()`
- `create_typst_document()` removed (internal to BFHcharts)
- `compile_typst_to_pdf()` removed → use `BFHcharts::bfh_compile_typst()`

**Migration Guide:**

```r
# OLD (biSPCharts v0.1.x)
generate_png_export(
  plot_object = plot,
  width_inches = 10,
  height_inches = 7.5,
  dpi = 96,
  output_path = "chart.png"
)

# NEW (biSPCharts v0.2.0+)
# Note: BFHcharts uses mm, not inches
BFHcharts::bfh_export_png(
  bfh_result = bfh_result,  # bfh_qic_result object
  width_mm = 254,           # 10 inches * 25.4
  height_mm = 190.5,        # 7.5 inches * 25.4
  output_path = "chart.png"
)
```

**What Stays the Same:**
- Export size presets (`EXPORT_SIZE_PRESETS`) unchanged
- `get_size_from_preset()` still available in biSPCharts
- Export UI and workflow unchanged for end users

**Dependencies:**
- **Requires:** `BFHcharts (>= 0.4.0)`

**Benefits:**
- Single source of truth for export logic (no duplicate code)
- Automatic feature updates from BFHcharts
- Reduced maintenance burden
- Consistent export behavior across BFH tools

## Improvements

### Migrated to BFHcharts Public API (Issue #98)

* **Migrated from internal to public API:** biSPCharts now uses BFHcharts public API instead of internal functions accessed via `:::` operator
* **What Changed:**
  - `BFHcharts:::extract_spc_stats()` → `BFHcharts::bfh_extract_spc_stats()`
  - `BFHcharts:::merge_metadata()` → `BFHcharts::bfh_merge_metadata()`
* **Benefits:**
  - ✅ Follows R package best practices (no `:::` usage)
  - ✅ API stability guarantees via semantic versioning
  - ✅ Better error messages (public API has parameter validation)
  - ✅ No code duplication
* **Impact:** Internal implementation detail - no user-visible changes
* **Dependencies:** Requires `BFHcharts (>= 0.4.0)`

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
* New export format available in Export module alongside PNG
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

# biSPCharts 0.1.0 (Initial Development)

* Initial package structure
* Basic SPC chart functionality
* Core modules: data upload, visualization, export
