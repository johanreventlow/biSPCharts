# ADR-006: Hybrid Anti-Race Strategy (5-Layer)

## Status
Accepted (retroaktiv dokumentation, 2026-05-07)

## Kontekst

Selv efter unified event-architecture (ADR-003) og hierarchical app_state
(ADR-004) opstod race conditions i specifikke scenarier:

1. **Konkurrerende observers**: Auto-detection startede mens brugeren stadig
   redigerede tabel; resultatet blev "current_data" snapshotted i et
   inkonsistent øjeblik.
2. **Programmatic UI vs. user input**: `updateSelectInput()` triggede ofte
   `input$X`-listener i samme flush-cyklus, hvilket gav uendelige loops
   eller stale-state writes.
3. **Burst-typing**: Hver tegn-tast i et tekstfelt udløste rebuild af
   downstream caches, hvilket blokerede UI-thread under hurtig indtastning.
4. **Tab-switch under processing**: Bruger skiftede til "Eksporter"-tab
   mens et plot stadig genererede; observer for navigation_changed kunne
   læse halv-færdig state.
5. **Concurrent UI updates**: Flere observers kaldte `update*Input()` på
   samme element → senest-vinder eller overlappende DOM-mutationer.

Ingen enkelt mekanisme dækkede alle scenarier. Behov: lagdelt strategi
hvor hver lag fanger en specifik race-klasse, kombineret design der sikrer
at bortfald af et lag ikke åbner alle scenarier.

## Beslutning

Vi indfører en **hybrid 5-lags anti-race-strategi** hvor hvert lag dækker
en distinkt race-kategori. Layers anvendes kombineret per feature efter
en **feature implementation checklist** dokumenteret i
`SHINY_ADVANCED_PATTERNS.md`.

### Lag 1: Event Architecture med eksplicitte prioriteter

Beskrevet i ADR-003. Sikrer deterministisk eksekverings-rækkefølge inden
for én flush-cyklus:

```r
shiny::observeEvent(app_state$events$data_updated,
  ignoreInit = TRUE,
  priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,  # 2000 — kører før priority 750
  { ... }
)
```

**Forhindrer**: Reactive-graph re-ordering, registrerings-rækkefølge-
afhængighed, observer-startup-races.

### Lag 2: State Atomicity via `safe_operation()`

Multi-felt-mutationer pakkes i `safe_operation()`-wrapper:

```r
safe_operation("Update mapping", {
  app_state$columns$mappings$x_column <- new_x
  app_state$columns$mappings$y_column <- new_y
  emit$ui_sync_requested()
})
```

`safe_operation()` wrap'er i `tryCatch()` + logger fejl + sikrer at
partial-update ikke efterlades synlig for konsumenter.

**Forhindrer**: Konsumenter læser inkonsistent state (X opdateret, Y ikke).

### Lag 3: Functional Guards på proces-flag

Hver længere-løbende operation beskytter sig selv via state-flag:

```r
update_ui_state <- function(state, new_value) {
  if (isTRUE(state$data$processing) ||
      isTRUE(state$ui$updating) ||
      isTRUE(state$visualization$plot_generation_in_progress)) {
    return(invisible(NULL))  # Skip — anden operation kører
  }
  state$ui$current_selection <- new_value
}
```

Konkrete flag i kodebasen:
- `app_state$data$updating_table`
- `app_state$data$table_operation_in_progress`
- `app_state$session$restoring_session`
- `app_state$ui$updating_programmatically`
- `app_state$visualization$cache_updating`
- `app_state$visualization$plot_generation_in_progress`

**Forhindrer**: Overlappende operationer (auto-save under tabel-edit,
auto-detect under restore, plot-gen under cache-rebuild).

### Lag 4: UI Atomicity via wrapper-helpers

Programmatic UI-opdateringer kanaliseres gennem `safe_programmatic_ui_update()`
som:
- Sætter `app_state$ui$updating_programmatically <- TRUE` før update
- Kører update i kontrolleret kontekst
- Resetter flag via scheduled `later::later()`-callback efter Shiny flush

Konkurrerende UI-opdateringer (samme element fra flere observers)
serialiseres via `app_state$ui$queued_updates`-kø + `process_ui_update_queue()`:

```r
# Session-global queue forhindrer DOM-overlap
app_state$ui$queued_updates  # list of pending updates
app_state$ui$queue_processing # mutex flag
```

**Forhindrer**:
- Programmatic update → `input$X`-observer triggers → cirkulært loop.
- To observers kalder `updateSelectInput()` på samme element samtidigt.

### Lag 5: Input Debouncing

Fritekst- og burst-inputs debounces 150-2000 ms via `DEBOUNCE_DELAYS`
(`R/config_system_config.R`):

```r
DEBOUNCE_DELAYS <- list(
  input_change = 150,    # dropdowns, fast typing
  file_select  = 500,    # file selection
  chart_update = 500,    # chart rendering
  table_cleanup = 2000   # table operation cleanup
)

# Auto-save data: 2000ms (get_save_interval_ms())
# Auto-save settings: 1000ms (get_settings_save_interval_ms())
```

