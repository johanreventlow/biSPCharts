## 1. Session-id hashing

- [x] 1.1 Implementer `hash_session_id(session_id, algo = "sha256", length = 8)` helper i `R/utils_analytics_github.R`
- [x] 1.2 Opdater `build_session_filename()` til at bruge hash (fallback når session_id er NULL: hash af timestamp + entropi)
- [x] 1.3 Test: `test_that("build_session_filename never exposes raw session_id prefix")`
- [x] 1.4 Test: samme input → samme hash (deterministisk)

## 2. PAT redaction

- [x] 2.1 Implementer `redact_pat_in_url(msg)` helper der matcher `x-access-token:[^@]+@`
- [x] 2.2 Anvend redaction i alle `error = function(e)`-paths i `sync_logs_to_github()`
- [x] 2.3 Anvend redaction på `list(success = FALSE, reason = ..., error = ...)` return-værdier
- [x] 2.4 Test: `redact_pat_in_url()` fjerner PAT fra URL-streng; no-op på besked uden credentials

## 3. Shinylogs allowlist

- [x] 3.1 Definer `SHINYLOGS_ALLOWLIST` i `R/utils_analytics_pins.R`
- [x] 3.2 Implementer `filter_shinylogs_allowlist(all_data)`
- [x] 3.3 Implementer `redact_error_messages(errors_df)`
- [x] 3.4 Replace rå session token med hashed session_hash i alle 4 dataframes
- [x] 3.5 Integrer i `sync_logs_to_github()` før `saveRDS()`
- [x] 3.6 Test: `filter_shinylogs_allowlist()` fjerner ikke-tilladte kolonner, hashes korrekt, redacter PAT

## 4. Opt-in verifikation

- [x] 4.1 Audit `inst/golem-config.yml` — prod: `analytics.enabled: true`, test: `false`
- [x] 4.2 Behold `analytics.enabled: true` i prod — consent-gate i `should_track_analytics()` er tilstrækkelig (bruger-godkendt)
- [x] 4.3 Verificeret: `utils_analytics_consent.R` honorerer config-flag OG consent — begge kræves
- [x] 4.4 Dækket af eksisterende `test-utils_analytics_consent.R`: `should_track_analytics() respekterer feature flag` (spc.analytics.enabled=FALSE → FALSE uanset consent)

## 5. Dokumentation

- [x] 5.1 Opret `docs/ANALYTICS_PRIVACY.md` med sektioner: hvad indsamles, opt-in, dataopbevaring, brugerrettigheder, DPIA-status
- [x] 5.2 Link tilføjet i `README.md` (Developer Resources) og `CLAUDE.md` (Analytics Privacy sektion)
- [x] 5.3 Opdater NEWS.md under "(development)"

## 6. Verifikation

- [x] 6.1 Alle nye tests består (20 analytics-github + 11 analytics-pins)
- [x] 6.2 Manuel test kørt: `redact_pat_in_url(conditionMessage(e))` med PAT i URL — output indeholder ikke PAT (verificeret 2026-04-24)
- [x] 6.3 `devtools::load_all()` kører rent
- [x] 6.4 Review fra bruger (DPIA-ansvar) før merge

Tracking: GitHub Issue #307
