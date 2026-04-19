# Test Audit Report

**Dato:** 2026-04-19T16:03:42+0200
**biSPCharts version:** 0.2.0
**R version:** 4.5.2
**Total filer:** 116
**Total koerselstid:** 427.6 s

---

## Executive Summary

| Kategori | Antal | % af total |
|----------|-------|-----------|
| `green` | 82 | 70.7% |
| `green-partial` | 24 | 20.7% |
| `skipped-all` | 2 | 1.7% |
| `stub` | 8 | 6.9% |

---

## Top-10 Manglende R-funktioner

| Funktion | Antal filer |
|----------|-------------|
| `clear_spc_cache` | 1 |

---

## Kategori: `green-partial` (24 filer)

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

### `test-bfh-error-handling.R`
- LOC: 363
- Test-blokke: 18
- Pass/Fail/Skip: 36 / 1 / 5

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-cache-data-signature-bugs.R`
- LOC: 351
- Test-blokke: 13
- Pass/Fail/Skip: 26 / 1 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-critical-fixes-integration.R`
- LOC: 374
- Test-blokke: 6
- Pass/Fail/Skip: 42 / 2 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-data-validation.R`
- LOC: 107
- Test-blokke: 4
- Pass/Fail/Skip: 12 / 2 / 2

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
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

### `test-label-formatting.R`
- LOC: 97
- Test-blokke: 10
- Pass/Fail/Skip: 39 / 2 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
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
- Pass/Fail/Skip: 10 / 2 / 0

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
Session token hashing performance: single=0.000136s, 100x=0.002s
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
- LOC: 715
- Test-blokke: 34
- Pass/Fail/Skip: 55 / 1 / 14

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-spc-cache-integration.R`
- LOC: 459
- Test-blokke: 15
- Pass/Fail/Skip: 39 / 1 / 0
- Manglende funktioner: `clear_spc_cache`

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Error in `clear_spc_cache(qic_cache)`: could not find function "clear_spc_cache"
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
- LOC: 396
- Test-blokke: 9
- Pass/Fail/Skip: 0 / 0 / 9

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-e2e-user-workflows.R`
- LOC: 417
- Test-blokke: 8
- Pass/Fail/Skip: 0 / 0 / 8

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

---

## Kategori: `stub` (8 filer)

### `test-branding-globals.R`
- LOC: 22
- Test-blokke: 1
- Pass/Fail/Skip: 2 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
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
- Pass/Fail/Skip: 7 / 0 / 0

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
- Pass/Fail/Skip: 1 / 0 / 0

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

## Kategori: `green` (82 filer)

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

### `test-autodetect-unified-comprehensive.R`
- LOC: 908
- Test-blokke: 24
- Pass/Fail/Skip: 120 / 0 / 3

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-bfhcharts-integration.R`
- LOC: 151
- Test-blokke: 6
- Pass/Fail/Skip: 11 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-cache-collision-fix.R`
- LOC: 79
- Test-blokke: 7
- Pass/Fail/Skip: 11 / 0 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-cache-invalidation-sprint3.R`
- LOC: 185
- Test-blokke: 10
- Pass/Fail/Skip: 61 / 0 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-cache-reactive-lazy-evaluation.R`
- LOC: 188
- Test-blokke: 8
- Pass/Fail/Skip: 13 / 0 / 2

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Loading required package: shiny
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

### `test-column-observer-consolidation.R`
- LOC: 191
- Test-blokke: 11
- Pass/Fail/Skip: 21 / 0 / 1

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

### `test-config_chart_types.R`
- LOC: 72
- Test-blokke: 7
- Pass/Fail/Skip: 25 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-config_export.R`
- LOC: 355
- Test-blokke: 23
- Pass/Fail/Skip: 132 / 0 / 0

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

### `test-context-aware-plots.R`
- LOC: 325
- Test-blokke: 20
- Pass/Fail/Skip: 79 / 0 / 2

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