**Forhindrer**: Burst-input invaliderer caches/triggrer beregning per
tegn.

### Feature implementation checklist

Hver ny feature der ændrer state vurderes mod de 5 lag:

- [ ] Emit via event-bus (lag 1)
- [ ] Observer med eksplicit prioritet (lag 1)
- [ ] Atomic mutation via `safe_operation()` (lag 2)
- [ ] Guard mod konflikt-flag (lag 3)
- [ ] UI-update via `safe_programmatic_ui_update()` hvis programmatic (lag 4)
- [ ] Debounce input hvis fritekst/burst (lag 5)
- [ ] Test concurrent operations (alle lag)

## Konsekvenser

### Positive
- **Lagdelt forsvar**: Bortfald af ét lag åbner kun specifik race-klasse,
  ikke hele systemet.
- **Eksplicit checklist**: Hver feature evalueres mod samme 6 punkter →
  konsistent kvalitetsnivau.
- **Diagnose-venlig**: Race conditions kan oftest spores til hvilket lag
  manglede (eks: glemt guard-flag → flaget ses i debug-logs).
- **Test-fokus**: "Concurrent ops"-tests dækker scenarier der historisk
  reproducerede races.

### Negative
- **Kognitivt overhead**: Nye contributors skal forstå alle 5 lag før de
  kan implementere ikke-trivielle features.
- **Verbositet**: Simple state-updates kræver flere wrappere end naivt
  kode-design.
- **Disciplin-afhængigt**: Glemt guard-flag eller manglende prioritet
  kan stadig genintroducere races. Mitigeret via code review + checklist.
- **Ydelse-omkostning**: Debounce introducerer latens (150-2000 ms);
  acceptable for klinisk arbejde, men ikke for realtids-feedback.

### Mitigations
- Checklist dokumenteret i `SHINY_ADVANCED_PATTERNS.md` (auto-loaded i
  CLAUDE.md Tier 2).
- `OBSERVER_PRIORITIES`-konstanter (ikke magic numbers) reducerer
  prioritets-fejl.
- `safe_operation()`/`safe_programmatic_ui_update()` reducerer boilerplate
  pr. feature.
- Logging i hvert lag (`log_debug` med `.context = "RACE_GUARD"` el.lign.)
  giver post-mortem data ved produktions-races.

## Alternativer overvejet

### A: Single-threaded queue for alle state-mutationer
Afvist: Shiny's reactive-graph er allerede "single-threaded" inden for
flush; problemerne ligger i cross-flush-races og UI-DOM-overlap. En
ekstra queue ville duplikere Shiny's eksisterende infrastruktur.

### B: Optimistic concurrency med version-counters per felt
Afvist: kompleksitet langt over reelle behov for in-session app;
traditionelt mønster fra distribuerede systemer.

### C: Mutexes via R6-baseret lock-manager
Afvist: deadlock-risiko; ingen forretnings-kritisk grund til at blokere
hele observer-træer mens et flag holdes.

### D: Aggressiv debounce kun (drop andre lag)
Afvist: høj debounce skader UX; lav debounce fanger ikke programmatic-
loops eller priority-races. Debounce alene løser ikke race-klassen.

## Implementering

- **Initial design**: Iterativ udvikling 2025-Q3 → Q4 efter observation
  af konkrete race-bugs i produktion
- **Lag 1+2**: Indført sammen med ADR-003+ADR-004 refactor
- **Lag 3 (guards)**: Tilføjet incrementelt per observerede race
  (table-update, restore-session, plot-generation)
- **Lag 4 (UI queue)**: Indført efter rapporter om sammenfaldende
  `updateSelectInput()`-kald gav flicker
- **Lag 5 (debounce)**: Optimeret 2025-Q4 (input_change 300 → 150 ms,
  chart_update 800 → 500 ms — 30-40 % perceived responsiveness)
- **Verificering**: Concurrent-ops integration-tests
  (`tests/testthat/test-integration-reactive-chain*.R`),
  manual smoke-tests af tab-switch + auto-save + plot-gen scenarier

## Referencer

- `R/utils_state_accessors.R` — `safe_programmatic_ui_update()`,
  `safe_operation()`
- `R/utils_ui_form_update_service.R` — UI update queue
- `R/utils_ui_table_update_service.R` — table-operation guards
- `R/config_observer_priorities.R` — `OBSERVER_PRIORITIES`
- `R/config_system_config.R` — `DEBOUNCE_DELAYS`, `LOOP_PROTECTION_DELAYS`
- `R/zzz.R` — `get_save_interval_ms()`, `get_settings_save_interval_ms()`
- ADR-003 — Unified Event Architecture (lag 1 fundament)
- ADR-004 — Hierarchical app_state (lag 2-3 fundament)
- `SHINY_ADVANCED_PATTERNS.md` — "Race Condition Prevention (5 Lag)" +
  "Feature implementation checklist"
- CLAUDE.md sektion "Race Condition Prevention"

## Dato
2026-05-07 (retroaktiv dokumentation af strategi udviklet 2025-Q3 → Q4)
