# Tasks — add-pdf-footnote-input

## Foran-arbejde

- [x] Bekræft cross-repo-koordinering: BFHcharts Typst-template har allerede `footer_content`-parameter (linje 27/52/207 i `bfh-template.typ`). Pipeline understøtter `metadata$footer_content` i `bfh_create_typst_document()` og `bfh_export_pdf()`. **Ingen BFHcharts-PR påkrævet.**
- [x] Bekræft footnote-design: BFHcharts renderer som UPPERCASE 6pt grå tekst nederst-højre under chart. Maks-længde 500 tegn passende til klinisk attribution.

## Konfiguration

- [x] Tilføj `EXPORT_FOOTNOTE_MAX_LENGTH <- 500L` til `R/config_export_config.R`
- [x] Dokumentér konstant i header-kommentar med kilde (`#485`-link)

## Validator (utils_export_validation.R)

- [x] Tilføj `footnote = ""` parameter til `validate_export_inputs()`-signature
- [x] Tilføj længde-check: `nchar(footnote) > EXPORT_FOOTNOTE_MAX_LENGTH` → fejl
- [x] Tilføj test-cases til `tests/testthat/test-utils_export_validation.R`

## Metadata-pipeline (utils_export_analysis_metadata.R)

- [x] Tilføj `footnote`-felt til `build_export_analysis_metadata()`-output
- [x] Default `""` hvis ej supplied
- [x] Anvendes ved `escape_typst_metadata()` ved indsættelse i PDF metadata-list (PDF-export-pathen, ikke i analysis_metadata-builderen — analyse-konteksten beholder rå tekst til LLM)

## UI (mod_export_ui.R)

- [x] Tilføj `textAreaInput("export_footnote", ...)` til trin 3-panelet (uconditional, gælder PDF + PNG)
- [x] Label: "Fodnote / Datakilde (vises under chart)"
- [x] Placeholder: "Eksempel: Datakilde: KvalDB udtræk 2026-04-29"
- [x] Hjælp-tekst med karakter-info (helpText + bsTooltip)
- [x] Maks-længde-attr (HTML5 `maxlength` via JS-snippet)

## Server — PDF (mod_export_download.R::generate_pdf_export)

- [x] Tilføj `footnote = input$export_footnote` til `validate_export_inputs()`-kald
- [x] Tilføj `footer_content = escape_typst_metadata(input$export_footnote)` til `metadata`-list (NULL hvis tom for graceful PDF-output)
- [x] Verificér at `BFHcharts::bfh_export_pdf()` accepterer `metadata$footer_content` (verificeret: `BFHcharts/R/utils_typst.R:528-530` + `utils_export_helpers.R:131` whitelist)

## Server — PNG (mod_export_download.R::generate_png_export)

- [x] Tilføj `footnote = input$export_footnote` til `validate_export_inputs()`-kald
- [x] Beslut: PNG beholder existing `ggplot2::labs(caption = ...)` for footnote (bevarer eksisterende UX, ej breaking change). PDF bruger BFHcharts Typst `footer_content` for separat tekst-element. Divergens dokumenteret i NEWS.

## Server — Preview (mod_export_server.R)

- [x] PDF-preview pathen: tilføj `footer_content = escape_typst_metadata(...)` til preview-metadata + ny `debounced_footnote`-reactive
- [x] PNG-preview pathen: behold eksisterende `ggplot2::labs(caption = ...)` (matcher PNG-eksport-styling)
- [x] Verificér at PDF preview viser footnote konsistent med PDF-output (samme metadata-sti)

## Typst-template (cross-repo / BFHcharts)

- [x] **Skip:** `footer_content`-parameter eksisterer allerede i BFHcharts `bfh-template.typ` (linje 27/52/207) — ingen template-ændring påkrævet
- [x] Skip: render-block findes allerede (UPPERCASE 6pt grå nederst-højre)
- [x] Skip: `footer_content = none` graceful tom-state allerede understøttet
- [x] Skip: ingen BFHcharts version-bump påkrævet (current `>= 0.15.0` er tilstrækkelig)

## LLM-integration (#489-koordinering)

- [x] Tilføj `"footnote"` til `truncate_llm_context_fields`'s `freetext_fields`-liste i `R/fct_ai_improvement_suggestions.R`

## Tests

- [x] Ny: `tests/testthat/test-export-footnote.R`
  - [x] `build_export_analysis_metadata` propagerer footnote til output
  - [x] `escape_typst_metadata` anvendes på footnote
  - [x] `validate_export_inputs(footnote = strrep("a", 1000))` kaster længde-fejl
  - [x] Default `""` ved manglende input
- [x] Udvid `tests/testthat/test-utils_export_validation.R` med footnote-cases (max-length, exact-cap, NULL/empty)
- [ ] **Manuel:** Test live PDF-eksport med footnote — verificér placering + readability (kræver browser)

## Dokumentation

- [x] Opdatér `docs/CONFIGURATION.md` med `EXPORT_FOOTNOTE_MAX_LENGTH`
- [x] Opdatér `NEWS.md` under "Nye features": "Footnote-felt i eksport (#485)"
- [x] Opdatér `R/mod_export_ui.R` (tooltip dokumenterer feltet inline)

## Pre-merge gate

- [x] Pre-push gate (fast) passerer (verificeret via PR #510 + #512 + #517 + #518 push-flows)
- [x] Manifest-validator passerer (`Rscript dev/validate_connect_manifest.R` → "Connect manifest OK")
- [x] BFHcharts cross-repo dependency synced (ingen bump påkrævet)
- [ ] Manuel test: round-trip preview ↔ PDF viser footnote konsistent (kræver browser)
- [ ] Manuel test: tom footnote-felt → PDF uden footnote-element (ej tom blok) (kræver browser)

## Archive

- [ ] Efter merge til master + Connect-deploy verifikation: kør `/opsx:archive add-pdf-footnote-input`
