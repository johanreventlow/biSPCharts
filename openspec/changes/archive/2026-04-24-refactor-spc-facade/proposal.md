## Why

`compute_spc_results_bfh()` i `R/fct_spc_bfh_facade.R:269` er 578 linjer og håndterer minimum 8 forskellige ansvar i én funktion: input-validering, cache-nøgle-generering, chart-type-validering, dato-/tidsparsing, numerisk parsing, BFHcharts-parameter-mapping, BFHcharts-kald, plot-mutering, metadata-ekstraktion, Anhøj-fallback, cache-write og logging. Små ændringer (fx i y-axis-labels eller cache-semantik) får utilsigtede effekter andre steder, og funktionen kan ikke unit-testes granulært — kun som black-box.

Derudover bruger funktionen `safe_operation()` som wrapper der fanger alle errors og returnerer fallback-lists. Det betyder at:
- Fejl i domænelogik konverteres til `NULL`/tomme resultater som propagerer gennem UI uden tydelig signalering
- Test-gaten svækkes fordi fejl ikke kan observeres som faktiske fejl i testthat
- Failure modes er uklare: en korrupt cache, en manglende kolonne og en BFHcharts-fejl kan alle se ud som "tomt plot"

Endelig bruger `R/zzz.R:318` `unlockBinding()` på 4 package-level bindings (`.panel_cache_stats`, `.grob_cache_stats`, `.panel_cache_config`, `.grob_cache_config`) for at tillade runtime-mutation. `R CMD check` markerer dette som unsafe, og det gør session-isolation og reproducerbar testing svært.

## What Changes

- **Split `compute_spc_results_bfh()`** i en pipeline af små, testbare helpers med typed S3-kontrakter:
  - `validate_spc_request(data, mapping, chart, ...)` → `spc_request` S3
  - `prepare_spc_data(request)` → `spc_prepared` (parsed dates, numeric, filtered)
  - `resolve_axis_units(prepared, chart_type, multiply)` → `spc_axes`
  - `build_bfh_args(prepared, axes, display_opts)` → named list klar til BFHcharts
  - `execute_bfh_request(bfh_args)` → rå BFHcharts-output
  - `extract_spc_metadata(raw, prepared)` → Anhøj-metadata via qicharts2 (uændret hybrid-arkitektur)
  - `decorate_plot_for_display(plot, metadata, display_opts)` → finished plot
  - `read_spc_cache(key)` / `write_spc_cache(key, result)` → injicerbare
  - `compute_spc_results_bfh()` bliver tyndt orkestreringslag (<100 linjer) der kalder helpers sekventielt
- **Reducer `safe_operation()` i domænelogik**:
  - Domæne-helpers kaster **typed errors** via `rlang::abort(class = c("spc_input_error", "spc_error"))` eller `stop(..., call. = FALSE)` med klar besked
  - `safe_operation()` bevares kun i UI-boundaries (`mod_spc_chart_compute.R`, `mod_*` server-handlers) hvor fallback giver mening
  - Indfør minimal fejlklasse-taksonomi: `spc_input_error`, `spc_prepare_error`, `spc_render_error`, `spc_cache_error`
  - `mod_spc_chart_compute.R` fanger via `tryCatch(..., spc_error = function(e) { notify_user(e); NULL })` i stedet for generic safe_operation
- **Fjern `unlockBinding()` fra `R/zzz.R`**:
  - Migrer `.panel_cache_stats`, `.grob_cache_stats`, `.panel_cache_config`, `.grob_cache_config` fra package-level `<-` bindings til en dedikeret cache-environment (fx `cache_state <- new.env(parent = emptyenv())`) defineret i `R/utils_cache.R`
  - Referencer på tværs af moduler opdateres til `cache_state$panel_stats` i stedet for `.panel_cache_stats`
  - `unlock_cache_statistics()` fjernes helt
- **Kontrakt-tests**:
  - Hver helper får dedikeret `test-fct_spc_<helper>.R` med inputs/outputs/edge cases
  - Black-box kontrakt-test for `compute_spc_results_bfh()` bevares for alle chart types (run, p, u, c, g, xbar, s, mr, i, t)
  - Regression-tests for typed errors: `expect_error(class = "spc_input_error")`

## Impact

- **Affected specs**: `spc-facade` (ny capability)
- **Affected code**:
  - `R/fct_spc_bfh_facade.R` (split til flere filer: `fct_spc_validate.R`, `fct_spc_prepare.R`, `fct_spc_execute.R`, `fct_spc_decorate.R`)
  - `R/utils_error_handling.R` (udvides med typed error helpers)
  - `R/utils_cache.R` (ny cache-environment)
  - `R/zzz.R` (fjern unlock_cache_statistics)
  - `R/mod_spc_chart_compute.R` (typed error catching)
  - `tests/testthat/test-fct_spc_*.R` (nye granulære tests)
- **Risks**:
  - Refaktorering af 578 linjer ramt af mange tests — høj regressionsrisiko
  - Mitigation: behold eksisterende black-box tests grøn gennem hele refactor, lav ændringerne commit-for-commit
  - Cache-layout-ændring (package-level → environment) kan påvirke performance — skal benchmark'es før/efter
  - Typed errors kan bryde caller-kode der forventer `NULL`-returnering — mitigeres ved at `compute_spc_results_bfh()`-orkestreringslaget fortsat returnerer `NULL` ved fejl (bevarer offentligt kontrakt), men nu med klarere logging
- **Non-breaking for brugere**: Ingen UI-ændring, ingen ændring af public API-signatur
- **Performance**: Ingen forventet regression; benchmark før/efter dokumenteres
- **Testbarhed**: Markant forbedret — hver helper kan unit-testes isoleret

## Related

- GitHub Issue: #289 (paraply)
- Codex-review: 2026-04-21 session (problem 2, 3, 4)
- `design.md`: Indeholder S3-kontrakter, cache-migration-plan og fejlklasse-taksonomi
