## 1. Shinylogs opt-in i produktion

- [ ] 1.1 Ændr `inst/golem-config.yml` → `default.analytics.shinylogs_enabled: FALSE`, `prod.analytics.shinylogs_enabled: FALSE` (override til FALSE)
- [ ] 1.2 Behold `dev.analytics.shinylogs_enabled: TRUE` og `test.analytics.shinylogs_enabled: TRUE`
- [ ] 1.3 Tilføj env-var-override: `BISPC_DISABLE_ANALYTICS=true` deaktiverer uanset config
- [ ] 1.4 Opdatér `R/utils_shinylogs_config.R:105` til at læse env-var først, så config
- [ ] 1.5 Tests for opt-in-logik: dev + test default-on, prod default-off, env-var tilsidesætter

## 2. Production logging policy dokumentation

- [ ] 2.1 Opdatér `docs/ANALYTICS_PRIVACY.md` med sektioner:
  - Hvad indsamles (eksakt liste af felter)
  - Hvad er ekskluderet (SHINYLOGS_ALLOWLIST-baseret)
  - Hvor gemmes (pins board, GitHub sync, lokal)
  - Retention-policy (default 90 dage, konfigurerbar)
  - Administrator opt-out-procedure
  - DPIA-status + hvem kontakter ved incident
- [ ] 2.2 Crosslinke fra CLAUDE.md og README.md
- [ ] 2.3 Verificér at policy matcher faktisk `SHINYLOGS_ALLOWLIST` i `R/utils_analytics_pins.R`

## 3. Analytics-sync opt-in

- [ ] 3.1 Verificér `R/utils_analytics_github.R` ikke kører automatisk uden eksplicit config-flag
- [ ] 3.2 Tilføj `analytics.github_sync_enabled` config-felt; default FALSE
- [ ] 3.3 Test at sync aldrig starter hvis flag er FALSE
- [ ] 3.4 Verificér PAT redaction via regression-test (allerede eksisterende i `analytics-privacy`-spec, men verificér enforcement)

## 4. Debug-snapshot redaction

- [ ] 4.1 Opret `redact_debug_snapshot(snapshot)`-helper i `R/utils_advanced_debug.R`
- [ ] 4.2 Fjern/hash kolonnenavne der matcher PII-heuristik (regex: navne-lignende, CPR-lignende, email-mønstre)
- [ ] 4.3 Erstat data-previews med metadata-only: `list(rows = nrow, cols = ncol, classes = sapply(data, class))`
- [ ] 4.4 Alle steder `digest::digest(app_state)` eller lignende kaldes SHALL bruge `redact_debug_snapshot()` først
- [ ] 4.5 Tests: verificér redaction på sample PII-data

## 5. Admin-UI-sektion

- [ ] 5.1 Beslut om separat admin-panel (kræver auth) eller synlig status-widget
- [ ] 5.2 Hvis implementeret: vis analytics-status + toggle + opt-out-info
- [ ] 5.3 Hvis ikke implementeret: dokumentér admin-procedure i DEPLOYMENT_GUIDE.md

## 6. Startup-rapport udvidelse

- [ ] 6.1 Udvid `.onAttach` (fra `fix-dependency-namespace-guards`) til at logge `analytics_enabled = TRUE/FALSE` på INFO-niveau
- [ ] 6.2 Log også `analytics_config_source` (env-var, config-file, default)

## 7. Validering

- [ ] 7.1 Kør fuld test-suite
- [ ] 7.2 Manuel test i dev-miljø: verificér shinylogs disable med env-var
- [ ] 7.3 Review `docs/ANALYTICS_PRIVACY.md` med DPIA-team hvis relevant
- [ ] 7.4 Kør `openspec validate audit-analytics-logging-privacy --strict`

Tracking: GitHub Issue #323
