## Context

`compute_spc_results_bfh()` er biSPCharts' centrale SPC-orkestrator. Den kaldes fra `mod_spc_chart_compute.R` (reactive plot-compute) og bruges til alle chart-typer (run, p, u, c, g, xbar, s, mr, i, t). Funktionen er vokset gradvist siden migrationen fra qicharts2 til BFHcharts, og den bærer nu ansvar for både validation, data-prep, chart-rendering, metadata-ekstraktion og caching.

Samtidig er der en permanent hybrid-arkitektur: BFHcharts bruges til plot-rendering, qicharts2 bruges til Anhøj-metadata (special-cause detection). Denne kontrakt SKAL bevares — den er dokumenteret i CLAUDE.md og har klinisk validering.

Tests er omfattende (~30+ test-filer nævner SPC) men primært black-box. Regressionsrisiko ved split er reel.

## Goals / Non-Goals

**Goals:**
- Hver helper-funktion har <100 linjer og én ansvar
- Typed S3-kontrakter mellem helpers (dokumenterede inputs/outputs)
- Domæne-fejl propagerer som typed errors (ikke tavse NULL-returneringer)
- Cache-state lever i environment, ikke unlocked package-bindings
- Public API for `compute_spc_results_bfh()` er uændret (signatur + return-kontrakt)

**Non-Goals:**
- Ændre hybrid-arkitekturen (BFHcharts + qicharts2)
- Ændre cache-nøgle-algoritme (bevar eksisterende viewport-baseret key)
- Performance-optimering (separat proposal hvis nødvendigt)
- Ændre UI/UX eller Shiny-integration
- Fjerne `safe_operation()` helt — kun i domænelogik

## Decisions

### Decision 1: S3-klasser for kontrakter
Hver pipeline-helper returnerer et S3-objekt med dokumenteret struktur:

```r
spc_request <- structure(
  list(data = ..., mapping = list(x_var, y_var, ...), chart_type = ..., ...),
  class = c("spc_request", "list")
)

spc_prepared <- structure(
  list(data = parsed_data, axes_meta = ..., n_rows_filtered = ...),
  class = c("spc_prepared", "list")
)
```

**Rationale:** S3 giver lette, introspicerbare kontrakter uden R6-overhead. Print-metoder hjælper debugging. Tests kan bruge `expect_s3_class()`.

**Alternativer:**
- Plain lists: mindre eksplicit, lettere at bryde kontrakt utilsigtet
- R6: overkill, genindfører mutable state-problem
- S7: nyt system, for risikabelt at introducere i refactor

### Decision 2: Typed error classes
Indfør taksonomi:

```r
# R/utils_error_handling.R
spc_abort <- function(message, class, ..., call = rlang::caller_env()) {
  rlang::abort(
    message = message,
    class = c(class, "spc_error", "error", "condition"),
    ...,
    call = call
  )
}

# Bruges:
spc_abort("Unknown chart type: 'xyz'", class = "spc_input_error")
spc_abort("Date column has no valid dates", class = "spc_prepare_error")
```

**Klasser:**
- `spc_input_error`: Ugyldig input (forkert chart_type, manglende kolonner)
- `spc_prepare_error`: Data-prep fejl (parsing, filtering)
- `spc_render_error`: BFHcharts-fejl under rendering
- `spc_cache_error`: Cache-læs/skriv fejl (typisk warn, ikke error)

**Rationale:** Caller i `mod_spc_chart_compute.R` kan skelne og reagere forskelligt:

```r
tryCatch(
  result <- compute_spc_results_bfh(...),
  spc_input_error = function(e) {
    showNotification(conditionMessage(e), type = "error")
    NULL
  },
  spc_render_error = function(e) {
    showNotification("Fejl under graf-generering", type = "warning")
    log_error(component = "[SPC_RENDER]", e$message)
    NULL
  }
)
```

### Decision 3: Cache migration til environment
Erstat:
```r
# R/... (package-level)
.panel_cache_stats <- list(hits = 0, misses = 0)
```

