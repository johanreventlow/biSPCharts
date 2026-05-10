# Cycle G — AI/RAG Integration

**Status:** Claude review + Codex adversarial reconciled (2026-05-09) + bruger-kontekst integreret. Område: BFHllm-integration-layer, AI improvement suggestions, export AI-modul, AI-config, knowledge curation, RAG-pipeline.

**Worktree:** `/Users/johanreventlow/R/biSPCharts-reviews` på `review/program-base` (synced med develop @ a8310c1a).

**Kritisk bruger-kontekst (2026-05-09):**
> "AI-feature er BEVIDST hidden i UI foreløbig — for meget i begyndelsen."

Verificeret empirisk: `R/mod_export_ui.R:233-244` wrapper AI-knap i `shiny::div(style = "display: none;")` med kommentar *"midlertidigt skjult, genaktiveres senere. Funktionaliteten er intakt i mod_export_server.R og fct_ai_improvement_suggestions.R."*

**Konsekvens for Cycle G:** Findings genklassificeres som **"defects der skal fixes FØR re-enable"** snarere end aktive prod-bugs. Implementation ROI lavere indtil roll-out planlagt — men dokumentation + lavere-risiko fixes (fail-closed defaults, dead-config-fjernelse) stadig værd.

**Codex peer-review konsekvens:** 4 recalibreringer integreret (H0 severity-downgrade, H3 fix-strategi-rewrite, H7 enabled-flag-mismatch, H2 key-shape-adapter).

---

## Findings (prioriteret efter REEL impact)

### 🟡 H0 — `data_consent="explicit"` mangler i begge AI-call-sites — **BLOCKING DEFECT FOR RE-ENABLE** (HIGH når feature genaktiveres, p.t. inert)

**Lokation:**
- `R/mod_export_ai.R:232-238` (sync fallback)
- `R/utils_async_helpers.R:121-126` (async path)

**Symptom:** Hvis AI-knap re-enables (UI-hide fjernes + GEMINI_API_KEY sat), vil hvert klik fejle med generic *"Kunne ikke generere AI-analyse. Tjek internetforbindelse..."*. Fejlen sker uafhængigt af om Gemini API-key er konfigureret korrekt.

**Verifikation:**

BFHcharts contract (pinned `v0.16.1` i `DESCRIPTION:78`, peer-pakke `R/spc_analysis.R:434-446`):
```r
if (isTRUE(use_ai)) {
  if (!identical(data_consent, DATA_CONSENT_EXPLICIT)) {
    stop("AI analysis requires data_consent = \"explicit\".\n", ...)
  }
}
```

biSPCharts call-sites (begge mangler `data_consent`-argument):

`R/mod_export_ai.R:232-238` (sync):
```r
BFHcharts::bfh_generate_analysis(
  spc_result$bfh_qic_result,
  metadata  = analysis_metadata,
  use_ai    = TRUE,
  max_chars = 375L
)
```

`R/utils_async_helpers.R:121-126` (async, kaldt fra `mod_export_ai.R:195` `ai_task$invoke()`):
```r
BFHcharts::bfh_generate_analysis(
  spc_result$bfh_qic_result,
  metadata  = analysis_metadata,
  use_ai    = TRUE,
  max_chars = max_chars
)
```

Empirisk: `grep -r "data_consent" R/ inst/` → **0 hits** i biSPCharts.

**Konsekvens (kalibreret efter Codex + bruger-kontekst):**
- **I dag:** AI-knap er hidden via `R/mod_export_ui.R:233 style = "display: none;"`. Normale brugere kan IKKE klikke. Server-path er broken, men ej trigget.
- **Ved re-enable (uden H0+H3-fix):** Hvert klik fejler. Brugere ser generic toast. Funktion 100% non-funktionel.
- **Defense-in-depth:** Codex bekræftede BFHcharts emitter audit-event INDE I `bfh_generate_analysis()` AFTER consent-validering. Bypassing-route ville miste audit-trail.

**Foreslået fix (REVIDERET efter Codex):** Implementér **shared preflight guard** der:
1. Kører PHI-check + `truncate_llm_context_fields()` på input
2. Hvis check passerer: kalder `BFHcharts::bfh_generate_analysis(..., use_ai = TRUE, data_consent = "explicit")` i både sync + async path
3. **Ej facade-route via `generate_improvement_suggestion()`** — facaden kalder direkte `BFHllm::bfhllm_spc_suggestion()` og bypasser BFHcharts' audit-emit. Codex's argument: bevar BFHcharts-audit-boundary.

