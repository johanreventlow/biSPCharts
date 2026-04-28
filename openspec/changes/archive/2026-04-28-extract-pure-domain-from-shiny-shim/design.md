# Design: Extract Pure Domain from Shiny Shim

Status: Implemented
Issue: #320

## API-signaturer

### parse_file(path, format, encoding_hints)

```r
parse_file <- function(path, format = c("csv", "excel"), encoding_hints = NULL)
# Returnerer ParsedFile S3-objekt:
structure(list(
  data        = <data.frame>,
  meta        = list(rows, cols, encoding, format),
  warnings    = character()
), class = "ParsedFile")
```

Ingen Shiny-afhængigheder. Kalder `try_with_diagnostics` og `preprocess_uploaded_data` (begge pure).
`on_all_fail` returnerer NULL i stedet for at kalde `showNotification` — fejlhåndtering delegeres til shim.

### run_autodetect(data, hints)

```r
run_autodetect <- function(data, hints = NULL)
# Returnerer AutodetectResult S3-objekt:
structure(list(
  x_col       = <chr or NULL>,
  y_col       = <chr or NULL>,
  n_col       = <chr or NULL>,
  skift_col   = <chr or NULL>,
  frys_col    = <chr or NULL>,
  kommentar_col = <chr or NULL>,
  scores      = list(),
  timestamp   = <POSIXct>
), class = "AutodetectResult")
```

Kalder `detect_columns_name_based` og `detect_columns_full_analysis` (begge pure).
Guard-logik (in_progress, frozen_until_next_trigger) forbliver i `autodetect_engine()` shim.
Caching (`cache_auto_detection_results`) forbliver i shim.

### build_visualization_config(data, autodetect, user_overrides)

```r
build_visualization_config <- function(data, autodetect, user_overrides)
# Returnerer VisualizationConfig S3-objekt:
structure(list(
  x_col      = <chr or NULL>,
  y_col      = <chr or NULL>,
  n_col      = <chr or NULL>,
  chart_type = <chr>,
  source     = c("manual", "autodetect", "mapping")
), class = "VisualizationConfig")
```

Ingen reaktive afhængigheder. `user_overrides` er plain R liste med saniterede input-værdier.

## Migration-plan

### Pure vs Shim

| Logik | Pure | Shim |
|-------|------|------|
| CSV/Excel parsing med fallbacks | `parse_file()` | `handle_csv_upload`, `handle_excel_upload` |
| Data preprocessing (tom-rækker, kolonnenavne) | `parse_file()` delegerer til `preprocess_uploaded_data` | Shim viser notifikationer |
| Kolonne-detektion baseret på navne/data | `run_autodetect()` | `autodetect_engine()` |
| Guard conditions (in_progress, frozen) | — | `autodetect_engine()` |
| Caching af autodetect-resultater | — | `autodetect_engine()` |
| Visualization config-beregning | `build_visualization_config()` | Reactives i `setup_visualization()` |
| app_state-mutations | — | `apply_state_transition()` via navngivne helpers |

### State-transition-helpers

State-transitions er navngivne pure funktioner der returnerer en
ændringsliste. `apply_state_transition(app_state, changes)` er den eneste
funktion der må mutere app_state.

`apply_state_transition` bruger rekursiv apply fordi alle sub-niveauer
i biSPCharts (`app_state$data`, `app_state$columns`, `app_state$columns$mappings`,
`app_state$columns$auto_detect` etc.) er `shiny::reactiveValues()`-objekter,
som er environments under motorhjelmen (`is.environment()` returnerer TRUE).
Rekursionen er derfor sikker og giver atomiske opdateringer per sub-sektion.

## Atomicity-garantier

`apply_state_transition` kalder `shiny::isolate()` om hele nested-apply,
hvilket sikrer at ingen observers affyres mens transitionens delændringer
skrives. Dette erstatter ad-hoc `shiny::isolate({})` blokke spredt i shim-koden.

## Begrænsninger og udskudt arbejde

- `handle_paste_data()` bruger samme parse+mutate mønster som CSV-upload,
  men er ikke inkluderet i denne PR. Den bør i en follow-up refaktoreres
  til at kalde `parse_file()` med en text-source parameter.
- `update_all_column_mappings()` muterer app_state direkte. Dens
  app_state-assignments er erstattet af `apply_state_transition()`.
- 387 baseline-mutations. Mål: ≤ 194. Denne refaktorering fjerner
  direkte mutations fra de tre kildefiler (~47 mutations) og
  `update_all_column_mappings` (~12 mutations).
