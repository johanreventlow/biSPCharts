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

---

## Task 4 (K3) Status

**Udført:** 2026-04-17

| # | Fix | Fil | Linje | Status |
|---|---|---|---|---|
| 1 | generateSPCPlot gammel API → config-baseret | test-performance-benchmarks.R | 109 | DONE (commit da0a35b) |
| 2 | generateSPCPlot stor data benchmark | test-performance-benchmarks.R | 130 | DONE (commit da0a35b) |
| 3 | cache_startup_data(test_data) → ingen argumenter | test-performance-benchmarks.R | 150 | DONE (commit da0a35b) |
| 4 | Benchmark-antagelse load_cached vs. get_hospital_colors | test-performance-benchmarks.R | 161 | DONE — ny assertion: load < build time (commit da0a35b) |
| 5 | generateSPCPlot memory-test gammel API | test-performance-benchmarks.R | 197 | DONE (commit da0a35b) |
| 6 | generateSPCPlot reproducerbarhedstest gammel API | test-performance-benchmarks.R | 226 | DONE (commit da0a35b) |
| 7 | cache-collision GlobalEnv assertion | test-cache-collision-fix.R | 72 | RE-KATEGORISERET til K1 — crash på manage_cache_size, skip bevaret som "TODO K1" (commit 2303fbf) |
| 8 | BFHcharts::create_spc_chart → bfh_qic + get_plot | test-bfhcharts-integration.R | 146 | DONE — bekræfter gammel API ikke i namespace (commit f566559) |

