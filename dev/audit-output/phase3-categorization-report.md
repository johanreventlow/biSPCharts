# Phase 3 Kategoriserings-rapport

**Dato:** 2026-04-17
**Total TODOs (test_that-blokke):** 57
**Kategorifordeling:** K1: 47 | K2: 0 | K3: 10

> **Tællenote:** `grep -c "TODO Fase 3"` giver 116 (multi-linje skip-strenge
> gentager "TODO Fase 3"-teksten). Reelt antal SKIP-blokke (ét TODO pr.
> `test_that`-block) = 57. Alle 57 er kategoriseret nedenfor.

---

## Summary

| Fil | TODOs i alt | K1 | K2 | K3 |
|---|---|---|---|---|
| test-utils-state-accessors.R | 17 | 17 | 0 | 0 |
| test-parse-danish-target-unit-conversion.R | 11 | 9 | 0 | 2 |
| test-performance-benchmarks.R | 9 | 5 | 0 | 4 |
| test-cache-reactive-lazy-evaluation.R | 7 | 7 | 0 | 0 |
| test-cache-collision-fix.R | 3 | 2 | 0 | 1 |
| test-label-placement-core.R | 3 | 3 | 0 | 0 |
| test-observer-cleanup.R | 2 | 2 | 0 | 0 |
| test-file-upload.R | 2 | 2 | 0 | 0 |
| test-plot-core.R | 1 | 1 | 0 | 0 |
| test-e2e-workflows.R | 1 | 1 | 0 | 0 |
| test-bfhcharts-integration.R | 1 | 0 | 0 | 1 |
| **Total** | **57** | **47** | **0** | **10** |

---

## Kategori 1 (R-kode-ændring kræves) — 47 entries

### test-utils-state-accessors.R (17 entries)

Alle 17 TODOs refererer til accessor-funktioner der **ikke eksisterer** i
`R/utils_state_accessors.R`. Filen indeholder kun 6 funktioner (`get_current_data`,
`set_current_data`, `set_original_data`, `is_plot_ready`, `get_viewport_dims`,
`set_viewport_dims`). Ingen er i NAMESPACE. Testerne forventer et komplet sæt
get/set-accessors for alle state-sektioner.

| # | Linje | Manglende funktion(er) | Placering i state | Foreslået R-fix |
|---|---|---|---|---|
| 1 | 110 | `get_original_data` | `app_state$data$original_data` | Tilføj getter i `R/utils_state_accessors.R` |
| 2 | 119 | `is_table_updating`, `set_table_updating` | `app_state$data$updating_table` | Tilføj getter + setter |
| 3 | 127 | `get_autodetect_status` | `app_state$columns$auto_detect` (returnér list med in_progress, completed, results, frozen) | Ny funktion med list-output |
| 4 | 135 | `set_autodetect_in_progress` | `app_state$columns$auto_detect$in_progress` | Tilføj setter |
| 5 | 142 | `get_column_mappings`, `get_column_mapping` | `app_state$columns$mappings` | Tilføj getter (alle) og getter (enkelt key) |
| 6 | 150 | `update_column_mapping` | `app_state$columns$mappings[[key]]` | Tilføj setter (enkelt key) |
| 7 | 157 | `set_plot_ready` | `app_state$visualization$plot_ready` | Tilføj setter (is_plot_ready finns) |
| 8 | 164 | `get_plot_warnings`, `set_plot_warnings` | `app_state$visualization$plot_warnings` | Tilføj getter + setter |
| 9 | 172 | `get_plot_object`, `set_plot_object` | `app_state$visualization$plot_object` | Tilføj getter + setter |
| 10 | 181 | `is_plot_generating`, `set_plot_generating` | `app_state$visualization$is_computing` | Tilføj getter + setter |
| 11 | 189 | `is_file_uploaded`, `set_file_uploaded` | `app_state$session$file_uploaded` | Tilføj getter + setter |
| 12 | 197 | `is_user_session_started`, `set_user_session_started` | `app_state$session$user_started_session` | Tilføj getter + setter |
| 13 | 205 | `get_last_error`, `set_last_error`, `get_error_count` | Ikke i state-schema (ny sub-sektion nødvendig) | Ny sub-state + 3 funktioner |
| 14 | 214 | `is_test_mode_enabled`, `set_test_mode_enabled` | `app_state$test_mode$enabled` | Tilføj getter + setter |
| 15 | 222 | `get_test_mode_startup_phase`, `set_test_mode_startup_phase` | `app_state$test_mode$startup_phase` | Tilføj getter + setter |
| 16 | 230 | `is_anhoej_rules_hidden`, `set_anhoej_rules_hidden` | `app_state$ui$hide_anhoej_rules` | Tilføj getter + setter |
| 17 | 238 | `is_y_axis_autoset_done`, `set_y_axis_autoset_done` | `app_state$ui$y_axis_unit_autoset_done` | Tilføj getter + setter |

