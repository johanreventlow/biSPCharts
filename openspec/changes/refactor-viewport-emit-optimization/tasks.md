## 1. Viewport emit optimization (pkt 2)

- [ ] 1.1 Tilføj change detection i `set_viewport_dims()` i `R/utils_state_accessors.R`: sammenlign nye width/height med eksisterende værdier, emit kun ved reel ændring
- [ ] 1.2 Fjern `set_viewport_dims()` kald fra renderPlot-stien i `R/mod_spc_chart_server.R` (viewport-observeren i `mod_spc_chart_observers.R` håndterer det allerede)
- [ ] 1.3 Verificér at viewport-resize stadig trigger korrekt re-render via observer-stien
- [ ] 1.4 Skriv test: `set_viewport_dims()` med uændrede dimensioner emitter IKKE
- [ ] 1.5 Skriv test: `set_viewport_dims()` med ændrede dimensioner emitter
- [ ] 1.6 Kør fuld test-suite — ingen regressioner

## 2. Centraliser upload-thresholds (pkt 10)

- [ ] 2.1 Tilføj konstanter i `R/config_system_config.R`: `UPLOAD_LIMITS` med `max_file_size_mb`, `max_line_count`, `warning_row_count`
- [ ] 2.2 Tilføj getter-funktioner: `get_max_file_size_mb()`, `get_max_upload_line_count()`, `get_upload_warning_row_count()`
- [ ] 2.3 Opdater `R/fct_file_operations.R:768+` til at bruge getter-funktioner i stedet for hardcodede værdier
- [ ] 2.4 Verificér at alle tre upload-paths (Excel, CSV, paste) bruger centraliserede værdier
- [ ] 2.5 Kør fuld test-suite — ingen regressioner

## 3. Verifikation

- [ ] 3.1 Kør fuld test-suite
- [ ] 3.2 Manuel test: resize browser-vindue og verificér at chart re-renderer korrekt — **[MANUELT TRIN]**
- [ ] 3.3 Manuel test: upload fil >50 MB og verificér fejlbesked — **[MANUELT TRIN]**
- [ ] 3.4 Commit: `refactor(perf): viewport change detection og centraliserede upload-thresholds`
