# Design: Session Persistence via Browser localStorage

## Context

biSPCharts bruges af klinikere til SPC-analyser. En typisk bruger-session består af:
1. Upload af CSV/XLSX-fil (eller paste fra Excel)
2. Opsætning af kolonne-mapping (x, y, n, skift, frys, kommentar)
3. Valg af chart-type (run, p, pp, i, u, g, t, …)
4. Indtastning af titel, beskrivelse, target-værdi, centerline, y-akse enhed
5. Observation og fortolkning af plottet

Hvis brugeren mister forbindelsen, lukker fanen ved en fejl, eller systemet crasher under trin 2–4, mister de ALT setup-arbejde. Filen er stadig på deres maskine, men de skal re-uploade og re-konfigurere.

Mål med denne persistence-funktion: efter et sådant afbrud kan brugeren åbne appen og finde sin session genetableret automatisk, inklusive både rådata og indstillinger.

## Goals / Non-Goals

### Goals
- **Auto-save** hvert 2 sekund (data) og 1 sekund (settings) efter bruger-interaktion
- **Auto-restore** ved app-load hvis der er gemt data
- **Fuld roundtrip-fidelitet** for data.frame (inkl. `Date`, `POSIXct`, `integer`, `factor`, `numeric`, `character`, `logical`)
- **Robust fejl-håndtering** — quota-fejl deaktiverer auto-save gracefully uden at crashe appen
- **Single source of truth** for feature flags via `inst/golem-config.yml`
- **Event-bus integration** — restore følger samme pattern som normal data-upload
- **Zero ekstra UI-friktion** — usynlig auto-save, kun kort notifikation ved restore

### Non-Goals
- **Multi-slot/navngivne projekter** — single slot per browser-origin
- **Cross-tab synkronisering** — last-write-wins accepteres
- **Cross-device sync** — lokalt kun
- **Server-side persistence** — ingen database, ingen Shiny bookmark state
- **Manuel "Gem projekt"-knap** — auto-save gør den overflødig
- **Download/upload til fil på disk** — separat feature (se `add-session-file-export`)
- **Versionering/historik** — kun seneste session
- **GDPR anonymisering** — afklaret udenfor scope: brugere uploader ikke patientdata

## Decisions

### D1: localStorage som backend (vs. sessionStorage, cookies, IndexedDB)

**Valgt:** `localStorage`

**Alternativer overvejet:**
- `sessionStorage`: mister data ved browserluk → løser ikke det egentlige problem (crash recovery)
- `cookies`: for små (4 KB), sendes med hver HTTP-request (performance + privacy issue)
- `IndexedDB`: mere kompliceret API, overkill for single-key storage under 1 MB

**Rationale:** `localStorage` er synkron, simpel nøgle-værdi, 5-10 MB typisk quota, præcist det vi behøver. Bruges allerede i codebase via `inst/app/www/local-storage.js`.

### D2: Single JSON-string vs. flere nøgler

**Valgt:** Én nøgle `spc_app_current_session` med hele payload som JSON

**Alternativer overvejet:**
- Flere nøgler (`spc_app_data`, `spc_app_metadata`, `spc_app_timestamp`) → atomicitet-problemer, mere kompleks load-logik

**Rationale:** Single key giver atomisk write og simpel roundtrip. Størrelsen er bounded til 1 MB.

### D3: JSON-encoding på R-siden (vs. JS-siden)

**Valgt:** `jsonlite::toJSON()` på R-siden, `localStorage.setItem(key, string)` på JS-siden uden yderligere `JSON.stringify`

**Den tidligere fejl:** `local-storage.js` kaldte `JSON.stringify(data)` selvom `data` allerede var en JSON-string fra R, hvilket gav dobbelt-encoding. Ved load blev der kun `JSON.parse`'et én gang, så R modtog en string i stedet for et list-objekt.

**Løsning:** Fjern `JSON.stringify` i `saveAppState`. Behold `JSON.parse` i `loadAppState` — det parser den ene lag som R forventer.

**Rationale:** `jsonlite` har bedre kontrol over R-specifikke typer (factors, Dates, NA-håndtering) end `JSON.stringify`. At gøre serialisering ét sted er mere vedligeholdbart.

### D4: Class preservation via eksplicit `class_info`

**Valgt:** Gem eksplicit class-metadata ved side af værdierne

```r
class_info <- lapply(data, function(x) {
  list(
    primary = class(x)[1],
    is_date = inherits(x, "Date"),
    is_posixct = inherits(x, "POSIXct"),
    is_factor = is.factor(x),
    levels = if (is.factor(x)) levels(x) else NULL,
    tz = if (inherits(x, "POSIXct")) attr(x, "tzone") else NULL
  )
})
```