**Root cause:** `R/utils_state_accessors.R` er delvist implementeret — kun 6 af ~30 forventede accessor-par er skrevet. De resterende 24+ funktioner skal tilføjes.

**Bemærkning:** #13 (`get_last_error`/`set_last_error`/`get_error_count`) kræver også et nyt `app_state$errors`-segment (error_list og error_count), da dette ikke er i det nuværende state-schema.

---

### test-parse-danish-target-unit-conversion.R (9 K1 entries)

`parse_danish_target()` er i `R/utils_y_axis_scaling.R:470` men IKKE eksporteret (`@keywords internal`). Funktionen er en "legacy wrapper" der **ignorer `y_axis_unit`-parameteret** i den nuværende implementation. De fleste bugs relaterer sig til at `normalize_axis_value()` ikke håndterer unit-aware konvertering korrekt.

| # | Linje | Problem | Foreslået R-fix |
|---|---|---|---|
| 18 | 26 | `parse_danish_target(NULL)` kaster fejl i `normalize_axis_value` if-check | Tilføj `if (is.null(target_input)) return(NULL)` øverst i `parse_danish_target()` |
| 19 | 70 | `y_axis_unit="percent"` ignoreres — returnerer 0.8 i stedet for 80 | Implementér unit-aware skalering i legacy wrapper: multiplicer med 100 for percent-unit |
| 20 | 77 | `y_axis_unit="count"` ignoreres — `parse_danish_target("80", NULL, "count")` returnerer NULL/0 | Tilføj count-path i `normalize_axis_value` eller i wrapper |
| 21 | 84 | Percent-skala y-data detekteres ikke korrekt (c(10,25,60,85) → proportion i stedet for percent) | Fix `detect_unit_from_data()` til at kende forskel på 0-1 og 0-100 skala |
| 22 | 93 | Integer-skala y-data fejldetekteres som proportion | Fix `detect_unit_from_data()` — store heltal skal give "absolute" ikke "proportion" |
| 23 | 100 | Permille-unit ikke understøttet | Tilføj "permille" case i `normalize_axis_value` |
| 24 | 107 | `rate_1000`/`rate_100000` units ikke understøttet | Tilføj rate-units til `normalize_axis_value` som absolutte enheder |
| 25 | 118 | Absolutte domæneenheder (days/hours/grams/kg/dkk) ikke understøttet | Tilføj absolut-group case i `normalize_axis_value` |
| 26 | 139 | `parse_danish_target("50", NULL, NULL)` returnerer NULL i stedet for 50 | Fix `normalize_axis_value` default-path for symbolless tal uden y_data |

**Root cause:** `normalize_axis_value()` (`R/utils_y_axis_scaling.R:391`) mangler unit-aware logik. `parse_danish_target` er en forældet wrapper der ikke videresender `y_axis_unit` korrekt til `normalize_axis_value`.

---

### test-parse-danish-target-unit-conversion.R — manglende funktioner (del af K1 per design)

| # | Linje | Problem | Foreslået R-fix |
|---|---|---|---|
| 27 | 129 | `detect_y_axis_scale()` eksisterer ikke i namespace | Opret ny funktion i `R/utils_y_axis_scaling.R` (wrapper around intern `detect_unit_from_data`) |
| 28 | 134 | `convert_by_unit_type()` eksisterer ikke i namespace | Opret ny funktion i `R/utils_y_axis_scaling.R` til unit-type konvertering |

