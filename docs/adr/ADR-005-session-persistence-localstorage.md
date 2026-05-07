# ADR-005: Session Persistence via Browser localStorage

## Status
Accepted (retroaktiv dokumentation, 2026-05-07)

## Kontekst

Klinikere på Bispebjerg + Frederiksberg Hospital arbejder typisk i sessioner
spredt over en arbejdsdag på delte hospital-PC'er. Browser-refresh,
utilsigtet luk af tab, eller server-reconnect kunne tidligere koste alt
arbejde — datasæt, kolonne-mappings, chart-type, eksport-tekst. Behov:

1. **Robusthed mod tilfældige reconnect**: Klinikere mister ikke flere
   timers arbejde fordi en RConnect-session timer ud.
2. **Klassebevarelse pr. kolonne**: Date, POSIXct (med tz), factor (med
   levels), integer, numeric skal restoreres præcist — JSON-roundtrip
   coercer alt til character/numeric uden metadata.
3. **Privacy på delte PC'er**: Data må ikke ligge i browser efter en
   klinisk arbejdsdag.
4. **Skema-evolution**: Persisteret state-format vil ændre sig over tid —
   ældre payloads må ikke crashe app eller producere subtile fejl.
5. **Server-uafhængighed**: Persistens må ikke kræve database eller
   ekstra infrastruktur — biSPCharts deployes til Connect Cloud uden
   persistent disk per bruger.

Eksterne constraints: Issue #193 dokumenterede behovet, double-encoding-bug
i tidlig implementation (`JSON.stringify(allerede_jsonifieret)`)
demonstrerede skørheden.

## Beslutning

Vi indfører **automatisk persistens af session-state i browser-localStorage**
med eksplicit schema-versionering, klassebevarelse pr. kolonne, og TTL-baseret
ekspirering:

### 1. Auto-save (debounced)
- **Data**: 2000 ms debounce (`get_save_interval_ms()`, override via
  `SAVE_INTERVAL_MS` package-config)
- **Settings (UI-state)**: 1000 ms debounce (`get_settings_save_interval_ms()`)
- Implementation: `shiny::debounce(reactive({...}), millis)` i
  `R/utils_server_session_helpers.R`
- Trigger-guards: skipper auto-save under
  `updating_table`/`table_operation_in_progress`/`restoring_session`/`!auto_save_enabled`

### 2. Schema-version gate
`LOCAL_STORAGE_SCHEMA_VERSION` (aktuelt `"3.0"`) bumpes ved payload-ændringer.
Load-logik:
- Ukendt eller ældre version → ryd payload (no-op load).
- Forventede migrations (eks. 2.0 → 3.0) → silent forward-migration via
  `migrate_time_yaxis_unit()`. Idempotent (3.0 returneres uændret).

