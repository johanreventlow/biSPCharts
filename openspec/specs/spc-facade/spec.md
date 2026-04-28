# spc-facade Specification

## Purpose
TBD - created by archiving change refactor-spc-facade. Update Purpose after archive.
## Requirements
### Requirement: SPC-facade orkestrator er tyndt lag

`compute_spc_results_bfh()` SHALL være tyndt orkestreringslag der delegerer til navngivne pipeline-helpers. Orkestratoren SHALL være <150 linjer eksklusive roxygen-dokumentation.

#### Scenario: Orkestrator-længde
- **WHEN** `compute_spc_results_bfh()` måles i linjer (eksklusive kommentarer og roxygen)
- **THEN** længden er <150 linjer
- **AND** alle ansvar ud over orkestrering er delegeret til helpers

#### Scenario: Pipeline-rækkefølge
- **WHEN** `compute_spc_results_bfh()` kaldes
- **THEN** eksekveringen følger sekvensen: validate → prepare → resolve axes → build args → execute → decorate → cache-write
- **AND** hver helper kan erstattes med mock i test

### Requirement: Typed errors i SPC-domænelogik

SPC-domæne-helpers (`validate_spc_request`, `prepare_spc_data`, `execute_bfh_request`, osv.) SHALL kaste typed errors med klar klassetaksonomi. Generic `stop()` uden klasse er NOT tilladt i domænelogik.

Klasse-taksonomi:
- `spc_input_error`: ugyldig input (manglende kolonner, forkert chart_type, NULL data)
- `spc_prepare_error`: data-prep fejl (dato-parsing, numerisk parsing)
- `spc_render_error`: BFHcharts-fejl under rendering
- `spc_cache_error`: cache-læs/skriv fejl

Alle klasser SHALL inherit fra `"spc_error"` og `"error"`.

#### Scenario: Ugyldig chart_type
- **WHEN** `validate_spc_request(..., chart_type = "invalid")` kaldes
- **THEN** funktionen kaster error med class `c("spc_input_error", "spc_error", "error", "condition")`
- **AND** error-message er dansk og brugervenlig

#### Scenario: UI-boundary fanger typed errors
- **WHEN** `mod_spc_chart_compute.R` fanger en error fra `compute_spc_results_bfh()`
- **THEN** den bruger `tryCatch(spc_input_error = ..., spc_render_error = ...)` for class-specifik håndtering
- **AND** bruger får dansk besked relevant for fejltypen

#### Scenario: Orkestrator bevarer NULL-returnering
- **WHEN** en typed error propagerer op til `compute_spc_results_bfh()`
- **THEN** orkestrator fanger den og returnerer `NULL` til caller (bagudkompatibilitet)
- **AND** logger fejlen struktureret via `log_error()`

### Requirement: Cache-state i environment

Alle mutable caches på package-level SHALL leve i en dedikeret environment (`cache_state`), ikke som `<-`-bindings der kræver `unlockBinding()`. Pakken SHALL NOT kalde `unlockBinding()`.

#### Scenario: R CMD check
- **WHEN** `R CMD check --as-cran` kører
- **THEN** INGEN warnings om `unlockBinding` eller `Namespace bindings lock`
- **AND** cache-statistik kan stadig opdateres under runtime

#### Scenario: Cache-stats opdateres
- **WHEN** `update_panel_stats(hits_delta = 1)` kaldes
- **THEN** `cache_state$panel_stats$hits` inkrementeres uden `unlockBinding`-kald
- **AND** opdateringen er tråd-sikker for Shiny's single-threaded event loop

### Requirement: safe_operation() kun i UI-boundaries

`safe_operation()` SHALL kun bruges i UI-boundary-kode (Shiny `mod_*_server.R`, `utils_server_*.R`). Domæne-helpers og rene beregningsfunktioner SHALL NOT wrappe forretningslogik i `safe_operation()`.

#### Scenario: Domæne-helper uden safe_operation
- **WHEN** `prepare_spc_data()` eller lignende domæne-helper kører
- **THEN** den kaster typed error ved fejl i stedet for at returnere fallback via `safe_operation()`

