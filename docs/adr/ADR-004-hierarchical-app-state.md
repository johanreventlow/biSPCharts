# ADR-004: Hierarchical app_state with reactiveValues

## Status
Accepted (retroaktiv dokumentation, 2026-05-07)

## Kontekst

Tidlige iterationer brugte mange flade `reactiveVal`-objekter +
session-globale `<<-`-assignments til at dele state mellem moduler. Det gav:

1. **Cross-session contamination**: Globale variable delte state mellem
   samtidige sessions i Connect Cloud-deploys (`.performance_cache`,
   `.data_signature_cache` lakede mellem brugere før issue #529).
2. **Scope-isolation**: Modul-lokale `reactiveVal`-objekter var ikke synlige
   for andre moduler uden at blive passet eksplicit gennem 4-5 funktionslag.
3. **Implicit copy-by-value**: Liste-baseret state passet til funktioner
   blev kopieret — mutationer forsvandt ved retur.
4. **State drift**: Samme logiske state-felt fandtes i flere moduler
   (`module_cached_data` + `current_data` + `processed_data`).
5. **Manglende oversigt**: Ingen single source of truth for "hvad er app'ens
   nuværende tilstand".

Behov: én central reference med session-isolation, by-reference deling,
hierarkisk gruppering efter domæne.

## Beslutning

Vi indfører **`app_state` som central environment-baseret container med
hierarkiske `reactiveValues`-sektioner**, oprettet per session i
`create_app_state()` (`R/state_management.R`):

### Top-level: environment (by-reference)

```r
app_state <- new.env(parent = emptyenv())
```

Environment vælges over list/reactiveValues fordi environments deles
**by reference** mellem funktioner — eliminerer scope-isolation-bug og
behøver ikke `<<-` for at mutere.

### Sektioner: hierarkiske reactiveValues

Hver domæne får egen reactiveValues-container med klar ansvarsgrænse:

| Sektion | Indhold |
|---------|---------|
| `app_state$events` | Event-bus counters (jf. ADR-003) |
| `app_state$data` | `current_data`, `original_data`, `processed_data`, `file_info`, `table_version`, ... |
| `app_state$columns` | Nested: `auto_detect`, `mappings`, `ui_sync` |
| `app_state$session` | `auto_save_enabled`, `file_uploaded`, `peek_result`, `active_tab`, ... |
| `app_state$test_mode` | Test-mode konfiguration + startup-fase |
| `app_state$ui` | Loop-protection-flags, queue-system, performance-metrics |
| `app_state$visualization` | `plot_ready`, `anhoej_results`, `viewport_dims`, cache-guards |
| `app_state$navigation` | Trigger-counter for eventReactive-patterns |
| `app_state$errors` | `last_error`, `error_count`, `error_history`, recovery-state |
| `app_state$cache` | Session-scoped: `qic`, `performance`, `data_signature` (issue #529) |
| `app_state$infrastructure` | Non-reactive flags til `later::later()`-callbacks |

### Atomic update-mønster
Multi-felt-mutationer pakkes i `safe_operation()` for "alt eller intet":

```r
safe_operation("Update mapping", {
  app_state$columns$mappings$x_column <- new_x
  app_state$columns$mappings$y_column <- new_y
  emit$ui_sync_requested()
})
```

### Session-scoped caches (issue #529)
`app_state$cache$performance` + `app_state$cache$data_signature` flyttet
fra package-environment til session-scope efter cross-session-contamination
i Connect Cloud-deploy.

## Konsekvenser

### Positive
- **Session-isolation**: Hver Shiny-session får egen `app_state`. Ingen
  cross-session-leakage.
- **By-reference deling**: Environment passes by reference — moduler kan
  mutere uden `<<-` eller round-trip-returns.
- **Single source of truth**: "Hvad er nuværende dataset?" → altid
  `app_state$data$current_data`.
- **Domæne-grupperet**: Hierarki gør state-graf navigerbar; `app_state$columns$auto_detect$completed`
  er selvforklarende vs. flad `auto_detect_completed`.
- **Reactive integration**: `reactiveValues` integrerer nativt med Shiny's
  reactive graph — ingen manuel invalidate-kald.
- **Testbarhed**: Tests kan oprette isoleret `app_state` + manipulere felter
  direkte uden at mocke Shiny session.

### Negative
- **Læringskurve**: Nye contributors skal lære skemaet før de finder rette
  felt; flade reactiveVal er intuitive ved første blik.
- **Ingen type-checking**: `reactiveValues` accepterer alt — ukorrekte
  felt-mutationer fanges først ved konsumenter.
- **Skema-stivhed**: Tilføje nyt felt kræver edit i `create_app_state()`;
  glemte initialiseringer giver `NULL`-bugs.
- **Memory overhead**: Per-session container er større end nødvendigt for
  features der kun bruger få felter — accepteret pris for isolation.

### Mitigations
- Skema dokumenteret i `create_app_state()` roxygen + CLAUDE.md sektion
  "App State Structure".
- Alle nye state-felter skal initieres i `create_app_state()` (ingen
  on-the-fly assignment) — håndhæves ved code review.
- `safe_operation()`-wrapper for atomic updates dokumenteret i
  `SHINY_ADVANCED_PATTERNS.md`.

## Alternativer overvejet

### A: Flade reactiveVal pr. modul
Afvist: scope-isolation-problemer + implicit cross-modul kobling.

### B: R6-klasser med private/public felter
Afvist: ingen native integration med Shiny's reactive graph; ekstra wrapping
omkring `invalidate()`.

### C: Globale package-level reactiveValues
Afvist: cross-session contamination i multi-bruger-deploys (issue #529
demonstrerede konsekvensen).

### D: External state-store (shinyStore, redis)
Afvist: overkill for in-session state; persisteret state løses separat
i ADR-005 (localStorage).

## Implementering

- **Initial implementation**: Phase 4 centraliseret state (~2025-Q3)
- **Hierarki-refaktorering**: `columns` opdelt i `auto_detect` / `mappings` /
  `ui_sync` sub-reactiveValues
- **Cache session-scope migration**: Issue #529 (cross-session contamination
  fix)
- **Verificering**: `tests/testthat/test-phase4-centralized-state.R` +
  integration tests for state-mutationer

## Referencer

- `R/state_management.R` — `create_app_state()`
- ADR-003 — Unified Event Architecture (events lever i `app_state$events`)
- ADR-005 — Session Persistence (persisteret subset af `app_state`)
- ADR-006 — Hybrid Anti-Race Strategy (bygger på state-atomicity)
- CLAUDE.md sektion "App State Structure"
- Issue #529 — Session-scoped performance cache

## Dato
2026-05-07 (retroaktiv dokumentation af beslutning truffet ~2025-Q3)