**Alternativer overvejet:**
- Bruge `serialize()` til raw bytes → binær, ikke JSON-kompatibel, kan ikke inspiceres i dev tools
- Lade `jsonlite` håndtere det alene → `Date`/`POSIXct` bliver til strings uden type-info, `factor` bliver til integer

**Rationale:** Eksplicit class_info er robust, inspicerbar og forward-kompatibel. Små overhead-omkostninger (få bytes ekstra per kolonne).

### D5: Restore-rækkefølge og race condition

**Valgt:** Metadata gendannes **før** data-event emitteres

**Tidligere bug:**
```r
set_current_data(app_state, reconstructed_data)
emit$data_updated(context = "session_restore")  # ← auto-detect starter med tom mapping
...
restore_metadata(session, saved_state$metadata)  # ← for sent
```

**Ny rækkefølge:**
```r
# 1. Set guards
app_state$session$restoring_session <- TRUE
app_state$data$updating_table <- TRUE
app_state$session$auto_save_enabled <- FALSE

# 2. Restore metadata FIRST (UI form fields)
if (!is.null(saved_state$metadata)) {
  restore_metadata(session, saved_state$metadata, ui_service)
}

# 3. THEN set data and mark completion flags
set_current_data(app_state, reconstructed_data)
app_state$data$original_data <- reconstructed_data
app_state$session$file_uploaded <- TRUE
app_state$columns$auto_detect$completed <- TRUE

# 4. FINALLY emit event (triggers chart render with correct mapping)
emit$data_updated(context = "session_restore")
```

**Rationale:** Event-bus listeners (auto-detect, chart render) skal se korrekt state når de fyrer. Metadata er UI-state som skal være synkroniseret før data-event.

### D6: Feature flag single source of truth

**Valgt:** `inst/golem-config.yml` er eneste kilde

```yaml
session:
  auto_save_enabled: true       # Kontinuerlig auto-save
  auto_restore_session: true    # Genindlæs ved app-start
  save_interval_ms: 2000        # Debounce for data
  settings_save_interval_ms: 1000  # Debounce for settings
```

**Tidligere problem:** To paralle paths — `determine_auto_restore_setting()` med hardkodede defaults OG `convert_profile_to_legacy_config()` der læser fra YAML. Uklar prioritet.

**Løsning:** Slet `determine_auto_restore_setting()` helt. YAML via Golem profiles er eneste kilde. Getters (`get_auto_save_enabled()`, `get_auto_restore_enabled()`) læser fra pakke-miljø populeret af `apply_runtime_config()`.

### D7: JS → R fejl-kanal

**Valgt:** Ny input `local_storage_save_result` sendes fra JS efter hver save

```js
Shiny.addCustomMessageHandler('saveAppState', function(message) {
  var success = window.saveAppState(message.key, message.data);
  Shiny.setInputValue('local_storage_save_result', {
    success: success,
    timestamp: new Date().toISOString(),
    key: message.key
  }, {priority: 'event'});
});
```

R-side observer:
```r
shiny::observeEvent(input$local_storage_save_result, {
  if (isFALSE(input$local_storage_save_result$success)) {
    log_warn("localStorage save failed", .context = "AUTO_SAVE")
    app_state$session$auto_save_enabled <- FALSE
    shiny::showNotification(
      "Browseren kan ikke gemme mere data (lokal lagerplads fuld). Automatisk lagring er deaktiveret for denne session.",
      type = "warning", duration = 8
    )
  } else {
    app_state$session$last_save_time <- Sys.time()
  }
})
```

**Rationale:** Uden denne feedback-sløjfe kunne R opdatere `last_save_time` selvom quota var sprunget, og brugeren ville tro alt var gemt. Nu er R og browser synkroniserede.

### D8: `autoSaveAppState` signatur

**Valgt:** Tilføj `app_state` som eksplicit parameter

```r
autoSaveAppState <- function(session, current_data, metadata, app_state) {
  # ...
  if (identical(result, FALSE)) {
    app_state$session$auto_save_enabled <- FALSE
  }
}
```

**Tidligere bug:** `exists("app_state")` fandt ikke app_state (var ikke i scope), så fallback-logikken virkede aldrig.

**Rationale:** Eksplicit dependency injection følger projektets arkitekturprincipper (`ARCHITECTURE_PATTERNS.md`). Testbart, klart.

### D9: `shiny:sessioninitialized` vs. `setTimeout`

**Valgt:** Lyt på `shiny:sessioninitialized`

```js
$(document).on('shiny:sessioninitialized', function() {
  if (window.hasAppState('current_session')) {
    var data = window.loadAppState('current_session');
    if (data) {
      Shiny.setInputValue('auto_restore_data', data, {priority: 'event'});
    }
  }
});
```

