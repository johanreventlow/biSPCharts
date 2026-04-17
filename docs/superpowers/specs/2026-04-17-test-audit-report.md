# Test Audit Report

**Dato:** 2026-04-17T16:32:41+0200
**biSPCharts version:** 0.2.0
**R version:** 4.5.2
**Total filer:** 125
**Total koerselstid:** 259.3 s

---

## Executive Summary

| Kategori | Antal | % af total |
|----------|-------|-----------|
| `broken-missing-fn` | 4 | 3.2% |
| `green` | 48 | 38.4% |
| `green-partial` | 62 | 49.6% |
| `skipped-all` | 2 | 1.6% |
| `stub` | 9 | 7.2% |

---

## Top-10 Manglende R-funktioner

| Funktion | Antal filer |
|----------|-------------|
| `validate_column_exists` | 2 |
| `validate_config_value` | 2 |
| `validate_data_or_return` | 2 |
| `validate_function_exists` | 2 |
| `validate_state_transition` | 2 |
| `value_or_default` | 2 |
| `appears_date` | 1 |
| `appears_numeric` | 1 |
| `apply_metadata_update` | 1 |
| `calculate_plot_data_hash` | 1 |

---

## Kategori: `broken-missing-fn` (4 filer)

### `test-panel-height-cache.R`
- LOC: 163
- Test-blokke: 4
- Pass/Fail/Skip: 0 / 4 / 0
- Manglende funktioner: `clear_panel_height_cache`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `clear_panel_height_cache()`: could not find function "clear_panel_height_cache"
Error in `clear_panel_height_cache()`: could not find function "clear_panel_height_cache"
Error in `clear_panel_height_cache()`: could not find function "clear_panel_height_cache"
Error in `clear_panel_height_cache()`: could not find function "clear_panel_height_
```

### `test-plot-diff.R`
- LOC: 321
- Test-blokke: 24
- Pass/Fail/Skip: 0 / 24 / 0
- Manglende funktioner: `calculate_plot_metadata_hash`, `calculate_plot_data_hash`, `detect_plot_update_type`, `identify_changed_metadata_fields`, `apply_metadata_update`, `create_plot_state_snapshot`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `calculate_plot_metadata_hash(metadata)`: could not find function "calculate_plot_metadata_hash"
Error in `calculate_plot_metadata_hash(metadata1)`: could not find function "calculate_plot_metadata_hash"
Error in `calculate_plot_metadata_hash(metadata1)`: could not find function "calculate_plot_metadata_hash"
Error in `calculate_plot_data_has
```

### `test-utils_validation_guards.R`
- LOC: 182
- Test-blokke: 27
- Pass/Fail/Skip: 0 / 27 / 0
- Manglende funktioner: `validate_data_or_return`, `value_or_default`, `validate_column_exists`, `validate_function_exists`, `validate_config_value`, `validate_state_transition`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `validate_data_or_return(df)`: could not find function "validate_data_or_return"
Error in `validate_data_or_return(NULL)`: could not find function "validate_data_or_return"
Error in `validate_data_or_return(list(a = 1))`: could not find function "validate_data_or_return"
Error in `validate_data_or_return(df, min_rows = 3)`: could not find fun
```

### `test-validation-guards.R`
- LOC: 302
- Test-blokke: 29
- Pass/Fail/Skip: 0 / 29 / 0
- Manglende funktioner: `validate_data_or_return`, `value_or_default`, `validate_column_exists`, `validate_function_exists`, `validate_config_value`, `validate_reactive_value`, `validate_state_transition`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `validate_data_or_return(NULL, fallback = data.frame())`: could not find function "validate_data_or_return"
Error in `validate_data_or_return(test_data, min_rows = 3, fallback = NULL)`: could not find function "validate_data_or_return"
Error in `validate_data_or_return(test_data, min_cols = 2, fallback = NULL)`: could not find function "valid
```

---

## Kategori: `green-partial` (62 filer)

### `test-100x-mismatch-prevention.R`
- LOC: 383
- Test-blokke: 17
- Pass/Fail/Skip: 47 / 5 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Loading required package: shiny
Error in `eval_bare(expr, quo_get_env(quo))`: attempt to apply non-function
```