---

### test-performance-benchmarks.R (5 K1 entries)

| # | Linje | Problem | Foreslået R-fix |
|---|---|---|---|
| 29 | 109 | `generateSPCPlot(data, x_col, y_col, n_col, chart_type)` — gammel API | Test skal opdateres til ny API `generateSPCPlot(data, config, chart_type)` (K3 — se nedenfor). Reelt K3, men skip-besked siger "R-bug" |
| 30 | 171 | `detect_columns_full_analysis()` ikke i namespace | Funktion fins i `R/fct_autodetect_unified.R:309` men mangler `#' @export` → **K2 kandidat** (se tvivlstilfælde) |
| 31 | 184 | `detect_columns_name_based()` ikke i namespace | Funktion fins i `R/fct_autodetect_unified.R:212` men mangler `#' @export` → **K2 kandidat** (se tvivlstilfælde) |
| 32 | 197 | `generateSPCPlot` memory-test — gammel API | Samme som #29: K3 (test-API forkert) |
| 33 | 226 | `generateSPCPlot` reproducerbarhedstest — gammel API | Samme som #29: K3 |

**Se Tvivlstilfælde** for #30 og #31 (kan være K2 i stedet).

---

### test-cache-reactive-lazy-evaluation.R (7 K1 entries)

`create_cached_reactive()` er defineret i `R/utils_performance_caching.R:47` men:
1. Ikke eksporteret (ingen `#' @export`)
2. Kalder `manage_cache_size()` (linje 101) som **ikke er defineret noget sted** i R/ — dette er en reel R-bug

| # | Linje | Problem | Foreslået R-fix |
|---|---|---|---|
| 34 | 33 | `create_cached_reactive()` fejler ved kald pga. `manage_cache_size()` mangler | Implementér `manage_cache_size(limit)` i `R/utils_performance_caching.R` |
| 35 | 59 | Reaktive dependencies reagerer ikke pga. samme bug | Afhænger af #34-fix |
| 36 | 83 | Cache-within-timeout pga. samme bug | Afhænger af #34-fix |
| 37 | 110 | Cache-udløb håndtering pga. samme bug | Afhænger af #34-fix |
| 38 | 137 | Komplekse reaktive udtryk pga. samme bug | Afhænger af #34-fix |
| 39 | 159 | Funktion + udtryk pga. samme bug | Afhænger af #34-fix |
| 40 | 184 | Performance-fordel pga. samme bug | Afhænger af #34-fix |

**Root cause:** Single missing function `manage_cache_size()`. Fix én funktion → alle 7 tests potentielt passérbare (forudsat `create_cached_reactive` eksporteres).

---

### test-cache-collision-fix.R (2 K1 entries)

| # | Linje | Problem | Foreslået R-fix |
|---|---|---|---|
| 41 | 28 | Samme `manage_cache_size` bug som cache-reactive-tests | Afhænger af fix for #34 |
| 42 | 48 | Samme `manage_cache_size` bug | Afhænger af fix for #34 |

---

### test-label-placement-core.R (3 K1 entries)

Disse tests vedrører `BFHcharts:::place_two_labels_npc()` — **ekstern pakke**.

| # | Linje | Problem | Foreslået R-fix |
|---|---|---|---|
| 43 | 49 | `place_two_labels_npc()` validerer ikke `label_height_npc > 0.5` (accepterer i stedet og degraderer) | BFHcharts-eskalering: tilføj `stopifnot(label_height_npc <= 0.5)` i BFHcharts |
| 44 | 257 | NIVEAU 2 fallback (label flip) udløses ikke med dokumenterede parametre | BFHcharts-eskalering: dokumentér og test parametre der udløser NIVEAU 2 |
| 45 | 284 | NIVEAU 3 shelf placement udløses ikke med dokumenterede parametre | BFHcharts-eskalering: dokumentér og test parametre der udløser NIVEAU 3 |

