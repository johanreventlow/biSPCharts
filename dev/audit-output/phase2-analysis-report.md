# Fase 2 Analyse-rapport

**Dato:** 2026-04-17
**Purpose:** Grundlag for archive/merge/rewrite-beslutninger i Fase 2

---

## 1. Archive-kandidater

### Metoder anvendt

1. Scan for legacy-filnavne (`test-phase*.R`, `test-fase*.R`, `test-sprint*.R`)
2. Scan for direkte BFHcharts/BFHtheme/BFHllm-import i testfiler
3. Git-forensics for identificerede kandidater

### Fund: Legacy-filnavne

```
test-phase-2c-reactive-chain.R   # fund via grep -E '(test-phase|test-fase|test-sprint)'
test-cache-invalidation-sprint3.R  # "sprint" i filnavn
```

### Fund: Direkte ekstern pakke-import

```
tests/testthat/test-bfh-error-handling.R       (BFHcharts::)
tests/testthat/test-bfhcharts-integration.R    (BFHcharts::)
tests/testthat/test-fct_ai_improvement_suggestions.R  (BFHllm:: via mock)
tests/testthat/test-fct_export_png.R           (BFHcharts::)
tests/testthat/test-utils_server_export.R      (BFHcharts::)
```

### Git-forensics resultater

- `test-phase-2c-reactive-chain.R`: Oprettet i commit `ef03343` ("chore(phase-2c): establish reactive chain baseline and execution plan"). Har `handling=keep` i manifest og indeholder 10 veldefinerede unit-tests mod `compute_spc_results_bfh`, `module_data_reactive` m.fl. **Kriterium 4 opfyldt** (legacy-filnavn "phase-2c"), men **kriterium 1 IKKE opfyldt** (funktionerne er ikke fjernet), **kriterium 3 IKKE opfyldt** (ingen bedre alternativ). → **BEHOLD** (kun 1 kriterium matched)

- `test-cache-invalidation-sprint3.R`: Oprettet i commit `bb663ff` ("feat(security): implement Sprint 3 cache invalidation and XSS hardening"). Har `handling=fix-in-phase-3`. Tester `clear_performance_cache`, `cache_result`, event-baseret cache-invalidation — alle aktive R/-funktioner. **Kriterium 4 opfyldt** (sprint-filnavn), men **kriterium 1 IKKE opfyldt** (cache API er intakt), **kriterium 3 IKKE opfyldt**. → **BEHOLD** (kun 1 kriterium matched)

- `test-bfhcharts-integration.R`: Tester direkte `BFHcharts::create_spc_chart` og `BFHcharts::spc_plot_config`. Audit-stderr: `Error: 'spc_plot_config' is not an exported object from 'namespace:BFHcharts'` — tester BFHcharts API der ikke eksisterer i nuværende version. `handling=rewrite`. **Kriterium 2 opfyldt** (tester migreret BFHcharts-funktionalitet), men **kriterium 4 IKKE opfyldt** (filnavn er ikke legacy-format), **kriterium 1 IKKE opfyldt** (BFHcharts eksisterer, API er blot ændret). → **BEHOLD som rewrite-kandidat** (kun 1 kriterium matched, rewrite er korrekt handling)

### Archive-kandidat-liste

| Fil | Matched kriterier | Foreslået handling | Begrundelse |
|---|---|---|---|
| (ingen) | — | — | Ingen filer matchede ≥2 kriterier. |

**Konklusion Task 2:** Ingen filer kvalificerer til arkivering. De identificerede kandidater opfylder kun 1 kriterium hver:
- `test-phase-2c-reactive-chain.R`: kun kriterium 4 (legacy-navn), men tester aktiv funktionalitet
- `test-cache-invalidation-sprint3.R`: kun kriterium 4 (sprint-navn), men tester aktiv cache-API
- `test-bfhcharts-integration.R`: kun kriterium 2 (BFHcharts), men er korrekt markeret som rewrite

---

## 2. Merge-kluster-verifikation

### Dataaggregering

