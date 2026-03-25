## 1. Forberedelse
- [ ] 1.1 Kør fuld test-suite som baseline (gem resultat)
- [ ] 1.2 Opret feature branch `chore/remove-legacy-dead-code`
- [ ] 1.3 Tag snapshot af NAMESPACE (til sammenligning)

## 2. Fase 1: Fjern helt døde filer (10 filer)
- [ ] 2.1 Fjern `utils_server_plot_optimization.R` (582 linjer)
- [ ] 2.2 Fjern `utils_dependency_injection.R` (355 linjer)
- [ ] 2.3 Fjern `utils_validation_guards.R` (322 linjer)
- [ ] 2.4 Fjern `utils_config_consolidation.R` (288 linjer)
- [ ] 2.5 Fjern `utils_ui_ui_components.R` (281 linjer)
- [ ] 2.6 Fjern `utils_ui_form_helpers.R` (317 linjer)
- [ ] 2.7 Fjern `utils_chart_module_helpers.R` (382 linjer)
- [ ] 2.8 Fjern `fct_file_io.R` (120 linjer)
- [ ] 2.9 Fjern `app_dependencies.R` (336 linjer)
- [ ] 2.10 Fjern `utils_plot_diff.R` (323 linjer)
- [ ] 2.11 Kør `devtools::document()` og opdater NAMESPACE
- [ ] 2.12 Kør test-suite — alle tests skal bestå
- [ ] 2.13 Commit: `chore: fjern 10 helt ubrugte R-filer (~3.300 linjer)`

## 3. Fase 2: Fjern ubrugte funktioner i aktive filer
- [ ] 3.1 `ui_app_ui.R`: Fjern `create_export_card()` (linje ~500-536)
- [ ] 3.2 `utils_ui_ui_helpers.R`: Fjern 8 ubrugte hjælpere (behold `sanitize_selection`)
- [ ] 3.3 `utils_state_accessors.R`: Fjern 28 ubrugte accessors (behold 6 aktive)
- [ ] 3.4 `utils_server_server_management.R`: Fjern welcome page handlers + ghost input refs
- [ ] 3.5 `utils_performance_monitoring.R`: Fjern 10 ubrugte funktioner
- [ ] 3.6 `utils_microbenchmark.R`: Fjern 6 ubrugte benchmark-funktioner
- [ ] 3.7 `utils_profiling.R`: Fjern 4 ubrugte profiling-funktioner
- [ ] 3.8 `utils_server_performance.R`: Fjern 7 ubrugte funktioner (behold aktive)
- [ ] 3.9 `config_branding_getters.R`: Fjern 5 ubrugte branding-funktioner
- [ ] 3.10 `fct_spc_helpers.R`: Fjern 6 ubrugte SPC-hjælpere
- [ ] 3.11 `utils_memory_management.R`: Fjern 5 ubrugte funktioner (behold `setup_session_cleanup`)
- [ ] 3.12 `utils_danish_locale.R`: Fjern 4 ubrugte locale-funktioner
- [ ] 3.13 Diverse: Fjern øvrige ubrugte funktioner (golem_utils, font_registration, shinylogs, etc.)
- [ ] 3.14 Kør `devtools::document()` og opdater NAMESPACE
- [ ] 3.15 Kør test-suite — alle tests skal bestå
- [ ] 3.16 Commit: `chore: fjern ~100+ ubrugte funktioner fra aktive filer`

## 4. Fase 3: Fjern duplikater og orphaned events
- [ ] 4.1 Fjern duplikerede `set_current_data`/`set_original_data`/`get_current_data` i `state_management.R`
- [ ] 4.2 Konsolidér `calculate_combined_anhoej_signal` (fjern den i `fct_anhoej_rules.R`)
- [ ] 4.3 Konsolidér `parse_danish_target` (fjern legacy wrapper)
- [ ] 4.4 Konsolidér duplikater i `utils_performance.R` vs `utils_performance_caching.R`
- [ ] 4.5 Fjern orphaned event bus entries (`form_update_needed`, `column_mapping_modal_*`)
- [ ] 4.6 Kør test-suite
- [ ] 4.7 Commit: `chore: fjern duplikerede funktioner og orphaned events`

## 5. Fase 4: JS/CSS og statiske assets oprydning
- [ ] 5.1 Fjern `inst/app/www/plot-debug.css` + reference i `ui_app_ui.R`
- [ ] 5.2 Fjern `inst/app/www/bfh_frise.png` og `inst/app/www/RegionH_hospital.png`
- [ ] 5.3 Fjern `modal_closed_event` JS input i `shiny-handlers.js`
- [ ] 5.4 Fjern `showAppUI` handler i `shiny-handlers.js` + `ui-helpers.js`
- [ ] 5.5 Fjern `.selectize-dropup` CSS i `ui_app_ui.R` + JS i `ui-helpers.js`
- [ ] 5.6 Fjern `console.log` statements i `local-storage.js`
- [ ] 5.7 Kør test-suite
- [ ] 5.8 Commit: `chore: fjern ubrugt JS/CSS og orphaned assets`

## 6. Fase 5: Afsluttende oprydning
- [ ] 6.1 Fjern `output$data_summary_box` render i `mod_spc_chart_server.R`
- [ ] 6.2 Fjern eventuelle tests der kun tester fjernet kode
- [ ] 6.3 Kør fuld test-suite — sammenlign med baseline
- [ ] 6.4 Kør `devtools::document()` — verificer clean NAMESPACE
- [ ] 6.5 Final commit: `chore: afsluttende oprydning af dead outputs og tests`

## 7. Validering
- [ ] 7.1 Kør `R CMD check` eller tilsvarende
- [ ] 7.2 Start app manuelt og verificer kernefunktionalitet
- [ ] 7.3 Verificer at ingen warnings om manglende funktioner opstår