### `test-app-initialization.R`
- LOC: 66
- Test-blokke: 4
- Pass/Fail/Skip: 9 / 1 / 3

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-autodetect-unified-comprehensive.R`
- LOC: 1061
- Test-blokke: 31
- Pass/Fail/Skip: 138 / 20 / 0
- Manglende funktioner: `appears_date`, `appears_numeric`, `detect_columns_with_cache`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Loading required package: shiny
Error in `app_state$columns$auto_detect$last_run$trigger`: $ operator is invalid for atomic vectors
Error in `app_state$columns$auto_detect$last_run$trigger`: $ operator is invalid for atomic vectors
Error in `app_state$columns$auto_detect$last_run$data_rows`: $ operator is invalid for atomic vectors
Error in `appears_d
```

### `test-bfh-error-handling.R`
- LOC: 358
- Test-blokke: 18
- Pass/Fail/Skip: 36 / 6 / 0
- Manglende funktioner: `sanitize_log_details`, `log_with_throttle`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `sanitize_log_details(details)`: could not find function "sanitize_log_details"
Error in `sanitize_log_details(NULL)`: could not find function "sanitize_log_details"
Error in `log_with_throttle("test_key", interval_sec = 1, log_fn = mock_log_fn, "Test message")`: could not find function "log_with_throttle"
Error in `log_with_throttle("key", 6
```

### `test-bfhcharts-integration.R`
- LOC: 157
- Test-blokke: 5
- Pass/Fail/Skip: 5 / 10 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error: 'spc_plot_config' is not an exported object from 'namespace:BFHcharts'
```

### `test-cache-collision-fix.R`
- LOC: 144
- Test-blokke: 4
- Pass/Fail/Skip: 1 / 4 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `.getReactiveEnvironment()$currentContext()`: Operation not allowed without an active reactive context.
* You tried to do something that can only be done from inside a reactive consumer.
Error in `.getReactiveEnvironment()$currentContext()`: Operation not allowed without an active reactive context.
* You tried to do something that can only be
```

### `test-cache-data-signature-bugs.R`
- LOC: 351
- Test-blokke: 13
- Pass/Fail/Skip: 23 / 2 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `expect_lt(timing["elapsed"], 0.1, info = "Signature generation should be fast even for large data")`: unused argument (info = "Signature generation should be fast even for large data")
```

### `test-cache-invalidation-sprint3.R`
- LOC: 184
- Test-blokke: 10
- Pass/Fail/Skip: 61 / 1 / 0
- Manglende funktioner: `get_cache_stats`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `get_cache_stats()`: could not find function "get_cache_stats"
```

### `test-cache-reactive-lazy-evaluation.R`
- LOC: 258
- Test-blokke: 7
- Pass/Fail/Skip: 1 / 7 / 0
- Manglende funktioner: `manage_cache_size`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `manage_cache_size(cache_size_limit)`: could not find function "manage_cache_size"
Error in `manage_cache_size(cache_size_limit)`: could not find function "manage_cache_size"
Error in `manage_cache_size(cache_size_limit)`: could not find function "manage_cache_size"
Error in `manage_cache_size(cache_size_limit)`: could not find function "mana
```

### `test-column-observer-consolidation.R`
- LOC: 183
- Test-blokke: 11
- Pass/Fail/Skip: 10 / 4 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in ``*tmp*`$mappings`: Can't access reactive value 'mappings' outside of reactive consumer.
i Do you need to wrap inside reactive() or observe()?
Error in ``*tmp*`$mappings`: Can't access reactive value 'mappings' outside of reactive consumer.
i Do you need to wrap inside reactive() or observe()?
Error in ``*tmp*`$mappings`: Can't access reactiv
```

### `test-config_chart_types.R`
- LOC: 61
- Test-blokke: 7
- Pass/Fail/Skip: 19 / 16 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-config_export.R`
- LOC: 404
- Test-blokke: 26
- Pass/Fail/Skip: 131 / 10 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `eval(code, test_env)`: object 'EXPORT_PDF_CONFIG' not found
Error in `eval(code, test_env)`: object 'EXPORT_PDF_CONFIG' not found
Error in `eval(code, test_env)`: object 'EXPORT_PNG_CONFIG' not found
Error in `eval(code, test_env)`: object 'EXPORT_PDF_CONFIG' not found
```

### `test-constants-architecture.R`
- LOC: 219
- Test-blokke: 10
- Pass/Fail/Skip: 0 / 1 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
```

### `test-context-aware-plots.R`
- LOC: 355
- Test-blokke: 20
- Pass/Fail/Skip: 79 / 4 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for
```

### `test-critical-fixes-integration.R`
- LOC: 373
- Test-blokke: 6
- Pass/Fail/Skip: 39 / 4 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
<rlib_error_dots_nonempty/rlib_error_dots/rlang_error/error/condition>
Error in `expect_no_error({     observeEvent(test_val(), priority = priority_high(), {     })     observeEvent(test_val(), priority = get_priority("AUTO_DETECT"), {     })     observeEvent(test_val(), priority = priority_cleanup(), {     }) }, info = "Helper functions should work i
```

### `test-critical-fixes-regression.R`
- LOC: 494
- Test-blokke: 14
- Pass/Fail/Skip: 123 / 14 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
[LOG_CONFIG] Log level set to DEBUG (development mode)
[LOG_CONFIG] Log level set to WARN (production mode)
[LOG_CONFIG] Log level set to ERROR (quiet mode)
[LOG_CONFIG] Log level set to INFO
<rlib_error_dots_nonempty/rlib_error_dots/rlang_error/error/condition>
Error in `expect_no_error({     log_warn("Simple warning uden details")     log_info("Simp
```

### `test-critical-fixes-security.R`
- LOC: 318
- Test-blokke: 8
- Pass/Fail/Skip: 42 / 21 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `expect_lt(duration, time_threshold, info = sprintf("500 structured log calls should complete within %.1fs on %s (actual: %.2fs)", time_threshold, environment_label, duration))`: unused argument (info = sprintf("500 structured log calls should complete within %.1fs on %s (actual: %.2fs)", time_threshold, environment_label, duration))
<rlib_er
```

### `test-data-validation.R`
- LOC: 119
- Test-blokke: 5
- Pass/Fail/Skip: 12 / 3 / 2
- Manglende funktioner: `validate_date_column`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `validate_date_column(test_data, "dato_valid")`: could not find function "validate_date_column"
```

### `test-e2e-workflows.R`
- LOC: 332
- Test-blokke: 4
- Pass/Fail/Skip: 3 / 5 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `app_state$data$current_data`: Can't access reactive value 'current_data' outside of reactive consumer.
i Do you need to wrap inside reactive() or observe()?
<rlib_error_dots_nonempty/rlib_error_dots/rlang_error/error/condition>
Error in `expect_no_error(test_function(), info = paste("Error recovery scenario:", scenario_name))`: `...` must be
```

### `test-edge-cases-comprehensive.R`
- LOC: 668
- Test-blokke: 36
- Pass/Fail/Skip: 63 / 3 / 2

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2

Attaching package: 'readr'

The following objects are masked from 'package:testthat':

    edition_get, local_edition

i Using "','" as decimal and "'.'" as grouping mark. Use `read_delim()` for more control.
i Using "','" as decimal and "'.'" as grouping mark. Use `read_delim()` for more control.
i Using "','" as decimal and "'.'" as grouping mark. 
```

### `test-event-system-emit.R`
- LOC: 238
- Test-blokke: 9
- Pass/Fail/Skip: 43 / 7 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Loading required package: shiny
```

### `test-event-system-observers.R`
- LOC: 875
- Test-blokke: 23
- Pass/Fail/Skip: 126 / 2 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-file-io-comprehensive.R`
- LOC: 174
- Test-blokke: 6
- Pass/Fail/Skip: 27 / 3 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Rows: 3 Columns: 4
-- Column specification --------------------------------------------------------
Delimiter: ";"
chr  (2): Afdeling, Kommentar
num  (1): Værdi
date (1): Dato

i Use `spec()` to retrieve the full column specification for this data.
i Specify the column types or set `show_col_types = FALSE` to quiet this message.
```

### `test-file-operations-tidyverse.R`
- LOC: 229
- Test-blokke: 5
- Pass/Fail/Skip: 23 / 2 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-file-upload.R`
- LOC: 164
- Test-blokke: 6
- Pass/Fail/Skip: 4 / 4 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `handle_csv_upload(temp_file, NULL, NULL, NULL)`: attempt to apply non-function
Error in `handle_excel_upload(temp_file, NULL, NULL, NULL, NULL)`: attempt to apply non-function
Error in `file.exists(file_info$datapath)`: invalid 'file' argument
Error in `emit$data_updated(context = "session_file_loaded")`: attempt to apply non-function
```

### `test-generateSPCPlot-comprehensive.R`
- LOC: 707
- Test-blokke: 24
- Pass/Fail/Skip: 147 / 9 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for
```

### `test-input-debouncing-comprehensive.R`
- LOC: 317
- Test-blokke: 9
- Pass/Fail/Skip: 6 / 5 / 3
- Manglende funktioner: `skip_on_ci_if_slow`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `skip_on_ci_if_slow()`: could not find function "skip_on_ci_if_slow"
Error in `expect_gte(delay_value, 100, info = paste(delay_name, "skal være mindst 100ms"))`: unused argument (info = paste(delay_name, "skal være mindst 100ms"))
Error in `skip_on_ci_if_slow()`: could not find function "skip_on_ci_if_slow"
Error in `skip_on_ci_if_slow()`: co
```

### `test-label-formatting.R`
- LOC: 90
- Test-blokke: 8
- Pass/Fail/Skip: 32 / 2 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-label-height-estimation.R`
- LOC: 149
- Test-blokke: 7
- Pass/Fail/Skip: 0 / 1 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
```

### `test-label-placement-bounds.R`
- LOC: 144
- Test-blokke: 6
- Pass/Fail/Skip: 0 / 1 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
```

### `test-label-placement-core.R`
- LOC: 413
- Test-blokke: 18
- Pass/Fail/Skip: 0 / 1 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
```

### `test-mod_export.R`
- LOC: 355
- Test-blokke: 22
- Pass/Fail/Skip: 41 / 3 / 12

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Loading required package: shiny
```

### `test-mod-spc-chart-comprehensive.R`
- LOC: 279
- Test-blokke: 7
- Pass/Fail/Skip: 27 / 16 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `app_state$data$current_data`: Can't access reactive value 'current_data' outside of reactive consumer.
i Do you need to wrap inside reactive() or observe()?
```

### `test-mod-spc-chart-integration.R`
- LOC: 485
- Test-blokke: 20
- Pass/Fail/Skip: 18 / 4 / 5

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-npc-mapper.R`
- LOC: 285
- Test-blokke: 15
- Pass/Fail/Skip: 0 / 1 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
```

### `test-observer-cleanup.R`
- LOC: 291
- Test-blokke: 4
- Pass/Fail/Skip: 4 / 4 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Loading required package: shiny
Error: object '' not found
Error: object '' not found
Error: object '' not found
Error in `sum(sapply(observer_registry, is.null))`: invalid 'type' (list) of argument
```

### `test-package-initialization.R`
- LOC: 187
- Test-blokke: 9
- Pass/Fail/Skip: 41 / 4 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `eval(code, test_env)`: object 'HOSPITAL_NAME' not found
```

### `test-package-namespace-validation.R`
- LOC: 92
- Test-blokke: 3
- Pass/Fail/Skip: 8 / 2 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `expect_gt(length(exports), 0, info = "NAMESPACE should contain export statements")`: unused argument (info = "NAMESPACE should contain export statements")
```

### `test-parse-danish-target-unit-conversion.R`
- LOC: 210
- Test-blokke: 10
- Pass/Fail/Skip: 8 / 65 / 0
- Manglende funktioner: `detect_y_axis_scale`, `convert_by_unit_type`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `if (is.na(parsed$value) || parsed$symbol == "invalid") {     log_debug("Invalid input in normalize_axis_value:", x, "parsed_value:", parsed$value, "symbol:", parsed$symbol, .context = "Y_AXIS_SCALING")     return(NULL) }`: missing value where TRUE/FALSE needed
Error in `detect_y_axis_scale(pure_decimal)`: could not find function "detect_y_ax
```

### `test-performance-benchmarks.R`
- LOC: 654
- Test-blokke: 25
- Pass/Fail/Skip: 7 / 9 / 9

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Cache: 0.10 ms, Compute: 0.00 ms, Speedup: 0.0x
App state memory usage: 0.40 MB (target: <100MB)
Auto-detection for 100 rows: 0.10 MB
Auto-detection for 500 rows: 0.10 MB
Auto-detection for 1000 rows: 0.00 MB
Process 1000 rows: 4.01 ms (target: <200ms)
Danish character overhead: -17.2% (target: <10%)
Auto-detection: 1.44 ms (target: <100ms)
Ambiguous 
```

### `test-plot-core.R`
- LOC: 85
- Test-blokke: 4
- Pass/Fail/Skip: 4 / 4 / 2

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-plot-generation-performance.R`
- LOC: 222
- Test-blokke: 6
- Pass/Fail/Skip: 13 / 1 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Subgroup size > 1. Data have been aggregated using mean().
Subgroup size > 1. Data have been aggregated using mean().
Subgroup size > 1. Data have been aggregated using mean().
```

### `test-reactive-batching.R`
- LOC: 221
- Test-blokke: 10
- Pass/Fail/Skip: 10 / 7 / 0
- Manglende funktioner: `is_batch_pending`, `clear_all_batches`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `is_batch_pending(app_state, "test_batch")`: could not find function "is_batch_pending"
Error in `is_batch_pending(app_state, "batch1")`: could not find function "is_batch_pending"
Error in `is_batch_pending(app_state, "error_batch")`: could not find function "is_batch_pending"
Error in `is_batch_pending(app_state, "non_existent")`: could not
```

### `test-runtime-config-comprehensive.R`
- LOC: 278
- Test-blokke: 12
- Pass/Fail/Skip: 37 / 21 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `expect_lt(duration, 1, info = paste("Configuration took", duration, "seconds for 10 iterations"))`: unused argument (info = paste("Configuration took", duration, "seconds for 10 iterations"))
```

### `test-security-session-tokens.R`
- LOC: 296
- Test-blokke: 14
- Pass/Fail/Skip: 54 / 1 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Testing session token hashing security improvements implemented 2025-09-26
Security fix: Session tokens are now hashed before logging
Prevents: Session token exposure in logs and potential session hijacking
Session token hashing performance: single=0.000092s, 100x=0.001s
Hash collision test: 1000 tokens, 1000 unique hashes, 0.00% collision rate
End-to
```

### `test-session-token-sanitization.R`
- LOC: 130
- Test-blokke: 11
- Pass/Fail/Skip: 21 / 1 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-shared-data-signatures.R`
- LOC: 225
- Test-blokke: 12
- Pass/Fail/Skip: 25 / 2 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-spc-bfh-service.R`
- LOC: 769
- Test-blokke: 38
- Pass/Fail/Skip: 58 / 20 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
`geom_line()`: Each group consists of only one observation.
i Do you need to adjust the group aesthetic?
`geom_line()`: Each group consists of only one observation.
i Do you need to adjust the group aesthetic?
```

### `test-spc-cache-integration.R`
- LOC: 459
- Test-blokke: 15
- Pass/Fail/Skip: 29 / 3 / 0
- Manglende funktioner: `get_spc_cache_stats`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `get_spc_cache_stats(qic_cache)`: could not find function "get_spc_cache_stats"
Error in `get_spc_cache_stats(qic_cache)`: could not find function "get_spc_cache_stats"
Error in `get_spc_cache_stats(qic_cache)`: could not find function "get_spc_cache_stats"
```

### `test-spc-plot-generation-comprehensive.R`
- LOC: 631
- Test-blokke: 13
- Pass/Fail/Skip: 49 / 12 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for
```

### `test-spc-regression-bfh-vs-qic.R`
- LOC: 789
- Test-blokke: 22
- Pass/Fail/Skip: 36 / 10 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `expect_gt(sum(bfh_result$qic_data$signal, na.rm = TRUE), 0, info = "I chart Anhøj: at least one signal detected")`: unused argument (info = "I chart Anhøj: at least one signal detected")
Error in `expect_s3_class(result$plot, "ggplot", info = sprintf("%s chart renders ggplot", chart_type))`: unused argument (info = sprintf("%s chart renders 
```

### `test-state-management-hierarchical.R`
- LOC: 475
- Test-blokke: 13
- Pass/Fail/Skip: 41 / 14 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `app_state$columns$auto_detect`: Can't access reactive value 'auto_detect' outside of reactive consumer.
i Do you need to wrap inside reactive() or observe()?
Error in ``*tmp*`$auto_detect`: Can't access reactive value 'auto_detect' outside of reactive consumer.
i Do you need to wrap inside reactive() or observe()?
Error in ``*tmp*`$mappings`
```

### `test-tidyverse-purrr-operations.R`
- LOC: 280
- Test-blokke: 8
- Pass/Fail/Skip: 22 / 2 / 2

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils_export_validation.R`
- LOC: 342
- Test-blokke: 29
- Pass/Fail/Skip: 48 / 2 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error: Titel må max være 200 tegn (nuværende: 201)
```

### `test-utils_performance_caching.R`
- LOC: 74
- Test-blokke: 9
- Pass/Fail/Skip: 10 / 1 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils-state-accessors.R`
- LOC: 555
- Test-blokke: 29
- Pass/Fail/Skip: 10 / 26 / 0
- Manglende funktioner: `get_original_data`, `is_table_updating`, `get_autodetect_status`, `set_autodetect_in_progress`, `set_autodetect_completed`, `set_autodetect_results`, `set_autodetect_frozen`, `get_column_mappings`, `get_column_mapping`, `update_column_mapping`, `update_column_mappings`, `set_plot_ready`, `get_plot_warnings`, `get_plot_object`, `is_plot_generating`, `is_file_uploaded`, `is_user_session_started`, `get_last_error`, `get_error_count`, `is_test_mode_enabled`, `get_test_mode_startup_phase`, `is_anhoej_rules_hidden`, `is_y_axis_autoset_done`, `set_table_updating`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `get_original_data(app_state)`: could not find function "get_original_data"
Error in `is_table_updating(app_state)`: could not find function "is_table_updating"
Error in `get_autodetect_status(app_state)`: could not find function "get_autodetect_status"
Error in `set_autodetect_in_progress(app_state, TRUE)`: could not find function "set_autod
```

### `test-visualization-server.R`
- LOC: 141
- Test-blokke: 5
- Pass/Fail/Skip: 11 / 3 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-y-axis-formatting.R`
- LOC: 218
- Test-blokke: 12
- Pass/Fail/Skip: 54 / 5 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-y-axis-mapping.R`
- LOC: 42
- Test-blokke: 3
- Pass/Fail/Skip: 0 / 3 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
```

### `test-y-axis-model.R`
- LOC: 40
- Test-blokke: 3
- Pass/Fail/Skip: 0 / 3 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
Error in `file(filename, "r", encoding = encoding)`: cannot open the connection
```

### `test-y-axis-scaling-overhaul.R`
- LOC: 342
- Test-blokke: 16
- Pass/Fail/Skip: 69 / 7 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-yaml-config-adherence.R`
- LOC: 198
- Test-blokke: 5
- Pass/Fail/Skip: 7 / 1 / 2

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
[LOG_CONFIG] Log level 'DEBUG' from YAML config 'development'
[LOG_CONFIG] Log level 'ERROR' from YAML config 'production'
[LOG_CONFIG] Explicit log level set to ERROR
[LOG_CONFIG] Log level 'ERROR' from YAML config 'production'
```

---

## Kategori: `skipped-all` (2 filer)

### `test-bfh-module-integration.R`
- LOC: 381
- Test-blokke: 9
- Pass/Fail/Skip: 0 / 0 / 9

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-e2e-user-workflows.R`
- LOC: 411
- Test-blokke: 8
- Pass/Fail/Skip: 0 / 0 / 8

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

---

## Kategori: `stub` (9 filer)

### `test-app-basic.R`
- LOC: 70
- Test-blokke: 2
- Pass/Fail/Skip: 0 / 2 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `eval(code, test_env)`: object 'AppDriver' not found
Error in `eval(code, test_env)`: object 'AppDriver' not found
```

### `test-branding-globals.R`
- LOC: 21
- Test-blokke: 1
- Pass/Fail/Skip: 0 / 2 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `eval(code, test_env)`: object 'HOSPITAL_COLORS' not found
```

### `test-clean-qic-call-args.R`
- LOC: 34
- Test-blokke: 2
- Pass/Fail/Skip: 6 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-denominator-field-toggle.R`
- LOC: 36
- Test-blokke: 2
- Pass/Fail/Skip: 9 / 2 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-dependency-namespace.R`
- LOC: 54
- Test-blokke: 1
- Pass/Fail/Skip: 1 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-logging-debug-cat.R`
- LOC: 24
- Test-blokke: 1
- Pass/Fail/Skip: 0 / 1 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-namespace-integrity.R`
- LOC: 15
- Test-blokke: 1
- Pass/Fail/Skip: 1 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-run-app.R`
- LOC: 90
- Test-blokke: 1
- Pass/Fail/Skip: 0 / 0 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-ui-token-management.R`
- LOC: 83
- Test-blokke: 2
- Pass/Fail/Skip: 16 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

---

## Kategori: `green` (48 filer)

### `test-anhoej-metadata-local.R`
- LOC: 449
- Test-blokke: 24
- Pass/Fail/Skip: 47 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-anhoej-rules.R`
- LOC: 646
- Test-blokke: 31
- Pass/Fail/Skip: 52 / 0 / 7

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for
```

### `test-audit-classifier.R`
- LOC: 283
- Test-blokke: 26
- Pass/Fail/Skip: 34 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-autodetect-tidyverse-integration.R`
- LOC: 295
- Test-blokke: 7
- Pass/Fail/Skip: 65 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-centerline-handling.R`
- LOC: 148
- Test-blokke: 4
- Pass/Fail/Skip: 0 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-comment-row-mapping.R`
- LOC: 100
- Test-blokke: 3
- Pass/Fail/Skip: 17 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-comprehensive-ui-sync.R`
- LOC: 124
- Test-blokke: 4
- Pass/Fail/Skip: 29 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-config_analytics.R`
- LOC: 33
- Test-blokke: 4
- Pass/Fail/Skip: 21 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-config-performance-getters.R`
- LOC: 171
- Test-blokke: 26
- Pass/Fail/Skip: 63 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-config-ui-getters.R`
- LOC: 172
- Test-blokke: 23
- Pass/Fail/Skip: 57 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-cross-component-reactive.R`
- LOC: 521
- Test-blokke: 10
- Pass/Fail/Skip: 67 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-csv-parsing.R`
- LOC: 217
- Test-blokke: 11
- Pass/Fail/Skip: 28 / 0 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-csv-sanitization.R`
- LOC: 150
- Test-blokke: 8
- Pass/Fail/Skip: 22 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-danish-clinical-edge-cases.R`
- LOC: 453
- Test-blokke: 10
- Pass/Fail/Skip: 111 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-debug-context-filtering.R`
- LOC: 233
- Test-blokke: 16
- Pass/Fail/Skip: 59 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
[LOG_CONFIG] Debug context filtering enabled - logging: state, data
[LOG_CONFIG] Debug context filtering enabled - logging: STATE, data
[LOG_CONFIG] Debug context filtering enabled - logging: state, UNSPECIFIED
[LOG_CONFIG] Debug context filtering enabled - logging: state, data
[LOG_CONFIG] Debug context filtering disabled - logging all contexts
[LOG_
```

### `test-error-handling.R`
- LOC: 139
- Test-blokke: 10
- Pass/Fail/Skip: 25 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-excelr-data-reconstruction.R`
- LOC: 133
- Test-blokke: 3
- Pass/Fail/Skip: 21 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-fct_ai_improvement_suggestions.R`
- LOC: 285
- Test-blokke: 13
- Pass/Fail/Skip: 18 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-fct_export_png.R`
- LOC: 196
- Test-blokke: 11
- Pass/Fail/Skip: 36 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-fct_spc_file_save_load.R`
- LOC: 315
- Test-blokke: 10
- Pass/Fail/Skip: 63 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-file-operations.R`
- LOC: 650
- Test-blokke: 31
- Pass/Fail/Skip: 66 / 0 / 2

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2

Attaching package: 'readr'

The following objects are masked from 'package:testthat':

    edition_get, local_edition

i Using "','" as decimal and "'.'" as grouping mark. Use `read_delim()` for more control.
i Using "','" as decimal and "'.'" as grouping mark. Use `read_delim()` for more control.
i Using "','" as decimal and "'.'" as grouping mark. 
```

### `test-foreign-column-names.R`
- LOC: 223
- Test-blokke: 4
- Pass/Fail/Skip: 21 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-input-sanitization.R`
- LOC: 119
- Test-blokke: 4
- Pass/Fail/Skip: 1 / 0 / 3

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-integration-workflows.R`
- LOC: 551
- Test-blokke: 10
- Pass/Fail/Skip: 42 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-logging-precedence.R`
- LOC: 136
- Test-blokke: 9
- Pass/Fail/Skip: 17 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-logging-standardization.R`
- LOC: 369
- Test-blokke: 19
- Pass/Fail/Skip: 58 / 0 / 4

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Testing logging system standardization implemented 2025-09-26
Improvement: Unified logging API with backward compatibility
372+ logging calls across 34 files standardized
Logging performance: single=0.000130s, 100x=0.006s
End-to-end logging system test successful
```

### `test-logging-system.R`
- LOC: 267
- Test-blokke: 9
- Pass/Fail/Skip: 80 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-no-file-dependencies.R`
- LOC: 50
- Test-blokke: 5
- Pass/Fail/Skip: 11 / 0 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-outlier-count-latest-part.R`
- LOC: 38
- Test-blokke: 4
- Pass/Fail/Skip: 6 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-phase-2c-reactive-chain.R`
- LOC: 547
- Test-blokke: 37
- Pass/Fail/Skip: 56 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-plot-generation.R`
- LOC: 522
- Test-blokke: 11
- Pass/Fail/Skip: 56 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-recent-functionality.R`
- LOC: 513
- Test-blokke: 8
- Pass/Fail/Skip: 58 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-run-chart-denominator-stability.R`
- LOC: 150
- Test-blokke: 3
- Pass/Fail/Skip: 10 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for x, which will replace the existing scale.
Scale for x is already present.
Adding another scale for
```

### `test-safe-operation-comprehensive.R`
- LOC: 551
- Test-blokke: 10
- Pass/Fail/Skip: 42 / 0 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-session-persistence.R`
- LOC: 561
- Test-blokke: 21
- Pass/Fail/Skip: 72 / 0 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-startup-optimization.R`
- LOC: 375
- Test-blokke: 15
- Pass/Fail/Skip: 0 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-ui-synchronization.R`
- LOC: 581
- Test-blokke: 12
- Pass/Fail/Skip: 107 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils_analytics_consent.R`
- LOC: 43
- Test-blokke: 5
- Pass/Fail/Skip: 10 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils_analytics_github.R`
- LOC: 103
- Test-blokke: 9
- Pass/Fail/Skip: 12 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils_analytics_pins.R`
- LOC: 96
- Test-blokke: 5
- Pass/Fail/Skip: 23 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils_data_signatures.R`
- LOC: 72
- Test-blokke: 8
- Pass/Fail/Skip: 12 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils_error_handling.R`
- LOC: 90
- Test-blokke: 12
- Pass/Fail/Skip: 14 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils_export_filename.R`
- LOC: 365
- Test-blokke: 36
- Pass/Fail/Skip: 61 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils_input_sanitization.R`
- LOC: 112
- Test-blokke: 13
- Pass/Fail/Skip: 34 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils_qic_caching.R`
- LOC: 91
- Test-blokke: 11
- Pass/Fail/Skip: 14 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-utils_server_export.R`
- LOC: 143
- Test-blokke: 8
- Pass/Fail/Skip: 8 / 0 / 3

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-visualization-dimensions.R`
- LOC: 29
- Test-blokke: 4
- Pass/Fail/Skip: 5 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-wizard.R`
- LOC: 326
- Test-blokke: 23
- Pass/Fail/Skip: 49 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2

Attaching package: 'readr'

The following objects are masked from 'package:testthat':

    edition_get, local_edition

i Using "','" as decimal and "'.'" as grouping mark. Use `read_delim()` for more control.
```

---

## Scope-forslag

- **Green:** 110 af 125 (88%)
- **Broken:** 4 af 125 (3%)
- **Stubs/skipped:** 11 af 125 (9%)

**Anbefaling: Minimal scope** - fokuser paa de faa braekkede filer.