| Cluster | Filer | Types | Handlings | LOC (samlet) | LOC OK (<500)? | Type OK (ensartet)? |
|---|---|---|---|---|---|---|
| y-axis (4) | test-y-axis-formatting.R, test-y-axis-mapping.R, test-y-axis-model.R, test-y-axis-scaling-overhaul.R | unit, unit, unit, unit | fix-in-p3, rewrite, rewrite, fix-in-p3 | 641 LOC | NEJ (641 > 500) | JA |
| critical-fixes (3) | test-critical-fixes-integration.R, test-critical-fixes-regression.R, test-critical-fixes-security.R | snapshot, unit, unit | fix-in-p3, fix-in-p3, fix-in-p3 | 1182 LOC | NEJ | Nej (snapshot+unit) |
| event-system (2) | test-event-system-emit.R, test-event-system-observers.R | unit, unit | fix-in-p3, fix-in-p3 | 1113 LOC | NEJ (1113 > 500) | JA |
| file-operations (2) | test-file-operations-tidyverse.R, test-file-operations.R | unit, unit | fix-in-p3, keep | 879 LOC | NEJ (879 > 500) | JA |
| label-placement (2) | test-label-placement-bounds.R, test-label-placement-core.R | unit, unit | rewrite, rewrite | 557 LOC | NEJ (557 > 500) | JA |
| mod-spc (2) | test-mod-spc-chart-comprehensive.R, test-mod-spc-chart-integration.R | integration, integration | fix-in-p3, fix-in-p3 | 763 LOC | NEJ (763 > 500) | JA |
| plot-generation (2) | test-plot-generation-performance.R, test-plot-generation.R | e2e, unit | fix-in-p3, keep | 743 LOC | NEJ (743 > 500) | Nej (e2e+unit) |

### Tema-verifikation (udvalgte klustre)

**y-axis (4 filer):**
- test-y-axis-formatting.R: 12 tests om label formattering, decimal separatorer, procentformater
- test-y-axis-mapping.R: 3 tests om y-axis mapping (fixture-baserede, 100% fail)
- test-y-axis-model.R: 3 tests om y-axis model (fixture-baserede, 100% fail)
- test-y-axis-scaling-overhaul.R: 16 tests om axis skalering, bounderies, range-beregning
- **Tema-sammenhæng:** JA — alle handler om y-axis logik

**event-system (2 filer):**
- test-event-system-emit.R: 9 tests om emit API
- test-event-system-observers.R: 23 tests om observer setup og reaktivitet
- **Tema-sammenhæng:** JA

**label-placement (2 filer):**
- test-label-placement-bounds.R: 1 test (fixture-mangler, 100% fail)
- test-label-placement-core.R: 18 tests om core placement-logik (1 test failing)
- **Tema-sammenhæng:** JA

### Merge-verifikation-tabel

| Cluster | Tema OK? | LOC OK (<500)? | Type OK? | Handling | Begrundelse |
|---|---|---|---|---|---|
| y-axis (4) | JA | NEJ (641 LOC) | JA | **BEHOLD SEPARAT** | LOC-kriterium fejler. test-y-axis-mapping.R og test-y-axis-model.R auto-downgraded til merge (se Task 3). |
| critical-fixes (3) | NEJ | NEJ (1182 LOC) | NEJ | **BEHOLD SEPARAT** | Spec: "3 different concerns". Snapshot+unit mismatch. |
| event-system (2) | JA | NEJ (1113 LOC) | JA | **BEHOLD SEPARAT** | LOC-kriterium fejler markant (1113 > 500). |
| file-operations (2) | JA | NEJ (879 LOC) | JA | **BEHOLD SEPARAT** | LOC-kriterium fejler. test-file-operations.R bruger describe/it-syntax, ikke test_that. |
| label-placement (2) | JA | NEJ (557 LOC) | JA | **BEHOLD SEPARAT** | LOC-kriterium fejler marginalt (557 > 500). test-label-placement-bounds.R auto-downgraded til merge (se Task 3). |
| mod-spc (2) | JA | NEJ (763 LOC) | JA | **BEHOLD SEPARAT** | LOC-kriterium fejler. Spec: "verificér". |
| plot-generation (2) | NEJ | NEJ (743 LOC) | NEJ | **BEHOLD SEPARAT** | Spec: "behold separat (benchmark + unit)". e2e og unit er forskellige typer. |

**Konklusion Task 3:** 0 klustre kvalificerer til merge i fase 2. Samtlige 7 klustre fejler LOC-kriteriet (>500 LOC). Kritiske og plot-generation klustre fejler derudover type-kriteriet. Den effektive fil-reduktion fra merge er 0 i fase 2.

**Bemærkning:** De 4 lille rewrite-filer i y-axis og label-placement klustrene (test-y-axis-mapping.R, test-y-axis-model.R, test-label-placement-bounds.R, test-label-placement-core.R) behandles via auto-downgrade i Task 4.

---

## 3. Rewrite-hybrid-auto-downgrade

### Rewrite-kandidater (17 filer total)