### `test-critical-fixes-regression.R`
- LOC: 496
- Test-blokke: 14
- Pass/Fail/Skip: 150 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
[LOG_CONFIG] Log level set to DEBUG (development mode)
[LOG_CONFIG] Log level set to WARN (production mode)
[LOG_CONFIG] Log level set to ERROR (quiet mode)
[LOG_CONFIG] Log level set to INFO
```

### `test-critical-fixes-security.R`
- LOC: 278
- Test-blokke: 8
- Pass/Fail/Skip: 34 / 0 / 3

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

### `test-e2e-workflows.R`
- LOC: 266
- Test-blokke: 5
- Pass/Fail/Skip: 24 / 0 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
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

### `test-event-system-emit.R`
- LOC: 234
- Test-blokke: 9
- Pass/Fail/Skip: 46 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Loading required package: shiny
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

### `test-facade-time-parsing.R`
- LOC: 79
- Test-blokke: 7
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

### `test-file-upload.R`
- LOC: 131
- Test-blokke: 8
- Pass/Fail/Skip: 12 / 0 / 2

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
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

### `test-generateSPCPlot-comprehensive.R`
- LOC: 714
- Test-blokke: 24
- Pass/Fail/Skip: 128 / 0 / 8

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
- LOC: 344
- Test-blokke: 9
- Pass/Fail/Skip: 20 / 0 / 4

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-input-sanitization.R`
- LOC: 119
- Test-blokke: 4
- Pass/Fail/Skip: 14 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
Loading required package: shiny
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

### `test-label-placement-core.R`
- LOC: 577
- Test-blokke: 25
- Pass/Fail/Skip: 85 / 0 / 3

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-local-storage-time-migration.R`
- LOC: 59
- Test-blokke: 6
- Pass/Fail/Skip: 10 / 0 / 0

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
Logging performance: single=0.000201s, 100x=0.010s
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

### `test-mod-spc-chart-comprehensive.R`
- LOC: 590
- Test-blokke: 24
- Pass/Fail/Skip: 34 / 0 / 10

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-no-file-dependencies.R`
- LOC: 50
- Test-blokke: 5
- Pass/Fail/Skip: 12 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-observer-cleanup.R`
- LOC: 133
- Test-blokke: 5
- Pass/Fail/Skip: 8 / 0 / 2

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

### `test-parse-danish-target-unit-conversion.R`
- LOC: 139
- Test-blokke: 15
- Pass/Fail/Skip: 8 / 0 / 8

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-performance-benchmarks.R`
- LOC: 233
- Test-blokke: 15
- Pass/Fail/Skip: 18 / 0 / 3

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

### `test-plot-core.R`
- LOC: 80
- Test-blokke: 5
- Pass/Fail/Skip: 10 / 0 / 2

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

### `test-reactive-batching.R`
- LOC: 74
- Test-blokke: 3
- Pass/Fail/Skip: 6 / 0 / 0

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

### `test-runtime-config-comprehensive.R`
- LOC: 306
- Test-blokke: 12
- Pass/Fail/Skip: 60 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
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
- LOC: 562
- Test-blokke: 21
- Pass/Fail/Skip: 72 / 0 / 1

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-spc-plot-generation-comprehensive.R`
- LOC: 636
- Test-blokke: 13
- Pass/Fail/Skip: 39 / 0 / 4

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
- LOC: 790
- Test-blokke: 22
- Pass/Fail/Skip: 50 / 0 / 4

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

### `test-state-management-hierarchical.R`
- LOC: 503
- Test-blokke: 13
- Pass/Fail/Skip: 46 / 0 / 6

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-time-formatting.R`
- LOC: 149
- Test-blokke: 16
- Pass/Fail/Skip: 45 / 0 / 0

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

### `test-time-parsing.R`
- LOC: 92
- Test-blokke: 11
- Pass/Fail/Skip: 28 / 0 / 0

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
- LOC: 114
- Test-blokke: 6
- Pass/Fail/Skip: 21 / 0 / 0

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

### `test-utils_performance_caching.R`
- LOC: 77
- Test-blokke: 9
- Pass/Fail/Skip: 11 / 0 / 0

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

### `test-utils-state-accessors.R`
- LOC: 225
- Test-blokke: 26
- Pass/Fail/Skip: 44 / 0 / 0

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

### `test-y-axis-scaling-overhaul.R`
- LOC: 642
- Test-blokke: 39
- Pass/Fail/Skip: 132 / 0 / 8

```
Registered S3 methods overwritten by 'ggpp':
  method                  from   
  heightDetails.titleGrob ggplot2
  widthDetails.titleGrob  ggplot2
```

---

## Scope-forslag

- **Green:** 106 af 116 (91%)
- **Broken:** 0 af 116 (0%)
- **Stubs/skipped:** 10 af 116 (9%)

**Anbefaling: Minimal scope** - fokuser paa de faa braekkede filer.

