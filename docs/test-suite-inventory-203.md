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


---

## Inventory af `skip("TODO")`-kald (§1.2.1)

**Dato:** 2026-04-19
**Oprindelig total:** 92 skip-kald i 15 filer

### Opdatering 2026-04-19 (§1.2.2 batch 1+2+3+4+5 — ✅ COMPLETE)

| Skip-form | Antal | Beskrivelse |
|---|---|---|
| `skip("TODO ...")` — uden issue-ref | **0** ✅ | Alle håndteret |
| `skip("testServer-migration — se ... §2.3 (#230)")` | 15 | Kat C (7) + kat D testServer-kandidater (8) |
| `skip("Afventer ... — se #XXX")` | 41 | Kat E med konkrete tracking-issues |
| `skip("BFHcharts-followup — se ... draft")` | 6 | Kat F (5) + kat D L136 — afventer BFHcharts sibling-issue |
| **Fixet inline** (test opdateret til ny API) | 2 | Batch 5: expect_named, setup_development_config |
| **Slettet** (obsolete test-blokke) | 28 | Batch 1 (18) + batch 5 (10) |
| **Total** | **92** | |

**Status §1.2.2 handling per kategori — ALLE HÅNDTERET:**

| Kat | Antal | Håndtering |
|---|---|---|
| A (fjernet/omdøbt) | 8 | ✅ Slettet (batch 1) |
| B (feature ikke impl.) | 10 | ✅ Slettet (batch 1) |
| C (reaktiv kontekst) | 7 | ✅ Re-labelet → #230 §2.3 (batch 2) |
| D (API-struktur) | 21 | ✅ 2 fixet + 10 slettet + 8 → #230 + 1 → BFHcharts (batch 5) |
| E (R-bug) | 41 | ✅ Re-labelet → #212/#213 (batch 3) + #240-#245 (batch 4) |
| F (qicharts2 baseline) | 5 | ✅ Re-labelet → BFHcharts draft-doc (batch 5) |

### Relaterede eksisterende og nyoprettede issues

**Eksisterende (Fase 3 follow-up):**
- **#212** — Fix reactive cache-key i `create_cached_reactive` (dækker 2 skips i `test-cache-reactive-lazy-evaluation.R`)
- **#213** — `parse_danish_target`/`normalize_axis_value` unit-awareness refactor (dækker 8+1 skips)
- **#216** — 3 tests afventer BFHcharts-ændringer (ikke direkte overlap med kat F i denne inventory — handler om `place_two_labels_npc` o.a.)

**Nye (§1.2.2 batch 4, 2026-04-19):**
- **#240** — `compute_spc_results_bfh()` mangler input-validering (12 skips, `test-spc-bfh-service.R`)
- **#241** — `generateSPCPlot()` mangler edge case fejl-håndtering (5 skips)
- **#242** — `format_scaled_number`/`format_unscaled_number`/`format_time_with_unit` edge cases (3 skips)
- **#243** — `resolve_y_unit`/`detect_unit_from_data` percent-detection (2 skips)
- **#244** — `sanitize_user_input()` mangler SQL injection + path traversal prevention (2 skips)
- **#245** — SPC-plot geom-assertions + data-transformation edge cases (6 skips)

**Issues lukket under dette arbejde:**
- **#234** — PR A3 catch-all (lukket som completed, dækket af commit `1614c1c`)

**BFHcharts sibling-issue draft (§1.2.2 batch 5, 2026-04-19):**
- `docs/cross-repo/draft-bfhcharts-qic-baseline-mismatch.md` — klar
  til copy-paste i BFHcharts-repo. Dækker 6 skips (5 kat F + 1 kat D).
  GitHub MCP-adgang til sibling-repo var utilgængelig da drafted blev
  lavet — maintainer opretter selve BFHcharts-issue manuelt.

**Issue-fordeling per kategori:**

| Kat | Reference | Antal skips |
|---|---|---|
| E | #212 | 2 |
| E | #213 | 9 |
| E | #240 | 12 |
| E | #241 | 5 |
| E | #242 | 3 |
| E | #243 | 2 |
| E | #244 | 2 |
| E | #245 | 6 |
| C | #230 | 7 |
| **I alt issue-refererede** | | **48** |