| Fil | Tests | Fail% | Size | Cluster? | Decision | Plan |
|---|---|---|---|---|---|---|
| test-bfhcharts-integration.R | 15 | 67% | mellem | nej | REWRITE: salvage | Opdatér BFHcharts API-kald til nuværende eksporterede funktioner. Stderr: `spc_plot_config` ikke eksporteret. Studér BFHcharts namespace. |
| test-cache-collision-fix.R | 5 | 80% | mellem | nej | REWRITE: salvage | Studér R/utils_performance_caching.R, R/utils_cache_generators.R |
| test-cache-reactive-lazy-evaluation.R | 8 | 88% | mellem | nej | REWRITE: salvage | Studér R/utils_performance_caching.R (reaktive evalueringspunkter) |
| test-constants-architecture.R | 1 | 100% | lille | nej | **AUTO-DG: arkivér** | Tester `create_config_registry()` fra `utils_config_consolidation.R` som ikke eksisterer i R/. Solo + 100% fail. |
| test-e2e-workflows.R | 8 | 62% | mellem | nej | REWRITE: salvage | Studér R/mod_spc_chart_server.R (integration workflows) |
| test-file-upload.R | 8 | 50% | mellem | nej | REWRITE: salvage | Studér R/fct_file_operations.R |
| test-label-height-estimation.R | 1 | 100% | lille | nej | **AUTO-DG: arkivér** | Tester `estimate_label_height_npc()` fra `utils_standalone_label_placement.R` (ikke en R/-fil). Solo + 100% fail. |
| test-label-placement-bounds.R | 1 | 100% | lille | JA (label-placement) | **AUTO-DG: merge** | 1 test, 100% fail, i label-placement kluster. Merge ind i test-label-placement-core.R (canonical med 18 tests) |
| test-label-placement-core.R | 1* | 100% | lille | JA (label-placement) | **AUTO-DG: merge** | 1 failing test (fixture mangler). 18 tests total — men YAML siger 1/1 fail → merge decision baseret på YAML-data. Se note. |
| test-npc-mapper.R | 1 | 100% | lille | nej | **AUTO-DG: arkivér** | Tester `npc_mapper_from_plot()` fra `utils_standalone_label_placement.R` (ikke eksporteret R/-funktion). Solo + 100% fail. |
| test-observer-cleanup.R | 8 | 50% | mellem | nej | REWRITE: salvage | Studér R/utils_server_server_management.R (observer cleanup patterns) |
| test-parse-danish-target-unit-conversion.R | 73 | 89% | **stor** | nej | **REWRITE: TDD** | 65/73 fejl. API-drift: refererede funktioner fjernet. Studér R/utils_danish_locale.R for nuværende parse API. |
| test-performance-benchmarks.R | 16 | 56% | **stor** | nej | **REWRITE: TDD** | 9/16 fejl. Studér R/utils_performance_caching.R, R/utils_microbenchmark.R, R/config_performance_getters.R |
| test-plot-core.R | 8 | 50% | mellem | nej | REWRITE: salvage | Studér R/fct_spc_bfh_service.R (plot core logik) |
| test-utils-state-accessors.R | 36 | 72% | **stor** | nej | **REWRITE: TDD** | 26/36 fejl. API-drift. Studér R/utils_state_accessors.R, R/state_management.R |
| test-y-axis-mapping.R | 3 | 100% | lille | JA (y-axis) | **AUTO-DG: merge** | 3 tests, 100% fail (fixture mangler), i y-axis kluster. Merge ind i test-y-axis-scaling-overhaul.R (canonical, 16 tests) |
| test-y-axis-model.R | 3 | 100% | lille | JA (y-axis) | **AUTO-DG: merge** | 3 tests, 100% fail (fixture mangler), i y-axis kluster. Merge ind i test-y-axis-scaling-overhaul.R (canonical) |

**Note om test-label-placement-core.R:** Audit-JSON viser 1/1 fail (fixture-baseret), men filen indeholder faktisk 18 test_that-blokke. Auto-downgrade-beslutningen er baseret på YAML-audit-data (1 test, 100% fail). Anbefaling: brugeren bør verificere om denne fil reelt har 18 tests kørende eller kun 1 — hvis 18 tests, bør den forblive som rewrite (salvage) fremfor auto-DG-merge.

### Opsummering auto-downgrade

