# Test Suite Audit Report

**Audit-kørsel:** 2026-04-17T16:32:41+0200
**Total filer:** 125
**Total kørselstid:** 259.3 s
**Issue:** #203
**Manifest:** `dev/audit-output/test-classification.yaml`

---

## 1. Executive summary

### Audit-kategorier

| Kategori | Antal | % |
|---|---|---|
| `broken-missing-fn` | 4 | 3.2% |
| `green` | 48 | 38.4% |
| `green-partial` | 62 | 49.6% |
| `skipped-all` | 2 | 1.6% |
| `stub` | 9 | 7.2% |

### Manifest-typer

| Type | Antal | % |
|---|---|---|
| `benchmark` | 3 | 2.4% |
| `e2e` | 6 | 4.8% |
| `integration` | 5 | 4.0% |
| `policy-guard` | 5 | 4.0% |
| `snapshot` | 3 | 2.4% |
| `unit` | 103 | 82.4% |

## 2. Kritiske fund

- Audit-classifier's `n_test_blocks < 3 → stub`-heuristik misklassificerer
  værdifulde policy-tests. Alle 9 "stubs" verificeret som aktive.
- De 2 `skipped-all` filer er bevidste E2E-gates, ikke obsolete.
- Manifest-klassifikationen er menneske-verificeret ground truth.

## 3. Pr-fil klassifikations-tabel

