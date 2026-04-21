## 1. Session-id hashing

- [ ] 1.1 Implementer `hash_session_id(session_id, algo = "sha256", length = 8)` helper i `R/utils_analytics_github.R`
- [ ] 1.2 Opdater `build_session_filename()` til at bruge hash (fallback når session_id er NULL: `digest(Sys.time()+runif(1))`)
- [ ] 1.3 Test: `test_that("build_session_filename never exposes raw session_id prefix")`
- [ ] 1.4 Test: samme input → samme hash (deterministisk)

## 2. PAT redaction

- [ ] 2.1 Implementer `redact_pat_in_url(msg)` helper der matcher `x-access-token:[^@]+@`
- [ ] 2.2 Anvend redaction i alle `error = function(e)`-paths i `sync_logs_to_github()`
- [ ] 2.3 Anvend redaction på `list(success = FALSE, reason = ..., error = ...)` return-værdier
- [ ] 2.4 Test: mock `gert::git_clone` til at kaste error med `auth_url` i message → verificer at PAT ikke optræder i return-værdi

## 3. Shinylogs allowlist

- [ ] 3.1 Definer allowlist-konstanter i `R/config_analytics.R` (ny fil) eller i `R/utils_analytics_pins.R`:
  ```r
  SHINYLOGS_ALLOWLIST <- list(
    sessions = c("session_hash", "app_version", "browser", "os", "timestamp"),
    inputs = c("session_hash", "name", "value", "timestamp"),
    outputs = c("session_hash", "name", "timestamp"),
    errors = c("session_hash", "error_class", "redacted_message", "timestamp")
  )
  ```
- [ ] 3.2 Implementer `filter_shinylogs_allowlist(all_data)` der beholder kun allowlistede kolonner
- [ ] 3.3 Implementer `redact_error_messages(errors_df)` der scrubber PAT, paths og tokens
- [ ] 3.4 Replace rå session token med hashed session_hash i alle 4 dataframes før upload
- [ ] 3.5 Integrer i `sync_logs_to_github()` før `saveRDS()`
- [ ] 3.6 Test: `test_that("filter_shinylogs_allowlist removes non-allowed columns")`

## 4. Opt-in verifikation

- [ ] 4.1 Audit `inst/golem-config.yml` sektion `analytics:` — verificer default pr. environment
- [ ] 4.2 Sæt `analytics.enabled: false` i prod-config hvis ikke allerede tilfældet
- [ ] 4.3 Verificer at `utils_analytics_consent.R` honorerer config-flag før upload
- [ ] 4.4 Test: `test_that("analytics disabled in prod config blocks upload")`

## 5. Dokumentation

- [ ] 5.1 Opret `docs/ANALYTICS_PRIVACY.md` med sektioner:
  - Hvad indsamles (med allowlist-reference)
  - Hvor gemmes data (privat GitHub repo, kontaktperson)
  - Hvordan opt-in fungerer (consent UI, config flag)
  - Hvordan brugere eksporterer/sletter data
  - DPIA-status
- [ ] 5.2 Link fra README og CLAUDE.md
- [ ] 5.3 Opdater NEWS.md under "(development)"

## 6. Verifikation

- [ ] 6.1 Alle nye tests består
- [ ] 6.2 Manuel test: kør analytics-sync lokalt med dummy PAT, verificer at fejl-output ikke indeholder PAT
- [ ] 6.3 `R CMD check` forbliver ren
- [ ] 6.4 Review fra bruger (DPIA-ansvar) før merge

Tracking: GitHub Issue TBD