#### Scenario: UI-boundary med safe_operation
- **WHEN** en Shiny-observer kalder en domæne-funktion
- **THEN** `safe_operation()` eller `tryCatch(spc_error = ...)` wrapper kaldet for at vise brugervendt fejlbesked

### Requirement: Pipeline-helpers har S3-kontrakter

Hver pipeline-helper SHALL returnere et S3-objekt med dokumenteret struktur og class-attribut. Objekter SHALL være inspicerbare via `print()` og testbare via `expect_s3_class()`.

#### Scenario: validate_spc_request returnerer spc_request
- **WHEN** `validate_spc_request(...)` kaldes med gyldig input
- **THEN** returnerer objekt med class `c("spc_request", "list")`
- **AND** indeholder navngivne felter: `data`, `mapping`, `chart_type`, `options`

#### Scenario: prepare_spc_data returnerer spc_prepared
- **WHEN** `prepare_spc_data(request)` kaldes med gyldig `spc_request`
- **THEN** returnerer objekt med class `c("spc_prepared", "list")`
- **AND** indeholder parsed `data`, `axes_meta`, `filter_stats`

### Requirement: Public API uændret

`compute_spc_results_bfh()` SHALL bevare sin offentlige signatur og return-kontrakt efter refactor. Ingen caller-kode må kræve opdatering.

#### Scenario: Signatur bevaret
- **WHEN** refactor er merged
- **THEN** `formals(compute_spc_results_bfh)` er identisk med før refactor
- **AND** return-struktur indeholder samme top-level felter: `plot`, `metadata`, `cache_hit`

#### Scenario: Hybrid-arkitektur bevaret
- **WHEN** Anhøj-metadata ekstraheres
- **THEN** qicharts2 bruges fortsat til Anhøj-rules (ikke BFHcharts)
- **AND** BFHcharts bruges fortsat til plot-rendering (ikke qicharts2)

### Requirement: Anhøj-regel-derivation SHALL udføres via én pure funktion

Anhøj-regel-metadata (crossings, longest_run, signals) SHALL beregnes af én navngivet pure funktion `derive_anhoej_results(qic_data, chart_type, show_phases)` i `R/fct_spc_anhoej_derivation.R`. Denne funktion er eneste autoritative kilde; alle kaldere SHALL invokere den i stedet for at reimplementere logikken.

#### Scenario: Compute-observer beregner metadata

- **GIVEN** `mod_spc_chart_compute.R` skal udlede Anhøj-resultater
- **WHEN** observeren trigger ved ny qic-output
- **THEN** den kalder `derive_anhoej_results(qic_data, chart_type, show_phases)`
- **AND** bruger returvalue direkte uden yderligere reimplementation af run-length- eller crossings-logik

#### Scenario: Cache-aware observer beregner metadata

- **GIVEN** cache-aware observeren skal udlede Anhøj-resultater fra cached qic-output
- **WHEN** observer kører efter cache-hit
- **THEN** den kalder samme `derive_anhoej_results()` som compute-observeren
- **AND** resultater er identiske med compute-path for samme input

#### Scenario: Ingen duplikeret Anhøj-logik

- **WHEN** statisk audit scanner `R/` for run-length- eller crossings-beregning
- **THEN** den finder implementationen kun i `fct_spc_anhoej_derivation.R`
- **AND** andre filer bruger kun den pure funktion via import

### Requirement: derive_anhoej_results SHALL være Shiny-uafhængig

`derive_anhoej_results()` SHALL være ren funktion uden Shiny-imports, uden `app_state`-reference, uden reactiveValues-side-effects, og uden caching. Alle inputs passes som argumenter; alle outputs returneres i named list.

#### Scenario: Unit-test uden Shiny-context

- **GIVEN** en test eksekveres i isoleret R-session uden `shiny`-load
- **WHEN** testen kalder `derive_anhoej_results(test_data, "run", FALSE)`
- **THEN** funktionen returnerer struktureret metadata
- **AND** ingen fejl om manglende `app_state`, `session`, eller reactive context

#### Scenario: Bruger i parallel worker

- **GIVEN** fremtidig parallel-computation-use-case
- **WHEN** koden kalder `derive_anhoej_results()` i en `future()`-context
- **THEN** funktionen fungerer uden at kræve Shiny-main-thread

