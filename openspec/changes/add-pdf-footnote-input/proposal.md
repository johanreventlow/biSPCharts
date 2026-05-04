## Why

Klinisk personale tilføjer typisk dataattribution (fx "Datakilde: KvalDB udtræk 2026-04-29") som footnote til SPC-grafer for at sikre sporbarhed i kvalitetsrapporter. Den nuværende implementation (`mod_export_download.R:229-231`, `mod_export_server.R:194-196`) tilføjer `input$export_footnote` som `ggplot2::labs(caption = ...)` på PNG-plottet og preview, men:

1. **PDF-eksport-pathen passer ej footnote til BFHcharts' Typst-template** — `metadata`-list (linje 153-160) inkluderer `hospital`, `department`, `title`, `analysis`, `data_definition`, `date`, men intet footnote-felt.
2. **Typst-template har ingen footnote-parameter** (verificeret ved gennemgang af `inst/templates/typst/`-skabelonkontrakt).

Konsekvens: Bruger skriver footnote → ser den i preview + PNG-download → **download PDF uden footnote**. Klinisk attribution forsvinder silently. Bug-#485 (production-readiness review).

Ønsket adfærd: Footnote skal være et **separat tekst-element i Typst-template** (ikke en del af plot-billedet), så det vises konsistent på tværs af preview, PNG og PDF.

## What Changes

**UI-laget (`R/mod_export_ui.R`):**
- Tilføj `textAreaInput("export_footnote", "Footnote / Datakilde", placeholder = "...")` til trin 3 (Eksport)
- Maks-længde: `EXPORT_FOOTNOTE_MAX_LENGTH` (ny konstant, fx 500 tegn)

**Server-laget (`R/mod_export_server.R`, `R/mod_export_download.R`):**
- **Fjern** `ggplot2::labs(caption = ...)` fra PNG-pathen — footnote skal ikke længere brændes ind i plot-pixels
- **Tilføj** `footnote = escape_typst_metadata(input$export_footnote)` til `metadata`-list i `generate_pdf_export()`
- **Tilføj** `validate_export_inputs(footnote = input$export_footnote)` (ny validator-arg)
- Preview-pathen (`mod_export_server.R:194-196`) skal generere preview baseret på samme metadata-sti

**Validator (`R/utils_export_validation.R`):**
- Tilføj `footnote`-parameter til `validate_export_inputs()` med længde-cap
- Udvid `escape_typst_metadata`-anvendelse til footnote (allerede dækket af #486)

**Konfiguration (`R/config_export_config.R`):**
- Ny konstant: `EXPORT_FOOTNOTE_MAX_LENGTH <- 500L`

**Typst-template (BFHcharts repo — cross-repo dependency):**
- Template-update: tilføj optional `footnote`-parameter med render-block under chart
- BFHcharts feature-request påkrævet (cross-repo bump-protokol §E)

**Tests:**
- `tests/testthat/test-export-footnote.R` — ny fil
  - Footnote → metadata-pipe (unit-test af `build_export_metadata`)
  - Validator-cap håndhævet (input length > MAX → fejl)
  - Footnote escapes via `escape_typst_metadata`
  - Preview-PDF round-trip viser footnote (integration, kan kræve mock af BFHcharts Typst-render)

**LLM-context (#489-relateret):**
- Tilføj `footnote` til `truncate_llm_context_fields`-freetext-liste

## Impact

- **Affected specs**: `export-preview` (MODIFIED — udvider eksisterende krav om Typst-metadata med footnote-parameter)
- **Affected code**:
  - Modificeret: `R/mod_export_ui.R` (UI-input)
  - Modificeret: `R/mod_export_server.R` (preview-flow)
  - Modificeret: `R/mod_export_download.R` (PDF + PNG-flow)
  - Modificeret: `R/utils_export_validation.R` (validator-arg)
  - Modificeret: `R/utils_export_analysis_metadata.R` (metadata-build)
  - Modificeret: `R/config_export_config.R` (max-konstant)
  - Modificeret: `R/fct_ai_improvement_suggestions.R` (LLM-context-cap udvides)
  - Ny: `tests/testthat/test-export-footnote.R`
  - Modificeret: `inst/templates/typst/bfh-template/*` (template-update — eller koordineret BFHcharts-PR)
- **Cross-repo**: BFHcharts skal eksponere footnote-parameter i Typst-template eller leverer biSPCharts en lokal template-override.
- **Breaking changes**: Ingen — input-felt er nyt; eksisterende eksport uden footnote fortsætter uændret.

## Related

- GitHub Issue #485 (production-readiness review fund 1.6)
- Production-readiness review 2026-05-04 (PR-batch #481-#492)
- `R/utils_export_validation.R:330` (escape_typst_metadata, udvidet i #486)
- BFHcharts repo (cross-repo Typst-template-update)
- ADR-015 (BFHchart-migrering, etablerer template-kontrakt)
