# Tasks — add-excel-sheet-picker

## 1. Pure helpers (R/fct_excel_sheet_detection.R)

- [x] 1.1 Opret ny fil `R/fct_excel_sheet_detection.R`
- [x] 1.2 Implementer `list_excel_sheets(path)` med tryCatch → NULL ved fejl
- [x] 1.3 Implementer `detect_empty_sheets(path, sheets)` via `read_excel(n_max=1)` per ark
- [x] 1.4 Implementer `is_bispchart_excel_format(sheets)` (Data + Indstillinger AND-check)
- [x] 1.5 Roxygen-dokumentation for alle tre helpers (@noRd da intern brug)
- [x] 1.6 Kør `devtools::document()` — kørt; ingen NAMESPACE-aendringer fra @noRd helpers

## 2. Tests for pure helpers

- [x] 2.1 Opret `tests/testthat/test-excel-sheet-picker.R`
- [x] 2.2 ~~Opret test-fixtures i `tests/testthat/fixtures/`~~ (i stedet: runtime-fixtures via `make_test_xlsx()` helper i test-fil — ingen committede binaerer)
- [x] 2.3 Tests for `list_excel_sheets()` — gyldig, korrupt, ikke-eksisterende
- [x] 2.4 Tests for `detect_empty_sheets()` — alle kombinationer
- [x] 2.5 Tests for `is_bispchart_excel_format()` — 2-ark biSPCharts, 3-ark biSPCharts, standard

## 3. State management

- [x] 3.1 Tilføj `pending_excel_upload = NULL` til `app_state$session` initialisering i `R/state_management.R`
- [x] 3.2 Verificér at session-clear (`clear_saved`) rydder pending-slot — tilføjet eksplicit `app_state$session$pending_excel_upload <- NULL` i `reset_to_empty_session()`

## 4. UI

- [x] 4.1 Tilføj container-div `#excel_sheet_dropdown` med `uiOutput("excel_sheet_dropdown_items")` under "Indlæs XLS/CSV"-knappen i `R/ui_app_ui.R`
- [x] 4.2 Tilføj CSS-klasse `.excel-sheet-dropdown` i samme stil som `.sample-data-dropdown`
- [x] 4.3 Tilføj CSS-klasse `.excel-sheet-item--empty` (dæmpet farve for tomme ark)
- [x] 4.4 Tilføj JS click-outside-handler for ny dropdown (i samme script-blok som sample-dropdown-handler)

## 5. Observer-logik (R/utils_server_paste_data.R)

- [x] 5.1 Implementer `build_excel_sheet_dropdown_items(sheets, empty_flags)` helper med JSON-escaped onclick + htmlEscape label
- [x] 5.2 Tilføj `output$excel_sheet_dropdown_items <- renderUI({ ... })` reaktivt på `app_state$session$pending_excel_upload`
- [x] 5.3 Modificér multi-sheet-grenen i `direct_file_upload`-observer (split i 3 grene: biSPCharts / single-sheet / multi-sheet); ekstraheret `excel_data_to_paste_text()` helper
- [x] 5.4 Tilføj ny `observeEvent(input$selected_excel_sheet)` med safe_operation, sheet-validering, paste-felt-fyld, dropdown-skjul, ryd pending

## 6. Observer-tests

- [x] 6.1 Test: single-sheet upload (state-niveau via helpers) — bevarer flow
- [x] 6.2 Test: biSPCharts-format detekteres korrekt (3-ark inkl. SPC-analyse)
- [x] 6.3 Test: multi-sheet upload setter pending_excel_upload med korrekt struktur
- [x] 6.4 Test: pending ryddes efter selected_excel_sheet (state-mutation verificeret)
- [x] 6.5 Test: re-upload overskriver pending med ny info
- [x] 6.6 Test: JSON-escape virker for citationstegn; UTF-8 (æøå) bevares

## 7. Manuel verifikation

**Manuel verifikation gennemført af bruger 2026-04-28 — OK:**

- [x] 7.1 Test i dev-app: upload multi-sheet xlsx → dropdown vises → vælg ark → paste-felt fyldt → tryk Fortsæt → analyse OK
- [x] 7.2 Test: upload single-sheet Excel → uændret flow
- [x] 7.3 Test: upload biSPCharts-format → auto-restore (uændret)
- [x] 7.4 Test: upload Excel med tomt ark → ark vises grå-ud, men kan stadig vælges
- [x] 7.5 Test: upload nyt fil mens dropdown er åben → dropdown opdateres med nye ark-navne
- [x] 7.6 Verificér med ark-navne `"Q1 2024"`, `"Data \"med\" citater"`, `"Sjælland-data"` — ingen JS-fejl i browser-console

## 8. Dokumentation

- [x] 8.1 Opdatér `CLAUDE.md` sektion 2 — tilføjet "Excel Upload (sheet-picker for multi-sheet)" parallel til Excel Download-sektion
- [x] 8.2 Tilføj NEWS.md-entry under biSPCharts 0.3.0 — sheet-picker dokumenteret som ny feature (issue-nummer udelades indtil bruger opretter)

## 9. Pre-commit

- [x] 9.1 `lintr::lint("R/fct_excel_sheet_detection.R")` — 0 lints. Eksisterende lint-warnings i andre filer er pre-existing
- [x] 9.2 `styler::style_file()` paa aendrede R-filer + test-fil
- [x] 9.3 `devtools::test()` — Total fails: 0, errors: 0 (alle nye + regression passerer)
- [ ] 9.4 `devtools::check()` — udsat (langsom, koeres ved release-gate)