Eksempel-skitse:
```r
# R/utils_ai_preflight.R (NY)
ai_preflight_or_abort <- function(context, session) {
  # 1. PHI-check (CPR-pattern på relevant fields)
  if (has_phi(context)) {
    showModal(modalDialog("CPR detekteret - AI-kald afbrudt"))
    return(NULL)
  }
  # 2. Truncate
  truncate_llm_context_fields(context)
}

# R/mod_export_ai.R + R/utils_async_helpers.R:
guarded_context <- ai_preflight_or_abort(context, session)
if (is.null(guarded_context)) return(NULL)
BFHcharts::bfh_generate_analysis(
  spc_result$bfh_qic_result,
  metadata = analysis_metadata,
  use_ai = TRUE,
  data_consent = "explicit",
  max_chars = max_chars,
  ...
)
```

**Test:** Integration-test der mocker `BFHllm::bfhllm_spc_suggestion` men kalder rigtig `bfh_generate_analysis(use_ai=TRUE)` for at fange contract-brud ved fremtidige BFHcharts-bumps.

**Severity:** HIGH (var CRITICAL pre-Codex; brugerens hidden-UI gør den til blocking-for-re-enable, ej aktiv outage).

---

### 🟡 H3 — PHI-check + LLM-truncation lever kun i død kode-sti (HIGH når H0 fixes, p.t. inert)

**Lokation:** `R/fct_ai_improvement_suggestions.R:54-144` (defineret men ikke kaldt fra `R/`)

**Symptom:** `generate_improvement_suggestion()` indeholder CPR-pattern-detektion (`linje 82-112`) + `truncate_llm_context_fields()`-kald (`linje 80`). Funktionen kaldes **kun fra tests**.

**Verifikation:** `grep -rn "generate_improvement_suggestion" /Users/johanreventlow/R/biSPCharts/R/` → kun definition + ingen call-sites i andre R-filer.

Production-stier (`R/mod_export_ai.R:232` sync + `R/utils_async_helpers.R:121` async) går direkte til `BFHcharts::bfh_generate_analysis(use_ai = TRUE)` — uden PHI-check, uden field-truncation. Free-text-felter sendes rå:

`R/mod_export_ai.R:222-227`:
```r
data_definition = input$pdf_description %||% "",
chart_title     = input$export_title %||% "",
department      = input$export_department %||% "",
footnote        = input$export_footnote %||% ""
```

