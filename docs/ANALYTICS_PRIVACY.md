# Analytics Privacy

Beskriver præcist hvad biSPCharts indsamler, hvor data gemmes, og
hvordan brugere kan få indsigt eller anmode om sletning.

**Opdatér dette dokument** når `SHINYLOGS_ALLOWLIST` i
`R/utils_analytics_pins.R` ændres.

---

## Hvad indsamles

Analytics aktiveres **kun** efter eksplicit bruger-consent (opt-in via
consent-dialog i appen). Ingen data sendes uden samtykke.

### Sessions

| Kolonne | Indhold | Formål |
|---------|---------|--------|
| `session_hash` | SHA-256 hash (8 tegn) af session-token | Korrelér events uden at eksponere rå token |
| `app` | App-navn (`"biSPCharts"`) | Versionsidentifikation |
| `server_connected` | Tidspunkt for session-start (UTC) | Sessionsvarighed |
| `server_disconnected` | Tidspunkt for session-slut (UTC) | Sessionsvarighed |

Følgende shinylogs-kolonner **indsamles ikke**: `user`, `user_agent`,
`screen_res`, `browser_res`, `pixel_ratio`, `browser_connected`.

### Inputs

| Kolonne | Indhold | Formål |
|---------|---------|--------|
| `session_hash` | SHA-256 hash (8 tegn) | Sessionkorrelation |
| `name` | Navn på Shiny-input (fx `"chart_type"`) | Forstå UI-brug |
| `timestamp` | Tidspunkt (UTC) | Kronologi |
| `value` | Inputværdi (fx `"p-chart"`) | Forstå feature-brug |

Følgende shinylogs-kolonner **indsamles ikke**: `type`, `binding`.

### Outputs

| Kolonne | Indhold | Formål |
|---------|---------|--------|
| `session_hash` | SHA-256 hash (8 tegn) | Sessionkorrelation |
| `name` | Navn på output-element | Forstå render-mønstre |
| `timestamp` | Tidspunkt (UTC) | Kronologi |

### Errors

| Kolonne | Indhold | Formål |
|---------|---------|--------|
| `session_hash` | SHA-256 hash (8 tegn) | Sessionkorrelation |
| `name` | Navn på fejlende element | Triage |
| `timestamp` | Tidspunkt (UTC) | Kronologi |
| `redacted_message` | Fejlbesked med PAT/credentials fjernet | Debugging |

---

## Opt-in mekanisme

1. Bruger præsenteres for consent-dialog ved første app-start
2. Kun ved eksplicit accept aktiveres `shinylogs::track_usage()`
3. `should_track_analytics()` tjekker **begge** betingelser:
   - `analytics.enabled` i `inst/golem-config.yml` (prod: `true`)
   - Brugerens runtime-consent (`input$analytics_consent`)
4. Ingen af delene er alene tilstrækkeligt — begge skal være opfyldt

Consent gemmes i browser `localStorage` så genbesøg ikke gentager dialogen.

---

## Hvor gemmes data

Analytics-data uploades til et **privat** GitHub-repository
(`biSPCharts-analytics-data`) ved session-afslutning.

- Format: `.rds`-fil per session i `sessions/`-mappe
- Adgang: begrænset til maintainer 
- Filnavn: `YYYYMMDDTHHMMSSZ_<session_hash>.rds` — ingen PII i filnavn
- Indhold: allowlist-filtreret subset (se tabeller ovenfor)

Backend kræver:
- `GITHUB_PAT` env var (fine-grained PAT med `contents:write`)
- `PIN_REPO_URL` env var (HTTPS URL til data-repo)

---

## Tekniske garantier

- **Session-token hashing**: Rå Shiny session-tokens optræder aldrig
  i filnavne, logs eller uploadede filer. `hash_session_id()` bruger
  SHA-256 (ikke reversibel).
- **PAT redaction**: `redact_pat_in_url()` fjerner credentials fra alle
  fejlbeskeder inden de logges eller returneres.
- **Allowlist-filtering**: `filter_shinylogs_allowlist()` dropper alle
  kolonner der ikke er eksplicit tilladt i `SHINYLOGS_ALLOWLIST`.

---

## Brugerrettigheder

### Tilbagetrækning af consent

Consent kan tilbagekaldes ved at slette analytics-data i browserens
`localStorage`. Fremtidige sessioner vil præsentere consent-dialogen på
ny.

---

## DPIA-status

| Felt | Værdi |
|------|-------|
| Sidst gennemgået | 2026-04-23 |
| Ansvarlig | Johan Reventlow |
| Status | Ikke formelt DPIA-vurderet — app bruges internt, ingen ekstern transmission af PII |
| Næste review | Ved udvidelse af allowlist eller ændring af datamodtager |

---

*Opdatér DPIA-tabellen og allowlist-tabellerne ved enhver ændring af
`SHINYLOGS_ALLOWLIST` i `R/utils_analytics_pins.R`.*