Tabellen er produceret som input til §1.2.2 (per-skip beslutning) og
§1.2.3 (særlig håndtering af `test-spc-bfh-service.R`).

### Kategori-fordeling

| Kat | Antal | Primær strategi |
|---|---|---|
| A — Fjernet/omdøbt i R/ | 8 | Opdater test-kald til ny funktion ELLER slet testblok |
| B — Feature/export ikke implementeret | 10 | Opret issue-ref + skip ELLER slet testblok |
| C — Kræver reaktiv kontekst | 7 | Migrér til `testServer()` (jf. §2.3) ELLER slet |
| D — API-struktur mismatch | 21 | Juster test til ny return-/event-shape ELLER slet |
| E — R-bug afsløret | 41 | Fix i R/ via separat issue+PR (uden for #228) |
| F — qicharts2 baseline | 5 | Eskalér til BFHcharts cross-repo coordination |

**Bemærkning:** Kategorierne er en _første grove klassifikation_ fra
skip-rationale-tekst. §1.2.2-beslutning kan flytte skips mellem
kategorier efter dybere inspektion.

### Beslutningsmatrix per kategori

- **A** (funktion/konstant fjernet i R/): hvis erstatning findes →
  opdater kald og fjern skip. Ellers → slet testblok (dokumentér i
  commit-message).
- **B** (feature ikke implementeret): opret issue (#NN — feature X)
  og erstat `skip("TODO Fase 4: ...")` med
  `skip("Ny feature X — se issue #NN")`. Uden issue → slet.
- **C** (reaktiv kontekst): kandidat til §2.3 testServer-kontrakter.
  Indtil da → slet testblok eller wrap med
  `skip_if_not_installed("shinytest2")`.
- **D** (API-struktur mismatch): gennemgå ny API shape, opdater
  assertions. Hvis ny API er bevidst breaking → slet test.
- **E** (R-bug): opret GitHub issue per bug, link fra skip-besked
  (`skip("R-bug X — se issue #NN")`). §1.2 kræver issue-reference.
- **F** (qicharts2/BFHcharts baseline): dokumentér som
  BFHcharts-followup via
  `.github/ISSUE_TEMPLATE/bfhchart-feature-request.md`.

### Detaljeret per fil

#### `test-y-axis-scaling-overhaul.R` — 6 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 69 | 68 | resolve_y_unit follows correct priority order | E | TODO Fase 4: resolve_y_unit returnerer ikke 'percent' for percent data (#203-followup) |
| 90 | 89 | detect_unit_from_data uses clear heuristics | E | TODO Fase 4: detect_unit_from_data returnerer ikke 'percent' for percent data (#203-followup) |
| 247 | 246 | parse_danish_target maintains backwards compatibility | E | TODO Fase 4: parse_danish_target konverterer ikke korrekt i backwards-compat scenarier (#203-followup) |
| 502 | 501 | format_scaled_number formats correctly with Danish notation | E | TODO Fase 4: format_scaled_number returnerer '2,75K' ikke '2,8K' — afrunding forkert (#203-followup) |
| 519 | 518 | format_unscaled_number uses Danish notation | E | TODO Fase 4: format_unscaled_number returnerer scientific notation ikke dansk format (#203-followup) |
| 538 | 537 | format_time_with_unit handles edge cases | E | TODO Fase 4: format_time_with_unit returnerer forkert format for 10000 days (#203-followup) |

#### `test-spc-regression-bfh-vs-qic.R` — 4 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 136 | 135 | Run chart: Basic scenario matches qicharts2 | D | TODO Fase 4: bfh_result returnerer ikke expected struktur (plot/qic_data/metadata) + cl mismatch (#203-followup) |
| 210 | 209 | Run chart: Freeze period handling | F | TODO Fase 4: cl mismatch mod qicharts2 baseline (#203-followup) |
| 591 | 590 | Xbar chart: Subgroup means | F | TODO Fase 4: ucl/lcl mismatch mod qicharts2 baseline (#203-followup) |
| 672 | 671 | S chart: Standard deviation | F | TODO Fase 4: ucl/lcl/cl mismatch mod qicharts2 baseline (#203-followup) |

#### `test-config_chart_types.R` — 2 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 14 | 5 | get_qic_chart_type konverterer danske labels korrekt | A | TODO Fase 4: MR/PP/UP/G-kort labels mangler i CHART_TYPES_DA (#203-followup) |
| 24 | 17 | get_qic_chart_type returnerer engelske koder uændret | B | TODO Fase 4: get_qic_chart_type understøtter ikke mr/pp/up/g koder direkte (#203-followup) |

#### `test-spc-bfh-service.R` — 19 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 57 | 56 | compute_spc_results_bfh() handles run charts | D | TODO Fase 4: result mangler expected names (plot/qic_data/metadata) (#203-followup) |
| 192 | 191 | compute_spc_results_bfh() requires data parameter | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl ved manglende data (#203-followup) |
| 205 | 204 | compute_spc_results_bfh() requires x_var parameter | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl ved manglende x_var (#203-followup) |
| 220 | 219 | compute_spc_results_bfh() requires y_var parameter | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl ved manglende y_var (#203-followup) |
| 235 | 234 | compute_spc_results_bfh() requires chart_type parameter | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl ved manglende chart_type (#203-followup) |
| 250 | 249 | compute_spc_results_bfh() validates chart_type values | E | TODO Fase 4: compute_spc_results_bfh() validerer ikke ugyldigt chart_type (#203-followup) |
| 266 | 265 | compute_spc_results_bfh() requires n_var for P charts | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl ved manglende n_var for P-chart (#203-followup) |
| 284 | 283 | compute_spc_results_bfh() requires n_var for U charts | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl ved manglende n_var for U-chart (#203-followup) |
| 303 | 302 | compute_spc_results_bfh() accepts optional freeze_var | D | TODO Fase 4: metadata indeholder ikke freeze_var (#203-followup) |
| 321 | 320 | compute_spc_results_bfh() accepts optional part_var | D | TODO Fase 4: metadata indeholder ikke part_var (#203-followup) |
| 357 | 356 | compute_spc_results_bfh() accepts optional cl_var | D | TODO Fase 4: metadata indeholder ikke cl_var (#203-followup) |
| 439 | 438 | compute_spc_results_bfh() handles validation errors gracefully | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl for ikke-numerisk y (#203-followup) |
| 508 | 507 | compute_spc_results_bfh() handles empty data | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl for tom data (#203-followup) |
| 527 | 526 | compute_spc_results_bfh() handles single data point | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl for enkelt datapunkt (#203-followup) |
| 546 | 545 | compute_spc_results_bfh() handles all NA values | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl for all-NA data (#203-followup) |
| 565 | 564 | compute_spc_results_bfh() handles missing columns | E | TODO Fase 4: compute_spc_results_bfh() kaster ikke fejl for manglende kolonner (#203-followup) |
| 669 | 668 | compute_spc_results_bfh() handles notes_column parameter | D | TODO Fase 4: metadata indeholder ikke notes_column (#203-followup) |
| 691 | 690 | compute_spc_results_bfh() baseline: run-basic | F | TODO Fase 4: cl mismatch mod qicharts2 baseline (#203-followup) |
| 718 | 717 | compute_spc_results_bfh() baseline: p-anhoej | F | TODO Fase 4: signal mismatch mod qicharts2 Anhøj baseline (#203-followup) |

#### `test-config_export.R` — 3 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 223 | 220 | EXPORT_PDF_CONFIG has correct structure | A | TODO Fase 4: EXPORT_PDF_CONFIG konstant eksisterer ikke (#203-followup) |
| 247 | 246 | EXPORT_PDF_CONFIG margins are valid | A | TODO Fase 4: EXPORT_PDF_CONFIG konstant eksisterer ikke (#203-followup) |
| 258 | 257 | EXPORT_PNG_CONFIG has correct structure | A | TODO Fase 4: EXPORT_PNG_CONFIG konstant eksisterer ikke (#203-followup) |

#### `test-reactive-batching.R` — 7 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 28 | 27 | schedule_batched_update batches rapid-fire events | B | TODO Fase 4: is_batch_pending er ikke implementeret (#203-followup) |
| 52 | 51 | schedule_batched_update handles different batch keys independently | B | TODO Fase 4: is_batch_pending er ikke implementeret (#203-followup) |
| 81 | 80 | schedule_batched_update handles errors gracefully | B | TODO Fase 4: is_batch_pending er ikke implementeret (#203-followup) |
| 106 | 105 | is_batch_pending returns FALSE for non-existent batches | B | TODO Fase 4: is_batch_pending er ikke implementeret i nuværende codebase (#203-followup) |
| 110 | 109 | clear_all_batches removes all pending batches | B | TODO Fase 4: is_batch_pending/clear_all_batches er ikke implementeret (#203-followup) |
| 158 | 157 | handle_column_input uses batching infrastructure | B | TODO Fase 4: is_batch_pending er ikke implementeret (#203-followup) |
| 204 | 203 | batching infrastructure is created lazily | B | TODO Fase 4: batching infrastructure er ikke implementeret (#203-followup) |

#### `test-critical-fixes-security.R` — 3 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 14 | 9 | Input sanitization forhindrer SQL injection patterns | E | TODO Fase 4: sanitize_user_input laver ikke SQL injection prevention - kun XSS+whitelist (#203-followup) |
| 21 | 17 | Input sanitization forhindrer path traversal attacks | E | TODO Fase 4: sanitize_user_input laver ikke path traversal prevention - brug validate_safe_path() (#203-followup) |
| 174 | 172 | OBSERVER_PRIORITIES runtime integration fungerer | C | TODO Fase 4: Observer priority execution order kræver reaktiv kontekst (shinytest2) (#203-followup) |

#### `test-generateSPCPlot-comprehensive.R` — 7 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 59 | 58 | generates run chart correctly | E | TODO Fase 4: run chart returnerer ucl/lcl uventet + y værdier out of range (#203-followup) |
| 261 | 260 | formats time values intelligently | E | TODO Fase 4: y værdier transformeres ikke til under-60 format (#203-followup) |
| 471 | 470 | handles character x-column as factor | E | TODO Fase 4: character x-kolonne konverteres ikke til factor (#203-followup) |
| 503 | 502 | handles empty data gracefully | E | TODO Fase 4: generateSPCPlot kaster ikke fejl for tom data (#203-followup) |
| 521 | 520 | handles single row data | E | TODO Fase 4: generateSPCPlot kaster ikke fejl for enkelt-rækket data (#203-followup) |
| 573 | 572 | handles all NA values gracefully | E | TODO Fase 4: generateSPCPlot kaster ikke fejl for all-NA data (#203-followup) |
| 626 | 625 | handles zero denominators | E | TODO Fase 4: generateSPCPlot kaster ikke fejl for nul-nævnere (#203-followup) |

#### `test-mod-spc-chart-comprehensive.R` — 8 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 14 | 13 | SPC chart module initialization creates proper state | D | TODO Fase 4: create_chart_manager() returnerer ikke expected API (#203-followup) |
| 36 | 35 | Chart data binding handles various data types | D | TODO Fase 4: create_data_validator() returnerer NULL (#203-followup) |
| 130 | 129 | Chart module handles reactive updates correctly | C | TODO Fase 4: create_data_manager() returnerer NULL + shiny::flushReact ikke eksporteret (#203-followup) |
| 239 | 238 | SPC results processor handles various chart types | D | TODO Fase 4: create_spc_processor() returnerer NULL (#203-followup) |
| 365 | 364 | updates plot when data changes | D | TODO Fase 4: session$returned er ikke reactive (module return structure mismatch) (#203-followup) |
| 543 | 542 | renders plot_ready output correctly | D | TODO Fase 4: plot_ready ikke i output names (module output struktur mismatch) (#203-followup) |
| 569 | 568 | renders plot_info with warnings | D | TODO Fase 4: plot_info ikke i output names (#203-followup) |
| 591 | 590 | renders anhoej_rules_boxes correctly | D | TODO Fase 4: anhoej_rules_boxes ikke i output names (#203-followup) |

#### `test-cache-reactive-lazy-evaluation.R` — 2 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 56 | 55 | create_cached_reactive reagerer paa reaktive dependencies | E | TODO Fase 3: create_cached_reactive bruger digest-cache-key (string), ikke reaktiv tracking — val1(5) invaliderer ikke cachen korrekt (#203-followup) |
| 102 | 101 | create_cached_reactive haandterer cache-udloeb | E | TODO Fase 3: create_cached_reactive re-evaluerer ikke automatisk efter timeout — cache-key er statisk string, ikke tidsbaseret (#203-followup) |

#### `test-autodetect-unified-comprehensive.R` — 10 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 7 | 6 | autodetect_engine basic functionality works | D | TODO Fase 4: auto_detect$last_run er atomic ikke liste med $trigger (#203-followup) |
| 153 | 152 | autodetect_engine session start scenario works | D | TODO Fase 4: auto_detect$last_run er atomic ikke liste med $trigger (#203-followup) |
| 495 | 494 | autodetect_engine performance and caching works | D | TODO Fase 4: auto_detect$last_run$data_rows er ikke tilgængeligt (#203-followup) |
| 610 | 609 | Auto-detect identificerer kolonnetyper korrekt | A | TODO Fase 4: appears_date() funktion mangler (#203-followup) |
| 640 | 639 | Auto-detect håndterer dansk dato format | A | TODO Fase 4: appears_date() funktion mangler (#203-followup) |
| 653 | 652 | Auto-detect håndterer edge cases | A | TODO Fase 4: appears_numeric() funktion mangler (#203-followup) |
| 674 | 673 | Column mapping logic fungerer korrekt | A | TODO Fase 4: detect_columns_with_cache() funktion mangler (#203-followup) |
| 810 | 809 | update_all_column_mappings synchronizes state correctly | E | TODO Fase 4: update_all_column_mappings sætter ikke app_state$columns$mappings korrekt (#203-followup) |
| 987 | 986 | No autodetect on excelR table edits (table_cells_edited) | D | TODO Fase 4: event flow for auto_detection_started + navigation_changed er forkert (#203-followup) |
| 1027 | 1026 | n_column stays cleared during table edit refresh | D | TODO Fase 4: n_column state ikke bevaret korrekt under table edit (#203-followup) |

#### `test-runtime-config-comprehensive.R` — 1 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 94 | 84 | setup_development_config creates valid configuration | D | TODO Fase 4: setup_development_config struktur er ændret - debug_enabled er fjernet (#203-followup) |

#### `test-spc-plot-generation-comprehensive.R` — 4 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 294 | 293 | generateSPCPlot centerline label bruger geom_marquee | E | TODO Fase 4: layer$aes_params$size er ikke 4 (#203-followup) |
| 329 | 328 | generateSPCPlot target label bruger geom_marquee | E | TODO Fase 4: layer$aes_params$size er ikke 4 (#203-followup) |
| 412 | 411 | generateSPCPlot error handling works correctly | E | TODO Fase 4: generateSPCPlot kaster ikke fejl for tom/ufuldstændig/NA/nul/lille data (#203-followup) |
| 588 | 587 | generateSPCPlot Danish clinical data patterns work | E | TODO Fase 4: character x-kolonne konverteres ikke til factor (#203-followup) |

#### `test-state-management-hierarchical.R` — 6 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 104 | 101 | app_state hierarchical column management works | C | TODO Fase 4: Nested reactive value access kræver reactive context (#203-followup) |
| 221 | 218 | app_state reactive chains work correctly | C | TODO Fase 4: reactive() kræver aktiv Shiny-session udenfor isolate (#203-followup) |
| 261 | 257 | app_state event-driven workflows work | C | TODO Fase 4: flushReact er ikke eksporteret - brug shiny::testServer() (#203-followup) |
| 357 | 354 | app_state complex state transitions work | D | TODO Fase 4: Kompleks state transition test bruger gamle event-navne (#203-followup) |
| 415 | 412 | app_state backward compatibility works | C | TODO Fase 4: Nested reactive access i backward compat test (#203-followup) |
| 453 | 450 | app_state Danish clinical workflow works | C | TODO Fase 4: Danish clinical workflow test bruger nested reactive access (#203-followup) |

#### `test-parse-danish-target-unit-conversion.R` — 10 skip-kald

| skip L | blok L | blok-navn | kat | skip-rationale |
|---|---|---|---|---|
| 70 | 69 | TODO Fase 3: y_axis_unit=percent skalerer korrekt uden y-data | E | TODO Fase 3: R-bug afsloeret — y_axis_unit ignoreres i legacy wrapper (#203-followup) Nuvaerende adfaerd: parse_danish_target('80%', NULL, 'percent') = 0.8 (ikke 80) Forventet adfaerd: 80 (pct-skala) |
| 77 | 76 | TODO Fase 3: y_axis_unit=count haandterer tal korrekt uden y-data | E | TODO Fase 3: R-bug afsloeret — y_axis_unit ignoreres i legacy wrapper (#203-followup) Nuvaerende adfaerd: parse_danish_target('80', NULL, 'count') = NULL/0 Forventet adfaerd: 80 |
| 84 | 83 | TODO Fase 3: percent y-data skalerer korrekt til 0-100 | E | TODO Fase 3: R-bug afsloeret — percent-skala data detekteres ikke korrekt (#203-followup) Nuvaerende: parse_danish_target('80%', c(10,25,60,85), 'count') = 0.8 (ikke 80) Forventet: 80 (procent y-da... |
| 93 | 92 | TODO Fase 3: integer y-data behandles som absolute skala | E | TODO Fase 3: R-bug afsloeret — integer-skala data fejldetekteres som proportion (#203-followup) Nuvaerende: parse_danish_target('80', c(150,250,450,800), 'percent') = NULL Forventet: 80 |
| 100 | 99 | TODO Fase 3: y_axis_unit=permille skalerer korrekt | E | TODO Fase 3: R-bug afsloeret — permille unit ikke understottet i normalize_axis_value via legacy wrapper (#203-followup) |
| 107 | 106 | TODO Fase 3: rate_* enheder haandteres som absolutte tal | E | TODO Fase 3: R-bug afsloeret — rate_1000/rate_100000 units ikke understottet (#203-followup) |
| 118 | 117 | TODO Fase 3: absolutte enheder (days/hours etc.) haandteres konsistent | E | TODO Fase 3: R-bug afsloeret — absolutte domæneenheder ikke understottet (#203-followup) |
| 129 | 128 | TODO Fase 3: detect_y_axis_scale funktion eksisterer | B | TODO Fase 3: R-bug afsloeret — detect_y_axis_scale() ikke eksporteret/eksisterer ikke i namespace (#203-followup) |
| 134 | 133 | TODO Fase 3: convert_by_unit_type funktion eksisterer | B | TODO Fase 3: R-bug afsloeret — convert_by_unit_type() ikke eksporteret/eksisterer ikke i namespace (#203-followup) |
| 139 | 138 | TODO Fase 3: fallback uden y_axis_unit returnerer korrekte vaerdier | D | TODO Fase 3: R-bug afsloeret — parse_danish_target('50', NULL, NULL) returnerer NULL i stedet for 50 (#203-followup) |

### Særlig note: `test-spc-bfh-service.R` (§1.2.3)

Filen indeholder **19 skip-kald** — fordelt på:

- Kategori **D**: 5
- Kategori **E**: 12
- Kategori **F**: 2

Disse tests dækker **SPC-kerne-facaden** (`compute_spc_results_bfh()`)
og er derfor højeste prioritet for reparation. Rationale-eskalering:

- Kategori **E** (kaster ikke fejl, validerer ikke): afspejler at
  `compute_spc_results_bfh()` kun har happy-path validering. Dette er
  en reel svaghed i input-validering og bør adresseres som R-bug fix
  i separat issue og PR (uden for #228-scope).
- Kategori **D** (metadata indeholder ikke freeze_var/part_var/cl_var/
  notes_column): nuværende BFHcharts-facade returnerer ikke disse i
  metadata-struktur. Kræver enten (a) BFHcharts-feature-request, eller
  (b) test opdateres til at matche faktisk metadata-shape.
- Kategori **F** (cl/signal mismatch mod qicharts2): hybrid
  arkitektur-regressionstest. Kræver dybere analyse — se
  `CLAUDE.md §4 Cross-Repository Coordination` og
  `docs/CROSS_REPO_COORDINATION.md`.
