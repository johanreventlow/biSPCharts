## REMOVED Requirements

### Requirement: Plot Optimization Layer
**Reason**: `utils_server_plot_optimization.R` og alle 16 funktioner er aldrig kaldt. Applikationen bruger `generateSPCPlot` direkte.
**Migration**: Ingen — koden er ubrugt.

#### Scenario: Fjernelse påvirker ikke plot-generering
- **WHEN** `utils_server_plot_optimization.R` fjernes
- **THEN** alle eksisterende plot-tests består uændret

### Requirement: Dependency Injection Framework
**Reason**: `utils_dependency_injection.R` og alle 24 funktioner er aldrig kaldt. Dependencies passes direkte som argumenter.
**Migration**: Ingen — koden er ubrugt.

#### Scenario: Fjernelse påvirker ikke app-initialisering
- **WHEN** `utils_dependency_injection.R` fjernes
- **THEN** app starter normalt og alle tests består

### Requirement: Validation Guards Library
**Reason**: `utils_validation_guards.R` og alle 7 funktioner er aldrig kaldt. `safe_operation()` og `req()` bruges i stedet.
**Migration**: Ingen — koden er ubrugt.

#### Scenario: Fjernelse påvirker ikke validering
- **WHEN** `utils_validation_guards.R` fjernes
- **THEN** al input-validering fungerer via eksisterende `safe_operation()` og `req()`

### Requirement: Config Consolidation Registry
**Reason**: `utils_config_consolidation.R` og alle 3 funktioner er aldrig kaldt. Config tilgås direkte.
**Migration**: Ingen — koden er ubrugt.

#### Scenario: Fjernelse påvirker ikke konfiguration
- **WHEN** `utils_config_consolidation.R` fjernes
- **THEN** alle config-værdier tilgås uændret via direkte konstanter

### Requirement: UI Component Factories
**Reason**: `utils_ui_ui_components.R` (6 funktioner) og `utils_ui_form_helpers.R` (3 funktioner) er aldrig kaldt. UI bygges direkte.
**Migration**: Ingen — koden er ubrugt.

#### Scenario: Fjernelse påvirker ikke UI
- **WHEN** begge filer fjernes
- **THEN** alle UI-elementer renderes korrekt

### Requirement: Chart Module Service Layer
**Reason**: `utils_chart_module_helpers.R` og alle 4 factory-funktioner er aldrig kaldt.
**Migration**: Ingen — koden er ubrugt.

#### Scenario: Fjernelse påvirker ikke chart-modulet
- **WHEN** `utils_chart_module_helpers.R` fjernes
- **THEN** `mod_spc_chart_server.R` fungerer uændret

### Requirement: Legacy File IO
**Reason**: `fct_file_io.R` (`readCSVFile`, `readExcelFile`) er superseded af `fct_file_operations.R`.
**Migration**: Ingen — koden er ubrugt i produktion.

#### Scenario: Fjernelse påvirker ikke fil-import
- **WHEN** `fct_file_io.R` fjernes
- **THEN** CSV/Excel import fungerer via `fct_file_operations.R`

### Requirement: App Dependencies Manager
**Reason**: `app_dependencies.R` og alle 8 funktioner er aldrig kaldt. Packages loades via `library()`.
**Migration**: Ingen — koden er ubrugt.

#### Scenario: Fjernelse påvirker ikke package loading
- **WHEN** `app_dependencies.R` fjernes
- **THEN** alle packages loades normalt via `global.R` og `zzz.R`

### Requirement: Plot Diff System
**Reason**: `utils_plot_diff.R` og alle 6 funktioner er aldrig kaldt. Plots regenereres fuldt via `bindCache()`.
**Migration**: Ingen — koden er ubrugt.

#### Scenario: Fjernelse påvirker ikke plot-opdateringer
- **WHEN** `utils_plot_diff.R` fjernes
- **THEN** plot-caching fungerer uændret via `bindCache()`

### Requirement: Ghost UI Input References
**Reason**: Server-kode refererer til 5 input IDs (`indicator_title`, `indicator_description`, `unit_select`, `unit_custom`, `unit_type`) og 3 welcome page buttons der ikke eksisterer i UI.
**Migration**: Fjern server-side references og observers.

#### Scenario: Fjernelse af ghost inputs forårsager ingen fejl
- **WHEN** alle ghost input references fjernes fra server-kode
- **THEN** ingen `NULL` input-evalueringer forekommer og alle tests består

### Requirement: Orphaned Event Bus Entries
**Reason**: `form_update_needed`, `column_mapping_modal_opened`, `column_mapping_modal_closed` emittes men har ingen listeners.
**Migration**: Fjern events og tilhørende emit-funktioner.

#### Scenario: Fjernelse af orphaned events påvirker ikke event-systemet
- **WHEN** de 3 orphaned events fjernes
- **THEN** alle aktive event-listeners fungerer uændret

### Requirement: Debug CSS and Orphaned Assets
**Reason**: `plot-debug.css` anvender CSS-klasser der ikke er tildelt. `bfh_frise.png` og `RegionH_hospital.png` er ikke refereret.
**Migration**: Fjern filer og references.

#### Scenario: Fjernelse af debug assets påvirker ikke UI
- **WHEN** debug CSS og orphaned billeder fjernes
- **THEN** app UI renderes identisk
