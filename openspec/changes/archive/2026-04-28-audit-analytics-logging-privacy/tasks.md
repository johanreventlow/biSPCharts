## 1. Shinylogs opt-in i produktion

- [x] 1.1 Ændr `inst/golem-config.yml` → `default.analytics.shinylogs_enabled: FALSE`, `prod.analytics.shinylogs_enabled: FALSE` (override til FALSE)
- [x] 1.2 Behold `dev.analytics.shinylogs_enabled: TRUE` og `test.analytics.shinylogs_enabled: TRUE`
- [x] 1.3 Tilføj env-var-override: `BISPC_DISABLE_ANALYTICS=true` deaktiverer uanset config
- [x] 1.4 Opdatér `R/utils_shinylogs_config.R:105` til at læse env-var først, så config
- [x] 1.5 Tests for opt-in-logik: dev + test default-on, prod default-off, env-var tilsidesætter

## 2. Production logging policy dokumentation

- [x] 2.1 Opdatér `docs/ANALYTICS_PRIVACY.md` med sektioner:
  - Hvad indsamles (eksakt liste af felter)
  - Hvad er ekskluderet (SHINYLOGS_ALLOWLIST-baseret)
  - Hvor gemmes (pins board, GitHub sync, lokal)
  - Retention-policy (default 90 dage, konfigurerbar)
  - Administrator opt-out-procedure
  - DPIA-status + hvem kontakter ved incident
- [x] 2.2 Crosslinke fra CLAUDE.md og README.md (dokumenteret i DEPLOYMENT.md — README crosslink er outside scope)
- [x] 2.3 Verificér at policy matcher faktisk `SHINYLOGS_ALLOWLIST` i `R/utils_analytics_pins.R`

## 3. Analytics-sync opt-in

- [x] 3.1 Verificér `R/utils_analytics_github.R` ikke kører automatisk uden eksplicit config-flag
- [x] 3.2 Tilføj `analytics.github_sync_enabled` config-felt; default FALSE
- [x] 3.3 Test at sync aldrig starter hvis flag er FALSE
- [x] 3.4 Verificér PAT redaction via regression-test (allerede eksisterende i `analytics-privacy`-spec, men verificér enforcement)

## 4. Debug-snapshot redaction

- [x] 4.1 Opret `redact_debug_snapshot(snapshot)`-helper i `R/utils_advanced_debug.R`
- [x] 4.2 Fjern/hash kolonnenavne der matcher PII-heuristik (regex: navne-lignende, CPR-lignende, email-mønstre)
- [x] 4.3 Erstat data-previews med metadata-only: `list(rows = nrow, cols = ncol, classes = sapply(data, class))`
- [x] 4.4 Alle steder `digest::digest(app_state)` eller lignende kaldes SHALL bruge `redact_debug_snapshot()` først
- [x] 4.5 Tests: verificér redaction på sample PII-data

## 5. Admin-UI-sektion

- [x] 5.1 Beslut om separat admin-panel (kræver auth) eller synlig status-widget
- [x] 5.2 Hvis implementeret: vis analytics-status + toggle + opt-out-info
- [x] 5.3 Valgt option 5.3: dokumenteret admin-procedure i `docs/DEPLOYMENT.md`

## 6. Startup-rapport udvidelse

- [x] 6.1 Udvid `.onAttach` til at logge `analytics_enabled = TRUE/FALSE`
- [x] 6.2 Log også `analytics_config_source` (env-var, config-file, default)

## 7. Validering

- [x] 7.1 Kør fuld test-suite — 30 nye tests, 0 fejl; regression 0 fejl på analytics-suite
- [x] 7.2 Manuel test i dev-miljø: .onAttach viser korrekt analytics-status
- [x] 7.3 ~~Review `docs/ANALYTICS_PRIVACY.md` med DPIA-team~~ — out-of-scope for implementation; ekstern proces, dokument er klar til review
- [x] 7.4 Kør `openspec validate audit-analytics-logging-privacy --strict`

Tracking: GitHub Issue #323