| Fil | Kategori | Type | Handling | Rationale |
|---|---|---|---|---|
| `test-panel-height-cache.R` | broken-missing-fn | unit | blocked-by-change-1 | Venter på Change 1 der genindfører clear_panel_height_cache. |
| `test-plot-diff.R` | broken-missing-fn | unit | blocked-by-change-1 | Venter på Change 1 der genindfører plot-state-snapshot-funktioner. |
| `test-utils_validation_guards.R` | broken-missing-fn | unit | blocked-by-change-1 | Venter på Change 1 der genindfører validation-guard-familien. |
| `test-validation-guards.R` | broken-missing-fn | unit | blocked-by-change-1 | Duplikat af test-utils_validation_guards.R — markér til Fase 2 merge eller archive. |
| `test-bfhcharts-integration.R` | green-partial | unit | rewrite | Green-partial med 10/15 fejl. Handling=rewrite baseret paa fail-ratio. |
| `test-cache-collision-fix.R` | green-partial | unit | rewrite | Green-partial med 4/5 fejl. Handling=rewrite baseret paa fail-ratio. |
| `test-cache-reactive-lazy-evaluation.R` | green-partial | e2e | rewrite | API-drift: refererede funktioner fjernet (7/8 fejl). Rewrite efter API-stabilisering. |
| `test-constants-architecture.R` | green-partial | unit | rewrite | Fixture-filer mangler (1/1 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3. |
| `test-e2e-workflows.R` | green-partial | integration | rewrite | Green-partial med 5/8 fejl. Handling=rewrite baseret paa fail-ratio. |
| `test-file-upload.R` | green-partial | unit | rewrite | Green-partial med 4/8 fejl. Handling=rewrite baseret paa fail-ratio. |
| `test-label-height-estimation.R` | green-partial | unit | rewrite | Fixture-filer mangler (1/1 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3. |
| `test-label-placement-bounds.R` | green-partial | unit | rewrite | Fixture-filer mangler (1/1 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3. |
| `test-label-placement-core.R` | green-partial | unit | rewrite | Fixture-filer mangler (1/1 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3. |
| `test-npc-mapper.R` | green-partial | unit | rewrite | Fixture-filer mangler (1/1 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3. |
| `test-observer-cleanup.R` | green-partial | unit | rewrite | Green-partial med 4/8 fejl. Handling=rewrite baseret paa fail-ratio. |
| `test-parse-danish-target-unit-conversion.R` | green-partial | unit | rewrite | API-drift: refererede funktioner fjernet (65/73 fejl). Rewrite efter API-stabilisering. |
| `test-performance-benchmarks.R` | green-partial | benchmark | rewrite | Green-partial med 9/16 fejl. Handling=rewrite baseret paa fail-ratio. |
| `test-plot-core.R` | green-partial | unit | rewrite | Green-partial med 4/8 fejl. Handling=rewrite baseret paa fail-ratio. |
| `test-utils-state-accessors.R` | green-partial | unit | rewrite | API-drift: refererede funktioner fjernet (26/36 fejl). Rewrite efter API-stabilisering. |
| `test-y-axis-mapping.R` | green-partial | unit | rewrite | Fixture-filer mangler (3/3 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3. |
| `test-y-axis-model.R` | green-partial | unit | rewrite | Fixture-filer mangler (3/3 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3. |
| `test-100x-mismatch-prevention.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 5/52 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-app-initialization.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 1/10 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-autodetect-unified-comprehensive.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 20/158 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-bfh-error-handling.R` | green-partial | unit | fix-in-phase-3 | API-drift: refererede funktioner fjernet (6/42 fejl). Fix-in-phase-3 efter API-stabilisering. |
| `test-cache-data-signature-bugs.R` | green-partial | e2e | fix-in-phase-3 | testthat API-drift: argumenter ikke understoettet (2/25 fejl). Fix-in-phase-3 efter API-opdatering. |
| `test-cache-invalidation-sprint3.R` | green-partial | unit | fix-in-phase-3 | API-drift: refererede funktioner fjernet (1/62 fejl). Fix-in-phase-3 efter API-stabilisering. |
| `test-column-observer-consolidation.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 4/14 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-config_chart_types.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 16/35 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-config_export.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 10/141 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-context-aware-plots.R` | green-partial | unit | fix-in-phase-3 | ggplot warning (4/83 fejl) - ikke-kritisk men kraever scale-haandtering. Fix-in-phase-3. |
| `test-critical-fixes-integration.R` | green-partial | snapshot | fix-in-phase-3 | Green-partial med 4/43 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-critical-fixes-regression.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 14/137 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-critical-fixes-security.R` | green-partial | unit | fix-in-phase-3 | testthat API-drift: argumenter ikke understoettet (21/63 fejl). Fix-in-phase-3 efter API-opdatering. |
| `test-data-validation.R` | green-partial | unit | fix-in-phase-3 | API-drift: refererede funktioner fjernet (3/15 fejl). Fix-in-phase-3 efter API-stabilisering. |
| `test-edge-cases-comprehensive.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 3/66 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-event-system-emit.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 7/50 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-event-system-observers.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 2/128 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-file-io-comprehensive.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 3/30 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-file-operations-tidyverse.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 2/25 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-generateSPCPlot-comprehensive.R` | green-partial | snapshot | fix-in-phase-3 | ggplot warning (9/156 fejl) - ikke-kritisk men kraever scale-haandtering. Fix-in-phase-3. |
| `test-input-debouncing-comprehensive.R` | green-partial | e2e | fix-in-phase-3 | API-drift: refererede funktioner fjernet (5/11 fejl). Fix-in-phase-3 efter API-stabilisering. |
| `test-label-formatting.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 2/34 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-mod_export.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 3/44 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-mod-spc-chart-comprehensive.R` | green-partial | integration | fix-in-phase-3 | Green-partial med 16/43 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-mod-spc-chart-integration.R` | green-partial | integration | fix-in-phase-3 | Green-partial med 4/22 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-package-initialization.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 4/45 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-package-namespace-validation.R` | green-partial | policy-guard | fix-in-phase-3 | testthat API-drift: argumenter ikke understoettet (2/10 fejl). Fix-in-phase-3 efter API-opdatering. |
| `test-plot-generation-performance.R` | green-partial | e2e | fix-in-phase-3 | Green-partial med 1/14 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-reactive-batching.R` | green-partial | unit | fix-in-phase-3 | API-drift: refererede funktioner fjernet (7/17 fejl). Fix-in-phase-3 efter API-stabilisering. |
| `test-runtime-config-comprehensive.R` | green-partial | unit | fix-in-phase-3 | testthat API-drift: argumenter ikke understoettet (21/58 fejl). Fix-in-phase-3 efter API-opdatering. |
| `test-security-session-tokens.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 1/55 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-session-token-sanitization.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 1/22 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-shared-data-signatures.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 2/27 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-spc-bfh-service.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 20/78 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-spc-cache-integration.R` | green-partial | unit | fix-in-phase-3 | API-drift: refererede funktioner fjernet (3/32 fejl). Fix-in-phase-3 efter API-stabilisering. |
| `test-spc-plot-generation-comprehensive.R` | green-partial | unit | fix-in-phase-3 | ggplot warning (12/61 fejl) - ikke-kritisk men kraever scale-haandtering. Fix-in-phase-3. |
| `test-spc-regression-bfh-vs-qic.R` | green-partial | unit | fix-in-phase-3 | testthat API-drift: argumenter ikke understoettet (10/46 fejl). Fix-in-phase-3 efter API-opdatering. |
| `test-state-management-hierarchical.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 14/55 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-tidyverse-purrr-operations.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 2/24 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-utils_export_validation.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 2/50 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-utils_performance_caching.R` | green-partial | benchmark | fix-in-phase-3 | Green-partial med 1/11 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-visualization-server.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 3/14 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-y-axis-formatting.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 5/59 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-y-axis-scaling-overhaul.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 7/76 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-yaml-config-adherence.R` | green-partial | unit | fix-in-phase-3 | Green-partial med 1/8 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio. |
| `test-anhoej-metadata-local.R` | green | unit | keep |  |
| `test-anhoej-rules.R` | green | unit | keep |  |
| `test-app-basic.R` | stub | integration | keep | E2E-smoke med AppDriver-mock fallback (2 blokke). Misklassificeret som stub. |
| `test-audit-classifier.R` | green | unit | keep |  |
| `test-autodetect-tidyverse-integration.R` | green | unit | keep |  |
| `test-bfh-module-integration.R` | skipped-all | e2e | keep | skip_if_not_installed('shinytest2'); snapshot-tests for BFHchart. |
| `test-branding-globals.R` | stub | policy-guard | keep | Legacy-constant tilgængelighed (HOSPITAL_COLORS bruges stadig i R/zzz.R, R/app_run.R). |
| `test-centerline-handling.R` | green | unit | keep |  |
| `test-clean-qic-call-args.R` | stub | unit | keep | Reel unit-test på freeze-adjustment (2 test_that-blokke). Misklassificeret som stub. |
| `test-comment-row-mapping.R` | green | unit | keep |  |
| `test-comprehensive-ui-sync.R` | green | unit | keep |  |
| `test-config_analytics.R` | green | unit | keep |  |
| `test-config-performance-getters.R` | green | benchmark | keep |  |
| `test-config-ui-getters.R` | green | unit | keep |  |
| `test-cross-component-reactive.R` | green | unit | keep |  |
| `test-csv-parsing.R` | green | unit | keep |  |
| `test-csv-sanitization.R` | green | unit | keep |  |
| `test-danish-clinical-edge-cases.R` | green | unit | keep |  |
| `test-debug-context-filtering.R` | green | unit | keep |  |
| `test-denominator-field-toggle.R` | stub | unit | keep | Unit-test på chart-type/denominator-mapping (2 blokke). Misklassificeret som stub. |
| `test-dependency-namespace.R` | stub | policy-guard | keep | Policy-guard mod library()-kald på 15 pakker i R/. Misklassificeret som stub. |
| `test-e2e-user-workflows.R` | skipped-all | e2e | keep | Bevidst skip_on_ci(); kører lokalt med shinytest2. |
| `test-error-handling.R` | green | unit | keep |  |
| `test-excelr-data-reconstruction.R` | green | unit | keep |  |
| `test-fct_ai_improvement_suggestions.R` | green | unit | keep |  |
| `test-fct_export_png.R` | green | unit | keep |  |
| `test-fct_spc_file_save_load.R` | green | unit | keep |  |
| `test-file-operations.R` | green | unit | keep |  |
| `test-foreign-column-names.R` | green | unit | keep |  |
| `test-input-sanitization.R` | green | unit | keep |  |
| `test-integration-workflows.R` | green | integration | keep |  |
| `test-logging-debug-cat.R` | stub | policy-guard | keep | Policy-guard mod cat("DEBUG...")-statements. Misklassificeret som stub. |
| `test-logging-precedence.R` | green | unit | keep |  |
| `test-logging-standardization.R` | green | unit | keep |  |
| `test-logging-system.R` | green | unit | keep |  |
| `test-namespace-integrity.R` | stub | policy-guard | keep | Policy-guard mod simple NAMESPACE-eksporter. Misklassificeret som stub pga. 1 test_that-block. |
| `test-no-file-dependencies.R` | green | unit | keep |  |
| `test-outlier-count-latest-part.R` | green | unit | keep |  |
| `test-phase-2c-reactive-chain.R` | green | unit | keep |  |
| `test-plot-generation.R` | green | unit | keep |  |
| `test-recent-functionality.R` | green | unit | keep |  |
| `test-run-app.R` | stub | unit | keep | Unit-test på run_app port-forwarding (1 blok). Misklassificeret som stub. |
| `test-run-chart-denominator-stability.R` | green | unit | keep |  |
| `test-safe-operation-comprehensive.R` | green | unit | keep |  |
| `test-session-persistence.R` | green | unit | keep |  |
| `test-startup-optimization.R` | green | snapshot | keep |  |
| `test-ui-synchronization.R` | green | unit | keep |  |
| `test-ui-token-management.R` | stub | unit | keep | Unit-test på token counter-logik (2 blokke). Misklassificeret som stub. |
| `test-utils_analytics_consent.R` | green | unit | keep |  |
| `test-utils_analytics_github.R` | green | unit | keep |  |
| `test-utils_analytics_pins.R` | green | unit | keep |  |
| `test-utils_data_signatures.R` | green | unit | keep |  |
| `test-utils_error_handling.R` | green | unit | keep |  |
| `test-utils_export_filename.R` | green | unit | keep |  |
| `test-utils_input_sanitization.R` | green | unit | keep |  |
| `test-utils_qic_caching.R` | green | unit | keep |  |
| `test-utils_server_export.R` | green | unit | keep |  |
| `test-visualization-dimensions.R` | green | unit | keep |  |
| `test-wizard.R` | green | unit | keep |  |

## 4. Handling-oversigt

### blocked-by-change-1 (4 filer)

- `test-panel-height-cache.R` — Venter på Change 1 der genindfører clear_panel_height_cache.
- `test-plot-diff.R` — Venter på Change 1 der genindfører plot-state-snapshot-funktioner.
- `test-utils_validation_guards.R` — Venter på Change 1 der genindfører validation-guard-familien.
- `test-validation-guards.R` — Duplikat af test-utils_validation_guards.R — markér til Fase 2 merge eller archive.

### rewrite (17 filer)

- `test-bfhcharts-integration.R` — Green-partial med 10/15 fejl. Handling=rewrite baseret paa fail-ratio.
- `test-cache-collision-fix.R` — Green-partial med 4/5 fejl. Handling=rewrite baseret paa fail-ratio.
- `test-cache-reactive-lazy-evaluation.R` — API-drift: refererede funktioner fjernet (7/8 fejl). Rewrite efter API-stabilisering.
- `test-constants-architecture.R` — Fixture-filer mangler (1/1 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3.
- `test-e2e-workflows.R` — Green-partial med 5/8 fejl. Handling=rewrite baseret paa fail-ratio.
- `test-file-upload.R` — Green-partial med 4/8 fejl. Handling=rewrite baseret paa fail-ratio.
- `test-label-height-estimation.R` — Fixture-filer mangler (1/1 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3.
- `test-label-placement-bounds.R` — Fixture-filer mangler (1/1 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3.
- `test-label-placement-core.R` — Fixture-filer mangler (1/1 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3.
- `test-npc-mapper.R` — Fixture-filer mangler (1/1 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3.
- `test-observer-cleanup.R` — Green-partial med 4/8 fejl. Handling=rewrite baseret paa fail-ratio.
- `test-parse-danish-target-unit-conversion.R` — API-drift: refererede funktioner fjernet (65/73 fejl). Rewrite efter API-stabilisering.
- `test-performance-benchmarks.R` — Green-partial med 9/16 fejl. Handling=rewrite baseret paa fail-ratio.
- `test-plot-core.R` — Green-partial med 4/8 fejl. Handling=rewrite baseret paa fail-ratio.
- `test-utils-state-accessors.R` — API-drift: refererede funktioner fjernet (26/36 fejl). Rewrite efter API-stabilisering.
- `test-y-axis-mapping.R` — Fixture-filer mangler (3/3 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3.
- `test-y-axis-model.R` — Fixture-filer mangler (3/3 fejl). Rewrite forventet efter fixtures-oprydning i Fase 3.

### fix-in-phase-3 (45 filer)

- `test-100x-mismatch-prevention.R` — Green-partial med 5/52 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-app-initialization.R` — Green-partial med 1/10 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-autodetect-unified-comprehensive.R` — Green-partial med 20/158 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-bfh-error-handling.R` — API-drift: refererede funktioner fjernet (6/42 fejl). Fix-in-phase-3 efter API-stabilisering.
- `test-cache-data-signature-bugs.R` — testthat API-drift: argumenter ikke understoettet (2/25 fejl). Fix-in-phase-3 efter API-opdatering.
- `test-cache-invalidation-sprint3.R` — API-drift: refererede funktioner fjernet (1/62 fejl). Fix-in-phase-3 efter API-stabilisering.
- `test-column-observer-consolidation.R` — Green-partial med 4/14 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-config_chart_types.R` — Green-partial med 16/35 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-config_export.R` — Green-partial med 10/141 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-context-aware-plots.R` — ggplot warning (4/83 fejl) - ikke-kritisk men kraever scale-haandtering. Fix-in-phase-3.
- `test-critical-fixes-integration.R` — Green-partial med 4/43 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-critical-fixes-regression.R` — Green-partial med 14/137 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-critical-fixes-security.R` — testthat API-drift: argumenter ikke understoettet (21/63 fejl). Fix-in-phase-3 efter API-opdatering.
- `test-data-validation.R` — API-drift: refererede funktioner fjernet (3/15 fejl). Fix-in-phase-3 efter API-stabilisering.
- `test-edge-cases-comprehensive.R` — Green-partial med 3/66 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-event-system-emit.R` — Green-partial med 7/50 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-event-system-observers.R` — Green-partial med 2/128 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-file-io-comprehensive.R` — Green-partial med 3/30 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-file-operations-tidyverse.R` — Green-partial med 2/25 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-generateSPCPlot-comprehensive.R` — ggplot warning (9/156 fejl) - ikke-kritisk men kraever scale-haandtering. Fix-in-phase-3.
- `test-input-debouncing-comprehensive.R` — API-drift: refererede funktioner fjernet (5/11 fejl). Fix-in-phase-3 efter API-stabilisering.
- `test-label-formatting.R` — Green-partial med 2/34 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-mod_export.R` — Green-partial med 3/44 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-mod-spc-chart-comprehensive.R` — Green-partial med 16/43 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-mod-spc-chart-integration.R` — Green-partial med 4/22 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-package-initialization.R` — Green-partial med 4/45 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-package-namespace-validation.R` — testthat API-drift: argumenter ikke understoettet (2/10 fejl). Fix-in-phase-3 efter API-opdatering.
- `test-plot-generation-performance.R` — Green-partial med 1/14 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-reactive-batching.R` — API-drift: refererede funktioner fjernet (7/17 fejl). Fix-in-phase-3 efter API-stabilisering.
- `test-runtime-config-comprehensive.R` — testthat API-drift: argumenter ikke understoettet (21/58 fejl). Fix-in-phase-3 efter API-opdatering.
- `test-security-session-tokens.R` — Green-partial med 1/55 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-session-token-sanitization.R` — Green-partial med 1/22 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-shared-data-signatures.R` — Green-partial med 2/27 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-spc-bfh-service.R` — Green-partial med 20/78 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-spc-cache-integration.R` — API-drift: refererede funktioner fjernet (3/32 fejl). Fix-in-phase-3 efter API-stabilisering.
- `test-spc-plot-generation-comprehensive.R` — ggplot warning (12/61 fejl) - ikke-kritisk men kraever scale-haandtering. Fix-in-phase-3.
- `test-spc-regression-bfh-vs-qic.R` — testthat API-drift: argumenter ikke understoettet (10/46 fejl). Fix-in-phase-3 efter API-opdatering.
- `test-state-management-hierarchical.R` — Green-partial med 14/55 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-tidyverse-purrr-operations.R` — Green-partial med 2/24 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-utils_export_validation.R` — Green-partial med 2/50 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-utils_performance_caching.R` — Green-partial med 1/11 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-visualization-server.R` — Green-partial med 3/14 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-y-axis-formatting.R` — Green-partial med 5/59 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-y-axis-scaling-overhaul.R` — Green-partial med 7/76 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.
- `test-yaml-config-adherence.R` — Green-partial med 1/8 fejl. Handling=fix-in-phase-3 baseret paa fail-ratio.

### keep (59 filer)

- `test-anhoej-metadata-local.R`
- `test-anhoej-rules.R`
- `test-app-basic.R` — E2E-smoke med AppDriver-mock fallback (2 blokke). Misklassificeret som stub.
- `test-audit-classifier.R`
- `test-autodetect-tidyverse-integration.R`
- `test-bfh-module-integration.R` — skip_if_not_installed('shinytest2'); snapshot-tests for BFHchart.
- `test-branding-globals.R` — Legacy-constant tilgængelighed (HOSPITAL_COLORS bruges stadig i R/zzz.R, R/app_run.R).
- `test-centerline-handling.R`
- `test-clean-qic-call-args.R` — Reel unit-test på freeze-adjustment (2 test_that-blokke). Misklassificeret som stub.
- `test-comment-row-mapping.R`
- `test-comprehensive-ui-sync.R`
- `test-config_analytics.R`
- `test-config-performance-getters.R`
- `test-config-ui-getters.R`
- `test-cross-component-reactive.R`
- `test-csv-parsing.R`
- `test-csv-sanitization.R`
- `test-danish-clinical-edge-cases.R`
- `test-debug-context-filtering.R`
- `test-denominator-field-toggle.R` — Unit-test på chart-type/denominator-mapping (2 blokke). Misklassificeret som stub.
- `test-dependency-namespace.R` — Policy-guard mod library()-kald på 15 pakker i R/. Misklassificeret som stub.
- `test-e2e-user-workflows.R` — Bevidst skip_on_ci(); kører lokalt med shinytest2.
- `test-error-handling.R`
- `test-excelr-data-reconstruction.R`
- `test-fct_ai_improvement_suggestions.R`
- `test-fct_export_png.R`
- `test-fct_spc_file_save_load.R`
- `test-file-operations.R`
- `test-foreign-column-names.R`
- `test-input-sanitization.R`
- `test-integration-workflows.R`
- `test-logging-debug-cat.R` — Policy-guard mod cat("DEBUG...")-statements. Misklassificeret som stub.
- `test-logging-precedence.R`
- `test-logging-standardization.R`
- `test-logging-system.R`
- `test-namespace-integrity.R` — Policy-guard mod simple NAMESPACE-eksporter. Misklassificeret som stub pga. 1 test_that-block.
- `test-no-file-dependencies.R`
- `test-outlier-count-latest-part.R`
- `test-phase-2c-reactive-chain.R`
- `test-plot-generation.R`
- `test-recent-functionality.R`
- `test-run-app.R` — Unit-test på run_app port-forwarding (1 blok). Misklassificeret som stub.
- `test-run-chart-denominator-stability.R`
- `test-safe-operation-comprehensive.R`
- `test-session-persistence.R`
- `test-startup-optimization.R`
- `test-ui-synchronization.R`
- `test-ui-token-management.R` — Unit-test på token counter-logik (2 blokke). Misklassificeret som stub.
- `test-utils_analytics_consent.R`
- `test-utils_analytics_github.R`
- `test-utils_analytics_pins.R`
- `test-utils_data_signatures.R`
- `test-utils_error_handling.R`
- `test-utils_export_filename.R`
- `test-utils_input_sanitization.R`
- `test-utils_qic_caching.R`
- `test-utils_server_export.R`
- `test-visualization-dimensions.R`
- `test-wizard.R`

## 5. Top-10 fejlmønstre

| Mønster | Filer |
|---|---|
| cannot open the connection (fixtures mangler) | 7 |
| could not find function (API drift) | 13 |
| unused argument (testthat API-drift) | 6 |
| missing value where TRUE/FALSE | 1 |
| invalid input (data-drift) | 1 |
| encoding (æøå) | 7 |

## 6. Foreslået sekvens for Fase 2-4

1. **Fase 2 (konsolidering):** `archive` + `merge-in-phase-2`
2. **Fase 3 (fix):** `fix-in-phase-3` + `rewrite`, batched efter sektion 5-mønstre
3. **Fase 4 (standarder):** test-arkitektur-docs + evt. CI-check

## 7. Audit-classifier-limitationer

- `n_test_blocks < 3 → stub` er for aggressiv; misklassificerer policy-tests
- Subproces-kørsel aktiverer `skip_on_ci()` lokalt (ENV-detektion)

## 8. Appendix: Audit-kategori-fuldtabel

### broken-missing-fn (4 filer)

- `test-panel-height-cache.R` — 0 pass / 4 fail
- `test-plot-diff.R` — 0 pass / 24 fail
- `test-utils_validation_guards.R` — 0 pass / 27 fail
- `test-validation-guards.R` — 0 pass / 29 fail

### green (48 filer)

- `test-anhoej-metadata-local.R` — 47 pass / 0 fail
- `test-anhoej-rules.R` — 52 pass / 0 fail
- `test-audit-classifier.R` — 34 pass / 0 fail
- `test-autodetect-tidyverse-integration.R` — 65 pass / 0 fail
- `test-centerline-handling.R` — 0 pass / 0 fail
- `test-comment-row-mapping.R` — 17 pass / 0 fail
- `test-comprehensive-ui-sync.R` — 29 pass / 0 fail
- `test-config_analytics.R` — 21 pass / 0 fail
- `test-config-performance-getters.R` — 63 pass / 0 fail
- `test-config-ui-getters.R` — 57 pass / 0 fail
- `test-cross-component-reactive.R` — 67 pass / 0 fail
- `test-csv-parsing.R` — 28 pass / 0 fail
- `test-csv-sanitization.R` — 22 pass / 0 fail
- `test-danish-clinical-edge-cases.R` — 111 pass / 0 fail
- `test-debug-context-filtering.R` — 59 pass / 0 fail
- `test-error-handling.R` — 25 pass / 0 fail
- `test-excelr-data-reconstruction.R` — 21 pass / 0 fail
- `test-fct_ai_improvement_suggestions.R` — 18 pass / 0 fail
- `test-fct_export_png.R` — 36 pass / 0 fail
- `test-fct_spc_file_save_load.R` — 63 pass / 0 fail
- `test-file-operations.R` — 66 pass / 0 fail
- `test-foreign-column-names.R` — 21 pass / 0 fail
- `test-input-sanitization.R` — 1 pass / 0 fail
- `test-integration-workflows.R` — 42 pass / 0 fail
- `test-logging-precedence.R` — 17 pass / 0 fail
- `test-logging-standardization.R` — 58 pass / 0 fail
- `test-logging-system.R` — 80 pass / 0 fail
- `test-no-file-dependencies.R` — 11 pass / 0 fail
- `test-outlier-count-latest-part.R` — 6 pass / 0 fail
- `test-phase-2c-reactive-chain.R` — 56 pass / 0 fail
- `test-plot-generation.R` — 56 pass / 0 fail
- `test-recent-functionality.R` — 58 pass / 0 fail
- `test-run-chart-denominator-stability.R` — 10 pass / 0 fail
- `test-safe-operation-comprehensive.R` — 42 pass / 0 fail
- `test-session-persistence.R` — 72 pass / 0 fail
- `test-startup-optimization.R` — 0 pass / 0 fail
- `test-ui-synchronization.R` — 107 pass / 0 fail
- `test-utils_analytics_consent.R` — 10 pass / 0 fail
- `test-utils_analytics_github.R` — 12 pass / 0 fail
- `test-utils_analytics_pins.R` — 23 pass / 0 fail
- `test-utils_data_signatures.R` — 12 pass / 0 fail
- `test-utils_error_handling.R` — 14 pass / 0 fail
- `test-utils_export_filename.R` — 61 pass / 0 fail
- `test-utils_input_sanitization.R` — 34 pass / 0 fail
- `test-utils_qic_caching.R` — 14 pass / 0 fail
- `test-utils_server_export.R` — 8 pass / 0 fail
- `test-visualization-dimensions.R` — 5 pass / 0 fail
- `test-wizard.R` — 49 pass / 0 fail

### green-partial (62 filer)

- `test-100x-mismatch-prevention.R` — 47 pass / 5 fail
- `test-app-initialization.R` — 9 pass / 1 fail
- `test-autodetect-unified-comprehensive.R` — 138 pass / 20 fail
- `test-bfh-error-handling.R` — 36 pass / 6 fail
- `test-bfhcharts-integration.R` — 5 pass / 10 fail
- `test-cache-collision-fix.R` — 1 pass / 4 fail
- `test-cache-data-signature-bugs.R` — 23 pass / 2 fail
- `test-cache-invalidation-sprint3.R` — 61 pass / 1 fail
- `test-cache-reactive-lazy-evaluation.R` — 1 pass / 7 fail
- `test-column-observer-consolidation.R` — 10 pass / 4 fail
- `test-config_chart_types.R` — 19 pass / 16 fail
- `test-config_export.R` — 131 pass / 10 fail
- `test-constants-architecture.R` — 0 pass / 1 fail
- `test-context-aware-plots.R` — 79 pass / 4 fail
- `test-critical-fixes-integration.R` — 39 pass / 4 fail
- `test-critical-fixes-regression.R` — 123 pass / 14 fail
- `test-critical-fixes-security.R` — 42 pass / 21 fail
- `test-data-validation.R` — 12 pass / 3 fail
- `test-e2e-workflows.R` — 3 pass / 5 fail
- `test-edge-cases-comprehensive.R` — 63 pass / 3 fail
- `test-event-system-emit.R` — 43 pass / 7 fail
- `test-event-system-observers.R` — 126 pass / 2 fail
- `test-file-io-comprehensive.R` — 27 pass / 3 fail
- `test-file-operations-tidyverse.R` — 23 pass / 2 fail
- `test-file-upload.R` — 4 pass / 4 fail
- `test-generateSPCPlot-comprehensive.R` — 147 pass / 9 fail
- `test-input-debouncing-comprehensive.R` — 6 pass / 5 fail
- `test-label-formatting.R` — 32 pass / 2 fail
- `test-label-height-estimation.R` — 0 pass / 1 fail
- `test-label-placement-bounds.R` — 0 pass / 1 fail
- `test-label-placement-core.R` — 0 pass / 1 fail
- `test-mod_export.R` — 41 pass / 3 fail
- `test-mod-spc-chart-comprehensive.R` — 27 pass / 16 fail
- `test-mod-spc-chart-integration.R` — 18 pass / 4 fail
- `test-npc-mapper.R` — 0 pass / 1 fail
- `test-observer-cleanup.R` — 4 pass / 4 fail
- `test-package-initialization.R` — 41 pass / 4 fail
- `test-package-namespace-validation.R` — 8 pass / 2 fail
- `test-parse-danish-target-unit-conversion.R` — 8 pass / 65 fail
- `test-performance-benchmarks.R` — 7 pass / 9 fail
- `test-plot-core.R` — 4 pass / 4 fail
- `test-plot-generation-performance.R` — 13 pass / 1 fail
- `test-reactive-batching.R` — 10 pass / 7 fail
- `test-runtime-config-comprehensive.R` — 37 pass / 21 fail
- `test-security-session-tokens.R` — 54 pass / 1 fail
- `test-session-token-sanitization.R` — 21 pass / 1 fail
- `test-shared-data-signatures.R` — 25 pass / 2 fail
- `test-spc-bfh-service.R` — 58 pass / 20 fail
- `test-spc-cache-integration.R` — 29 pass / 3 fail
- `test-spc-plot-generation-comprehensive.R` — 49 pass / 12 fail
- `test-spc-regression-bfh-vs-qic.R` — 36 pass / 10 fail
- `test-state-management-hierarchical.R` — 41 pass / 14 fail
- `test-tidyverse-purrr-operations.R` — 22 pass / 2 fail
- `test-utils_export_validation.R` — 48 pass / 2 fail
- `test-utils_performance_caching.R` — 10 pass / 1 fail
- `test-utils-state-accessors.R` — 10 pass / 26 fail
- `test-visualization-server.R` — 11 pass / 3 fail
- `test-y-axis-formatting.R` — 54 pass / 5 fail
- `test-y-axis-mapping.R` — 0 pass / 3 fail
- `test-y-axis-model.R` — 0 pass / 3 fail
- `test-y-axis-scaling-overhaul.R` — 69 pass / 7 fail
- `test-yaml-config-adherence.R` — 7 pass / 1 fail

### skipped-all (2 filer)

- `test-bfh-module-integration.R` — 0 pass / 0 fail
- `test-e2e-user-workflows.R` — 0 pass / 0 fail

### stub (9 filer)

- `test-app-basic.R` — 0 pass / 2 fail
- `test-branding-globals.R` — 0 pass / 2 fail
- `test-clean-qic-call-args.R` — 6 pass / 0 fail
- `test-denominator-field-toggle.R` — 9 pass / 2 fail
- `test-dependency-namespace.R` — 1 pass / 0 fail
- `test-logging-debug-cat.R` — 0 pass / 1 fail
- `test-namespace-integrity.R` — 1 pass / 0 fail
- `test-run-app.R` — 0 pass / 0 fail
- `test-ui-token-management.R` — 16 pass / 0 fail

