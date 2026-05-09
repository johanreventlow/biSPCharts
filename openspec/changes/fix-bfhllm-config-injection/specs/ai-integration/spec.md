## ADDED Requirements

### Requirement: BFHllm SHALL konfigureres med biSPCharts aktive AI-config ved app-startup

biSPCharts SHALL kalde `initialize_bfhllm(get_ai_config())` under app-startup (efter `configure_app_environment()`) for at sikre BFHllm bruger biSPCharts konfigurerede model, timeout og max_response_chars i stedet for ellmer environment-defaults. Init-call MUST udføres FØR første reactive observer registreres for at undgå race-condition mellem AI-button-state-init og config-injection.

#### Scenario: Production-startup applier korrekt config

- **GIVEN** app startes med `GOLEM_CONFIG_ACTIVE=production`
- **WHEN** `run_app()` har gennemført startup
- **THEN** `BFHllm::bfhllm_get_config()$timeout_seconds` returnerer `10` (prod-profile-værdi)
- **AND** `BFHllm::bfhllm_get_config()$model` følger BFHllm's default (Gemini 3.1 Flash-Lite — biSPCharts override'er ej model med mindre eksplicit `model:` er sat i golem-config.yml)

#### Scenario: Development-startup applier dev-overrides

- **GIVEN** app startes med `GOLEM_CONFIG_ACTIVE=development`
- **WHEN** `run_app()` har gennemført startup
- **THEN** `BFHllm::bfhllm_get_config()$timeout_seconds` returnerer `15` (dev-profile-værdi)

#### Scenario: BFHllm utilgængelig degraderes graciously

- **GIVEN** BFHllm pakken er ikke installeret
- **WHEN** `run_app()` startes
- **THEN** app startes uden crash
- **AND** structured log advarer om manglende BFHllm
- **AND** AI-features er deaktiveret (button disabled i UI)

### Requirement: AI-config helpers SHALL læse aktiv YAML-profile

`get_ai_config()` og `get_rag_config()` SHALL bruge `get_golem_config("ai")` mønsteret (som `get_session_config()`) i stedet for `golem::get_golem_options("ai")` som kun returnerer runtime-options. Profile-specifikke YAML-overrides MUST respekteres.

#### Scenario: Profile-specific timeout-override respekteres

- **GIVEN** `inst/golem-config.yml` har `ai.timeout_seconds: 15` i `development`-profile og `10` i `production`-profile
- **WHEN** `GOLEM_CONFIG_ACTIVE=development` og `get_ai_config()` kaldes
- **THEN** returnerer `timeout_seconds = 15`
- **WHEN** `GOLEM_CONFIG_ACTIVE=production` og `get_ai_config()` kaldes
- **THEN** returnerer `timeout_seconds = 10`

#### Scenario: Fallback-defaults bevares for tests uden golem-context

- **GIVEN** test-context hvor `get_golem_config()` fejler eller returnerer NULL
- **WHEN** `get_ai_config()` kaldes
- **THEN** returnerer hardcoded sane defaults uden at kaste fejl
- **AND** structured log advarer om fallback-mode

### Requirement: Integration-test SHALL verificere config-pipeline

Test-suiten SHALL inkludere en integration-test der starter app under begge profiler og asserter at `BFHllm::bfhllm_get_config()` reflekterer biSPCharts aktive config. Testen MUST fejle hvis `get_ai_config()` returnerer config der divergerer fra `BFHllm::bfhllm_get_config()` efter `initialize_bfhllm()`-kald.

#### Scenario: Test-suite fanger config-injection-regression

- **GIVEN** udvikler ændrer `get_ai_config()` til at returnere forkert timeout
- **WHEN** `testthat::test_file('tests/testthat/test-bfhllm-config-injection.R')` køres
- **THEN** test fejler med besked om config-mismatch
- **AND** udvikler informeres om profile-override-pattern
