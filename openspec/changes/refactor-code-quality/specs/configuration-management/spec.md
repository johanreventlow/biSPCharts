## ADDED Requirements

### Requirement: Unified Logging Configuration

The system SHALL provide a single, unified source of truth for logging level configuration with clear precedence rules.

#### Scenario: Logging level configuration via environment variable
- **WHEN** user sets `Sys.setenv("SPC_LOG_LEVEL", "DEBUG")`
- **THEN** logging level is set to DEBUG (highest priority)
- **AND** this override persists for the session

#### Scenario: Logging level configuration via Golem config YAML
- **WHEN** Golem config YAML specifies `logging.level: "INFO"`
- **THEN** logging level is set to INFO (if no env var override)
- **AND** configuration is read at app startup

#### Scenario: Logging level default
- **WHEN** no environment variable or YAML config is set
- **THEN** logging level defaults to "INFO" (production default)

#### Scenario: Precedence is documented
- **WHEN** user needs to customize logging
- **THEN** documentation clearly shows: Environment Variable > YAML > Default
- **AND** examples show how to override at each level

### Requirement: Performance Constants Accessor Functions

The system SHALL provide getter functions for all performance-related constants, allowing future runtime configuration.

#### Scenario: Debounce delay accessor
- **WHEN** code calls `get_debounce_delay("input_change")`
- **THEN** the system returns debounce delay value (default: 800ms)
- **AND** this can be overridden in future without code changes

#### Scenario: Operation timeout accessor
- **WHEN** code calls `get_operation_timeout("chart_render")`
- **THEN** the system returns timeout value (default: varies by operation)
- **AND** this can be configured per-environment (dev vs prod)

#### Scenario: Performance threshold accessor
- **WHEN** code calls `get_performance_threshold("reactive_warning")`
- **THEN** the system returns threshold value
- **AND** this value is used for performance monitoring

#### Scenario: Cache configuration accessor
- **WHEN** code calls `get_cache_config("hospital_branding")`
- **THEN** the system returns TTL and size limits for cache
- **AND** configuration is documented with defaults

### Requirement: UI Constants Accessor Functions

The system SHALL provide getter functions for all UI-related constants, allowing future responsive design configuration.

#### Scenario: UI column width accessor
- **WHEN** code calls `get_ui_column_width("main")`
- **THEN** the system returns column width (default: 12 for Bootstrap grid)
- **AND** this can be responsive in future (e.g., based on screen size)

#### Scenario: UI height accessor
- **WHEN** code calls `get_ui_height("plot")`
- **THEN** the system returns height value (default: 500px)
- **AND** this can be configured per-section

#### Scenario: UI style accessor
- **WHEN** code calls `get_ui_style("header")`
- **THEN** the system returns styling object (colors, fonts, spacing)
- **AND** this supports hospital theming

### Requirement: Configuration Documentation

The system SHALL provide comprehensive documentation of all configuration layers and how they interact.

#### Scenario: Configuration precedence documented
- **WHEN** user reads docs/CONFIGURATION.md
- **THEN** all 8 configuration layers are documented with priority order
- **AND** examples show how to use each layer

#### Scenario: Environment variables documented
- **WHEN** user checks documentation
- **THEN** all environment variables are listed with purpose, default, and examples
- **AND** includes: GOOGLE_API_KEY, GEMINI_API_KEY, SPC_LOG_LEVEL, etc.

#### Scenario: Golem configuration documented
- **WHEN** user examines inst/golem-config.yml
- **THEN** configuration file is documented with all sections
- **AND** default values and overrides are explained

#### Scenario: Runtime override examples provided
- **WHEN** user needs to customize at runtime
- **THEN** documentation shows how to:
  - Override via environment variables
  - Override via Golem config YAML
  - Override via options()/getOption()
  - Override via function defaults

## MODIFIED Requirements

### Requirement: Configuration Access Pattern

All configuration access SHALL use centralized getter functions instead of direct constant/env var references.

#### Scenario: Constants accessed via getters
- **WHEN** code needs a configuration value
- **THEN** it calls appropriate getter function (not direct constant access)
- **EXAMPLES:**
  - `get_debounce_delay()` instead of `DEBOUNCE_DELAYS$input_change`
  - `get_operation_timeout()` instead of `OPERATION_TIMEOUTS$chart_render`
  - `get_effective_log_level()` instead of `Sys.getenv("SPC_LOG_LEVEL", "INFO")`

#### Scenario: Getter functions provide fallback chain
- **WHEN** getter function is called
- **THEN** it attempts to resolve value in priority order:
  - Check Golem config YAML (if structured)
  - Check environment variable (if applicable)
  - Return constant default value
- **AND** invalid or missing values return documented default

#### Scenario: Future YAML migration
- **WHEN** YAML migration is needed (Phase N+1)
- **THEN** getter functions can be updated to read from YAML first
- **AND** no calling code changes required (interface preserved)

## Notes

Refactoring is **additive only** - no removal of existing getters or breaking changes to configuration API. All old constants remain accessible during transition period.

Future considerations:
- **Phase N+1:** Full migration of performance constants to YAML
- **Phase N+2:** Responsive UI configuration via reactiveValues
- **Phase N+3:** Dynamic configuration reload without app restart