Med:
```r
# R/utils_cache.R
cache_state <- new.env(parent = emptyenv())
cache_state$panel_stats <- list(hits = 0L, misses = 0L)
cache_state$grob_stats <- list(hits = 0L, misses = 0L)
cache_state$panel_config <- list(...)
cache_state$grob_config <- list(...)

get_panel_stats <- function() cache_state$panel_stats
update_panel_stats <- function(hits_delta = 0L, misses_delta = 0L) {
  cache_state$panel_stats$hits <- cache_state$panel_stats$hits + hits_delta
  cache_state$panel_stats$misses <- cache_state$panel_stats$misses + misses_delta
  invisible(cache_state$panel_stats)
}
```

**Rationale:** Environment er altid mutable, ingen `unlockBinding()` behov, ingen `R CMD check`-warnings. Referencer opdateres søg/erstat.

**Migration:**
1. Find alle brug af `.panel_cache_stats`, `.grob_cache_stats`, `.panel_cache_config`, `.grob_cache_config`
2. Replace med `cache_state$panel_stats` osv.
3. Slet package-level bindings
4. Slet `unlock_cache_statistics()` + fjern kald i `.onLoad`

### Decision 4: Public API uændret
`compute_spc_results_bfh()` bevarer:
- Samme parameternavne og defaults
- Samme return-struktur: `list(plot = ..., metadata = ..., cache_hit = ...)`
- Samme fejl-returnering (NULL ved fejl, ikke throw) — orkestreringslaget fanger typed errors og returnerer NULL til caller

**Rationale:** Ingen caller skal opdateres. Refactor er rent internt.

### Decision 5: File organization
Split til flere filer under `R/`:
- `R/fct_spc_validate.R` — `validate_spc_request()`
- `R/fct_spc_prepare.R` — `prepare_spc_data()`, `resolve_axis_units()`
- `R/fct_spc_execute.R` — `build_bfh_args()`, `execute_bfh_request()`
- `R/fct_spc_decorate.R` — `decorate_plot_for_display()`, `extract_spc_metadata()` (flyttes her hvis logisk)
- `R/fct_spc_bfh_facade.R` — bevarer `compute_spc_results_bfh()` som tyndt orkestreringslag

**Rationale:** Matcher eksisterende Golem-struktur (`fct_*` for business logic). Holder filer <300 linjer.

## Risks / Trade-offs

- **Regression i alle SPC-charts** → Mitigation: kør fuld testsuite efter hver helper-extraction; behold public API strictly uændret
- **Performance-regression fra ekstra funktions-kald** → Mitigation: benchmark før/efter med `microbenchmark`; acceptér op til 5% overhead, rollback hvis >10%
- **Typed errors bryder eksisterende tryCatch-kode** → Mitigation: alle typed errors inherit fra `"error"`, så generic tryCatch fortsat virker; audit call-sites før merge
- **Cache-environment-migration bryder state-persistence** → Mitigation: cache er in-memory only, ingen disk-persistence at migrere; session-restart resetter cache uanset

## Migration Plan

**Fase 1 (kan parallelliseres på worktrees):**
1. Indfør `spc_abort()` + fejlklasser i `utils_error_handling.R`
2. Indfør `cache_state` environment i `utils_cache.R`, migrer alle referencer
3. Fjern `unlock_cache_statistics()` + kald

**Fase 2 (sekventiel, én helper ad gangen):**
4. Extract `validate_spc_request()` → ny fil, ny test, compute_spc_results_bfh kalder
5. Extract `prepare_spc_data()` → samme pattern
6. Extract `resolve_axis_units()`
7. Extract `build_bfh_args()`
8. Extract `execute_bfh_request()`
9. Extract `decorate_plot_for_display()`

**Fase 3:**
10. Reducer `compute_spc_results_bfh()` til orkestrering (<100 linjer)
11. Opdater `mod_spc_chart_compute.R` med typed error catching
12. Benchmark før/efter

**Rollback:** Hver fase er separat commit. Revert til `main` hvis test-gate bryder.

## Open Questions

1. Skal qicharts2-Anhøj-ekstraktion blive i `extract_spc_metadata()` eller flyttes til separat `fct_spc_anhoj_metadata.R`? Forslag: behold i `decorate/metadata`-helper medmindre den vokser >100 linjer.
2. Skal vi samtidig indføre S3 print-methods? Ikke kritisk, men nice-to-have for debugging. Foreslås som separat follow-up.
3. Benchmark-budget: acceptér hvilken overhead? Forslag: <5% p50, <10% p99 på representative datasæt (10k, 100k rows).
