## MODIFIED Requirements

### Requirement: File Size and Module Clarity

Large R source files (>1200 LOC) SHALL be split into smaller, focused modules (<500 LOC each) to improve maintainability, testability, and code navigation.

#### Scenario: SPC service refactored
- **WHEN** Phase 2a completes
- **THEN** fct_spc_bfh_service.R (2200 LOC) is split into:
  - fct_spc_bfh_facade.R (200 LOC) - Main orchestrator with compute_spc_results_bfh()
  - fct_spc_bfh_params.R (500 LOC) - Parameter transformation logic
  - fct_spc_bfh_invocation.R (300 LOC) - BFHcharts API invocation
  - fct_spc_bfh_output.R (400 LOC) - Output processing and annotations
  - fct_spc_bfh_signals.R (300 LOC) - Anhøj signal calculation
- **AND** public API remains unchanged (compute_spc_results_bfh still exported)

#### Scenario: Export module refactored
- **WHEN** Phase 2b completes
- **THEN** mod_export_server.R (1335 LOC) is split into:
  - mod_export_server.R (400 LOC) - Main module orchestrator
  - mod_export_analysis.R (150 LOC) - Auto-analysis generation
  - mod_export_ai.R (300 LOC) - AI suggestion logic
  - mod_export_download.R (200 LOC) - Format-specific download handlers
  - utils_export_helpers.R (100 LOC) - Shared utility functions
- **AND** public API remains unchanged (mod_export_ui, mod_export_server still exported)

#### Scenario: Chart visualization module refactored
- **WHEN** Phase 2c completes
- **THEN** mod_spc_chart_server.R (1330 LOC) is split into:
  - mod_spc_chart_server.R (250 LOC) - Main orchestrator
  - mod_spc_chart_state.R (200 LOC) - Data reactives and state
  - mod_spc_chart_config.R (200 LOC) - Configuration building
  - mod_spc_chart_compute.R (300 LOC) - SPC computation pipeline
  - mod_spc_chart_observers.R (150 LOC) - Observers and side effects
  - mod_spc_chart_ui.R (350 LOC) - Output rendering
- **AND** reactive dependencies are preserved (no race conditions introduced)
- **AND** public API remains unchanged (visualizationModuleServer still exported)

#### Scenario: Event system refactored
- **WHEN** Phase 2d completes
- **THEN** utils_server_event_listeners.R (1791 LOC) is split into:
  - utils_server_event_listeners.R (100 LOC) - Main orchestrator
  - utils_server_events_data.R (100 LOC) - Data lifecycle events
  - utils_server_events_autodetect.R (120 LOC) - Auto-detection events
  - utils_server_events_ui.R (150 LOC) - UI synchronization events
  - utils_server_events_navigation.R (300 LOC) - Navigation events
  - utils_server_events_chart.R (600 LOC) - Chart type and column events
  - utils_server_wizard_gates.R (150 LOC) - Wizard flow management
  - utils_server_paste_data.R (200 LOC) - Data paste handlers
- **AND** event ordering and observer priorities are preserved
- **AND** public API remains unchanged (setup_event_listeners still exported)

### Requirement: Code Navigation and Testability

Split modules SHALL be independently testable with clear responsibility boundaries.

#### Scenario: Module dependencies mapped
- **WHEN** files are split
- **THEN** imports are updated in all dependent files
- **AND** circular dependencies are eliminated or documented
- **AND** module interfaces are clear (input/output contracts)

#### Scenario: Tests updated for split modules
- **WHEN** code is split
- **THEN** existing tests continue to pass
- **AND** new test files are created for each module if needed
- **AND** test organization mirrors code organization

#### Scenario: Performance maintained
- **WHEN** Phase 2 completes
- **THEN** startup time remains <100ms
- **AND** chart rendering time remains <500ms for typical datasets
- **AND** memory footprint unchanged (no new object allocations)

## Naming Conventions

Files created during refactoring follow existing biSPCharts patterns:
- `fct_*.R` - Business logic factories
- `mod_*.R` - Shiny modules (with _ui and _server variants)
- `utils_*.R` - Utility functions grouped by domain
- `config_*.R` - Configuration and constants

All imports in dependent files are updated to reflect new file locations. NAMESPACE is regenerated via `devtools::document()`.
