## Why

Codex-review (2026-04-24) flagede flere policy-huller omkring logging og analytics: (1) Shinylogs er default-enabled (`R/utils_shinylogs_config.R:105`), og selvom den filtrerer store inputs som `main_data_table` og localStorage-payloads, er der ingen eksplicit produktions-policy der dokumenterer præcis hvad der indsamles, hvor det gemmes, og hvordan det opt-out'es. (2) Analytics GitHub sync (`R/utils_analytics_github.R:96`) bruger PAT-in-URL-mønstret med redaction på fejl — sikkert, men ikke reviewet mod nyeste practices. (3) Debug-snapshot-funktionalitet (`R/utils_advanced_debug.R:170`) kan hashe hele app_state inkl. kolonnenavne og state-summaries — potentiel metadata-lækage. Disse items hører under eksisterende `analytics-privacy`-capability og bør opdateres med klarere policy + opt-in-model.

## What Changes

- **Shinylogs opt-in**: ændr default fra `enabled = TRUE` til `enabled = FALSE` i produktions-config (`inst/golem-config.yml > prod > analytics.shinylogs_enabled`). Dev og test beholder `TRUE` for debug-værdi.
- **Production logging policy**: dokumentér i `docs/ANALYTICS_PRIVACY.md`:
  - Hvad shinylogs indsamler præcis (input-events, timestamps, session-ids hashede)
  - Hvad er ekskluderet (main_data_table, localStorage-payloads, passwords, tokens)
  - Hvor data gemmes (pins board, GitHub sync eller lokal)
  - Hvordan administrator kan deaktivere: env-var `BISPC_DISABLE_ANALYTICS=true` ELLER config-override
  - Retention-policy (hvor længe gemmes data)
- **Analytics GitHub sync review**: verificér `R/utils_analytics_github.R:96` PAT-håndtering:
  - PAT gemmes aldrig i kode eller config
  - URL-redaction test-dækket for fejl-paths (eksisterende `### Requirement: PAT redaction i fejl-paths` — verificér stadig håndhævet)
  - Tilføj ny requirement: analytics-sync SHALL være opt-in via eksplicit config-flag, ikke default-on
- **Debug-snapshot policy**: Tilføj `redact_debug_snapshot()`-helper der fjerner:
  - Kolonnenavne der matcher PII-heuristik (navne-lignende strings)
  - Data-previews (kun metadata bevares: rows, cols, classes)
  - Dokumentér i ANALYTICS_PRIVACY.md
- **Administrator-kontrol**: tilføj Shiny UI-sektion (admin-only) der viser "Analytics-status: enabled/disabled" med toggle.
- **Startup-rapport**: udvid `.onAttach` (fra `fix-dependency-namespace-guards`) til også at logge analytics-status på INFO-level.

## Impact

- **Affected specs**: `analytics-privacy` (ADDED + MODIFIED requirements)
- **Affected code**:
  - `inst/golem-config.yml` (shinylogs_enabled default i prod)
  - `R/utils_shinylogs_config.R` (env-var-check)
  - `R/utils_analytics_github.R` (opt-in-flag verificering)
  - `R/utils_advanced_debug.R` (redact_debug_snapshot)
  - `docs/ANALYTICS_PRIVACY.md` (omfattende opdatering)
  - Evt. ny admin-UI-panel i `R/mod_*_admin.R` (hvis besluttet)
- **Risks**:
  - Shinylogs opt-in betyder tab af automatisk drift-telemetri — afvej mod privacy-krav
  - Redaction af debug-snapshots kan reducere debugging-effektivitet — dokumentér trade-off
- **Non-breaking for brugere**: Mere restriktivt ved default — krav til eksplicit opt-in er bedre default.

## Related

- GitHub Issue: #323
- Review-rapport: Codex (V3 Logging/analytics + Analytics GitHub sync)
- Eksisterende spec: `analytics-privacy` (session-id hashing, PAT redaction)
