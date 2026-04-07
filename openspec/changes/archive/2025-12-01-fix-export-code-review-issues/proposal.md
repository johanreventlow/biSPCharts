# Proposal: Fix Export Code Review Issues

**ID:** fix-export-code-review-issues
**Type:** bugfix
**Status:** completed
**Priority:** critical
**GitHub Issue:** [#97](https://github.com/johanreventlow/claude_spc/issues/97)

## Problem Statement

Code review af BFHcharts v0.3.0 export migration har identificeret flere kritiske og høj-prioritets issues der skal adresseres før merge til master.

## Issues Identificeret

### Critical

#### 1. Legacy Typst Test Suite Targets Removed Functions
**File:** `tests/testthat/test-fct_export_typst.R:1`

Test suite refererer stadig til fjernede Typst helper funktioner:
- `export_chart_for_typst()`
- `create_typst_document()`
- `export_spc_to_typst_pdf()`
- `compile_typst_to_pdf()`

App'en bruger nu `BFHcharts::bfh_export_pdf()`. CI vil fejle og coverage er misaligned med ny export pipeline.

### High Priority

#### 2. PNG Export Height Validation Bug
**File:** `R/mod_export_server.R:972-978`

PNG export validation bruger `height = round(width_inches * dpi)` (width bruges til begge dimensioner). Height valideres aldrig korrekt:
- Out-of-range eller zero heights slipper igennem
- Valide heights kan blive afvist
- Risiko for dårlige exports og forvirrende validation errors

#### 3. PDF Preview Dimension Mismatch
**Files:**
- `R/utils_server_export.R:365-372` - Preview: 250×140 mm @300 dpi
- `R/config_plot_contexts.R:68` - Export: 200×120 mm @300 dpi

Preview matcher ikke downloaded PDF - label placement og whitespace vil være forskellige.

### Medium Priority

#### 4. BFHcharts Internal API Dependency
**File:** `R/utils_server_export.R:376-379`

Preview bruger BFHcharts internals via `:::`:
- `BFHcharts:::extract_spc_stats()`
- `BFHcharts:::merge_metadata()`

Upstream ændringer vil bryde previews. Bryder public API contract.

#### 5. Quarto Exit Status Ignoreret
**File:** `R/utils_server_export.R:395-417`

`system2("quarto", …)` ignorerer exit status:
- Fejl giver tom preview med kun log entry
- Ingen user feedback
- Ingen stdout/stderr retained for diagnose

### Low Priority

#### 6. Preview Temp File Leak
**File:** `R/utils_server_export.R:392-429`

Hver preview generation skriver ny temp PNG der aldrig ryddes op. Lange sessions kan lække mange filer indtil R session afsluttes.

### Coverage Gap

Ny PDF path (`generate_pdf_preview()`, `bfh_export_pdf` integration) mangler tests, mens legacy Typst tests forbliver. Ny funktionalitet er ikke verificeret, og gamle tests vil fejle.

## Solution

### Phase 1: Critical - Fix CI (Blocking)

1. **Fjern eller erstat legacy Typst tests**
   - Slet `tests/testthat/test-fct_export_typst.R`
   - Opret nye tests for BFHcharts-baseret export/preview path

### Phase 2: High Priority Fixes

2. **Fix PNG height validation**
   - Ret validation til at bruge korrekt height parameter
   - Tilføj test coverage

3. **Align preview og export dimensioner**
   - Opdater preview til at bruge samme dimensioner som export config
   - Eller opret separat preview config med dokumenteret rationale

### Phase 3: Medium Priority Improvements

4. **Håndter BFHcharts internal API**
   - Option A: Request public API i BFHcharts (anbefalet)
   - Option B: Duplikér logic i biSPCharts (ikke anbefalet)
   - Option C: Accept risiko og dokumentér (kortsigtet)

5. **Tilføj Quarto error handling**
   - Check exit code fra `system2()`
   - Vis user-facing warning ved fejl
   - Log stdout/stderr for diagnose

### Phase 4: Low Priority Cleanup

6. **Implementér temp file cleanup**
   - Registrer temp files for cleanup
   - Eller genbrug samme temp file path per session

## Acceptance Criteria

- [x] CI er grøn (ingen test failures)
- [x] PNG export validerer height korrekt
- [x] PDF preview dimensioner matcher export
- [x] Quarto fejl giver brugervenlig feedback
- [x] Test coverage for ny export pipeline
- [x] Temp file leak addresseret

## Files to Modify

| File | Change |
|------|--------|
| `tests/testthat/test-fct_export_typst.R` | Slet eller erstat med BFHcharts tests |
| `R/mod_export_server.R` | Fix PNG height validation |
| `R/utils_server_export.R` | Align dimensioner, error handling, temp cleanup |
| `R/config_plot_contexts.R` | Review export context dimensioner |
| `tests/testthat/test-mod_export_server.R` | Tilføj tests for ny export path |

## Related

- **Parent:** OpenSpec `migrate-to-bfhcharts-export`
- **Sibling:** OpenSpec `fix-export-preview-blank`
- **Branch:** `refactor/bfhcharts-export-migration`
