# Audit: Anhøj Derivation Call-Sites

Genereret: 2026-04-26
Formål: Kortlæg duplikeret Anhøj-logik (jf. OpenSpec `extract-anhoej-derivation-pure`)

---

## Call-sites

### Site 1 — `mod_spc_chart_compute.R` linje 193–220 (primær compute-observer)

```r
runs_sig <- if ("runs.signal" %in% names(qic_data)) any(qic_data$runs.signal, na.rm = TRUE) else FALSE

crossings_sig <- if ("n.crossings" %in% names(qic_data) && "n.crossings.min" %in% names(qic_data)) {
  n_cross <- safe_max(qic_data$n.crossings)
  n_cross_min <- safe_max(qic_data$n.crossings.min)
  !is.na(n_cross) && !is.na(n_cross_min) && n_cross < n_cross_min
} else { FALSE }

qic_results <- list(
  any_signal = any(qic_data$sigma.signal, na.rm = TRUE),
  out_of_control_count = count_outliers_latest_part(qic_data),
  runs_signal = runs_sig, crossings_signal = crossings_sig,
  anhoej_signal = runs_sig || crossings_sig,
  longest_run = if ("longest.run" %in% names(qic_data)) safe_max(qic_data$longest.run) else NA_real_,
  longest_run_max = if ("longest.run.max" %in% names(qic_data)) safe_max(qic_data$longest.run.max) else NA_real_,
  n_crossings = if ("n.crossings" %in% names(qic_data)) safe_max(qic_data$n.crossings) else NA_real_,
  n_crossings_min = if ("n.crossings.min" %in% names(qic_data)) safe_max(qic_data$n.crossings.min) else NA_real_,
  message = if (inputs$chart_type == "run") { ... } else { ... }
)
update_anhoej_results(current, qic_results, centerline_changed, qic_data, show_phases)
```

**Særtræk:** Har `message`-felt (chart_type-afhængigt). Bruger `safe_max()`.

---

### Site 2 — `mod_spc_chart_compute.R` linje 410–431 (`register_cache_aware_observer`)

Identisk logik med site 1. **Mangler `message`-felt.** Bruger `safe_max()`.

```r
runs_sig <- if ("runs.signal" %in% names(qic_data)) any(qic_data$runs.signal, na.rm = TRUE) else FALSE
crossings_sig <- if (...) { safe_max() ... } else { FALSE }
qic_results <- list(
  any_signal = any(qic_data$sigma.signal, na.rm = TRUE),
  out_of_control_count = count_outliers_latest_part(qic_data),
  runs_signal = runs_sig, crossings_signal = crossings_sig,
  anhoej_signal = runs_sig || crossings_sig,
  longest_run = ..., longest_run_max = ..., n_crossings = ..., n_crossings_min = ...
  # INGEN message
)
update_anhoej_results(current, qic_results, centerline_changed = FALSE, qic_data, show_phases)
```

---

### Site 3 — `utils_anhoej_results.R` linje 51–84 (inde i `update_anhoej_results`)

Re-derivation ved `show_phases = TRUE`:

```r
qic_data_filtered <- filter_latest_part(qic_data, show_phases)
qic_results$longest_run    <- max(qic_data_filtered$longest.run, na.rm = TRUE)
qic_results$longest_run_max<- max(qic_data_filtered$longest.run.max, na.rm = TRUE)
qic_results$n_crossings    <- max(qic_data_filtered$n.crossings, na.rm = TRUE)
qic_results$n_crossings_min<- max(qic_data_filtered$n.crossings.min, na.rm = TRUE)
qic_results$runs_signal    <- any(qic_data_filtered$runs.signal, na.rm = TRUE)
n_cross <- max(qic_data_filtered$n.crossings, na.rm = TRUE)
n_cross_min <- max(qic_data_filtered$n.crossings.min, na.rm = TRUE)
qic_results$crossings_signal <- !is.na(n_cross) && !is.na(n_cross_min) && n_cross < n_cross_min
qic_results$anhoej_signal <- (qic_results$runs_signal %||% FALSE) || (qic_results$crossings_signal %||% FALSE)
```

**Særtræk:** Bruger `max()` i stedet for `safe_max()`. Ingen `special_cause_points`.

---

## Divergenser

| Aspekt | Site 1 | Site 2 | Site 3 |
|--------|--------|--------|--------|
| Scalar-ekstraktion | `safe_max()` | `safe_max()` | `max()` |
| Fase-filtrering | Nej (delegerer til update) | Nej (delegerer til update) | Ja (ejer filtrering) |
| `message`-felt | Ja | Nej | Nej |
| `special_cause_points` | Nej | Nej | Nej |
| `data_points_used` | Nej | Nej | Nej |

**Funktionel ækvivalens for `safe_max()` vs `max()`:** Anhøj-kolonner
(`n.crossings`, `longest.run` etc.) er konstante per chart-beregning (qicharts2
garanterer én unik værdi per kolonne). Derfor er `safe_max()` og `max()` 
funktionelt ækvivalente — `safe_max()` tilføjer kun NA-sikkerhed ved edge cases
(tom vektor, alle NA, uendeligt).

**Konklusion:** De tre sites er semantisk ækvivalente for ikke-tomme datasæt.
`derive_anhoej_results()` bruger `safe_max()`-semantik for at bevare edge-case-sikkerhed.

---

## Plan

`derive_anhoej_results(qic_data, show_phases = FALSE)` konsoliderer site 1, 2 og 3:
- Kalder `filter_latest_part()` internt
- Returnerer alle Anhøj-metrics (runs_signal, crossings_signal, anhoej_signal,
  longest_run, longest_run_max, n_crossings, n_crossings_min, special_cause_points,
  data_points_used)
- Ingen Shiny-afhængighed, ingen side-effekter, ingen `message`

Callers bygger selv `qic_results` med `any_signal`, `out_of_control_count`, `message`
og kalder derefter `update_anhoej_results(previous, qic_results, centerline_changed)`
(forenklet — `qic_data` og `show_phases` parametrene fjernes).
