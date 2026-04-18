# Test Suite Inventory — Issue #203

**Dato:** 2026-04-18
**Branch:** `chore/test-suite-inventory-203`
**Formål:** Kortlægge de ~66 fejlede test-blokke så #203 kan fixes i systematiske batches.

## Omfang

Efter refactor-code-quality Phase 1–3 (merged) er antallet af fejl reduceret
betydeligt fra issue #203's oprindelige skøn på ~200. Aktuel status:

- **Total test-blokke:** 1460
- **Failed/errored blokke:** 66
- **Skipped:** 180
- **Fordelt på:** 30 testfiler

## Top-10 problem-filer

| Fil | Blokke | Primær årsag |
|---|---|---|
| `test-bfh-error-handling.R` | 6 | `sanitize_log_details`, `log_with_throttle` fjernet |
| `test-input-debouncing-comprehensive.R` | 5 | Sandsynligvis debounce API-ændring |
| `test-column-observer-consolidation.R` | 4 | Reactive-value access pattern |
| `test-context-aware-plots.R` | 4 | `PLOT_CONTEXT_DIMENSIONS` ikke findes |
| `test-100x-mismatch-prevention.R` | 3 | Target-line scaling |
| `test-critical-fixes-integration.R` | 3 | Blandet |
| `test-edge-cases-comprehensive.R` | 3 | — |
| `test-input-sanitization.R` | 3 | — |
| `test-spc-cache-integration.R` | 3 | `get_cache_stats`, `get_spc_cache_stats` |
| `test-app-basic.R` | 2 | `AppDriver` (shinytest2 setup) |

## Fejl-kategorier med fix-strategi

### Kategori A — Fjernede funktioner

Tests kalder funktioner der ikke længere eksisterer i R/. Løsning: slet
testen eller skip med tydelig rationale.

| Manglende funktion | Antal tests | Sandsynlig årsag |
|---|---|---|
| `sanitize_log_details` | 2+ | Logging-refactor har fjernet helper |
| `log_with_throttle` | 2+ | Samme logging-refactor |
| `get_cache_stats` | 1 | Cache-API konsolideret |
| `get_spc_cache_stats` | 1 | Cache-API konsolideret |
| `validate_date_column` | 1 | Validering integreret andre steder |
| `skip_on_ci_if_slow` | 1 | Test-helper fjernet |

**Fix-strategi:** Vurdér pr. funktion om testen er:
- **Relevant** (funktion genindført eller omdøbt) → opdater kald
- **Forældet** (funktionalitet integreret elsewhere) → slet test eller skip med `skip("Funktion integreret i X, se commit Y")`

### Kategori B — Fjernede konstanter/objekter

| Manglende objekt | Antal | Kommentar |
|---|---|---|
| `HOSPITAL_COLORS` | 1 | Flyttet til BFHtheme? |
| `HOSPITAL_NAME` | 1 | Flyttet til BFHtheme? |
| `PLOT_CONTEXT_DIMENSIONS` | 2 | Omdøbt eller flyttet |
| `AppDriver` (shinytest2) | 2 | Kræver `library(shinytest2)` + Chrome |

**Fix-strategi:**
- Branding-konstanter: opdater tests til at bruge `get_hospital_branding()` accessor
- `PLOT_CONTEXT_DIMENSIONS`: grep i R/ for nuværende navn
- `AppDriver`-tests: skip hvis Chrome ikke er tilgængelig (allerede handled i andre tests)

### Kategori C — testthat 3.x API-breaks

Fejl: `unused argument (info = ...)`.

Dette skyldes at `info` parameter i `expect_gt/gte/lt` blev fjernet i testthat 3.x.
Løsning: Erstat `expect_gt(x, y, info = "msg")` med `expect_gt(x, y)` eller
omskriv til `expect_true(x > y, info = "msg")`.

**Berørt:**
- `test-package-namespace-validation.R`
- `test-input-debouncing-comprehensive.R`
- `test-plot-generation-performance.R`
- `test-cache-data-signature-bugs.R`
- `test-shared-data-signatures.R`
- `test-spc-regression-bfh-vs-qic.R`

### Kategori D — Chrome/shinytest2

Fejl: `Failed to start chrome. Cannot find an available port.`

Systemafhængighed. Påvirker `test-app-basic.R`, `test-visualization-server.R`.
**Fix-strategi:** Wrap i `skip_if_not(shinytest2::detect_chrome())` så tests
kun kører når Chrome er tilgængelig.

### Kategori E — Reactive/Shiny context

Fejl: `Can't access reactive value 'mappings' outside of reactive consumer.`

Tests forsøger at tilgå reactive values uden shiny reactive scope.
**Fix-strategi:** Brug `shiny::isolate({})` eller refaktorér tests til
ikke at afhænge af live reactive-context.

### Kategori F — Manglende package (claudespc)

Fejl: `there is no package called 'claudespc'`.

Refererer til gammelt pakkenavn. Pakken hedder nu `biSPCharts`.
**Fix-strategi:** Søg og erstat `claudespc` → `biSPCharts` i tests.

## Foreslået PR-plan

Hver kategori som separat PR for at holde reviews små:

1. **PR A1: Slet/skip fjernede logging-helpers** (~5 tests)
   - `sanitize_log_details`, `log_with_throttle` i `test-bfh-error-handling.R`

2. **PR A2: Slet/skip fjernede cache-helpers** (~3 tests)
   - `get_cache_stats`, `get_spc_cache_stats` i `test-spc-cache-integration.R`

3. **PR B1: Opdater branding-konstant-tests** (~3 tests)
   - Brug `get_hospital_branding()` accessor

4. **PR C1: testthat 3.x info-argument cleanup** (~6-10 tests)
   - Mekanisk fix via sed/regex

5. **PR D1: Skip Chrome-tests når ikke tilgængelig** (~3 tests)

6. **PR E1: Fix reactive context i tests** (~5 tests)

7. **PR F1: `claudespc` → `biSPCharts` rename** (~2 tests)

8. **PR A3: Restende fjernede funktioner** (catch-all ~5 tests)

## Næste skridt

1. Merge denne inventory som dokumentation
2. Start PR A1 (lavest risiko, små ændringer)
3. Verificér at `devtools::test()` går grøn efter alle PR'er
4. Fjern `--skip-tests` flag fra `dev/publish_prepare.R`
5. Lukk issue #203

## Metodologi

```r
# Fuld inventory
options(testthat.progress.max_fails = 2000L)
devtools::load_all('.')
result <- testthat::test_local(
  reporter = testthat::SilentReporter$new(),
  stop_on_failure = FALSE
)
df <- as.data.frame(result)
problem <- df[df$failed > 0 | df$error == TRUE, ]
```