**Bemærkning:** Disse er teknisk BFHcharts-bugs, ikke biSPCharts. De kræver eskalering til BFHcharts-maintainer (jf. CROSS_REPO_COORDINATION.md). De klassificeres K1 fordi de kræver R-kode-ændring (men i ekstern pakke).

---

### test-observer-cleanup.R (2 K1 entries)

| # | Linje | Problem | Foreslået R-fix |
|---|---|---|---|
| 46 | 101 | `testServer(app = function(...))` pattern fejler med shiny v1.7+ — `setup_event_listeners()` kan ikke testes direkte | Refaktorér test til moduleServer-pattern ELLER opret moduleServer-wrapper til setup_event_listeners |
| 47 | 129 | Samme shiny testServer-begrænsning | Afhænger af fix for #46 |

**Vurdering:** Kategoriseret K1 fordi testerne ønsker at teste `setup_event_listeners()` funktionalitet — løsningen kræver enten en R-arkitekturændring (wrapper module) eller at accept at funktionaliteten ikke kan unit-testes direkte.

---

### test-file-upload.R (2 K1 entries)

| # | Linje | Problem | Foreslået R-fix |
|---|---|---|---|
| 48 | 74 | `handle_csv_upload()` læser `app_state$data$current_data` (reactiveValues) uden `isolate()` i `debug_state_change()`-kaldet | Tilføj `shiny::isolate()` rundt om `app_state$data$current_data` i kald til `debug_state_change()` i `R/fct_file_operations.R:587` |
| 49 | 91 | `handle_excel_upload()` har tilsvarende problem med reaktiv kontekst | Undersøg og tilføj `isolate()` i handle_excel_upload tilsvarende |

---

### test-plot-core.R (1 K1 entry)

| # | Linje | Problem | Foreslået R-fix |
|---|---|---|---|
| 50 | 30 | "MR-kort (Moving Range)" er kommenteret ud i `CHART_TYPES_DA` | Uncomment MR-kort linje i `R/config_chart_types.R:32` (og tilsvarende linje 46). Opdatér test til at bruge præcist DA-navn fra CHART_TYPES_DA |

---

### test-e2e-workflows.R (1 K1 entry)

| # | Linje | Problem | Foreslået R-fix |
|---|---|---|---|
| 51 | 160 | `create_chart_validator()` eksisterer ikke | Opret ny funktion i passende R-fil (fx `R/utils_chart_validation.R`) der returnerer list med `validate_chart_data` funktion |

---

## Kategori 2 (NAMESPACE-export) — 0 entries

Ingen rene K2-cases identificeret. Alle undersøgte funktioner der "mangler i namespace" mangler enten selve implementeringen (K1) eller er intentionelt `@keywords internal` (og kræver designbeslutning om eksponering).

---

## Kategori 3 (test-bug) — 10 entries