**Auto-downgraded fra rewrite (5 filer i alt):**
- Merge: test-y-axis-mapping.R → canonical: test-y-axis-scaling-overhaul.R
- Merge: test-y-axis-model.R → canonical: test-y-axis-scaling-overhaul.R
- Merge: test-label-placement-bounds.R → canonical: test-label-placement-core.R
- Merge: test-label-placement-core.R → canonical: (se note ovenfor — tvivlstilfælde)
- Arkivér: test-constants-architecture.R (R-funktion `create_config_registry` eksisterer ikke)
- Arkivér: test-label-height-estimation.R (R-funktion `estimate_label_height_npc` ikke i R/ som eksporteret funktion)
- Arkivér: test-npc-mapper.R (R-funktion `npc_mapper_from_plot` ikke i R/ som eksporteret funktion)

**Egentlige rewrites (9 filer forbliver):**
- Salvage (4-15 tests): test-bfhcharts-integration.R, test-cache-collision-fix.R, test-cache-reactive-lazy-evaluation.R, test-e2e-workflows.R, test-file-upload.R, test-observer-cleanup.R, test-plot-core.R (7 filer)
- TDD klassisk (>15 tests): test-parse-danish-target-unit-conversion.R (73 tests), test-performance-benchmarks.R (16 tests), test-utils-state-accessors.R (36 tests) (3 filer)

**Tvivlstilfælde (kræver bruger-beslutning):**
- `test-label-placement-core.R`: YAML siger 1 test/100% fail, men filen indeholder 18 test_that-blokke. Sandsynligvis er kun 1 test kørende pga. source-fejl. Bruger bør afgøre: auto-DG-merge (som ved 1-test analyse) eller salvage-rewrite (som ved 18-test analyse).

---

## 4. Net-effekt

**Baseline:** 121 filer

### Operationer

| Operation | Påvirkede filer | Filer slettes |
|---|---|---|
| Archive direkte (Task 2) | 0 | 0 |
| Merge-klustre (Task 3) | 0 | 0 (ingen klustre merger) |
| Auto-downgrade → arkivér | 3 filer | 3 |
| Auto-downgrade → merge (kildes slettes) | 4 filer (3 kildes + 1 canonical) | 3 kildes slettes |
| Rewrite (same fil, nyt indhold) | 10 filer (7 salvage + 3 TDD) | 0 |
| **Total** | **~17 filer berørt** | **~6 filer** |

**Note om label-placement-core tvivlstilfælde:** Ovenfor er 3 kildes inkluderet (y-axis-mapping, y-axis-model, label-placement-bounds). Hvis test-label-placement-core.R bekræftes som auto-DG-merge, slettes den som kilde og label-placement-core.R udgår også (= 4 kildes slettes, 7 filer netto).

### Slutresultat (forventet)

```
Baseline:                121 filer
- Archive (auto-DG):      -3 filer (constants-architecture, label-height-estimation, npc-mapper)
- Merge kildes (auto-DG): -3 filer (y-axis-mapping, y-axis-model, label-placement-bounds)
  [+ evt. -1 label-placement-core hvis tvivlstilfælde bekræftes]
= Slutresultat:           ~115 filer (evt. ~114)
```

**Forventet reduktion: ~6 filer** (spec-mål var 10-21 filer = 100-110 resulterende).

### Vurdering mod spec-mål

Reduktionen på ~6 filer er under spec-målet på 11-21 filer. Årsagerne:
1. **Ingen archive-kandidater** opfyldte ≥2 kriterier — "legacy" filnavne tester aktiv funktionalitet
2. **Alle 7 klustre** fejler LOC-kriteriet (>500 LOC) — ingen merge-effekt i fase 2
3. **Rewrite** er en in-place operation (0 fil-reduktion, men quality-gevinst)

Størstedelen af reduktionen forventes i **Fase 3** via fix-in-phase-3-håndtering af de 45 filer.

---

## Tvivlstilfælde — kræver bruger-beslutning

1. **test-label-placement-core.R**: YAML viser 1 test/100% fail → auto-DG-merge-beslutning.
   Men filen indeholder faktisk 18 test_that-blokke. Anbefaling: kør
   `Rscript -e "pkgload::load_all(); testthat::test_file('tests/testthat/test-label-placement-core.R')"` direkte
   for at afgøre om det er 1 eller 18 tests der køres. Konsekvens for net-effekt: +/- 1 fil.

2. **Klustre BEHOLD separat**: Spec forventede y-axis → merge (1), event-system → merge (1), label-placement → merge (1).
   Alle 3 fejler LOC > 500. Ønsker bruger at overveje at hæve LOC-grænsen til fx 800 for disse klustre?
   Ville give yderligere ~4 filers reduktion (y-axis: 4→1, event-system: 2→1, label-placement: 2→1).
