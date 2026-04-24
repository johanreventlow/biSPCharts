## ADDED Requirements

### Requirement: Session-id hashing i alle persisterede artefakter

Shiny session tokens SHALL aldrig optræde i klartekst i filnavne, logs eller data der persisteres uden for den kørende session. Alle identifikatorer afledt af session-tokens SHALL være kryptografiske hashes (SHA-256 eller stærkere) med mindst 8 tegn prefix.

#### Scenario: Filnavn i analytics-upload
- **WHEN** `build_session_filename(session_id)` kaldes med en gyldig session-token
- **THEN** det returnerede filnavn indeholder `substr(digest::digest(session_id, algo = "sha256"), 1, N)` hvor N ≥ 8
- **AND** filnavnet indeholder NOT rå session-token som substring

#### Scenario: NULL session-id
- **WHEN** `build_session_filename(NULL)` kaldes
- **THEN** returnerer et filnavn med deterministisk fallback-hash baseret på timestamp + entropi
- **AND** filnavnet matcher sorterbart format `YYYYMMDDTHHMMSSZ_<hash>.rds`

### Requirement: PAT redaction i fejl-paths

GitHub Personal Access Tokens og andre credentials SHALL aldrig optræde i fejlbeskeder, logs eller return-værdier fra analytics-sync-funktioner. Alle `conditionMessage()`-værdier der kan indeholde auth-URL'er SHALL passere gennem en redaction-funktion før de eksponeres.

#### Scenario: Clone fejler med auth-URL i message
- **WHEN** `gert::git_clone(url = "https://x-access-token:TOKEN@github.com/...")` kaster error med URL i message
- **AND** `sync_logs_to_github()` fanger fejlen
- **THEN** returværdien `list(success = FALSE, reason = ..., error = msg)` indeholder NOT `TOKEN` som substring
- **AND** `msg` er transformeret så `x-access-token:TOKEN@` er erstattet med `x-access-token:[REDACTED]@`

#### Scenario: Push fejler med credential-reference
- **WHEN** `gert::git_push(...)` kaster error
- **THEN** samme redaction anvendes før return

### Requirement: Shinylogs-payload allowlist

Analytics-uploader SHALL anvende en eksplicit allowlist til at filtrere shinylogs-data før upload. Data der ikke er på allowlisten SHALL droppes, ikke bare redactes, for at reducere blast-radius.

#### Scenario: Ikke-allowlistet kolonne i inputs
- **WHEN** `filter_shinylogs_allowlist(all_data)` kaldes med en `inputs`-dataframe der indeholder kolonner ud over `SHINYLOGS_ALLOWLIST$inputs`
- **THEN** de ikke-allowlistede kolonner fjernes fra resultatet
- **AND** de allowlistede kolonner bevares uændret

#### Scenario: Rå session-token i data
- **WHEN** en record i `sessions`, `inputs`, `outputs` eller `errors` indeholder rå session-token i en kolonne
- **THEN** tokenet SHALL erstattes med session_hash før upload
- **AND** rå token optræder NOT i RDS-filen der pushes

#### Scenario: Errors-dataframe redaction
- **WHEN** en error-record indeholder `message` med PAT, fil-sti eller anden sensitiv information
- **THEN** `redact_error_messages(errors_df)` scrubber disse før upload
- **AND** `error_class` og `timestamp` bevares til triage

### Requirement: Opt-in default i produktion

Analytics-upload SHALL være opt-in pr. default i produktionsmiljø. Upload SHALL blokeres når enten (a) `app_state$session$analytics_consent` er FALSE eller (b) config `analytics.enabled` er FALSE.

#### Scenario: Prod-config uden explicit consent
- **WHEN** appen kører med `GOLEM_CONFIG_ACTIVE = "prod"` og ingen bruger-consent er givet
- **THEN** `sync_logs_to_github()` returnerer `list(success = FALSE, reason = "consent_required")`
- **AND** INGEN data sendes til remote

#### Scenario: Dev-config med analytics disabled
- **WHEN** config indeholder `analytics.enabled: false`
- **THEN** sync-funktionen returnerer tidligt uden at kalde `git_clone` eller `git_push`

### Requirement: Dokumenteret payload-kontrakt

`docs/ANALYTICS_PRIVACY.md` SHALL eksistere og beskrive præcist hvilke felter der indsamles, hvor data gemmes, og hvordan brugere kan få indsigt/sletning. Dokumentet SHALL opdateres senest samtidig med ændringer i `SHINYLOGS_ALLOWLIST`.

#### Scenario: Allowlist udvides
- **WHEN** en ny kolonne tilføjes til `SHINYLOGS_ALLOWLIST$<group>`
- **THEN** `docs/ANALYTICS_PRIVACY.md` SHALL opdateres i samme change-proposal
- **AND** DPIA-status-linje opdateres med ny review-dato

#### Scenario: Dokumentation mangler
- **WHEN** en PR ændrer allowlist uden at opdatere `docs/ANALYTICS_PRIVACY.md`
- **THEN** PR SHALL afvises af review
