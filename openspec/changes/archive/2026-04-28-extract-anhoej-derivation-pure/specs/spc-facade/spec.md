## ADDED Requirements

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
