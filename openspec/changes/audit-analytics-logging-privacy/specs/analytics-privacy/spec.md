## ADDED Requirements

### Requirement: Shinylogs SHALL være opt-in i produktion

Shinylogs-analytics SHALL være deaktiveret som default i produktions-miljø (`GOLEM_CONFIG_ACTIVE = "prod"`). Aktivering SHALL kræve eksplicit config-override eller env-var. Dev- og test-miljøer kan beholde default-on for debug-værdi.

#### Scenario: Produktions-start uden eksplicit opt-in

- **GIVEN** pakken starter med `GOLEM_CONFIG_ACTIVE = "prod"` og standard-config
- **WHEN** `utils_shinylogs_config.R` initialiseres
- **THEN** shinylogs ER NOT aktiveret
- **AND** log-linje på INFO-niveau rapporterer `analytics_enabled = FALSE, reason = "prod-default"`

#### Scenario: Administrator opt-in via config

- **GIVEN** administrator har sat `prod.analytics.shinylogs_enabled = TRUE` i `inst/golem-config.yml` eller via env-override
- **WHEN** pakken starter
- **THEN** shinylogs ER aktiveret
- **AND** log-linje rapporterer `analytics_enabled = TRUE, reason = "config-override"`

#### Scenario: Global env-var kill-switch

- **GIVEN** env-var `BISPC_DISABLE_ANALYTICS=true` er sat
- **WHEN** pakken starter — uanset GOLEM_CONFIG_ACTIVE eller config-fil
- **THEN** shinylogs ER NOT aktiveret
- **AND** log rapporterer `analytics_enabled = FALSE, reason = "env-var kill-switch"`

### Requirement: Analytics-indsamling SHALL være dokumenteret i ANALYTICS_PRIVACY.md

`docs/ANALYTICS_PRIVACY.md` SHALL være autoritativ kilde for hvad analytics-modulet indsamler. Dokumentet SHALL synkroniseres med `SHINYLOGS_ALLOWLIST` i `R/utils_analytics_pins.R` — enhver ændring i koden SHALL reflekteres i dokumentet i samme PR.

#### Scenario: Dokument matcher kode

- **WHEN** PR ændrer `SHINYLOGS_ALLOWLIST`
- **THEN** PR-check verificerer at `docs/ANALYTICS_PRIVACY.md` også er opdateret
- **AND** hvis ikke: PR fejler med "ANALYTICS_PRIVACY.md ud af sync med allowlist"

#### Scenario: Udvikler kan finde policy

- **GIVEN** en ny udvikler søger efter "hvad indsamler analytics"
- **WHEN** de åbner `docs/ANALYTICS_PRIVACY.md`
- **THEN** dokumentet indeholder sektioner: included-fields, excluded-fields, storage, retention, opt-out, DPIA-contact

### Requirement: Analytics GitHub-sync SHALL være opt-in

GitHub-sync af analytics-logs SHALL kræve eksplicit config-flag `analytics.github_sync_enabled = TRUE`. Default SHALL være FALSE. Aktivering SHALL også kræve at `ANALYTICS_GITHUB_PAT`-env-var er sat.

#### Scenario: Default-deployment uden PAT

- **GIVEN** administrator deployer uden at sætte GitHub-sync-flag
- **WHEN** analytics-aggregation kører
- **THEN** data gemmes lokalt eller i pins board
- **AND** ingen forsøg på GitHub-push foretages

#### Scenario: Opt-in men PAT mangler

- **GIVEN** `github_sync_enabled = TRUE` men `ANALYTICS_GITHUB_PAT` env-var er tom
- **WHEN** sync-job kører
- **THEN** sync afbrydes gracefully med log `WARN: analytics_github_sync_enabled=TRUE but PAT missing`
- **AND** ingen fejlende requests sendes

### Requirement: Debug-snapshots SHALL redacte PII før hash/log

Funktioner der producerer debug-snapshots af `app_state` (fx i `R/utils_advanced_debug.R`) SHALL bruge `redact_debug_snapshot()`-helper der fjerner eller hasher:
- Kolonnenavne der matcher PII-heuristik (navne, CPR-nummer, email)
- Data-previews (bevarer kun metadata: rows, cols, classes)
- Brugerinput-felter fra UI-state

#### Scenario: app_state med PII-kolonnenavn

- **GIVEN** `app_state$data$current_data` har kolonnenavn "Patient_navn"
- **WHEN** `debug_state_snapshot(app_state)` kaldes
- **THEN** output indeholder `columns = c("[REDACTED_PII]", "Dato", "Værdi")` eller hashet-version
- **AND** ingen rå patient-navn eksponeres i log

#### Scenario: Data-preview skjules

- **GIVEN** debug-snapshot trigger på data med 1000 rækker
- **WHEN** snapshot serialiseres
- **THEN** output indeholder metadata (nrow=1000, ncol=5, classes=...) men ikke data-preview
- **AND** hash-sum beregnes over metadata, ikke rå indhold
