## Why

biSPCharts-kodebasen indeholder ~8.000+ linjer ubrugt kode fordelt på:
- **10 helt døde filer** (~3.300 linjer) — abstraktionslag og frameworks der aldrig blev adopteret
- **~100+ ubrugte funktioner** spredt over 20+ filer
- **Ghost input IDs** — server-kode der refererer til UI-elementer der ikke eksisterer
- **Duplikerede funktionsdefinitioner** — 4 sæt funktioner defineret i flere filer
- **Orphaned event bus entries** — events der emittes men aldrig observeres
- **Død JS/CSS** — ubrugte handlers, debug-stylesheets, forældede billeder

Denne tekniske gæld øger cognitive load, risikerer fejl ved R's load-order-afhængige name resolution (duplikater), og gør fremtidige refaktoreringer unødigt komplekse.

## What Changes

### Fase 1: Fjern helt døde filer (10 filer, ~3.300 linjer)
- `utils_server_plot_optimization.R` — superseded af direkte `generateSPCPlot` kald
- `utils_dependency_injection.R` — DI framework aldrig adopteret
- `utils_validation_guards.R` — erstattet af `safe_operation()` + `req()`
- `utils_config_consolidation.R` — config tilgås direkte, ikke via registry
- `utils_ui_ui_components.R` — UI component factories aldrig brugt
- `utils_ui_form_helpers.R` — form service layer aldrig adopteret
- `utils_chart_module_helpers.R` — module service layer aldrig adopteret
- `fct_file_io.R` — superseded af `fct_file_operations.R`
- `app_dependencies.R` — package loading aldrig integreret
- `utils_plot_diff.R` — differential update aldrig adopteret

### Fase 2: Fjern ubrugte funktioner i aktive filer
- `ui_app_ui.R`: Fjern `create_export_card()`
- `utils_ui_ui_helpers.R`: Fjern 8 ubrugte style-hjælpere (behold `sanitize_selection`)
- `utils_state_accessors.R`: Fjern 28 ubrugte accessors (behold 6 der bruges)
- `utils_server_server_management.R`: Fjern welcome page handlers + ghost input refs
- `utils_performance_monitoring.R`: Fjern 10 ubrugte monitoring-funktioner
- `utils_microbenchmark.R`: Fjern 6 ubrugte benchmark-funktioner
- `utils_profiling.R`: Fjern 4 ubrugte profiling-funktioner
- `utils_server_performance.R`: Fjern 7 ubrugte funktioner
- `config_branding_getters.R`: Fjern 5 ubrugte branding-funktioner
- `fct_spc_helpers.R`: Fjern 6 ubrugte SPC-hjælpere
- `utils_memory_management.R`: Fjern 5 ubrugte memory-funktioner
- `utils_danish_locale.R`: Fjern 4 ubrugte locale-funktioner
- Diverse: ~15 ubrugte funktioner i andre filer

### Fase 3: Fjern duplikater og orphans
- Fjern duplikerede definitioner i `state_management.R` (shadowed af `utils_state_accessors.R`)
- Fjern duplikat `calculate_combined_anhoej_signal` i `fct_anhoej_rules.R` (keep `fct_spc_bfh_service.R`)
- Fjern duplikat `parse_danish_target` i `utils_y_axis_scaling.R` (keep `utils_danish_locale.R` eller omvendt)
- Fjern duplikater i `utils_performance.R` vs `utils_performance_caching.R`
- Fjern orphaned event bus entries (`form_update_needed`, `column_mapping_modal_*`)

### Fase 4: Oprydning af JS/CSS og statiske assets
- Fjern `plot-debug.css` + reference
- Fjern `bfh_frise.png` og `RegionH_hospital.png`
- Fjern `modal_closed_event` JS input (ingen server-consumer)
- Fjern `showAppUI` JS handler (aldrig triggered)
- Fjern `.selectize-dropup` CSS/JS (klasse aldrig tildelt)
- Fjern `console.log` debug statements i `local-storage.js`

### Fase 5: Opryd kommenteret kode og dead outputs
- Fjern `output$data_summary_box` render (UI consumer er kommenteret ud)
- Opdater NAMESPACE efter fjernelse af exports

## Impact

- Affected specs: Ingen — al fjernet kode er ubrugt
- Affected code: ~30 filer i `R/`, ~5 filer i `inst/app/www/`
- Estimat: ~8.000 linjer fjernet
- Risiko: Lav — al kode er verificeret ubrugt via grep-analyse
- Kræver: `devtools::document()` efter NAMESPACE-ændringer, fuld test-suite kørsel

## Related
- GitHub Issue: #171
