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

Brugeren præsenteres for en **hård modal-dialog** ved første app-start
(eller efter version-bump af `consent_version`). Modalen blokerer al
app-interaktion indtil et eksplicit valg er truffet — ingen "ignorér"-
mulighed (som det tidligere banner tillod).

### Binær valg-model

| Valg | Konsekvens |
|------|------------|
| **Acceptér alle** | Aktiverer alle samtykke-bundne features: shinylogs analytics, performance-metrics, visitor-ID, client-metadata **og** localStorage-app-state-persistens (auto-save af data + indstillinger). |
| **Kun nødvendige** | Deaktiverer alle samtykke-bundne features. Ingen tracking. **Ingen auto-save** — browser-refresh = mistet arbejde i nuværende session, brug Excel/CSV-download for manuel persistens. Eksisterende `spc_app_*`-data slettes straks ved revoke (advarsel vises i modal når relevant). |

### Hvad gates af samtykke

| Feature | "Acceptér alle" | "Kun nødvendige" |
|---------|:---:|:---:|
| shinylogs analytics-events | ✅ | ❌ |
| Performance-metrics (page-load, render) | ✅ | ❌ |
| Visitor-ID + client-metadata | ✅ | ❌ |
| localStorage app-state auto-save | ✅ | ❌ |
| localStorage TTL-cleanup | ✅ | ✅ (strengt nødvendig — delte hospitals-PCer) |
| Cookie-præferencer-storage | ✅ | ✅ |

### Server-side gating

`should_track_analytics()` tjekker **begge** betingelser før shinylogs aktiveres:
- `analytics.enabled` i `inst/golem-config.yml` (prod: `true`)
- Brugerens runtime-consent (`input$analytics_consent`)

`is_persistence_allowed()` (separat helper) tjekker **kun** brugerens consent
— persistens er en GDPR-funktionel-kategori uafhængig af analytics-feature-flag.

Begge gates fail-closed: NULL/NA/manglende → returnér FALSE.

### Storage-schema (v2)

Samtykket gemmes som JSON-objekt under nøglen `spc_app_consent` i browserens
`localStorage`:

```json
{
  "schema_version": 2,
  "consent_version": 2,
  "timestamp": "2026-05-10T12:34:56.789Z",
  "consented": true,
  "visitor_id": "uuid-string-eller-null"
}
```

v1-brugere (4 separate `spc_app_*`-keys) migreres transparent ved første
load efter v2-deploy. Legacy-keys slettes efter successful migration.

### Tilbagekaldelse + re-prompt

- **Tilbagekaldelse:** Footer-link "Cookie-indstillinger" genåbner modalen
  i alle app-tilstande. Skift fra "Acceptér alle" → "Kun nødvendige" sletter
  eksisterende app-state straks.
- **Auto re-prompt:** Modal vises automatisk igen når
  - `consent_version` bumpes i `R/config_analytics.R` (v1→v2: 2026-05-10), eller
  - samtykket er > 365 dage gammelt (GDPR-loft, `consent_max_age_days`).

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