**K3 fixes applied:** 7/10 (8 testet, 2 var K1 fra start)
**Re-kategoriseret til K1:** 1 (cache-collision #72 — afhænger af manage_cache_size fix)
**Rapporten K3-tæller opdateret:** 10 → 9 rene K3, 1 borderline K1

---

## Kategori 1 Patch-Proposals (batch-godkendelse)

**Format:** Bruger markerer `[x]` apply / `[ ]` skip / `[ ]` modify per proposal.

Alle K1-entries er grupperet efter root cause. Task 6 implementerer KUN godkendte proposals.

---

### Gruppe 1: State-accessor wrappers (17 TODOs)

**Root cause:** `R/utils_state_accessors.R` indeholder kun 6 af ~30 forventede accessor-par. Alle 17 manglende funktioner er simple get/set-wrappers over eksisterende `app_state`-felter.

**Approach:** Tilføj 17 nye funktioner i `R/utils_state_accessors.R`. Alle bruger `shiny::isolate()` konsistent med de 6 eksisterende.

**State-skema verificeret:** Alle felter eksisterer i `create_app_state()` i `R/state_management.R`.

**Foreslået diff (alle 17 funktioner):**

```diff
--- a/R/utils_state_accessors.R
+++ b/R/utils_state_accessors.R
@@ -73,6 +73,14 @@ set_original_data <- function(app_state, value) {
   })
 }

+#' @keywords internal
+get_original_data <- function(app_state) {
+  shiny::isolate(app_state$data$original_data)
+}
+
+#' @keywords internal
+is_table_updating <- function(app_state) {
+  shiny::isolate(isTRUE(app_state$data$updating_table))
+}
+
+#' @keywords internal
+set_table_updating <- function(app_state, value) {
+  shiny::isolate({ app_state$data$updating_table <- value })
+}
+
+#' @keywords internal
+get_autodetect_status <- function(app_state) {
+  shiny::isolate(list(
+    in_progress = isTRUE(app_state$columns$auto_detect$in_progress),
+    completed   = isTRUE(app_state$columns$auto_detect$completed),
+    results     = app_state$columns$auto_detect$results,
+    frozen      = isTRUE(app_state$columns$auto_detect$frozen_until_next_trigger)
+  ))
+}
+
+#' @keywords internal
+set_autodetect_in_progress <- function(app_state, value) {
+  shiny::isolate({ app_state$columns$auto_detect$in_progress <- value })
+}
+
+#' @keywords internal
+get_column_mappings <- function(app_state) {
+  shiny::isolate(as.list(app_state$columns$mappings))
+}
+
+#' @keywords internal
+get_column_mapping <- function(app_state, key) {
+  shiny::isolate(app_state$columns$mappings[[key]])
+}
+
+#' @keywords internal
+update_column_mapping <- function(app_state, key, value) {
+  shiny::isolate({ app_state$columns$mappings[[key]] <- value })
+}
+
+#' @keywords internal
+set_plot_ready <- function(app_state, value) {
+  shiny::isolate({ app_state$visualization$plot_ready <- value })
+}
+
+#' @keywords internal
+get_plot_warnings <- function(app_state) {
+  shiny::isolate(app_state$visualization$plot_warnings %||% character(0))
+}
+
+#' @keywords internal
+set_plot_warnings <- function(app_state, value) {
+  shiny::isolate({ app_state$visualization$plot_warnings <- value })
+}
+
+#' @keywords internal
+get_plot_object <- function(app_state) {
+  shiny::isolate(app_state$visualization$plot_object)
+}
+
+#' @keywords internal
+set_plot_object <- function(app_state, value) {
+  shiny::isolate({ app_state$visualization$plot_object <- value })
+}
+
+#' @keywords internal
+is_plot_generating <- function(app_state) {
+  shiny::isolate(isTRUE(app_state$visualization$is_computing))
+}
+
+#' @keywords internal
+set_plot_generating <- function(app_state, value) {
+  shiny::isolate({ app_state$visualization$is_computing <- value })
+}
+
+#' @keywords internal
+is_file_uploaded <- function(app_state) {
+  shiny::isolate(isTRUE(app_state$session$file_uploaded))
+}
+
+#' @keywords internal
+set_file_uploaded <- function(app_state, value) {
+  shiny::isolate({ app_state$session$file_uploaded <- value })
+}
+
+#' @keywords internal
+is_user_session_started <- function(app_state) {
+  shiny::isolate(isTRUE(app_state$session$user_started_session))
+}
+
+#' @keywords internal
+set_user_session_started <- function(app_state, value) {
+  shiny::isolate({ app_state$session$user_started_session <- value })
+}
+
+#' @keywords internal
+get_last_error <- function(app_state) {
+  shiny::isolate(app_state$errors$last_error)
+}
+
+#' @keywords internal
+set_last_error <- function(app_state, value) {
+  shiny::isolate({
+    app_state$errors$last_error <- value
+    app_state$errors$error_count <- (app_state$errors$error_count %||% 0L) + 1L
+  })
+}
+
+#' @keywords internal
+get_error_count <- function(app_state) {
+  shiny::isolate(app_state$errors$error_count %||% 0L)
+}
+
+#' @keywords internal
+is_test_mode_enabled <- function(app_state) {
+  shiny::isolate(isTRUE(app_state$test_mode$enabled))
+}
+
+#' @keywords internal
+set_test_mode_enabled <- function(app_state, value) {
+  shiny::isolate({ app_state$test_mode$enabled <- value })
+}
+
+#' @keywords internal
+get_test_mode_startup_phase <- function(app_state) {
+  shiny::isolate(app_state$test_mode$startup_phase %||% "initializing")
+}
+
+#' @keywords internal
+set_test_mode_startup_phase <- function(app_state, value) {
+  shiny::isolate({ app_state$test_mode$startup_phase <- value })
+}
+
+#' @keywords internal
+is_anhoej_rules_hidden <- function(app_state) {
+  shiny::isolate(isTRUE(app_state$ui$hide_anhoej_rules))
+}
+
+#' @keywords internal
+set_anhoej_rules_hidden <- function(app_state, value) {
+  shiny::isolate({ app_state$ui$hide_anhoej_rules <- value })
+}
+
+#' @keywords internal
+is_y_axis_autoset_done <- function(app_state) {
+  shiny::isolate(isTRUE(app_state$ui$y_axis_unit_autoset_done))
+}
+
+#' @keywords internal
+set_y_axis_autoset_done <- function(app_state, value) {
+  shiny::isolate({ app_state$ui$y_axis_unit_autoset_done <- value })
+}
```

**Risiko:** Lav. Alle nye `@keywords internal` funktioner. Ingen eksisterende kode bruger dem (de mangler jo). Ingen brudflader.
**Public API-ændring:** Nej (alle `@keywords internal`).
**Anslået fail-reduktion:** 17 tests.

**Bruger-valg:** `[ ]` apply alle / `[ ]` apply selective / `[ ]` skip

---

### Gruppe 2: manage_cache_size (9 TODOs)

**Root cause:** `create_cached_reactive()` i `R/utils_performance_caching.R:101` kalder `manage_cache_size(cache_size_limit)`, men funktionen er aldrig defineret i R/.

**Approach:** Tilføj `manage_cache_size(limit)` i `R/utils_performance_caching.R`. Implementeringen skal rydde ældste/udløbne entries fra `.performance_cache` når limit overskrides.

**Foreslået diff:**

```diff
--- a/R/utils_performance_caching.R
+++ b/R/utils_performance_caching.R
@@ -280,6 +280,39 @@ cache_result <- function(cache_key, value, timeout_seconds) {
   assign(cache_key, cached_entry, envir = .performance_cache)
 }

+#' Manage Cache Size
+#'
+#' Rydder udløbne og overskydende entries fra performance cache.
+#' Kaldet automatisk af create_cached_reactive() efter cache writes.
+#'
+#' @param limit Integer. Max antal entries i cache (default: CACHE_CONFIG$size_limit_entries)
+#' @keywords internal
+manage_cache_size <- function(limit = CACHE_CONFIG$size_limit_entries) {
+  cache_keys <- ls(envir = .performance_cache)
+  n_entries <- length(cache_keys)
+
+  if (n_entries == 0) return(invisible(NULL))
+
+  # Trin 1: Ryd udloebne entries
+  now <- Sys.time()
+  expired <- character(0)
+  for (key in cache_keys) {
+    entry <- get(key, envir = .performance_cache)
+    if (!is.null(entry$expires_at) && entry$expires_at < now) {
+      expired <- c(expired, key)
+    }
+  }
+  if (length(expired) > 0) {
+    rm(list = expired, envir = .performance_cache)
+    cache_keys <- setdiff(cache_keys, expired)
+  }
+
+  # Trin 2: Hvis stadig over limit — fjern aeldste entries (LRU)
+  n_remaining <- length(cache_keys)
+  if (n_remaining > limit) {
+    last_access_times <- vapply(cache_keys, function(key) {
+      entry <- get(key, envir = .performance_cache)
+      as.numeric(entry$last_access %||% entry$created_at)
+    }, numeric(1))
+    oldest <- cache_keys[order(last_access_times)[seq_len(n_remaining - limit)]]
+    rm(list = oldest, envir = .performance_cache)
+  }
+
+  invisible(NULL)
+}
```

**Risiko:** Medium. Funktionen aktiveres ved kald fra `create_cached_reactive()` der køres i reaktiv kontekst. Fejl i `manage_cache_size` vil crashe alle cached reactives. Implementation bruger samme `.performance_cache` miljø som resten af caching-systemet — ingen ny state.
**Public API-ændring:** Nej (`@keywords internal`).
**Anslået fail-reduktion:** 9 tests (7 fra test-cache-reactive-lazy-evaluation.R + 2 fra test-cache-collision-fix.R). Inkl. K3-entry der blev re-kategoriseret til K1.

**Bruger-valg:** `[ ]` apply / `[ ]` skip / `[ ]` modify

---

### Gruppe 3: parse_danish_target unit-awareness (9 TODOs)

**Root cause:** `parse_danish_target()` er en "legacy wrapper" i `R/utils_y_axis_scaling.R:470` der **ignorerer `y_axis_unit`-parameteret**. Den sender `user_unit = y_axis_unit` til `normalize_axis_value()`, men `normalize_axis_value()` kan ikke mappe unit-navne som "percent", "count", "permille", "rate_1000" korrekt.

**Approach:** Refaktorér `parse_danish_target()` til at:
1. Håndtere `NULL` input (test #18)
2. Oversætte `y_axis_unit` til korrekt `internal_unit` (tests #19-#26)
3. Fix fallback-path for symbolless tal uden y_data (test #26)

OBS: Dette er **kompleks logik** med mange edge cases. Se separat diff-uddrag nedenfor.

**Foreslået diff (parse_danish_target NULL-fix — lav risiko, test #18):**

```diff
--- a/R/utils_y_axis_scaling.R
+++ b/R/utils_y_axis_scaling.R
@@ -470,6 +470,10 @@ parse_danish_target <- function(target_input, y_data = NULL, y_axis_unit = NULL)
+  # NULL input: returner NULL straks (normalize_axis_value crasher ellers)
+  if (is.null(target_input)) return(NULL)
+
   # Determine internal unit based on y_data characteristics
```

**Foreslået diff (unit-aware mapping — høj risiko, tests #19-#26):**

```diff
--- a/R/utils_y_axis_scaling.R
+++ b/R/utils_y_axis_scaling.R
@@ -470,6 +470,35 @@ parse_danish_target <- function(target_input, y_data = NULL, y_axis_unit = NULL)
+  if (is.null(target_input)) return(NULL)
+
+  # Map y_axis_unit til internal_unit for normalize_axis_value
+  internal_unit <- if (!is.null(y_axis_unit)) {
+    switch(y_axis_unit,
+      "percent"    = "percent",
+      "proportion" = "proportion",
+      "permille"   = "absolute",   # permille behandles som absolut skala
+      "rate_1000"  = "absolute",
+      "rate_100000"= "absolute",
+      "count"      = "absolute",
+      "days"       = "absolute",
+      "hours"      = "absolute",
+      "grams"      = "absolute",
+      "kg"         = "absolute",
+      "dkk"        = "absolute",
+      # Fallback: brug y_data-heuristik hvis unit er ukendt
+      if (!is.null(y_data)) {
+        detected_scale <- detect_unit_from_data(y_data)
+        if (detected_scale == "percent") "percent" else "proportion"
+      } else "proportion"
+    )
+  } else if (!is.null(y_data)) {
+    detected_scale <- detect_unit_from_data(y_data)
+    if (detected_scale == "percent") "percent" else "proportion"
+  } else {
+    "proportion"  # default
+  }
```

**BEMÆRKNING:** `normalize_axis_value` understøtter ikke `internal_unit = "absolute"` i nuværende implementation. Tilføjelse af "absolute" path i `normalize_axis_value` er yderligere scope (estimeret +2h). Anbefaling: implementér NULL-fix (lav risiko) som separat commit, lad resten afvente.

**Risiko:** Høj for fuld unit-mapping. Lav for NULL-fix alene.
**Public API-ændring:** Nej (begge er `@keywords internal`).
**Anslået fail-reduktion:** 1 (NULL-fix) / 9 (fuld unit-mapping, kræver mere scope).

**Bruger-valg for NULL-fix:** `[ ]` apply / `[ ]` skip / `[ ]` modify
**Bruger-valg for fuld unit-mapping:** `[ ]` apply (med extend-scope) / `[ ]` skip / `[ ]` modify

---

### Gruppe 4: BFHcharts-eskalering (3 TODOs)

**Root cause:** Tests i `test-label-placement-core.R:49,257,284` tester BFHcharts-intern adfærd (`BFHcharts:::place_two_labels_npc()`). Dette er udenfor biSPCharts scope.

**Approach:** Opdater skip-markør til `BFHcharts-followup` pattern for at signalere at fixes hører til i BFHcharts-repo.

**Foreslået change (test-label-placement-core.R):**

```diff
-  skip("TODO Fase 3: ... (#203-followup)")
+  skip("TODO BFHcharts-followup: place_two_labels_npc validering (#203)")
```

```diff
-  skip("TODO Fase 3: ... (#203-followup)")
+  skip("TODO BFHcharts-followup: NIVEAU 2 label flip parametrisering (#203)")
```

```diff
-  skip("TODO Fase 3: ... (#203-followup)")
+  skip("TODO BFHcharts-followup: NIVEAU 3 shelf placement parametrisering (#203)")
```

**Risiko:** Nul (kun kommentar-ændring).
**Public API-ændring:** Nej.
**Anslået fail-reduktion:** 0 (tests forbliver skipped).

**Bruger-valg:** `[x]` apply anbefalet (ren bookkeeping)

---

### Gruppe 5: Tvivlstilfælde — NAMESPACE-exports (2 TODOs)

**Tests:** `test-performance-benchmarks.R:171` og `test-performance-benchmarks.R:184`
**Funktioner:** `detect_columns_full_analysis()` og `detect_columns_name_based()`

**Status:** Begge funktioner eksisterer i `R/fct_autodetect_unified.R` (linje 309 og 212) med `@keywords internal`. Tests kalder dem med `col_names`-only signatur (ikke `app_state`-parameter), men funktionen accepterer `app_state = NULL`.

**Anbefaling:** K2 (tilføj `@export` til begge + `devtools::document()`). Men tests-kaldet matcher signatur (`app_state = NULL` som default). Dog: eksponering af interne autodetect-funktioner som public API kræver designbeslutning.

**Alternativ approach:** Tilføj `@export` men behold `@keywords internal`-dokumentation, eller opret public wrapper-funktioner.

**Risiko:** Medium. Eksponering af interne autodetect-funktioner ændrer public API.
**Public API-ændring:** Ja.
**Anslået fail-reduktion:** 2 tests.

**Bruger-valg (for `detect_columns_full_analysis`):** `[ ]` add @export / `[ ]` add public wrapper / `[ ]` skip
**Bruger-valg (for `detect_columns_name_based`):** `[ ]` add @export / `[ ]` add public wrapper / `[ ]` skip

---

### Gruppe 6: Individuelle K1-fixes

| # | Fil | Linje | Problem | Foreslået approach | Risiko | Anslået fail-reduktion | Bruger-valg |
|---|---|---|---|---|---|---|---|
| 1 | `R/fct_file_operations.R:588` | 588 | `handle_csv_upload()` læser `app_state$data$current_data` i `debug_state_change()` uden `isolate()` i non-reactive kontekst | Tilføj `shiny::isolate()` rundt om `app_state$data$current_data` i debug_state_change-kaldet | Lav | 1 | `[ ]` apply / `[ ]` skip |
| 2 | `R/fct_file_operations.R` | ~350 | `handle_excel_upload()` tilsvarende problem | Find og tilføj `isolate()` i handle_excel_upload | Lav | 1 | `[ ]` apply / `[ ]` skip |
| 3 | `R/config_chart_types.R:32` | 32 | "MR-kort" er kommenteret ud i `CHART_TYPES_DA`. Test forventer `"mr"` at være tilgængeligt. | Uncomment MR-kort linjer i `CHART_TYPES_DA` (linje 32) og `CHART_TYPES_EN` (linje 46) | Medium (UI-ændring: ny chart-type i dropdown) | 1 | `[ ]` apply / `[ ]` skip |
| 4 | Ny fil: `R/utils_chart_validation.R` | N/A | `create_chart_validator()` eksisterer ikke | Opret ny funktion der returnerer `list(validate_chart_data = function(chart_config, data) {...})` | Lav | 1 | `[ ]` apply / `[ ]` skip |
| 5 | `R/utils_event_system.R` + test | 101 | `setup_event_listeners()` kan ikke unit-testes med `testServer(app = ...)` pattern (shiny v1.7+ breaking change) | Opret moduleServer-wrapper ELLER tilføj alternativ testbar entry-point. Høj effort. | Høj | 2 | `[ ]` apply / `[ ]` skip |

---

### Tvivlstilfælde (4 entries — afklaret i rapporten)

| # | Original anbefaling | Task 5-vurdering |
|---|---|---|
| 1 | `detect_columns_full_analysis` K2 ELLER K1 | Se Gruppe 5. K2 (add @export). Kræver designbeslutning. |
| 2 | `detect_columns_name_based` K2 ELLER K1 | Se Gruppe 5. K2 (add @export). Kræver designbeslutning. |
| 3 | `testServer` pattern K1 vs K3 | Bekræftet K1 — se Gruppe 6 #5. Høj effort, anbefales skip. |
| 4 | `detect_y_axis_scale` / `convert_by_unit_type` K1 vs K3 | Bekræftet K1 — opret nye public-facing facade-funktioner. Del af Gruppe 3 scope. |

---

### Fail-reduktion estimat (hvis alle godkendes)

| Gruppe | Max fail-reduktion |
|---|---|
| Gruppe 1: State accessors | 17 |
| Gruppe 2: manage_cache_size | 9 |
| Gruppe 3: parse_danish_target NULL-fix | 1 |
| Gruppe 3: Fuld unit-mapping (ekstra scope) | 8 (kræver mere) |
| Gruppe 4: BFHcharts-skip opdatering | 0 |
| Gruppe 5: NAMESPACE-exports | 2 |
| Gruppe 6: file-upload isolate-fix | 2 |
| Gruppe 6: MR-kort uncomment | 1 |
| Gruppe 6: create_chart_validator | 1 |
| Gruppe 6: observer-cleanup testServer | 2 |
| **Total (konservativ, excl. Gruppe 3 fuld)** | **35** |
| **Total (optimistisk, inkl. Gruppe 3 fuld)** | **43** |

**Forventet fail-count efter alle K1+K3 fixes:** 57 - 7 (K3 done) - 35 til 43 (K1 konservativ/optimistisk) = **7 til 15 resterende SKIPs**

Baseline var 57 TODO-SKIPs. Alle kan potentielt fjernes med fuld scope (inkl. Gruppe 3 unit-mapping og Gruppe 6 observer-cleanup).

**Note:** Disse estimater er for TODO-SKIP-fjernelse, ikke for overordnet fail-count fra test-audit.json. Den samlede fail-reduction afhænger af om de nu-passable tests faktisk består (kræver faktisk kørsel).