**Tidligere problem:** `setTimeout(500)` er en gæt. For tidligt = observer endnu ikke registreret = silent drop. For sent = unødig forsinkelse.

**Rationale:** `shiny:sessioninitialized` fyrer præcis når Shiny er klar til at modtage inputs. Event-drevet er altid bedre end polling/gætning.

### D10: Versionering og migration

**Valgt:** Detektér gamle versioner, ryd og vis migration-besked

```r
saved_state_version <- saved_state$version %||% "unknown"
if (saved_state_version != "2.0") {
  log_info(
    "Ignoring incompatible localStorage version",
    .context = "SESSION_RESTORE",
    details = list(found = saved_state_version, expected = "2.0")
  )
  clearDataLocally(session)
  # Ingen notifikation — brugeren skal ikke forstyrres af teknisk gæld
  return()
}
```

**Rationale:** Vi har ikke en installeret brugerbase med gamle formater, så migration er unødvendig kompleksitet. Detect-and-clear er simpelt og sikkert. Bump version til `"2.0"` for at markere det nye format.

## Risks / Trade-offs

### R1: Cross-tab overskrivning

**Risiko:** To faner åbne samtidig overskriver hinanden's state uden koordinering.

**Mitigation:** Accepteret. Dokumentéret i CLAUDE.md. Last-write-wins er det forventede for single-slot storage. Kan tilføjes senere med `storage`-events hvis det bliver et problem.

### R2: localStorage quota

**Risiko:** 1 MB limit er konservativt for store datasæt. Klinikere kan have 10.000+ rækker datasæt.

**Mitigation:**
- 1 MB ≈ 10.000 rækker × 5 kolonner × ~20 bytes/celle = realistisk header
- Ved quota-fejl: graceful disable + notifikation + auto-save slukket for session
- Data er stadig i app'en (bare ikke persistent) → ingen tab ved fortsat brug
- Brugeren kan fortsætte uden afbrydelse

### R3: Schema-ændring i `app_state`

**Risiko:** Fremtidige ændringer i `app_state$session` kan bryde restore af gamle sessions.

**Mitigation:** Version-bump ved hver ændring + detect-and-clear i load. Simpel strategi.

### R4: `factor` med mange levels

**Risiko:** Kolonner med tusindvis af unique factor levels øger payload-størrelse markant.

**Mitigation:** Det er en kant-case. 1 MB limit fanger det. Bounds-check afviser ved load.

### R5: Timezone-tab for POSIXct

**Risiko:** `POSIXct` har tidszone-metadata der skal bevares.

**Mitigation:** `class_info` gemmer `tz` attributten. Ved restore sættes den eksplicit via `attr(x, "tzone") <- saved_tz`.

## Migration Plan

1. **Pre-release:** Gamle `v1.2` payloads i development-browsere detekteres og ryddes ved første boot efter rollout. Ingen brugervendt.
2. **Rollout:** Feature flag `auto_save_enabled: true` + `auto_restore_session: true` aktiveres i `prod`-profilen af `golem-config.yml`.
3. **Rollback:** Hvis problemer opstår: sæt begge flags til `false` i YAML og redeploy. Ingen kode-rollback nødvendig.

## Open Questions

Ingen åbne spørgsmål efter beslutninger truffet:
- 0.1 GDPR: afklaret — ingen patientdata, fuld persistence OK
- 0.2 Storage model: afklaret — single slot
- 0.3 UI-omfang: afklaret — kun auto-save, usynligt

## Testing Strategy

### Unit tests
- `saveDataLocally()` genererer korrekt custom message struktur (mock session)
- `collect_metadata()` + `restore_metadata()` roundtrip bevarer alle felter
- Bounds-check afviser ugyldige payloads (nrow > 1M, ncol > 1000, cells > 10M)
- `autoSaveAppState()` respekterer `auto_save_enabled = FALSE`
- `autoSaveAppState()` disable'r auto-save ved fejl (med mock app_state)
- Class-preservation: data.frame med `numeric`, `character`, `Date`, `POSIXct`, `integer`, `factor`, `logical` kolonner roundtrippes uden type-tab

### Integration tests
- Mock fuld save → load roundtrip via `session$sendCustomMessage` mocking
- Verificer at `input$auto_restore_data` processing rekonstruerer data.frame korrekt
- Test at `restore_metadata()` kører før `emit$data_updated()` (observer-spy pattern)
- Test at feature flag OFF resulterer i ingen auto-save observers

### Manuel verification
Se `tasks.md` punkt 7 for checkliste.

## Dependencies

Ingen nye R-pakker eller JS-biblioteker. Alt bygges på eksisterende:
- `jsonlite` (allerede i Imports)
- `shinyjs` (allerede i Imports)
- `safe_operation()` (eksisterende helper)
- `emit` event-bus (eksisterende)
- `ui_service` (eksisterende)