**Konsekvens:** I dag dobbelt-maskeret af (a) hidden UI-knap + (b) H0-stop. **Når H0 fixes uden også at addressere H3:**
- CPR i `pdf_description` flyder direkte til Gemini uden modal-advarsel.
- Ingen længde-cap → bruger kan paste 100k+ tegn → cost-amplification + Gemini rate-limit-risiko (#489).
- `truncate_llm_context_fields()` (`linje 150-180`) bliver dokumentations-artefact.

**Foreslået fix:** Som del af H0-fix: implementér shared preflight guard (se H0). Codex specifik anbefaling: **bevar BFHcharts-audit-boundary** ved fortsat at gå via `bfh_generate_analysis(..., data_consent="explicit")` snarere end facade-direkte-kald.

**Severity:** HIGH (kobles til H0).

---

### 🟢 H_NEW — Gør AI-disable EKSPLICIT via golem-flag i stedet for hidden CSS + missing consent (NYT, MEDIUM, recommendation)

**Lokation:** Multiple — `inst/golem-config.yml`, `R/mod_export_ai.R`, `R/utils_bfhllm_integration.R`

**Symptom (per bruger-kontekst):** AI-disable er i dag fragile, opnået via:
1. `R/mod_export_ui.R:233 style = "display: none;"` (CSS-hide)
2. Missing `data_consent` = de-facto kill-switch (H0)
3. Missing GEMINI_API_KEY i prod = button auto-disabled

Hvis nogen ved senere lejlighed:
- Fjerner `display: none;` (fx ved feature-roll-out) → button vises men crasher
- Sætter API key i .Renviron → button enabled men crasher
- Tilføjer config-fix uden audit → bypass af audit-trail

**Verifikation:**
- `inst/golem-config.yml` ai-sektion: `enabled: true` i alle profiles (default, dev, prod). Kun `testing: enabled: false`.
- `register_ai_button_state()` (R/mod_export_ai.R:39-89): tjekker `has_spc_data && api_ready` — **ikke `ai_config$enabled`**.
- `register_ai_suggestion_handler()`: ingen enabled-check.
- `initialize_bfhllm()`: ingen enabled-check.

`ai_config$enabled` er **dead config-flag** i AI-egress-paths. Kun `rag_config$enabled` bruges (af BFHllm internt via `use_rag`-arg).

**Konsekvens:** `ai.enabled: false` i prod-config ville IKKE deaktivere AI-knap eller AI-egress. Brugerens intent ("AI bevidst disabled") opnås kun via UI-CSS-hide + manglende API key — fragile.

**Foreslået fix:**
1. Sæt `ai.enabled: false` i production-config (dokumentérer eksplicit intent)
2. `register_ai_button_state()`: tilføj `enabled <- isTRUE(get_ai_config()$enabled)` check; hvis FALSE → `shinyjs::hide("ai_generate_suggestion")` + skip API-probe
3. `register_ai_suggestion_handler()`: tilføj guard `req(isTRUE(get_ai_config()$enabled))` før task-invoke
4. Fjern `style = "display: none;"` fra UI (eller behold som double-defense — men flag enabled-check som primary)

**Net-effekt:** AI-feature kontrolleres ét sted (`ai.enabled: false/true` i golem-config). Re-enable = flip flag + sikre H0+H3 fixed først.

**Severity:** MEDIUM — defensive design + ren single-source-of-truth for feature-state.

---

### 🟡 H2 — `circuit_breaker` + `rate_limit` YAML-keys er dead config + forkert key-shape (MEDIUM, op-team confusion)

**Lokation:** `inst/golem-config.yml:106-110` vs. `R/utils_bfhllm_integration.R:198-208`

**Symptom (recalibreret efter Codex):** YAML eksponerer:
```yaml
ai:
  circuit_breaker:
    failure_threshold: 5
    reset_timeout_seconds: 300
  rate_limit:
    max_requests_per_minute: 20
```

biSPCharts forwarder ikke disse til BFHllm. **OG** Codex inspicerede BFHllm-API: faktisk forventer:
- `rate_limit$rpm` (NOT `max_requests_per_minute`)
- `rate_limit$rpd` (requests per day)
- `rate_limit$behavior` (string)
- `circuit_breaker$failure_threshold` (matcher)
- `circuit_breaker$reset_timeout_seconds` (matcher? — verificer)

Defaults BFHllm: `rpm = 15`. Vores YAML siger `max_requests_per_minute: 20`. Hvis vi blindt forward'er, ville BFHllm IGNORE `max_requests_per_minute` (ukendt key) → forblive på `rpm = 15`.

**Verifikation:** `grep -r "circuit_breaker|rate_limit|failure_threshold|max_requests" R/` → matches kun i `inst/golem-config.yml` + `docs/CONFIGURATION.md`. **0 matches i `R/`.**

`R/utils_bfhllm_integration.R:198-208`:
```r
configure_args <- list(provider = "gemini")
if (!is.null(ai_config$model)) { configure_args$model <- ai_config$model }
if (!is.null(ai_config$timeout_seconds)) { configure_args$timeout_seconds <- ... }
if (!is.null(ai_config$max_response_chars)) { configure_args$max_response_chars <- ... }
do.call(BFHllm::bfhllm_configure, configure_args)
```

**Konsekvens:** Ops-team kan ikke tune circuit-breaker/rate-limit via biSPCharts-config. Hvis de prøver via vores YAML-keys, sker intet. Hvis de senere tilføjer naiv forwarding, forbliver BFHllm på defaults pga. key-mismatch.

**Foreslået fix:** Implementér eksplicit **adapter** i `initialize_bfhllm()`:
```r
# Map biSPCharts YAML -> BFHllm-API
if (!is.null(ai_config$rate_limit$max_requests_per_minute)) {
  configure_args$rate_limit <- list(
    rpm = as.integer(ai_config$rate_limit$max_requests_per_minute),
    rpd = ai_config$rate_limit$max_requests_per_day %||% NULL,
    behavior = ai_config$rate_limit$behavior %||% "throttle"
  )
}
if (!is.null(ai_config$circuit_breaker)) {
  configure_args$circuit_breaker <- list(
    failure_threshold = ai_config$circuit_breaker$failure_threshold,
    reset_timeout_seconds = ai_config$circuit_breaker$reset_timeout_seconds
  )
}
```

Tilføj config-injection-test der inspicerer `BFHllm::bfhllm_get_config()` efter `initialize_bfhllm()`.

Alternativt (simplere): **fjern circuit_breaker + rate_limit fra YAML** + dokumentér at de håndteres af BFHllm-defaults. Spørgsmål til bruger: ønsker du tunability eller defaults-OK?

**Severity:** MEDIUM — afhænger af om ops faktisk vil tune.

---

### 🟢 H7 — `get_ai_config()` + `get_rag_config()` fail-opens — men `ai.enabled` ENFORCES IKKE (LOW, pivots til H_NEW)

**Lokation:** `R/utils_bfhllm_integration.R:122-150` + `linje 27-62`

**Symptom (Codex recalibrerede):** Min oprindelige draft foreslog "skift defaults til `enabled = FALSE`". Codex verificerede: **`ai_config$enabled` checkes IKKE i nogen AI-egress-path** (initialize_bfhllm, is_bfhllm_available, register_ai_button_state, click handler). Kun `rag_config$enabled` bruges.

**Konsekvens:** 2-linje fix på defaults ville:
- Ej forhindre AI-egress (enabled-flag dead)
- Kun affekte RAG-behavior
- Give false confidence at "fail-closed implementeret"

**Foreslået fix:** Subsumés af **H_NEW** ovenfor. Real fail-closed kræver:
1. Sæt `ai_config$enabled` default = `FALSE` (begge funktioner)
2. **Sæt enforcement-checks** (H_NEW) i alle AI-paths

Hvis H_NEW implementeres, slår H7 i samme commit. Hvis H_NEW droppes, bør H7 også droppes (false-confidence-fix er værre end ingen fix).

**Severity:** LOW alene. Pivots til H_NEW for real impact.

---

### 🟢 H5 — `bfhllm_available` session-cache invalideres aldrig (LOW, UX-gap, p.t. inert)

**Lokation:** `R/mod_export_ai.R:31-36`

**Symptom:** API-key-status caches på første kald + læses resten af sessionen. Ingen invalidation-trigger.

**Verifikation:** `R/mod_export_ai.R:31-36`:
```r
get_bfhllm_available <- function() {
  if (is.null(app_state$session$bfhllm_available)) {
    app_state$session$bfhllm_available <- isTRUE(is_bfhllm_available())
  }
  app_state$session$bfhllm_available
}
```

`bindEvent` på linje 85-89 reagerer på `current_data` + column-mappings, IKKE på API-key-state.

**Konsekvens (kalibreret):** I dag inert pga. hidden UI. Ved re-enable: hvis admin sætter ny API-key under session, kræver session-genstart for re-probe. Lavt impact i klinisk produktion.

**Foreslået fix (low-prio):** Dokumentér intent in-line ELLER tilføj manuel "genprøv API-status"-knap der nulstiller cache. Defer indtil AI-roll-out.

**Severity:** LOW — UX-gap kun relevant ved re-enable.

---

## Dismissed (verificeret afvist)

### ❌ H1 — Knowledge-content mangler i `inst/spc_knowledge/`

CLAUDE.md hævder content lever i `inst/spc_knowledge/`, men `docs/AI_INTEGRATION.md:36` siger eksplicit at knowledge base lever i **BFHllm-pakken**. `data-raw/build_ragnar_store.R` mangler i biSPCharts (verificeret), men ej biSPCharts' ansvar.

**Anbefaling (cleanup):** Opdater CLAUDE.md (linje ~226-230) til at reflektere actual ownership.

### ❌ H4 — Async race-condition på rapid double-click

UI-knap disabled på `mod_export_ai.R:156` ved klik, re-enabled på `linje 244` (sync) + `linje 271` (async observer). Double-click mitigeret.

### ❌ H6 — `truncate_llm_context_fields` fields-coverage gap

Funktionen i sig selv håndterer fields korrekt (test-coverage god i `test-llm-context-truncation-489.R`); reelle problem er at den ikke kaldes (dækket af H3).

---

## Codex adversarial-review konsekvens (2026-05-09)

Verdict: **needs-attention** — 4 specifikke recalibreringer integreret:

1. **H0 severity-downgrade:** Bruger-kontekst (AI-knap hidden) gør "production broken end-to-end"-claim overstated. Reframet som "blocking defect for re-enable".

2. **H3 fix-strategi rewrite:** Min oprindelige "facade-route via `generate_improvement_suggestion()`" ville bypasse BFHcharts' audit/consent-emission (som sker INDE I `bfh_generate_analysis()`). Codex's fix: shared preflight guard der bevarer BFHcharts-call.

3. **H7 enabled-flag mismatch:** `ai_config$enabled` checkes IKKE i nogen AI-egress-path. Min 2-linje default-fix ville give false confidence. Pivot til H_NEW (real enabled-gating).

4. **H2 key-shape adapter:** BFHllm forventer `rate_limit$rpm` (ikke `max_requests_per_minute`), `rpd`, `behavior`. Adapter krævet hvis forwarding implementeres.

**Bonus-recommendation (ej fund, men design-input):** AI-disable bør være eksplicit (golem-flag) snarere end fragile (hidden-CSS + missing-consent + missing-key). H_NEW (NYT fund) opstår fra denne indsigt + brugerens kontekst.

---

## Filer der modificeres ved implementation (REVIDERET)

| Prio | Fil | Ændring |
|------|-----|---------|
| H_NEW | `inst/golem-config.yml` (production) | `ai.enabled: false` (eksplicit kill-switch) |
| H_NEW | `R/mod_export_ai.R:39-89` | Tilføj `enabled` check + skip-paths hvis FALSE |
| H_NEW | `R/mod_export_ai.R:109-276` | `req(isTRUE(get_ai_config()$enabled))` guard i handler |
| H_NEW | `R/utils_bfhllm_integration.R:48` (defaults) | `enabled = FALSE` (subsumér H7) |
| H0+H3 | `R/utils_ai_preflight.R` (NY) | Shared preflight: PHI-check + truncate |
| H0+H3 | `R/mod_export_ai.R:232-238` + `R/utils_async_helpers.R:121-126` | Brug preflight + tilføj `data_consent = "explicit"` |
| H0+H3 | `tests/testthat/test-mod-export-ai.R` (NY) | Integration-test med rigtig `bfh_generate_analysis(use_ai=TRUE)` |
| H2 | `R/utils_bfhllm_integration.R:198-208` ELLER `inst/golem-config.yml:106-110` | Adapter (rpm-mapping) ELLER fjern dead config |
| H5 | `R/mod_export_ai.R:31-36` | Dokumentér ELLER add manual invalidation (DEFER) |
| (cleanup) | `CLAUDE.md` | Opdater Knowledge curation-sektion |

---

## Implementation-rækkefølge & scope (ANBEFALING — bruger-godkendelse krævet)

Givet brugerens intent ("AI bevidst disabled foreløbig"):

**Anbefaling A: Make-it-explicit-now (low-effort)**
- Implementér H_NEW: eksplicit feature-flag + enforcement
- Skip H0/H3/H2: defer til AI-roll-out planlagt
- Cleanup CLAUDE.md (knowledge-curation-claim)

**Anbefaling B: Full-fix-for-future (medium-effort)**
- A + H0+H3+H2 i samme cycle
- Forbereder roll-out fully

**Anbefaling C: Status-quo + dokumentation**
- Skip implementation
- Behold report som reference

---

## Læringer (Cycle G)

1. **Bruger-kontekst overrides Codex-severity-claim.** Codex flagged H0 som CRITICAL ("production AI broken end-to-end"); bruger informerede om hidden UI → severity HIGH-blocking-for-re-enable. Empirisk verifikation i UI-koden bekræftede.

2. **Facade-route kan bypasse audit-boundary.** Min H3-foreslåede facade-route ville have skipped BFHcharts' audit-emission. Codex fanget via call-graph-trace. **Lesson:** før refactor til "centralized helper"-pattern, verificer at helper bevarer ALL upstream-contracts (audit, validation, observability).

3. **Default-flag-fix giver false confidence hvis ej enforced.** Min H7-foreslåede 2-linje default-skift ville have set ud som fail-closed-implementation, men `ai_config$enabled` checkes IKKE i nogen AI-egress-path. **Lesson:** før config-default-fix, grep efter actual enforcement-points.

4. **Config-key-shapes mellem pakker kræver eksplicit adapter.** biSPCharts YAML bruger `max_requests_per_minute`, BFHllm forventer `rpm`. Naive forwarding via `do.call` ville silent-ignore unknown keys og lade BFHllm-defaults stå. **Lesson:** cross-package-config kræver explicit-mapping + integration-test der inspicerer downstream-config-state.

5. **"Hidden via CSS" er fragile feature-toggle.** Display:none + missing API-key + missing consent = 3-lags by-accident-disable. Bryde 1 lag → re-enable. Eksplicit feature-flag i config + enforcement-check i alle paths = robust single-source-of-truth.
