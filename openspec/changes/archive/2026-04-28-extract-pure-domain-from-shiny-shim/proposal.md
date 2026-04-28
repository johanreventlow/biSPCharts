## Why

Reviews (Claude + Codex, 2026-04-24) pegede på at service-laget blander pure domænelogik med Shiny `reactiveValues`-mutation: `fct_file_operations.R:141+ (setup_file_upload)`, `fct_autodetect_unified.R:17+ (autodetect_engine)`, og `fct_visualization_server.R:20-80 (setup_visualization)`. Konsekvensen er at pure logic ikke kan unit-testes uden fuld Shiny-session; det forklarer hvorfor disse kritiske filer ikke har matching testfiler. Codex tilføjede at app_state-mutationer sker fra upload, restore, renderPlot, observers, cache-observers og event handlers — ingen single source of truth for state-transitions. Løsningen er at ekstrahere pure domain-core-funktioner og wrap dem med tynde Shiny-adapter-shims.

## What Changes

- Opret nyt capability `domain-core` der kodificerer separation mellem ren domænelogik og Shiny-state-mutation.
- Ekstrahér fra `fct_file_operations.R`:
  - `parse_file(path, format, encoding_hints)` → returnerer `ParsedFile`-struktur (pure, ingen Shiny)
  - Separat `apply_parsed_file_to_state(parsed, app_state)` → Shiny-shim
- Ekstrahér fra `fct_autodetect_unified.R`:
  - `run_autodetect(data, hints)` → returnerer `AutodetectResult`-struktur (pure)
  - Separat `apply_autodetect_to_state(result, app_state)` → Shiny-shim
- Ekstrahér fra `fct_visualization_server.R`:
  - `build_visualization_config(data, autodetect, user_overrides)` → returnerer `VisualizationConfig` (pure)
  - Shim håndterer `app_state`-mutation + reactive dependencies
- Indfør **state-transition-helpers**: navngivne pure funktioner som `transition_upload_to_ready(state_before, parsed_file)` der tager gammel state + input og returnerer ny state. Shiny-observer kalder `app_state <<- transition_upload_to_ready(isolate(app_state), parsed)` via centraliseret applier.
- Mål: reducere direkte `app_state$...<-`-assignments uden for state-laget med ≥50%.
- Tilføj unit-tests for hver ny pure-funktion med baseline-fixtures, edge cases, fejl-paths.

## Impact

- **Affected specs**: Nyt capability `domain-core` (ADDED)
- **Affected code**:
  - Ny: `R/fct_file_parse_pure.R`, `R/fct_autodetect_pure.R`, `R/fct_visualization_config_pure.R`
  - Ny: `R/utils_state_transitions.R` med named state-transition-helpers
  - Modificeret: `R/fct_file_operations.R` (reduceret til Shiny-shim)
  - Modificeret: `R/fct_autodetect_unified.R` (reduceret til Shiny-shim)
  - Modificeret: `R/fct_visualization_server.R` (reduceret til Shiny-shim)
  - Nye: `tests/testthat/test-fct_file_parse_pure.R`, `test-fct_autodetect_pure.R`, `test-state-transitions.R`
- **Afhængighed**: Kan landes parallelt med `extract-anhoej-derivation-pure` (samme princip, forskellige domæner). Afhænger af `harden-csv-parse-error-reporting` for CSV-parse-error-pattern.
- **Risks**:
  - Refaktor af `setup_file_upload()` (762 linjer i fct_file_operations.R) er betydelig — del op i inkrementelle PRs
  - Race condition-risiko hvis state-transitions ikke er atomiske — dokumentér i design.md
  - Performance-overhead fra `isolate()`-kald — mål før/efter
- **Non-breaking for brugere**: Ingen UI-ændring. Intern refaktor.

## Related

- GitHub Issue: #320
- Review-rapport: Claude (V3) + Codex (K2 architecture afhænger af implicit mutable state)
