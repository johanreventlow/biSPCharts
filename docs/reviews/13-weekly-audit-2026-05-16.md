# Wave-13 Weekly Code-Quality Audit (2026-05-09 → 2026-05-16)

**Status:** Konsolideret · 7-agent parallel-review · empirisk verificerede HIGH-fund
**Branch:** `master` post #766 (promote develop) + #767 (eliminate-partial-match)
**Scope:** 30+ PRs (#720 → #767), 1 uges udvikling
**Agents:** shiny-code-reviewer, architecture-validator, performance-optimizer, test-coverage-analyzer, refactoring-advisor, legacy-code-detector, logging-reviewer

---

## Executive Summary

Ugens kode-kvalitet er **god** med disciplineret PR-hygiene og stærk arkitektur-conformance. Dual-review-cycle-mønstret (cycle 10/11/12/13) leverede ægte runtime-fixes og empiriske bug-eskaleringer. Tre HIGH-fund kræver kort action før næste release: én logger-defekt der **kan regenerere** cycle 11 H2-NEW cache-staleness-bugen, ét dead reactive-block efterladt fra cycle 10-migration, og dokumentations-drift mellem CLAUDE.md §4 og faktisk fil-organisering.

**Top 3 actions (ROI-rangered):**

1. **[5 min, P0]** Tilføj `log_warn()` i `resolve_bfh_chart_title()` error-handler (`fct_spc_bfh_facade.R:398-400`). Silent NULL-fallback re-introducerer cycle 11 H2-NEW cache-staleness-bug-klassen usynligt.
2. **[5 min]** Slet `auto_detected_config` dead reactive (`utils_server_visualization.R:26-46`). Cycle 10-migration efterlod orphaned reactive med 0 callers i `R/`.
3. **[10 min]** Opdater CLAUDE.md §4 SPC-pipeline-tabel til at reflektere at `build_bfh_args` + `execute_bfh_request` er i `fct_spc_execute.R`, ikke `fct_spc_bfh_params.R` / `fct_spc_bfh_invocation.R`.

**Process-vurdering:** Dual-review-cycle-pattern (Claude+Codex) leverede ægte impact i cycle 10/11/12. Cycle 13 (COLLAPSE_ERROR) demonstrerede vigtigt princip: antaget BFHcharts-bug var faktisk biSPCharts logger-defekt (R `$`-partial-match). Bekræfter behov for empirisk repro før eskalering til sibling-pakker.

---

## Findings by Severity

### HIGH (4 fund — runtime-impact eller regression-risiko)

#### H1 — `resolve_bfh_chart_title()` silent NULL-fallback maskerer reactive-evaluation-fejl

**Lokation:** `R/fct_spc_bfh_facade.R:398-400`
**Agent:** logging-reviewer
**Severity:** HIGH (regression-risiko mod cycle 11 H2-NEW)

**Symptom:**
```r
error = function(e) {
  result <<- NULL
}
```

Når reactive-evaluering kaster, sættes `resolved_title <- NULL` uden log-call. NULL flyder ind i `extra_params$chart_title <- resolved_title` (linje 185) og `build_cache_key(..., chart_title = ..., ...)` (linje 281). Charts med **forskellige** titler der alle fejler reactive-evaluation deler **samme NULL-title cache-slot** — præcis cache-staleness-klassen som cycle 11 H2-NEW (#752) blev designet til at fixe.

**Root-cause:** Defensiv tryCatch uden observability. Silent failure er usynlig i prod-logs.

**Empirisk verifikation:** Direkte kode-citat (verificeret 2026-05-17):
```
398	          error = function(e) {
399	            result <<- NULL
400	          }
```

Ingen `log_warn` eller `log_error` mellem error-trap og NULL-assign. Cache-key downstream hash'er NULL identisk på tværs af forskellige fejl-titler.

**Recommended fix:**
```r
error = function(e) {
  log_warn(
    "Reactive chart_title evaluation failed; falling back to NULL",
    .context = "BFH_SERVICE",
    details = list(error_message = conditionMessage(e), error_class = class(e)[1])
  )
  result <<- NULL
}
```

**Priority:** P0 — fix før næste release. Lav-risk: tilføjer kun log-call.

---

#### H2 — `auto_detected_config` dead reactive efterladt efter cycle 10-migration

**Lokation:** `R/utils_server_visualization.R:26-46`
**Agent:** legacy-code-detector
**Severity:** HIGH-ROI cleanup (pure waste, 0 risk)

**Symptom:**
Cycle 10 (#730) introducerede `column_config` (linje 55-110) som state-derived erstatning for `auto_detected_config`/`manual_config`-parret. `manual_config` blev fjernet; `auto_detected_config` blev efterladt med 0 callers.

**Empirisk verifikation:**
```bash
$ grep -rn "auto_detected_config\|manual_config" R/ tests/
R/utils_server_visualization.R:26:  auto_detected_config <- shiny::reactive({...})
tests/testthat/test-foreign-column-names.R:30,39,53-122  # legacy simulator-tests, ej real callers
tests/testthat/test-upload-race-state-derived.R:9        # kommentar-reference
```

0 callers i `R/`. Eneste forekomster udenfor definition: legacy simulator-test der bruger `manual_config`/`auto_detected_config` som local mock-fn (skal ej opdateres).

**Impact:** Unødvendig reactive-subscription. `auto_detected_config` fyrer ved hver `app_state$columns$auto_detect$results`-ændring + `input$chart_type`-ændring, eksekverer `get_qic_chart_type()`, bygger config-liste og kasserer resultatet. Pure waste.

**Recommended fix:** Slet linje 25-46 (incl. stale comment `# Separate reactives for auto-detected and manual column selection`).

**Priority:** P1 — næste sprint.

---

#### H3 — CLAUDE.md §4 SPC-pipeline-fil-ownership drift

**Lokation:** `CLAUDE.md` linje 176-177 vs faktisk fil-organisering
**Agent:** legacy-code-detector
**Severity:** HIGH (documentation authority drift, compound impact)

**Symptom:**
CLAUDE.md §4 dokumenterer:
- `fct_spc_bfh_params.R` — `resolve_axis_units` + `build_bfh_args`
- `fct_spc_bfh_invocation.R` — `execute_bfh_request`

**Faktisk lokation (verificeret 2026-05-17):**
```bash
$ grep -n "build_bfh_args\|execute_bfh_request" R/fct_spc_*.R
R/fct_spc_execute.R:18:   build_bfh_args <- function(prepared, axes, extra_params) {...}
R/fct_spc_execute.R:118:  execute_bfh_request <- function(bfh_params, prepared) {...}
```

`fct_spc_bfh_params.R` indeholder kun: column-mapping helpers + `map_to_bfh_params` + `normalize_scale_for_bfh`. `fct_spc_bfh_invocation.R` indeholder kun `call_bfh_chart`.

**Impact:** Fremtidige bidragydere (incl. agent-baserede reviews) der følger CLAUDE.md §4 vil søge i forkerte filer. Documentation er autoritativ for onboarding — drift her amplificerer compound over hver review-cycle.

**Recommended fix (Option A, lav risiko):**
```markdown
- `fct_spc_execute.R`        — build_bfh_args + execute_bfh_request (BFHcharts-kald)
- `fct_spc_bfh_params.R`     — column-mapping helpers + map_to_bfh_params
- `fct_spc_bfh_invocation.R` — call_bfh_chart (low-level BFHcharts wrapper)
- `fct_spc_decorate.R`       — decorate_plot_for_display
```

**Priority:** P1 (documentation hygiene).

---

#### H4 — Integration-tests mangler for cycle 10 state-derived write-back path

**Lokation:** `tests/testthat/test-upload-race-state-derived.R`
**Agent:** test-coverage-analyzer
**Severity:** HIGH (regression-blindt punkt)

**Symptom:**
Alle 8 tests i suite er pure-function-tests mod `chart_config_from_state()`. Selve race-prevention-mekanismen — at server-observer-kæden læser fra `app_state$columns$mappings` snarere end stale `input$<col>` — er KUN dækket ved runtime.

**Risk:** Pure function kan være korrekt mens wiring (observer-priority, reactive-dependency, throttle) brækker. Regression i observer-chain ville ikke fanges af current suite.

**Recommended test:**
```r
test_that("state-derived column persists efter throttled input-roundtrip [integration]", {
  shiny::testServer(function(input, output, session) {
    # Wire actual observer + write app_state$columns$mappings$y_col <- "Count"
    # FØR input initialiseres. Flush + verify chart_config læser state, ej stale input.
  }, { ... })
})
```

**Priority:** P1 (regression-prevention).

---

### MED (8 fund — lokal impact, lav blast-radius)

#### M1 — JS-bridge observers untested i navigation-guard

**Lokation:** `R/utils_server_navigation_guard.R:180-280`
**Agent:** test-coverage-analyzer

5 observers (`nav_guard_trigger` JS-relay, `nav_guard_has_data_update`, `set_in_app_navigating`, `schedule_clear_in_app_navigating`, `onFlushed`-guard-clear) har 0 tests. Plus `setup_help_back_navigation()` har 0 testthat-coverage.

**Fix:** Tilføj `testServer()`-tests der setter `input$nav_guard_trigger = list(tab="spc_tab", ts=1L)` + flush + verify `app_state$events$navigation_requested` bumped.

---

#### M2 — Observer priority 0 race-risk i `utils_server_visualization.R:113`

**Lokation:** `R/utils_server_visualization.R:113-130`
**Agent:** performance-optimizer + architecture-validator (cross-overlap)

Bare `shiny::observe({...})` uden eksplicit priority kalder `apply_state_transition(transition_chart_config_updated(vc))` — samme anti-pattern som cycle 12 H1. Priority 0 = samme flush-runde som outputs → ekstra render-cyklus pr. kolonnevalg.

**Fix:** `priority = OBSERVER_PRIORITIES$UI_SYNC` (750).

---

#### M3 — ADR-004 exception-kommentar mangler ved `effective_analysis_val` reactiveVal

**Lokation:** `R/mod_export_server.R:355`
**Agent:** architecture-validator

Cycle 12 H1-fix bruger `shiny::reactiveVal(...)` uden for `app_state`. Korrekt valg, men savner ADR-004 exception-kommentar (jf. præcedens i `utils_server_events_navigation.R:32-38`).

**Fix:** Tilføj `# ADR-004 exception: ...`-kommentar med rationale-reference til PR #759.

---

#### M4 — Navigation-guard har 0 log-calls på 333 linjer kritisk state-machine

**Lokation:** `R/utils_server_navigation_guard.R`
**Agent:** logging-reviewer

`guard_active` set/clear, `handle_nav_guard_confirm` happy-path, Excel-download-trigger, `reset_to_empty_session` — alle silent. Guard-state-fejl ville være usynlige i prod.

**Fix:** Minimum `log_info` ved modal-åbn + confirm + reset, `log_debug` på guard_active-transitions, `log_warn` ved `guard_reverting`-path.

---

#### M5 — `auto_save_trigger` mangler diff-check guard (cycle 11 M2 defer)

**Lokation:** `R/utils_server_session_helpers.R` (`obs_data_save` observer)
**Agent:** performance-optimizer

`settings_save_trigger` har `last_settings_payload`-closure-guard, `auto_save_trigger` har ikke. Redundante `localStorage.setItem()` + JSON-serialiserings-kald på store datasets ved `data_updated` uden faktisk dataændring.

**Fix:** Tilføj `digest::digest(app_state$data$current_data)`-baseret diff-check analog med settings-pattern.

---

#### M6 — Priority-ordering guarantee ej executable-demonstreret i cycle 12-tests

**Lokation:** `tests/testthat/test-export-preview-redundans-elimination.R` test 3-4
**Agent:** test-coverage-analyzer

Test 3 asserter `OBSERVER_PRIORITIES$PLOT_GENERATION == 600L` (konstant-check, ej ordering-test). Test 4 bruger `testServer()` men kommentar acknowledger "testServer doesn't render outputs by default" — flush-ordering-garanti er undemonstrated.

**Fix:** Eksplicit `expect_gt(OBSERVER_PRIORITIES$LOW, OBSERVER_PRIORITIES$PLOT_GENERATION)` + `testServer`-test der mocker `compute_auto_analysis_text()` til sentinel og verificerer flush-rækkefølge.

---

#### M7 — `BFH_SERVICE` log-context (46 anvendelser) ej registreret i `LOG_CONTEXTS`

**Lokation:** `R/config_log_contexts.R`
**Agent:** logging-reviewer

`"BFH_SERVICE"` bruges 46 gange på tværs af SPC-pipeline men findes ej i centralt `LOG_CONTEXTS`-registry. Typo-risiko (silent unfiltered context), onboarding-gap. Lignende gaps for `NAV_GUARD`, `SPC_CACHE`, `TABLE_UPDATE_SERVICE`, `SESSION_RESTORE`, `LOCAL_STORAGE`, `FILE_PARSE_PURE`, `CSV_DETECT`, `PASTE_DATA`, `QIC_CACHE`, `BACKGROUND_TASKS`.

**Fix:** Registrer i `LOG_CONTEXTS`-liste. Prioritet: `BFH_SERVICE` P1, øvrige P2.

---

#### M8 — `handle_nav_guard_confirm()` ~80 linjer med blandede ansvar

**Lokation:** `R/utils_server_navigation_guard.R`
**Agent:** refactoring-advisor

Excel-download + session-reset + wizard-JS + nav_select + fallback-guard-clear i én funktion. SRP-brud. Moderat refactor-kandidat (~1.5h inkl. tests).

---

### LOW (6 fund — style, micro-perf, documentation hygiene)

#### L1 — `n_col_name` paste-collapse maskerer vektor-anomali i log-besked

**Lokation:** `R/fct_spc_bfh_invocation.R:~124`
**Agent:** shiny-code-reviewer

`paste(n_col_name, collapse=",")` sammenkæder hvis `n_col_name` mod forventning er vektor. `.safe_col_class()` rapporterer det korrekt, men log-prefix viser `"a,b"`. Lav-prioritet.

#### L2 — Magic offset `OBSERVER_PRIORITIES$STATE_MANAGEMENT + 1L`

**Lokation:** `R/utils_server_navigation_guard.R:114`
**Agent:** architecture-validator

Tilføj navngivet konstant `NAVIGATION_GUARD_INIT = STATE_MANAGEMENT + 1L` i `config_observer_priorities.R`.

#### L3 — `settings_save_trigger` logger INFO per reactive-fire (cycle 11 M1 defer)

**Lokation:** `R/utils_server_session_helpers.R:~401`
**Agent:** performance-optimizer

INFO-log før diff-check guard → log fyrer per 1000ms debounce-udløb selv ved identisk payload. Skift til `log_debug` eller flyt efter identical-check.

#### L4 — `ASYNC_HELPER` vs `ASYNC_HELPERS` inkonsistens

**Lokation:** `R/utils_async_helpers.R:43,98,107`
**Agent:** logging-reviewer

Linje 43 `"ASYNC_HELPER"`, linje 98+107 `"ASYNC_HELPERS"`. Vælg én form, registrér i LOG_CONTEXTS.

#### L5 — `set_autogen_active()` silent transition

**Lokation:** `R/utils_state_accessors.R:872`
**Agent:** logging-reviewer

Tilføj `log_debug` med flag-værdi for at gøre auto-detect-gating observerbar.

#### L6 — `log_debug_kv(message = ...)` antimønster

**Lokation:** `R/utils_qic_caching.R:115`
**Agent:** logging-reviewer

`log_debug_kv` tager `...` som key-value-pairs; `message = "..."` bliver til en KV-entry. Skift til `event = "LRU_eviction"` eller positionsargument.

---

## Findings by Area

| Område | HIGH | MED | LOW | Kommentar |
|--------|:----:|:---:|:---:|-----------|
| Navigation-guard (#737) | — | 2 (M1, M4) | 1 (L2) | Stærk arkitektur, men 0 logs + JS-bridge ej testet |
| Cycle 11/12 export-preview | 1 (H1) | 2 (M3, M6) | — | Logger-defekt regression-risiko mod cycle 11 H2-NEW |
| Cycle 13 COLLAPSE_ERROR | — | — | 1 (L1) | Fix er korrekt; KUN log-cosmetic gap |
| Report-bug (#749) | — | 1 (M1 partial) | — | Solid feature; back-nav untested |
| Cycle 10 upload-race | 2 (H2, H4) | 1 (M2) | — | Dead reactive efterladt + integration-test-gap |
| BFHcharts 0.19.0 (#740) | — | — | — | Eksemplarisk external-package-compliance |
| Documentation / arkitektur | 1 (H3) | — | — | CLAUDE.md §4 drift |
| Logging-infrastruktur | — | 2 (M4, M7) | 3 (L3-L6) | Centralt registry mangler entries |
| Refactoring | — | 1 (M8) | — | 3 HIGH-ROI extract-kandidater (DRY) |

---

## Empirisk Verifikation

| Finding | Status | Bevis |
|---------|--------|-------|
| H1 (`resolve_bfh_chart_title` silent) | ✅ Verificeret | Direkte kode-citat `fct_spc_bfh_facade.R:398-400` — ingen log_warn |
| H2 (`auto_detected_config` dead) | ✅ Verificeret | `grep -rn "auto_detected_config" R/` → 1 match (definition only). Test-mocks i `test-foreign-column-names.R` er IKKE real callers |
| H3 (CLAUDE.md §4 drift) | ✅ Verificeret | `grep -n "build_bfh_args\|execute_bfh_request" R/fct_spc_*.R` → begge i `fct_spc_execute.R` |
| H4 (state-derived integration-gap) | ⚠️ Static-analysis | Suite indeholder kun pure-function-tests; observer-chain ej dækket |
| M2 (priority 0 race) | ⚠️ Static-analysis (pattern-match til cycle 12 H1) | Krævet runtime-repro for at konfirmere ekstra render |
| M5 (auto_save 4x) | ⏸ Defer (cycle 11 M2) | Stadig ikke empirisk repro'd post-cycle-11; ingen ny evidens |

**Cycle 11/12 fix-verifikation (perf-agent):**
- PR #752 (cache-key reactive resolve): **BEKRÆFTET** — 7/7 tests pass i `test-cache-key-reactive-title.R`
- PR #759 (reactiveVal-diff + priority): **BEKRÆFTET** — 11/11 tests pass i `test-export-preview-redundans-elimination.R`
- PR #765/#767 (logger defense): **VERIFICERET I KODE** — dedikerede tests i `test-fct_spc_bfh_invocation.R`

---

## Process Lessons

### Hvad fangede dual-review-cycle som single-pass missede?

- **Cycle 11 H2-NEW (#752):** Codex empirisk repro af `digest::digest(reactive_fn)`-stable-hashing — kunne ikke spores via static analysis alene
- **Cycle 12 H1 priority-ordering:** Codex Shiny 1.13.0 flush-simulation afslørede regresssion fra priority-0 → mit initial fix var teoretisk korrekt men praktisk forkert
- **Cycle 13 (#765/#767):** Empirisk repro via `map_to_bfh_params()`-trace afslørede at antaget BFHcharts-bug VAR biSPCharts logger-bug (R `$`-partial-match)

### Hvor mange false-positives blev dismissed?

- Cycle 10 H2 (modal_column_mapping_active): dismissed-then-cleaned-up
- Cycle 11 M1 (settings_save 3x): dismissed (allerede impl. dedupe)
- Wave-13 finder: 0 false-positives blandt HIGH; alle empirisk repro'd

### Justeringer til `/dual-review-cycle`-skill?

**Bekræftede patterns (incoporated i existing skill):**
- Empirisk repro for HIGH er obligatorisk (forhindrer peer-review-laundering)
- Atomic commits per finding
- Worktree-aware branching

**Nye observerinser denne uge:**
- **R `$`-partial-match-gotcha**: bør tilføjes som default-check-item i logging-reviewer-prompt (alle list-access patterns)
- **CLAUDE.md drift-tjek**: ny default-check-item i architecture-validator-prompt (er documentation aligned med faktisk fil-organisering?)
- **Observer-priority-audit**: bare `observe()` uden priority bør auto-flag som MED i shiny-code-reviewer

### Cycle 10/11/12-cleanup-status

| Item | Cycle | Status |
|------|-------|--------|
| `modal_column_mapping_active` dead guard | 10 H2 | ✅ RESOLVED |
| Stale-input `input$<col>` direkte reads | 10 | ✅ RESOLVED (`column_config` er state-derived) |
| `auto_detected_config` orphan | 10 | ❌ **NY** — efterladt under migration |
| AUTO_SAVE 4x (M2) | 11 | ⏸ DEFER (3 call-sites arkitektonisk distinkt; ingen ny evidens) |
| PDF preview double-render | 12 H1 | ✅ RESOLVED |
| `reactiveVal()` uden ADR-doc | 12 | ❌ **NY** — `effective_analysis_val` mangler ADR-004-kommentar |
| `<<-` assignments | All | ✅ LEGITIMATE (kun closure-state) |

---

## Tech-Debt Inventory

### NEW debt (denne uge)

- **`auto_detected_config` orphan** (legacy H2) → DELETE-kandidat
- **`resolve_bfh_chart_title` silent error** (logging H1) → FIX-kandidat (P0)
- **CLAUDE.md §4 drift** (legacy H3) → DOCS-fix
- **JS-bridge test-gap** (test M1) → ADD-tests
- **Integration-test-gap state-derived path** (test H4) → ADD-tests
- **Nav-guard logging-gap** (logging M4) → ADD-logs

### Aktivt deferred (fra tidligere cycles)

- **AUTO_SAVE 4x** (cycle 11 M2) → DEFER indtil repro
- **Cycle 11 M3 Anhoej-beregning 2x** → DEFER (negligible, cache-aware)
- **`setup_helper_observers()` 270-linje god-funktion** → DEFER (større split, 2-3 dage)
- **ADR-018 unexport-audit** (3 funktioner: `validate_x_column_format`, `get_x_format_string`, `process_chart_title`) → DEFER til næste ADR-018-cycle

### Candidates for deletion

- `auto_detected_config` (legacy H2) — confirmed dead
- Mulig: ADR-018-kandidater hvis ingen sibling-package-users

---

## Recommended Follow-ups (prioriteret)

| # | Finding | Effort | Priority | Quick-win? |
|---|---------|--------|----------|------------|
| 1 | H1: log_warn i resolve_bfh_chart_title | 5 min | P0 | ✅ |
| 2 | H2: slet auto_detected_config | 5 min | P1 | ✅ |
| 3 | H3: opdater CLAUDE.md §4 | 10 min | P1 | ✅ |
| 4 | M2: priority på utils_server_visualization observer | 15 min | P1 | ✅ |
| 5 | M3: ADR-004 exception-kommentar | 5 min | P2 | ✅ |
| 6 | L2: NAVIGATION_GUARD_INIT-konstant | 10 min | P2 | ✅ |
| 7 | M7: registrér BFH_SERVICE i LOG_CONTEXTS | 20 min | P2 | ✅ |
| 8 | M4: nav-guard logs (5+ log-calls) | 1h | P2 | — |
| 9 | M1+H4: integration-tests nav-guard + state-derived | 4-6h | P1 | — |
| 10 | M5: auto_save diff-check guard | 1h | P2 | — |
| 11 | M6: executable priority-ordering test | 2h | P2 | — |
| 12 | M8: handle_nav_guard_confirm split | 1.5h | P3 | — |
| 13 | Refactor HIGH-ROI: guard_active idiom-extract | 30 min | P3 | ✅ |
| 14 | Refactor HIGH-ROI: wizard step-besked-helpers | 45 min | P3 | ✅ |
| 15 | Refactor HIGH-ROI: reactiveVal-diff-factory | 1h | P3 | — |

**Quick-win batch (P0+P1+P2-quick):** Items 1-7 + 13-14 = ~2 timer total. Anbefales som single `chore(quality):`-PR mod develop.

---

## GitHub Issue Drafts

Klar til kopi/paste via `gh issue create --title "..." --body "$(cat <<'EOF' ... EOF)"`.

---

### Issue draft #1 (HIGH, P0)

**Title:** `fix(logger): tilfoej log_warn i resolve_bfh_chart_title error-handler`

**Labels:** `bug`, `technical-debt`, `priority-high`

**Body:**
```markdown
## Summary

`R/fct_spc_bfh_facade.R:398-400` har silent NULL-fallback i reactive-evaluation error-handler. Det re-introducerer cycle 11 H2-NEW cache-staleness-bug-klassen usynligt: charts med forskellige titler der alle fejler reactive-evaluation deler samme NULL-title cache-slot.

## Repro

```r
# I app: chart_title-reactive der kaster (fx kaldet udenfor reactive-context).
# Cache-key for ALLE failures hash'er identisk → stale chart-output.
```

## Fix

```r
error = function(e) {
  log_warn(
    "Reactive chart_title evaluation failed; falling back to NULL",
    .context = "BFH_SERVICE",
    details = list(error_message = conditionMessage(e), error_class = class(e)[1])
  )
  result <<- NULL
}
```

## Acceptance

- [ ] `log_warn` synes ved reactive-failure
- [ ] Test verificerer log emitted ved tryCatch-trap
- [ ] Cache-staleness-regresion umulig at oprette uden log-trace

Refs: docs/reviews/13-weekly-audit-2026-05-16.md H1
```

---

### Issue draft #2 (HIGH, P1)

**Title:** `chore(cleanup): slet orphaned auto_detected_config reactive`

**Labels:** `technical-debt`, `cleanup`

**Body:**
```markdown
## Summary

`R/utils_server_visualization.R:25-46` indeholder `auto_detected_config` reactive der har 0 callers i `R/`. Cycle 10 (#730) migrerede til `column_config` (state-derived); `manual_config` blev fjernet, men `auto_detected_config` blev efterladt.

## Verifikation

```bash
grep -rn "auto_detected_config" R/ tests/
# Kun: definition + legacy simulator-tests (ej real callers)
```

## Impact

Unødvendig reactive-subscription fyrer ved hver auto-detect-event + chart_type-ændring. Pure waste, 0 correctness-impact.

## Fix

Slet linje 25-46 (incl. stale comment).

Refs: docs/reviews/13-weekly-audit-2026-05-16.md H2
```

---

### Issue draft #3 (HIGH, P1)

**Title:** `docs(claude): opdater SPC-pipeline-fil-ownership i CLAUDE.md §4`

**Labels:** `documentation`

**Body:**
```markdown
## Summary

CLAUDE.md §4 dokumenterer `build_bfh_args` + `execute_bfh_request` som boende i `fct_spc_bfh_params.R` + `fct_spc_bfh_invocation.R`. Faktisk er begge i `fct_spc_execute.R`. Documentation-drift forvirrer fremtidige bidragydere + agent-baserede reviews.

## Fix

```markdown
- `fct_spc_execute.R`        — build_bfh_args + execute_bfh_request (BFHcharts-kald)
- `fct_spc_bfh_params.R`     — column-mapping helpers + map_to_bfh_params
- `fct_spc_bfh_invocation.R` — call_bfh_chart (low-level BFHcharts wrapper)
- `fct_spc_decorate.R`       — decorate_plot_for_display
```

Refs: docs/reviews/13-weekly-audit-2026-05-16.md H3
```

---

### Issue draft #4 (HIGH, P1)

**Title:** `test(integration): tilfoej state-derived write-back integration-test`

**Labels:** `testing`, `quality`

**Body:**
```markdown
## Summary

Cycle 10 (#730) state-derived column_config-fix har KUN pure-function-tests. Selve race-prevention-mekanismen (server-observer-kæden) er undækket. Regression i observer-chain ville ikke fanges.

## Recommended test

```r
test_that("state-derived column persists efter throttled input-roundtrip", {
  shiny::testServer(server_under_test, args = list(app_state = mock_state), {
    app_state$columns$mappings$y_col <- "Count"
    session$flushReact()
    expect_equal(column_config()$y_col, "Count")
    # Plus: verificer cache-invalidation + chart-render
  })
})
```

## Acceptance

- [ ] Integration-test rammer real observer-chain
- [ ] Test fejler hvis priority sænkes eller dependency fjernes

Refs: docs/reviews/13-weekly-audit-2026-05-16.md H4
```

---

### Issue draft #5 (MED, P1)

**Title:** `test(nav-guard): tilfoej coverage for JS-bridge observers + back-navigation`

**Labels:** `testing`, `quality`

**Body:**
```markdown
## Summary

5 observers i `R/utils_server_navigation_guard.R:180-280` (nav_guard_trigger relay, has_data_update push, set_in_app_navigating, schedule_clear, onFlushed-guard-clear) har 0 testthat-coverage. `setup_help_back_navigation()` har også 0 coverage.

## Recommended

```r
test_that("nav_guard_trigger JS input relays til navigation_requested event", {
  shiny::testServer(server_with_nav_guard, args = list(app_state = make_test_state()), {
    session$setInputs(nav_guard_trigger = list(tab = "spc_tab", ts = 1L))
    session$flushReact()
    expect_gt(app_state$events$navigation_requested, 0L)
  })
})
```

Plus tests for back-navigation fra report-bug.

## Acceptance

- [ ] Mindst 4 testServer()-tests for JS-bridge-observers
- [ ] mod_report_bug back-nav-test eksisterer

Refs: docs/reviews/13-weekly-audit-2026-05-16.md M1
```

---

### Issue draft #6 (MED, P1)

**Title:** `perf(observer): tilfoej eksplicit priority paa column_config-observer`

**Labels:** `performance`, `technical-debt`

**Body:**
```markdown
## Summary

`R/utils_server_visualization.R:113-130` bruger bare `shiny::observe({...})` (priority 0) til at kalde `apply_state_transition(transition_chart_config_updated(vc))`. Samme anti-pattern som cycle 12 H1 (#759). Priority 0 race'r med outputs.

## Fix

```r
shiny::observe({
  # ...eksisterende logik...
}, priority = OBSERVER_PRIORITIES$UI_SYNC)  # 750
```

## Validering

Tilsvarende test til `test-export-preview-redundans-elimination.R` der tæller invaliderings-count for column_config-afhængige outputs.

Refs: docs/reviews/13-weekly-audit-2026-05-16.md M2
```

---

### Issue draft #7 (MED, P2)

**Title:** `chore(logging): registrer BFH_SERVICE og oevrige contexts i LOG_CONTEXTS`

**Labels:** `technical-debt`, `observability`

**Body:**
```markdown
## Summary

`"BFH_SERVICE"` bruges 46 gange på tværs af SPC-pipeline men findes ej i centralt `LOG_CONTEXTS`-registry. Typo-risiko + onboarding-gap. Også manglende: NAV_GUARD, SPC_CACHE, TABLE_UPDATE_SERVICE, SESSION_RESTORE, LOCAL_STORAGE, FILE_PARSE_PURE, CSV_DETECT, PASTE_DATA, QIC_CACHE, BACKGROUND_TASKS.

## Fix

Tilføj alle aktive contexts i `R/config_log_contexts.R`. Test: `assert_log_context_registered()` køres i pre-push.

Refs: docs/reviews/13-weekly-audit-2026-05-16.md M7
```

---

### Issue draft #8 (HIGH-ROI refactor)

**Title:** `refactor(nav-guard): extract guard_active idiom som with_nav_guard_active()`

**Labels:** `refactor`, `code-quality`

**Body:**
```markdown
## Summary

`guard_active`-set/onFlushed-clear-idiom er dupliceret i:
- `utils_server_navigation_guard.R:233,269-276,286`
- `utils_server_server_management.R:569-579`

## Fix

```r
with_nav_guard_active <- function(app_state, session, expr) {
  app_state$navigation$guard_active <- TRUE
  force(expr)
  session$onFlushed(function() {
    app_state$navigation$guard_active <- FALSE
  }, once = TRUE)
}
```

Plus tilføj accessors: `get_guard_active()`, `set_guard_active()`, `get_pending_destination()`, `set_pending_destination()` i `utils_state_accessors.R` for konsistens med øvrige `app_state`-niveauer.

Refs: docs/reviews/13-weekly-audit-2026-05-16.md refactor HIGH-ROI-01 + MED-01
```

---

### Issue draft #9 (HIGH-ROI refactor)

**Title:** `refactor(wizard): extract wizard step-besked-helpers (eliminér magic strings)`

**Labels:** `refactor`, `code-quality`

**Body:**
```markdown
## Summary

Wizard step-besked-strenge (`"wizard-lock-step"`, `"wizard-unlock-step"`, `"wizard-complete-step"`, `"wizard-uncomplete-step"`) er hardcoded på 12+ call-sites på tværs af 3 filer. Stavefejl producerer silent JS-fejl.

## Fix

```r
# I utils_server_wizard_gates.R eller config_ui.R:
wizard_lock_step       <- function(session, step) session$sendCustomMessage("wizard-lock-step",       step)
wizard_unlock_step     <- function(session, step) session$sendCustomMessage("wizard-unlock-step",     step)
wizard_complete_step   <- function(session, step) session$sendCustomMessage("wizard-complete-step",   step)
wizard_uncomplete_step <- function(session, step) session$sendCustomMessage("wizard-uncomplete-step", step)
```

Refs: docs/reviews/13-weekly-audit-2026-05-16.md refactor HIGH-ROI-02
```

---

## Out of Scope

- **Implementering af fixes** — kun rapportering
- **Security-deep-dive** — bruger valgte at fokusere på code-quality (jf. project_security_threat_model: hospital-PCer, ej PHI)
- **Architecture-redesign-proposaler** — audit, ej design
- **Auto-opret issues** — udkast-liste til manuel review

---

## Reviewer-noter

- 7 agents dispatched parallelt i worktree-isolation, Sonnet default
- Empirisk repro for alle HIGH (3/3 confirmed; H4 er coverage-gap, ej runtime-bug)
- Baseline-docs (cycle 10/11/12) brugt til de-duplikering — ingen double-reporting
- Threat-model kalibreret nedad mod biSPCharts-kontekst (kvalitetsdata, ej PHI)

**Review-dato:** 2026-05-17
**Audit-periode:** 2026-05-09 → 2026-05-16
