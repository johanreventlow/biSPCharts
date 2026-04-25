# error-handling Specification

## Purpose
TBD - created by archiving change harden-csv-parse-error-reporting. Update Purpose after archive.
## Requirements
### Requirement: Fallback-kæder SHALL opsamle fejl fra alle forsøg

Når en operation forsøger flere strategier i rækkefølge (fx CSV-parsing med forskellige delimiters), SHALL hvert forsøg's fejl opsamles og være tilgængeligt i fejlrapportering hvis alle strategier fejler. `error = function(e) NULL` uden sideløbende logging er NOT tilladt i fallback-kæder.

#### Scenario: CSV-parse med alle tre strategier fejlende

- **GIVEN** en CSV-fil som ikke kan parses af `read_csv2`, `read_delim` eller `read_csv`
- **WHEN** `fct_file_operations.R` forsøger at parse filen
- **THEN** fejlbeskeden til brugeren indeholder navnene på alle tre strategier og en kort beskrivelse af hver fejl
- **AND** struktureret log-entry med `log_warn(.context = "FILE_UPLOAD", details = list(attempts = <list>, errors = <named_list>))` er skrevet
- **AND** brugeren ser dansk besked med konkrete hints (encoding, delimiter)

#### Scenario: Første strategi succes

- **GIVEN** en CSV-fil som `read_csv2` kan læse
- **WHEN** parsing kører
- **THEN** `read_csv2`-resultatet returneres
- **AND** ingen efterfølgende strategier forsøges
- **AND** ingen fejl-logs genereres

### Requirement: Silent-failure-mønstre SHALL dokumenteres eller erstattes

Alle forekomster af `tryCatch(..., error = function(e) NULL)` i `R/` SHALL enten (a) have en sideløbende `log_debug(conditionMessage(e), .context = ..., details = ...)`-kald, (b) være erstattet med `try_with_diagnostics()` eller ækvivalent, eller (c) have en inline-kommentar der eksplicit begrunder hvorfor silent-fail er korrekt adfærd.

#### Scenario: Audit finder ubeskyttet swallowed error

- **WHEN** lint-check kører mod `R/`
- **AND** finder `error = function(e) NULL` uden omkringliggende log-kald eller `# nolint`-kommentar
- **THEN** linten fejler PRen
- **AND** besked angiver præcis fil + linje + anbefalet mønster

#### Scenario: Legitim silent-fail med begrundelse

- **GIVEN** en defensiv læsning af `session$token` der kan være `NULL` før session-init
- **WHEN** koden har `# nolint: swallowed_error_linter # Begrundelse: session_token kan være NULL ved tidlig init`
- **THEN** linten accepterer mønsteret
- **AND** kommentaren dokumenterer kontekst for fremtidige reviewers

### Requirement: `safe_operation()` SHALL kun bruges til ikke-essentiel kode

Helper-funktionen `safe_operation(name, expr)` SHALL kun bruges omkring kode hvor fejl IKKE skal stoppe den igangværende user-flow. Typiske legitime brug: UI-refresh, analytics-emit, optional post-processing, cache-write. Ulovlig brug: validation, core-data-processing, state-transitions der påvirker correctness.

#### Scenario: Legitim brug

- **GIVEN** kode der refresher UI-status-ikoner efter data-load
- **WHEN** refresh mislykkes pga. manglende output-element
- **THEN** `safe_operation()` fanger fejlen, logger den, og user-flow fortsætter uforstyrret

#### Scenario: Anti-pattern

- **GIVEN** kode der wrapper validering af upload-fil i `safe_operation()`
- **WHEN** validering fejler
- **THEN** koden tillader upload at fortsætte med korrupt state
- **AND** audit SHALL flagge dette som anti-pattern
- **AND** refaktorér til eksplicit `tryCatch()` med brugervendt fejl

### Requirement: Typed Errors for Domænelogik

Domænelogik (SPC-beregning, file-parsing, autodetect) SHALL kaste typed errors via `rlang::abort()` eller `structure(...)` med klasse-hierarki der inkluderer et domænespecifikt basis-klassenavn (`spc_error`, `file_error`, `autodetect_error`). Generic `stop()` uden klasse er NOT tilladt.

#### Scenario: qicharts2 ikke installeret

- **WHEN** `require_qicharts2()` kaldes og pakken mangler
- **THEN** fejl kastes med klasse `c("spc_dependency_error", "spc_error", "error", "condition")`
- **AND** observers kan fange og håndtere typed fejl specifikt

#### Scenario: Generisk stop()

- **WHEN** audit scanner domænelogik for `stop("...")` uden klasse
- **THEN** linten flagger forekomsten
- **AND** fejlen SHALL refaktoreres til typed error

