## Why

Analytics-/telemetri-pipelinen (`utils_analytics_*`) håndterer GitHub Personal Access Tokens (PAT), Shiny session tokens og aggregeret shinylogs-data. Ekstern codex-review (2026-04-21) identificerede tre reelle læk-risici: (1) rå session-token prefix bruges som del af filnavn på GitHub (`build_session_filename()`), (2) PAT injiceres i `https://x-access-token:<PAT>@github.com/...`-URL som kan optræde i `conditionMessage()` ved fejl, og (3) der er ingen allowlist på shinylogs-payload så alle input-/output-/error-records pushes som RDS til privat repo uden klart dokumenteret payload-schema.

I et klinisk miljø er dette potentielt compliance-problem. Selvom data-repoet er privat, SKAL PAT'er og session-identifikatorer aldrig optræde i logs eller fejlbeskeder, og der SKAL være et eksplicit kontrakt for hvad der sendes ud af appen.

## What Changes

- **Session-id hashing**: `build_session_filename()` SKAL bruge `substr(digest::digest(session_id, algo = "sha256"), 1, 8)` frem for `substr(session_id, 1, 8)`. Fallback-path ved NULL/tom session_id bevares, men hashes også.
- **PAT redaction**:
  - Implementer `redact_pat_in_url(msg)` der scrubber `x-access-token:<token>@` til `x-access-token:[REDACTED]@` i alle `conditionMessage()`-værdier før de logges eller returneres.
  - Anvend på alle fejl-paths i `sync_logs_to_github()` og eventuelle andre steder hvor `auth_url` kan lække.
- **Metadata allowlist**: Indfør eksplicit allowlist i `read_shinylogs_all()` eller `sync_logs_to_github()` for hvilke kolonner der pushes. Udkast til allowlist:
  - `sessions`: session_hash (ikke rå token), app_version, browser, os, timestamp_iso
  - `inputs`: session_hash, name, value (filtreret for PII-felter), timestamp
  - `outputs`: session_hash, name, timestamp (ingen værdi-kopi default)
  - `errors`: session_hash, error_class, redacted_message, timestamp (redact PAT+paths+tokens i message)
- **Opt-in dokumentation**: Opret `docs/ANALYTICS_PRIVACY.md` der beskriver:
  - Præcist hvad der indsamles, hvordan og hvornår
  - Hvordan brugere ser/eksporterer/sletter egne data
  - Hvordan opt-in styres via `app_state$session$analytics_consent` og `inst/golem-config.yml`
  - DPIA-status og dato for senest review
- **Environment-default**: Verificer at analytics er **opt-in** pr. default i produktion. Hvis ikke, tilføj `analytics.enabled: false` som default til prod-config.
- **Regression-tests**:
  - PAT må aldrig optræde i output af `sync_logs_to_github()` fejl-paths (mock `git_clone` til at kaste med URL)
  - Session token prefix må ikke matche rå token (verificer via hash)
  - Shinylogs-payload SKAL kun indeholde allowlistede kolonner

## Impact

- **Affected specs**: `analytics-privacy` (ny capability)
- **Affected code**:
  - `R/utils_analytics_github.R` (hashing, PAT redaction)
  - `R/utils_analytics_pins.R` (allowlist filtering)
  - `R/utils_analytics_consent.R` (opt-in verifikation)
  - `inst/golem-config.yml` (default opt-in værdier)
  - `docs/ANALYTICS_PRIVACY.md` (ny fil)
  - `tests/testthat/test-analytics-*.R` (nye tests + udvidelser)
- **Risks**:
  - Hashing bryder bagudkompatibilitet med tidligere uploadede filer — acceptabelt, nye sessioner skriver nye filnavne
  - Allowlist kan fjerne data som stakeholders finder nyttig — derfor dokumenteres allowlist eksplicit og kan udvides ved behov
- **Non-breaking for brugere**: Ingen UI-ændring, ingen funktionel ændring
- **Security posture**: Reducerer læk-risiko fra 3 vektorer (filename, URL, payload) til 0

## Related

- GitHub Issue: #288 (paraply)
- Codex-review: 2026-04-21 session
- Relateret til tidligere security-sprints (sanitize_session_token osv.)
