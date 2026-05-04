# Tasks — add-pdf-footnote-input

## Foran-arbejde

- [ ] Bekræft cross-repo-koordinering: er Typst-template ejet af BFHcharts (privat) eller biSPCharts? Hvis BFHcharts → opret feature-request først (cross-repo §E).
- [ ] Bekræft footnote-design med klinisk personale: tekst-blok under chart vs. footer på siden? Maks-længde 500 tegn passende?

## Konfiguration

- [ ] Tilføj `EXPORT_FOOTNOTE_MAX_LENGTH <- 500L` til `R/config_export_config.R`
- [ ] Dokumentér konstant i header-kommentar med kilde (`#485`-link)

## Validator (utils_export_validation.R)

- [ ] Tilføj `footnote = ""` parameter til `validate_export_inputs()`-signature
- [ ] Tilføj længde-check: `nchar(footnote) > EXPORT_FOOTNOTE_MAX_LENGTH` → fejl
- [ ] Tilføj test-cases til `tests/testthat/test-export-validation.R`

## Metadata-pipeline (utils_export_analysis_metadata.R)

- [ ] Tilføj `footnote`-felt til `build_export_analysis_metadata()`-output
- [ ] Default `""` hvis ej supplied
- [ ] Anvend `escape_typst_metadata()` på input

## UI (mod_export_ui.R)

- [ ] Tilføj `textAreaInput("export_footnote", ...)` til trin 3-panelet
- [ ] Label: "Footnote / Datakilde (vises under chart)"
- [ ] Placeholder: "Eksempel: Datakilde: KvalDB udtræk 2026-04-29"
- [ ] Hjælp-tekst med karakter-counter (helpText eller bsTooltip)
- [ ] Maks-længde-attr (HTML5 `maxlength`)

## Server — PDF (mod_export_download.R::generate_pdf_export)

- [ ] Tilføj `footnote = input$export_footnote` til `validate_export_inputs()`-kald
- [ ] Tilføj `footnote = escape_typst_metadata(input$export_footnote)` til `metadata`-list
- [ ] Verificér at `BFHcharts::bfh_export_pdf()` accepterer `metadata$footnote` (kræver BFHcharts-PR hvis ikke)

## Server — PNG (mod_export_download.R::generate_png_export)

- [ ] **Fjern** `ggplot2::labs(caption = footnote_text)`-tilføjelse til plot
- [ ] Beslut: Skal PNG også vise footnote? Hvis ja: render som adskilt tekst-element via ggplot2 `theme()` eller ny `cowplot::plot_grid` — IKKE som plot-caption.
- [ ] Hvis nej: dokumentér at footnote kun vises i PDF (UI-info-tekst)

## Server — Preview (mod_export_server.R)

- [ ] Opdater preview-flow til at bruge samme metadata-sti som download
- [ ] Verificér at preview viser footnote konsistent med PDF-output (ej ggplot caption)

## Typst-template (cross-repo / BFHcharts)

- [ ] **[BFHcharts-PR]** Tilføj optional `footnote`-parameter til `bfh-diagram`-template
- [ ] Render footnote som lille gråtone-tekst under chart-billedet (anbefalet placering: footer)
- [ ] Bekræft at template virker med `footnote = none` (graceful tom-state)
- [ ] Bump BFHcharts version efter merge → opdatér biSPCharts `DESCRIPTION` lower-bound

## LLM-integration (#489-koordinering)

- [ ] Tilføj `"footnote"` til `truncate_llm_context_fields`'s `freetext_fields`-liste i `R/fct_ai_improvement_suggestions.R`

## Tests

- [ ] Ny: `tests/testthat/test-export-footnote.R`
  - [ ] `build_export_analysis_metadata` propagerer footnote til output
  - [ ] `escape_typst_metadata` anvendes på footnote
  - [ ] `validate_export_inputs(footnote = strrep("a", 1000))` kaster længde-fejl
  - [ ] Default `""` ved manglende input
- [ ] Udvid `tests/testthat/test-export-validation.R` med footnote-cases
- [ ] **Manuel:** Test live PDF-eksport med footnote — verificér placering + readability

## Dokumentation

- [ ] Opdatér `docs/CONFIGURATION.md` med `EXPORT_FOOTNOTE_MAX_LENGTH`
- [ ] Opdatér `NEWS.md` under "Nye features": "Footnote-felt i eksport (#485)"
- [ ] Opdatér `R/mod_export_ui.R` roxygen-doc

## Pre-merge gate

- [ ] Pre-push gate (fast) passerer
- [ ] Manifest-validator passerer
- [ ] BFHcharts cross-repo dependency synced (DESCRIPTION lower-bound + manifest)
- [ ] Manuel test: round-trip preview ↔ PDF viser footnote konsistent
- [ ] Manuel test: tom footnote-felt → PDF uden footnote-element (ej tom blok)

## Archive

- [ ] Efter merge til master + Connect-deploy verifikation: kør `/opsx:archive add-pdf-footnote-input`
