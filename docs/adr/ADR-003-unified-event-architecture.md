# ADR-003: Unified Event Architecture

## Status
Accepted (retroaktiv dokumentation, 2026-05-07)

## Kontekst

Tidlige iterationer af biSPCharts brugte ad-hoc `reactiveVal()`-triggers
spredt på tværs af server-kode. Hver feature definerede egne flag-variable,
direkte mutationer skete i blandet rækkefølge, og afhængigheder mellem
features var implicitte. Symptomer:

1. **Race conditions**: Auto-detection kunne læse `current_data` før upload
   havde committet, fordi observer-rækkefølge var ikke-deterministisk.
2. **Duplicate execution**: Samme handling udløst flere gange når flere
   `reactiveVal`-triggers ændrede sig samtidigt.
3. **Skjulte afhængigheder**: Ingen central oversigt over hvilke features
   reagerede på hvilke ændringer — vanskelig at debugge.
4. **Inkonsistent cleanup**: Observer-lifetimer ikke koordineret med session-end,
   "zombie"-observers kunne hænge i Shiny's reactive graph.

Behov: deterministisk event-flow, eksplicit afhængighedsgraf, stabil
observer-prioritet, koordineret cleanup.

## Beslutning

Vi indfører en **central event-bus med emit-API + prioriterede observers**
som det eneste tilladte mønster for cross-feature reaktivitet:

### 1. Event-bus
Alle events lever i `app_state$events` som `shiny::reactiveValues` med
integer-counters. Initieres i `create_app_state()` (`R/state_management.R`):

```r
app_state$events <- shiny::reactiveValues(
  data_updated            = 0L,
  auto_detection_started  = 0L,
  auto_detection_completed = 0L,
  ui_sync_requested       = 0L,
  navigation_changed      = 0L,
  session_started         = 0L,
  error_occurred          = 0L,
  # ... 19 events total
)
```

### 2. Emit-API
`create_emit_api(app_state)` returnerer named list af emit-funktioner.
Hver inkrementerer sit event-counter inde i `shiny::isolate()`:

```r
emit$data_updated(context = "upload")
# → app_state$events$data_updated <- ... + 1L
```

`isolate()` forhindrer utilsigtede reactive-afhængigheder i kalder-koden.
Context-argumenter input-valideres + sanitiseres.

### 3. Prioriterede observers
Listeners registreres centralt via `setup_event_listeners()`
(`R/utils_server_event_listeners.R`) der orkestrerer 7 modulære
register-funktioner (data, autodetect, ui, navigation, chart, wizard,
paste). Alle observers angiver eksplicit `priority` fra
`OBSERVER_PRIORITIES` (`R/config_observer_priorities.R`):

```r
shiny::observeEvent(app_state$events$data_updated,
  ignoreInit = TRUE,
  priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,  # 2000
  { ... }
)
```

Hierarki (wide gaps mellem niveauer):

| Niveau | Værdi | Anvendelse |
|--------|-------|------------|
| `STATE_MANAGEMENT` | 2000 | Kritiske state-mutationer |
| `AUTO_DETECT` | 1500 | Auto-detection |
| `DATA_PROCESSING` | 1250 | Data operations |
| `UI_SYNC` | 750 | UI synchronization |
| `PLOT_GENERATION` | 600 | Plot rendering |
| `STATUS_UPDATES` | 500 | Status indicators |
| `CLEANUP` | 200 | Cleanup |
| `LOGGING` | 100 | Monitoring |

### 4. Observer registry + cleanup
`setup_event_listeners()` registrerer hvert observer i en lokal
`observer_registry` via `register_observer(name, observer)`. Ved
session-slut kaldes `observer$destroy()` for hvert registreret observer.
Overwrite-protection: re-registration af samme navn destruerer eksisterende
observer først (fix for issue #487 zombie-observers).

## Konsekvenser

### Positive
- **Deterministisk eksekvering**: STATE_MANAGEMENT-observers kører før
  DATA_PROCESSING før UI_SYNC, uafhængigt af registrerings-rækkefølge.
- **Eksplicit afhængighedsgraf**: Alle events listet centralt; hver listener
  binder eksplicit til ét event.
- **Konsolidering**: Tidligere `data_loaded`/`data_changed` smeltet til
  `data_updated` med context-parameter. Færre events, mindre noise.
- **Test-vendor**: Events kan triggeres direkte i tests (`emit$data_updated()`),
  ingen UI-roundtrip nødvendig.
- **Cleanup-garanti**: Session-end destruerer alle observers atomisk.

### Negative
- **Boilerplate**: Nye features kræver event-definition + emit-funktion +
  observer-registrering — tre touch-points i stedet for én reactiveVal.
- **Indirekte flow**: Kald-stedet (`emit$X()`) og handler er adskilt;
  navigation kræver grep efter event-navn.
- **Priority-disciplin**: Forkert priority kan reintroducere races.
  Mitigeret af `OBSERVER_PRIORITIES`-konstanter (ikke magic numbers).

### Mitigations
- Modulær registrering (`register_*_events()`-funktioner per domæne)
  begrænser monolitisk fil-vækst.
- Legacy emit-aliases (`data_loaded()`, `data_changed()`) bevaret for
  API-stabilitet under konsolidering — mapper til samme `data_updated`-counter.
- DUPLICATE PREVENTION-guard i `setup_event_listeners()` blokerer parallelle
  optimized + standard listener-systemer (jf. ADR-014).

## Alternativer overvejet

### A: Bevare ad-hoc reactiveVal-mønster
Afvist: race conditions + skjulte afhængigheder skalerede dårligt med
feature-vækst.

### B: Eksternt event-bibliotek (R6-baseret eller eventstream)
Afvist: ekstra dependency uden klar gevinst — `reactiveValues` integrerer
nativt med Shiny's reactive graph + flush-cyclus.

### C: Én central observer i stedet for emit-API
Afvist: én monolitisk observer ville eliminere prioritets-strukturen og
tvinge if/else-grenudvælgelse på event-typer (sværere at teste).

## Implementering

- **Initial implementation**: Phase 4 state-refactor (~2025-Q3)
- **Konsolidering**: Phase 2.2 (`data_loaded` + `data_changed` → `data_updated`)
- **Modulær split**: Phase 2d (`utils_server_event_listeners.R` 1791 LOC →
  7 fokuserede moduler)
- **Observer cleanup-fix**: Issue #487 (zombie-prevention)
- **Optimized pipeline deprecation**: ADR-014 (single event-bus)
- **Verificering**: Unit tests for emit-API + observer-prioriteter
  (`tests/testthat/test-event-system-emit.R`,
  `tests/testthat/test-event-system-observers.R`)

## Referencer

- `R/state_management.R` — `create_app_state()`, `create_emit_api()`
- `R/utils_server_event_listeners.R` — `setup_event_listeners()`
- `R/config_observer_priorities.R` — `OBSERVER_PRIORITIES` + helpers
- `R/utils_server_events_*.R` — modulær per-domæne registrering
- ADR-004 — Hierarchical app_state (relateret state-design)
- ADR-006 — Hybrid Anti-Race Strategy (bygger ovenpå denne ADR)
- ADR-014 — Deprecation af optimized event pipeline (følgebeslutning)
- CLAUDE.md sektion "Unified Event Architecture"

## Dato
2026-05-07 (retroaktiv dokumentation af beslutning truffet ~2025-Q3)