### 3. Klassebevarelse pr. kolonne
`extract_class_info(data)` producerer named list pr. kolonne:
`{primary, is_date, is_posixct, is_factor, levels, tz}`. Lagres sammen
med data. Ved restore kalder `restore_column_class()` korrekte
coercion-paths via whitelist (`ALLOWED_PRIMARY`-list — defensivt mod
manipulerede payloads fra DevTools, jf. issue #457).

### 4. TTL på client-side
`SPC_LOCALSTORAGE_DEFAULT_TTL_MINUTES = 480` (8 timer = klinisk arbejdsdag),
override via `window.SPC_LOCALSTORAGE_TTL_MINUTES`. `spc_expire_stale_sessions()`
kører ved hver `$(document).ready()` — fjerner forældede payloads før
load-logik tilgår dem. Beskytter data på delte hospital-PC'er.

### 5. Brugerstyret restore (peek-pattern)
Ved app-start sender JS et "peek"-resultat (`list(has_payload, ...)`) til
server via `app_state$session$peek_result`. Server gating:
- Ingen payload → standard tom session.
- Payload tilstede → vis brugeren explicit "Genoptag tidligere session"-prompt.
  Auto-restore kun ved bekræftet brugervalg.

### 6. Auto-disable ved persistente fejl
`autoSaveAppState()` returnerer `FALSE` ved gentagne `safe_operation()`-failures.
Server-side `set_auto_save_enabled(app_state, FALSE)` deaktiverer videre
forsøg + viser brugeren neutral notifikation ("Din data er stadig
tilgængelig i appen. Automatisk lagring er midlertidigt deaktiveret.").

### 7. Størrelses-cap
`object.size(current_data) >= 1000000` (1 MB) → spring auto-save over,
notify bruger om at downloade manuelt. localStorage-quota er typisk
5-10 MB, vi holder konservativ buffer for metadata + andre apps på domænet.

## Konsekvenser

### Positive
- **Robusthed**: Refresh/reconnect mister ikke arbejde; klinikere kan
  fortsætte hvor de slap.
- **Server-uafhængig**: Ingen database, ingen disk-mount — fungerer
  identisk i Connect Cloud, lokal dev, og selvhostet RConnect.
- **Type-præcis restore**: Date/POSIXct/factor bevares — undgår subtile
  bugs hvor numerisk parsing fejler efter restore.
- **Privacy-bevidst**: TTL + delte-PC-konstruktion eliminerer "glemt data
  i browser ved hjemtid"-risiko.
- **Forward-kompatibel evolution**: Schema-version-gate tillader frie
  ændringer i payload-format uden at brække eksisterende brugeres state.

### Negative
- **Browser-afhængighed**: localStorage skal være enabled — privatmode +
  visse hospital-policies kan blokere. Mitigeret af graceful degradation
  (skipper save, app fungerer normalt).
- **1 MB cap**: Store datasæt > ~10k rækker auto-saves ikke. Accepteret —
  store datasæt er "skal-downloades-eksplicit"-arbejdsflow.
- **Skema-bumps koster brugerstate**: Major schema-bump (eks. 2.0 → 3.0
  uden migration) sletter ældre payloads. Mitigeret af forward-migrations
  hvor det er praktisk.
- **JSON-roundtrip-skørhed**: `NULL`-elementer fra
  `jsonlite::fromJSON(simplifyVector = FALSE)` skal håndteres eksplicit
  i `restore_column_class()` (NULL → NA via `unlist()`).
- **Double-encoding-fælde**: JS må IKKE kalde `JSON.stringify()` på data
  fra R's `jsonlite::toJSON()` (allerede en streng). Issue #193 indikerede
  hvor let det er at brække roundtrip.

### Mitigations
- Schema-versionering eksplicit dokumenteret + bumpes synkront med
  payload-ændringer.
- `ALLOWED_PRIMARY` whitelist beskytter mod manipulerede class_info-payloads.
- TTL-check kører før load-logik så stale data aldrig når R-side.
- Tests dækker roundtrip for alle understøttede typer
  (`tests/testthat/test-local-storage-*.R`).

## Alternativer overvejet

### A: Server-side session-store (RConnect persisteret disk)
Afvist: kræver per-bruger persistent disk → ikke kompatibelt med
Connect Cloud + lokal dev. Privacy-implikationer på delt infrastruktur.

### B: Eksplicit Save/Load-knapper (ingen auto-persist)
Afvist: dårlig UX — klinikere ville glemme at gemme før timeout.
Manuel download bevares som komplement (Excel/CSV) til langtids-arkiv.

### C: IndexedDB
Afvist: API-kompleksitet (async + transactions) for ringe gevinst —
1 MB-budget rammer aldrig localStorage-grænserne.

### D: Cookies
Afvist: størrelsesgrænse (~4 KB) langt under behov.

## Implementering

- **Initial implementation**: Issue #193 (~2025-Q4)
- **Schema 3.0 migration**: `y_axis_unit "time"` split til
  `time_minutes`/`time_hours`/`time_days` med silent forward-migration
- **TTL-check**: Tilføjet for delte hospital-PC'er
- **Whitelist hardening**: Issue #457 (ALLOWED_PRIMARY beskytter mod
  manipulerede class_info-payloads)
- **Verificering**: Roundtrip-tests for alle datatyper, schema-migration
  tests, TTL-expiry tests

## Referencer

- `R/utils_local_storage.R` — server-side persistens, class-handling, migrations
- `R/utils_server_server_management.R` — restore-logik + peek-handling
- `R/utils_server_session_helpers.R` — auto-save debounce-trigger
- `inst/app/www/local-storage.js` — client-side TTL + storage
- ADR-004 — Hierarchical app_state (persisteret subset stammer herfra)
- Issue #193 — Original feature-request + double-encoding-fix
- Issue #457 — ALLOWED_PRIMARY whitelist hardening
- CLAUDE.md sektion "Session Persistence (Issue #193)"

## Dato
2026-05-07 (retroaktiv dokumentation af beslutning truffet ~2025-Q4)
