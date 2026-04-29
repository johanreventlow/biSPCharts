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

## Shinylogs-aktivering (administrator)

Analytics-indsamling via shinylogs styres af `analytics.shinylogs_enabled`
i `inst/golem-config.yml`. Standard er `false` i alle miljøer undtagen
`development` og `testing`.

### Aktivér shinylogs i production

Sæt `analytics.shinylogs_enabled: true` i `production:`-sektionen i
`inst/golem-config.yml`, **eller** sæt miljøvariablen:

```bash
# Aktivér — override af config-fil
ENABLE_SHINYLOGS=TRUE
```

### Deaktivér permanent (kill-switch)

Sæt miljøvariablen `BISPC_DISABLE_ANALYTICS=true` for at deaktivere al
analytics-indsamling uanset øvrig konfiguration. Kill-switch vinder over
både config-fil og `ENABLE_SHINYLOGS`.

```bash
# Deaktivér — vinder over alle andre indstillinger
BISPC_DISABLE_ANALYTICS=true
```

Prioritetsrækkefølge (øverst vinder):

1. `BISPC_DISABLE_ANALYTICS=true` — global kill-switch
2. `analytics.shinylogs_enabled` i `golem-config.yml`
3. `ENABLE_SHINYLOGS` env-var (legacy, bevares for bagudkompatibilitet)

---

## GitHub-sync af analytics-data

Analytics-data kan uploades til et privat GitHub-repository ved
session-afslutning. Dette er **opt-in** og kræver eksplicit konfiguration.

### Aktivér GitHub-sync

1. Sæt `analytics.github_sync_enabled: true` i `production:`-sektionen
   i `inst/golem-config.yml`
2. Sæt følgende miljøvariabler:
   - `GITHUB_PAT` — fine-grained PAT med `contents:write`-tilladelse
   - `PIN_REPO_URL` — HTTPS URL til det private data-repository

Alle tre betingelser skal opfyldes. Hvis én mangler, springes synkronisering
over lydløst med en `WARN`-logbesked.

Standard er `false` i **alle** miljøer — der uploades aldrig data uden
eksplicit administrator-beslutning.

---

## Opbevaring og sletning

### Retentionspolitik

| Periode | Handling |
|---------|---------|
| 0–90 dage | Data tilgængeligt som rå `.rds`-filer |
| 90–365 dage | Data komprimeres (konfigureret via `log_compress_after_days`) |
| Efter 365 dage | Data slettes (konfigureret via `log_retention_days`) |

Politikken håndhæves manuelt af maintainer. Automatisk sletning er ikke
implementeret.

### Sletning på forespørgsel

Individuelle sessions kan identificeres ved `session_hash` i de uploadede
`.rds`-filer. Kontakt maintainer for at anmode om sletning. Rå session-tokens
er ikke tilgængelige — hashen er ikke reversibel.

---

## Hvor gemmes data

Analytics-data uploades til et **privat** GitHub-repository
(`biSPCharts-analytics-data`) ved session-afslutning, **hvis** GitHub-sync
er aktiveret (se ovenfor).

- Format: `.rds`-fil per session i `sessions/`-mappe
- Adgang: begrænset til maintainer
- Filnavn: `YYYYMMDDTHHMMSSZ_<session_hash>.rds` — ingen PII i filnavn
- Indhold: allowlist-filtreret subset (se tabeller ovenfor)

Backend kræver:
- `GITHUB_PAT` env var (fine-grained PAT med `contents:write`)
- `PIN_REPO_URL` env var (HTTPS URL til data-repo)
- `analytics.github_sync_enabled: true` i `golem-config.yml`

---

## Debug-snapshot redaktion

Debug-snapshots (`debug_state_snapshot()`) kan indeholde kolonnenavne
fra indlæste datasæt. Disse redakteres automatisk inden de logges eller
hashes.

### Redaktionspolitik

Kolonnenavne der matcher følgende mønstre erstattes med `[redacted]`:

- Navne der indeholder: `navn`, `name`, `patient`
- CPR-mønstre: `\d{6}-?\d{4}`
- Email-tegn: `@`, `mail`, `email`
- Telefon/adresse: `phone`, `mobil`, `adresse`, `address`

Matchning er case-insensitiv. Redaktionen sker i `redact_debug_snapshot()`
i `R/utils_advanced_debug.R`.

State-hashen (`state_hash` i snapshots) beregnes **efter** redaktion, så
hashen aldrig afspejler PII-kolonnenavne.

---

## Tekniske garantier

- **Session-token hashing**: Rå Shiny session-tokens optræder aldrig
  i filnavne, logs eller uploadede filer. `hash_session_id()` bruger
  SHA-256 (ikke reversibel).
- **PAT redaction**: `redact_pat_in_url()` fjerner credentials fra alle
  fejlbeskeder inden de logges eller returneres.
- **Allowlist-filtering**: `filter_shinylogs_allowlist()` dropper alle
  kolonner der ikke er eksplicit tilladt i `SHINYLOGS_ALLOWLIST`.
  Filteret anvendes nu **på begge** sync-stier: GitHub-stien og
  Posit Connect pin_write-stien.
- **paste_data_input eksklusion**: Indsæt-data-feltet (`paste_data_input`)
  er ekskluderet fra shinylogs-capture via `exclude_input_id`. Feltet
  kan indeholde CPR-numre, patientnavne og anden PHI.
- **Debug-snapshot redaktion**: `redact_debug_snapshot()` fjerner
  PII-kolonnenavne fra debug-output og state-hashes.
- **Opt-in GitHub-sync**: Synkronisering kræver eksplicit
  `analytics.github_sync_enabled: true` + miljøvariabler.

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
| Sidst gennemgået | 2026-04-29 |
| Ansvarlig | Johan Reventlow |
| Status | Ikke formelt DPIA-vurderet — app bruges internt, ingen ekstern transmission af PII |
| Næste review | Ved udvidelse af allowlist eller ændring af datamodtager |

---

*Opdatér DPIA-tabellen og allowlist-tabellerne ved enhver ændring af
`SHINYLOGS_ALLOWLIST` i `R/utils_analytics_pins.R`.*
