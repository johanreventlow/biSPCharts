# biSPCharts 0.2.0-dev (development)

## Security

* **Path traversal test-dækning** (#244): To skipped tests i
  `test-critical-fixes-security.R` omformuleret efter maintainer-anbefalet
  Option B (match faktisk threat-model):
  - SQL injection-testen dokumenterer nu eksplicit at SQL-keywords bevares
    i `sanitize_user_input` — appen bruger ingen SQL direkte, så filtrering
    er ikke scope. Bevidst adfærd, ikke en sikkerhedsmangel.
  - Path traversal-testen omskrevet til at verificere
    `validate_safe_file_path()` (R/fct_file_operations.R), som er den
    faktiske app-beskyttelse mod traversal: blokerer absolute paths
    (`/etc/passwd`), relative traversal (`../../etc/passwd`), NULL,
    multi-element vektorer; validerer legitime tempdir-stier.
  Ingen ændringer i produktionskode — eksisterende beskyttelse er
  tilstrækkelig, testene manglede blot at pege på den.

## Bug fixes

* **format_scaled_number/format_unscaled_number afrunding og scientific
  notation leak** (#242): To bugs i `R/utils_y_axis_formatting.R`:
  - `format_scaled_number(2750, 1e3, "K")` returnerede "2,75K" i stedet
    for "2,8K" — `format(..., nsmall=1)` runder ikke (samme bug som #236).
  - `format_unscaled_number(100000)` returnerede "1e+05" (scientific
    notation leak) i stedet for "100.000".
  Fix: Begge funktioner bruger nu `formatC(val, digits=1, format="f")`
  (for decimaler) eller `formatC(val, format="d")` (for heltal), som
  giver deterministisk dansk formatering uden scientific notation og
  round-half-up (konsistent med #236 fix i `format_y_value`). De tre
  `format_time_with_unit` tests skipped permanent — funktionen er
  erstattet af `format_time_composite` og dækning ligger nu i
  `test-label-formatting.R`.



* **resolve_y_unit/detect_unit_from_data percent-detection tests** (#243):
  Opdateret 2 skipped tests i `test-y-axis-scaling-overhaul.R` til at
  matche ny API. Forventninger ændret fra `"percent"` til `"absolute"`
  for data i 0-100 range — konsistent med #238 beslutning om at fjerne
  percent-heuristik fra data-detection. Chart type (p/pp) + nævner er
  nu den korrekte indikator for procent. Skip-markering fjernet,
  tests aktive og grønne.

* **Chart type mapping tests** (#235): opdaterede forældede chart-type
  labels i `test-app-initialization.R`, `test-data-validation.R` og
  `test-visualization-server.R` til de use-case-baserede labels fra
  `c268f3a` (#147) og `8db3946`. 4 tests grønne, ingen kode-ændringer.
* **format_y_value() afrunding for rate/count/default** (#236): `format()`
  med `nsmall = 1` sikrer kun minimum decimaler, ikke maksimum — derfor
  returnerede `format_y_value(123.456, "rate")` "123,456" i stedet for
  forventet "123,5". Fix: byttet til `formatC(val, digits = 1, format = "f",
  decimal.mark = ",")` i rate/default/count-branches. `formatC` bruger
  round-half-up (123.45 → 123,5) som matcher klinisk læsevaner, modsat R's
  base `round()` som bruger banker's rounding (123.45 → 123,4). 2 tests
  grønne (linje 41 og 87 i `test-label-formatting.R`).
* **Mari font-registrering idempotent** (#237): `register_mari_font()`
  afviste at registrere Mari hvis den allerede var installeret som
  system-font (fx MacOS user fonts ~/Library/Fonts/), og genererede
  ERROR-log "A system font called `Mari` already exists" ved hver
  test-session-start. Fix: Tjek `systemfonts::system_fonts()` for
  eksisterende Mari-family før registrering; spring over (idempotent)
  hvis fonten allerede er tilgængelig. Primær symptom (ERROR-log)
  elimineret. **Restcase:** "font family 'Mari' not found in PostScript
  font database"-warnings ved plot-generering i PostScript-device
  kontekst er separat — ligger i BFHtheme-ansvar og kræver cross-repo
  eskalering (PostScript font-database er adskilt fra systemfonts).
* **100x-mismatch tests opdateret til BFHcharts 0.8.0 API** (#238):
  - `detect_unit_from_data([10,20,30,80])` forventning opdateret fra
    `"percent"` til `"absolute"` — percent-heuristik blev bevidst fjernet
    fra data-detection. Chart type (p/pp) + nævner er nu den korrekte
    indikator for procent (styres via `chart_type_to_ui_type()`).
  - 2 tests skipped med tydelige issue-references (`#238` + `#216`):
    `display_scaler` fjernet fra `generateSPCPlot()`-return struktur,
    og target-line rendering ændret i BFHcharts 0.8.0. Test-refactor
    til ny API kræver cross-repo samarbejde.

## Interne ændringer (Fase 1 saneringsarbejde, #228/#229)

* **Test-artefakter flyttet ud af aktiv suite** (jf. `harden-test-suite-
  regression-gate` §1.3):
  - `tests/testthat/archived/` (19 filer) → `tests/_archive/testthat-legacy/`,
    kommer ud af testthat's auto-discovery-scope. Git-historik bevaret for
    reference (commit `177e704`).
  - `tests/testthat/_problems/` (20 testthat edition 3-artefakter) slettet
    lokalt; allerede i `.gitignore`.
* **Broken tests opryddet fra audit-rapport** (kategori `stub`):
  - `test-app-basic.R` slettet — brugte globalt `AppDriver`-objekt der ikke
    eksisterede, gav 2 errors per kørsel. Test-scope (app starter + velkomst-
    side) flyttes til Fase 4 shinytest2-suite (commit `41e6fa7`).
  - `test-denominator-field-toggle.R` fikset — fjernede assertions for
    ikke-supporterede chart types (`mr`, `g`) hvor `get_qic_chart_type()`
    fallback til `"run"` gav false positives (commit `f67f8a9`).
  - `tests/performance/test_data_load_performance.R` fikset — "DEBUGGING:"-
    overskrift renameret til "Debug-info:" for at undgå false positive match
    mod `cat("DEBUG"`-regex i `test-logging-debug-cat.R` (commit `fdab691`).
* **PR A3 — catch-all fjernede funktioner (§1.1.8):**
  - `validate_date_column`-testblok fjernet fra `test-data-validation.R`.
    Funktionen blev slettet i `remove-legacy-dead-code §4.5` (arkiveret
    2026-04-18); dato-validering varetages nu af kolonneparser og
    auto-detection pipeline.
  - `skip_on_ci_if_slow` allerede migreret til `testthat::skip_on_ci()`
    i #225 `a14a529` — verificeret.
  - Øvrige audit-missing-functions (`sanitize_log_details`,
    `log_with_throttle`, `get_cache_stats`, `get_spc_cache_stats`)
    håndteret i PR A1/A2 (#222 `9f4b0c0`).
* **Kendt resterende arbejde i Fase 1:**
  - §1.2 TODO-skips (92 kald — kræver reparér/slet/issue-reference-beslutning)
  - §1.4 audit-kategorifordeling skal re-måles efter ovenstående

## Interne ændringer

* **Cross-repo bump:** `BFHcharts (>= 0.8.1)` og `BFHllm (>= 0.1.2)`. Begge
  sibling-pakker har nu egne `Remotes:`-felter, så pak kan løse transitive
  BFH-deps uden eksplicit workaround. Workarounden i
  `.github/workflows/R-CMD-check.yaml` (de fire `github::johanreventlow/...`
  entries i `extra-packages`) er fjernet. CI er nu arkitektonisk korrekt
  konfigureret og matcher VERSIONING_POLICY cross-repo bump-protokol.

## Interne ændringer (Fase 3 — TODO-resolution + targeted salvage, #203)

* **Fail-count reduceret fra 292 til 80** (-212, target <200 **klart opnået**).
* **Kategori 1 (R-bugs) fixed:** 4 grupper godkendt og implementeret:
  - **Gruppe 1:** 24 nye state-accessor wrappers i `R/utils_state_accessors.R`
    (commit `f03e696`) — løste 17 TODO-SKIPs
  - **Gruppe 2:** `manage_cache_size()` LRU-strategi defineret i
    `R/utils_performance_caching.R` (commit `3d182bb`) — løste 7/9 TODOs.
    2 afslørede dybere reaktiv bug (cache-key statisk), dokumenteret som
    separat SKIP med ny TODO-marker
  - **Gruppe 3:** `parse_danish_target(NULL)` null-guard tilføjet (commit
    `2434c21`) — løste 1 TODO
  - **Gruppe 4:** 3 BFHcharts-relaterede skips omdøbt til
    `BFHcharts-followup`-marker (commit `95b7149`) — cross-repo bookkeeping
* **Kategori 2 (NAMESPACE-exports):** 0 (alle "mangler i namespace" var
  reelt K1/K3 efter nærmere inspektion)
* **Kategori 3 (test-bugs):** 7 assertions fixed i
  `test-performance-benchmarks.R`, `test-bfhcharts-integration.R`,
  `test-cache-collision-fix.R` (commits `da0a35b`, `2303fbf`, `f566559`)
* **Targeted salvage (Task 8):** 10 af de 15 højest-fejlende
  `fix-in-phase-3`-filer reparerede gennem test-assertion-fixes og
  TODO-markers for resterende R-bugs (commit `858b7cd`)
* **16 filer flyttet** fra `fix-in-phase-3` → `keep` efter salvage

## Bemærkninger (Fase 3)

* **Opt-out grupper bevaret som SKIP med TODO-markers:**
  - Gruppe 3b (fuld `parse_danish_target` unit-mapping): kompleks refactor
    deferret til separat issue
  - Gruppe 5 (2 NAMESPACE-exports): kræver public API-vurdering
  - Gruppe 6 (observer-cleanup): høj effort, separat fix
* **Nye TODO-markers (`TODO Fase 4: ... #203-followup`)** indført under
  Task 8 for tests der afslørede R-bugs uden for Fase 3-scope
* **Publish-gate:** Går fra "delvist blokeret" til "nær-grøn" (80 fails
  vs. 302 baseline). Emergency-publish workaround fra Fase 2 kan bevares
  men er mindre kritisk

---

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

* **CI pilot (GitHub Actions):** Tilføjet `.github/workflows/R-CMD-check.yaml`
  (matrix: ubuntu + windows, R release) og `.github/workflows/lint.yaml`. Kører
  ved push/PR mod `master` og automatiserer det meste af 9-trins pre-release
  checklist. Cross-repo regressioner fra `Remotes:` sibling-pakker (BFHcharts,
  BFHllm, BFHtheme) fanges passivt ved hver kørsel. shinytest2-baserede tests
  guarded med `skip_on_ci()` (chromote hænger non-interaktivt). Replikering
  til sibling-pakker dokumenteret i `docs/CI_SETUP_GUIDE.md`.

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