| # | Fil | Linje | Problem | Foreslået fix |
|---|---|---|---|---|
| 1 | test-parse-danish-target-unit-conversion.R | 129 | Test kalder `detect_y_axis_scale()` som ikke eksisterer — men intern funktion `detect_unit_from_data()` gør det | Omdøb test-assertion til at bruge `detect_unit_from_data` eller accept at ny public function oprettes (→ K1) |
| 2 | test-parse-danish-target-unit-conversion.R | 134 | Test kalder `convert_by_unit_type()` som ikke eksisterer og intet tilsvarende findes | Enten K1 (ny funktion) eller fjern testen. Klassificeret som K1 ovenfor (#28) — medtaget her pga. tvivl |
| 3 | test-performance-benchmarks.R | 109 | Test kalder `generateSPCPlot(data, x_col=..., y_col=..., n_col=..., chart_type=...)` — gammel API. Ny API: `generateSPCPlot(data, config, chart_type, ...)` | Opdatér test til ny API med `config`-parameter |
| 4 | test-performance-benchmarks.R | 150 | Test kalder `cache_startup_data(test_data)` med argument — men ny signatur er `cache_startup_data()` (ingen argumenter) | Ret test: kald `cache_startup_data()` uden argument, og verificér returværdi |
| 5 | test-performance-benchmarks.R | 161 | Test asserter at `load_cached_startup_data()` er hurtigere end `get_hospital_colors()` — men skip-besked siger "benchmark-antagelse er forkert" (load_cached gør fil-I/O) | Fjern testen ELLER opdatér assertion til at teste fil-cache er varmere end computing fra scratch |
| 6 | test-performance-benchmarks.R | 197 | `generateSPCPlot` memory-test — gammel API (se #3) | Opdatér test til ny API |
| 7 | test-performance-benchmarks.R | 226 | `generateSPCPlot` reproducerbarhedstest — gammel API (se #3) | Opdatér test til ny API |
| 8 | test-cache-collision-fix.R | 72 | Test asserter at `create_cached_reactive()` opretter navngivne caches i `.GlobalEnv` — men impl bruger nu `get_session_cache()` (session-scoped) | Fjern GlobalEnv-assertion, opdatér test til at verificere session-scoped caching |
| 9 | test-bfhcharts-integration.R | 146 | Test kalder `BFHcharts::create_spc_chart()` som er fjernet fra BFHcharts namespace. Nuværende API: `BFHcharts::bfh_qic()` + `BFHcharts::get_plot()` | Opdatér test til `BFHcharts::bfh_qic(data, x = Dato, y = Taeller)` |

---

## Tvivlstilfælde

| # | Fil | Linje | Problem | Kandidat-kategorier |
|---|---|---|---|---|
| 1 | test-performance-benchmarks.R | 171 | `detect_columns_full_analysis()` defineret i `R/fct_autodetect_unified.R:309` uden `#' @export`. Skip-besked siger "ikke i namespace". | K2 (add @export) ELLER K1 (funktionen er intern og eksponering kræver designbeslutning). Anbefaling: **K2** — function er public-facing (bruges i tests, dokumenteret) |
| 2 | test-performance-benchmarks.R | 184 | `detect_columns_name_based()` defineret i `R/fct_autodetect_unified.R:212` uden `#' @export`. | K2 ELLER K1 — samme overvejelse som #1. Anbefaling: **K2** |
| 3 | test-observer-cleanup.R | 101 | `testServer(app = ...)` pattern virker ikke i shiny v1.7+. Fix er enten: (a) refaktorér setup_event_listeners til moduleServer-mønster (K1) ELLER (b) wrapp test i moduleServer-test (K3/test-bug). | K1 (R-arkitektur) vs K3 (test skal bruge moduleServer). Anbefaling: **K1** — det er en reel begrænsning i setup_event_listeners der forhindrer testbarhed |
| 4 | test-parse-danish-target-unit-conversion.R | 129+134 | `detect_y_axis_scale` og `convert_by_unit_type` eksisterer ikke. Tests registrerer blot `exists("fn", mode="function")`. Er dette K1 (manglende funktion) eller K3 (test bør kalde intern funktion under andet navn)? | K1 vs K3. Anbefaling: **K1** — tests afspejler intentionel API design. Ny public-facing funktion som façade over interne hjælpere |

---

## Nøgle-observationer

1. **K2 = 0:** Ingen rene NAMESPACE-only cases. Alle "ikke i namespace"-problemer er enten manglende implementering (K1) eller ændret API (K3).

2. **Single root cause for 9 tests:** `manage_cache_size()` mangler i `R/utils_performance_caching.R`. Fix ét sted → fjern 9 TODO-SKIPs (7 fra cache-reactive + 2 fra cache-collision).

3. **State accessors er størst (17 TODOs):** Alle 17 er K1 med samme root cause — `R/utils_state_accessors.R` er delvist implementeret. Der er plads til ~24 nye funktioner som alle er simple get/set wrappers over `app_state$*` sektioner.

4. **BFHcharts-bugs (3 TODOs):** Kræver eskalering til BFHcharts-repo — ikke fixable i biSPCharts direkte.

5. **parse_danish_target (9 K1):** Relateret til én central designfejl — `normalize_axis_value()` er ikke unit-aware og `parse_danish_target()` sender ikke `y_axis_unit` videre korrekt.

6. **generateSPCPlot gammel API (4 K3 + overlap tvivl):** Tests bruger den gamle pre-config signatur. Ny API kræver `config`-parameter. Test-fixes er mekaniske.
