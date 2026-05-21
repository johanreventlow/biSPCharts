# Cycle 11 — Export-preview-ineffektivitet (dev-log 2026-05-16)

**Status:** ✅ KOMPLET 2026-05-16 sen. PR #752 + #753 + #754 merged.
H1 follow-up: Option C accepteret (se "Post-merge verifikation" sektion).
**Område:** PDF preview reactive-chain + SPC cache-key.
**Baseline:** Bruger observerede ~3 sek delay ved navigation til eksport-tab pga dobbelt preview-render. Log-evidens vedlagt.

---

## Sammenfatning

| ID | Severity | Bucket | Lokation | Fix-kompleksitet |
|----|----------|--------|----------|------------------|
| H1 | HIGH | Sub-optimal performance (~3 sek wasted per tab-skift) | `R/mod_export_server.R:337-447` | Lav (req-guard) |
| H2 | MEDIUM | Sub-optimal cache-hit-rate | `R/utils_spc_cache.R:180` | Mellem (decorate-step refactor) |
| M1 | LOW | Log-støj + minimal CPU | `R/utils_server_session_helpers.R:340-477` (settings_save) | Lav (dedupe) |
| M2 | LOW | localStorage I/O 4x på 10 sek | `R/utils_server_server_management.R` (AUTO_SAVE) | Mellem (debounce-fix) |
| M3 | LOW | Anhoej-beregning 2x (cache-aware, ej dyrt) | `R/utils_visualization*.R` | Lav |

---

## Log-evidens (raw)

```
15:40:24  EXPORT_MODULE: Export plot generated for context: export_pdf
15:40:26  EXPORT_MODULE: PDF preview PNG generated     <-- 1. preview (uden analyse-tekst)
15:40:26  AUTO_SAVE: settings_save ... pdf_improvement='Processen udviser...'  <-- analyse-tekst landet
15:40:27  VISUALIZATION: Anhoej refresh (cache-aware)
15:40:29  EXPORT_MODULE: PDF preview PNG generated     <-- 2. preview (3 sek senere)
```

```
15:40:17  SPC_CACHE: Generated SPC cache key: chart_type=u, key=spc_u_c3ee6375e574eb2e_f16c66f9acd81cf4 ...
15:40:17  BFH_SERVICE: Cache miss → bfh_qic() 1.03 sek → cache_stored=TRUE
15:40:23  SPC_CACHE: Generated SPC cache key: chart_type=u, key=spc_u_2c1c300a749f9bf8_14abc77b8df9f6a1 ... (DIFFERENT key)
15:40:23  BFH_SERVICE: Cache miss → bfh_qic() 1.08 sek → cache_stored=FALSE
```

---

## H1 [HIGH] — PDF preview rendres 2x pr. tab-skift

**Lokation:** `R/mod_export_server.R:337-447` (pdf_preview_image reactive)

**Symptom:**
Ved navigation til eksport-tab fyrer `pdf_preview_image()` FØR `register_analysis_autogen()` har genereret + indsat auto-analyse-tekst via `updateTextAreaInput()`. Resultat: første preview rendres med tom `pdf_improvement`, dernæst re-rendrer preview 1500ms efter input-update ankommer fra klient. To Typst PDF→PNG roundtrips à ~2 sek = 4 sek effektivt arbejde for ÉN visning.

**Verifikation (kode-citat fra `R/mod_export_server.R:322-325`):**

```r
debounced_analysis <- shiny::debounce(
  shiny::reactive(input$pdf_improvement %||% ""),
  millis = DEBOUNCE_DELAYS$metadata_input  # 1500ms
)
```

```r
pdf_preview_image <- shiny::reactive({
  shiny::req(app_state$session$active_tab == "eksporter")
  # ... format/data-guards ...
  analysis_input <- debounced_analysis()  # <-- lytter direkte på input
  # ... bygger metadata + render Typst PDF → PNG ...
})
```

**Verifikation (kode-citat fra `R/mod_export_analysis.R:104-112`):**

```r
set_autogen_active(app_state, TRUE)
session$onFlushed(function() {
  set_autogen_active(app_state, FALSE)
}, once = TRUE)
shiny::updateTextAreaInput(session, "pdf_improvement", value = auto_text)
```

`autogen_active`-flag sættes FØR `updateTextAreaInput()`. Flag clears via `onFlushed` (efter Shiny har sendt besked til klient). `settings_save` bruger flagget for at undgå at gemme programmatisk input-ændring (`R/utils_server_session_helpers.R:451`). **Men `pdf_preview_image` checker IKKE flagget.**

**Konsekvens:**
- Wasted compute: ~2 sek per tab-skift (én ekstra Typst→PNG roundtrip)
- Synlig flicker: bruger ser preview opdatere to gange
- Cache-belastning: `pdf_export_plot()` evalueres 2x (anden eval = cache-hit, men metadata-build + Typst-render gentages)

**Foreslået fix (preliminært — afventer Codex):**

Tilføj `req(!is_autogen_active(app_state))` som første guard i `pdf_preview_image` efter format/data-guards:

```r
pdf_preview_image <- shiny::reactive({
  shiny::req(app_state$session$active_tab == "eksporter")
  format <- input$export_format %||% "pdf"
  if (format != "pdf") return(NULL)
  shiny::req(app_state, app_state$data$current_data, app_state$columns$mappings$y_column)

  # CYCLE 11 H1: Vent på auto-analyse-cycle inden første preview-render.
  # Forhindrer dobbelt-render-pattern: 1) tom analyse-tekst, 2) efter updateTextAreaInput.
  # autogen_active sættes TRUE i register_analysis_autogen() FØR updateTextAreaInput
  # og clears via session$onFlushed (mod_export_analysis.R:104-112).
  shiny::req(!is_autogen_active(app_state))

  pdf_result <- pdf_export_plot()
  # ... resten uændret
})
```

**Edge cases at verificere:**
1. **User har redigeret pdf_improvement:** `register_analysis_autogen()` returnerer tidligt (line 102) UDEN at sætte `autogen_active=TRUE`. Flag forbliver FALSE → guard passerer → preview rendres ÉN gang. OK.
2. **Format ≠ pdf:** Autogen returnerer tidligt (line 53-56). Flag forbliver FALSE. Preview returnerer NULL alligevel. OK.
3. **Første tab-skift med tomt feltet:** Autogen-observer (LOW pri) sætter flag TRUE → kalder `updateTextAreaInput()` → registrerer onFlushed. Preview-reactive eval'es UNDER samme reactive flush (output-rendering kommer efter observers): flag er TRUE → `req()` fail → preview render skippes. `onFlushed` fyrer EFTER preview-eval, clearer flag. Klient roundtrip lander input-update → debounced_analysis udløber 1500ms senere → preview re-eval → flag nu FALSE → render. **Risiko:** Hvis output-rendering sker FØR observer-cycle færdig (Shiny-internals), så fail vi at registrere autogen-cycle. Codex skal verificere observer→output evaluation order.
4. **Cross-tab race:** Bruger spam-skifter mellem tabs. `autogen_active` kan blive sat af tidligere tab-skift uden at clears. Cleanup-strategi: sæt `autogen_active=FALSE` ved tab-leave?

---

## H2 [MEDIUM] — SPC cache-key inkluderer `chart_title`, giver cache-miss per titel-ændring

**Lokation:** `R/utils_spc_cache.R:175-180`

**Symptom:**
Cache-key indeholder `chart_title` og `target_text`. Samme data, anden titel → total cache miss → 1+ sek BFHcharts render igen. Log viser 2 cache miss på 6 sek for samme data hvor eneste forskel er `has_chart_title=FALSE` (chart-preview-context) vs `has_chart_title=TRUE` (export-context).

**Verifikation (kode-citat fra `R/utils_spc_cache.R:161-188`):**

```r
config_signature <- list(
  chart_type = config$chart_type,
  x_column = config$x_column,
  # ... data-relaterede felter ...
  y_axis_unit = config$y_axis_unit,
  # Codex peer-review 2026-05-08 (#H3): target_text og chart_title bruges
  # i BFH-kald (fct_spc_execute.R:84,86) men manglede i config_signature.
  # Konsekvens: cache returnerede plot med stale labels naar bruger
  # aendrede target-tekst eller chart-titel.
  target_text = config$target_text,
  chart_title = config$chart_title,
  multiply_by = config$multiply_by %||% 1,
  viewport_width = config$viewport_width,
  viewport_height = config$viewport_height
)
```

**Verifikation (kode-citat fra `R/fct_spc_execute.R:66-84`):**

```r
chart_title <- resolve_bfh_chart_title(
  extra_params$chart_title_reactive %||% extra_params$chart_title
)
bfh_params <- map_to_bfh_params(
  # ...
  chart_title = chart_title,  # <-- embedded i plot via BFHcharts
  # ...
)
```

**Verifikation (kode-citat fra `R/fct_spc_decorate.R`):**
Decorate-step modificerer KUN Anhoej-metadata og backend-flag. Titel-application er IKKE post-cache.

**Konsekvens:**
- Titel-edits trigger fuld 1+ sek BFHcharts re-compute selv om underliggende data uændret
- Cross-context (preview vs export) cache-deling umulig hvis title differer
- BEMÆRK: viewport_width/height differer også mellem contexts → cache-miss er delvist forventet uafhængigt af titel. Title-removal alene løser IKKE cross-context-sharing.

**Foreslået fix (preliminært — kræver design-review):**

**Option A — Decorate-step adder titel post-cache:**
1. Strip `chart_title`/`target_text` fra `config_signature` (utils_spc_cache.R:175-180)
2. Strip `chart_title` fra `map_to_bfh_params()`-kald (fct_spc_execute.R:84)
3. Decorate-step adder titel: `standardized$plot <- standardized$plot + ggplot2::ggtitle(chart_title)` ELLER kalder BFHcharts' label-API post-render

**Risiko:** BFHcharts' egen layout-logik (label-placering, base_size-scaling) bygger på titel-tilstedeværelse. Post-cache title-injection kan give afvigende rendering vs pre-cache. **Kræver test mod BFHcharts-output:** sammenlign rendered plot med titel-pre-cache vs titel-post-cache pixel-for-pixel.

**Option B — Bevar nuværende arkitektur, acceptér miss:**
Title-cache-key er semantisk korrekt. Cross-context-sharing er ikke realistisk pga viewport-differens alligevel. **Verdict for #H2: defer hvis Option A pixel-test fejler.**

**Option C — Compromise: title-uafhængig cache + display-cache:**
- Compute-cache nøgles uden titel (deler data-beregning)
- Display-cache nøgles med titel (deler rendered plot)
- Decorate-step returnerer display-cached plot eller renders titel-overlay

**Anbefaling:** Start med Option B-vurdering. Hvis Codex bekræfter at title-edit-flow er sjælden (kun ved første eksport-setup), så er ROI lav.

---

## M1 [LOW] — `settings_save` fyrer 3x på 1 sek ved tab-skift

**Lokation:** `R/utils_server_session_helpers.R:340-477`

**Symptom:**
```
15:40:16 settings_save active_tab='upload'
15:40:16 settings_save active_tab='analyser'
15:40:16 settings_save active_tab='analyser'   <-- duplikat
```

Tab-skift trigger + sandsynligvis observer der re-fyrer på samme state.

**Foreslået fix:** Tilføj dedupe via `last_saved_hash` — sammenlign payload-hash med forrige save, skip hvis identisk.

**ROI:** Lav. Kun log-støj + minimal CPU. Kan deferes.

---

## M2 [LOW] — AUTO_SAVE 24x6 rows persisteret 4x på 10 sek

**Lokation:** `R/utils_server_server_management.R` (auto-save observer)

**Symptom:**
```
15:40:19, 15:40:19, 15:40:26, 15:40:27  Auto-saving 24 rows x 6 cols to localStorage
```

Debounce 2s konfigureret men virker ikke. Mulig årsag: `auto_save_debounced` reactive instantiated inde i observer i stedet for én gang i server-init.

**Foreslået fix:** Verificer debounce-wrapper-placering. Skal være ÉN reactive-instans pr. session.

**ROI:** Lav-mellem. localStorage write er sync ~1-5ms. Ej bruger-synlig.

---

## M3 [LOW] — Anhoej-beregning fyrer 2x (cache-aware, 2. er fast)

**Lokation:** Visualization-modul Anhoej refresh-cycle

**Symptom:**
```
15:40:18 VISUALIZATION: Anhoej update (centerline_changed=FALSE)
15:40:27 VISUALIZATION: Anhoej refresh (cache-aware)
```

Andre er cache-aware (fast), men `update` med `centerline_changed=FALSE` burde være no-op fra start. Mindre cleanup.

**ROI:** Negligible. Kan deferes til separat cycle.

---

## Codex-trigger-decision (Phase 2)

Run Codex YES — trigger-criteria mødt:
- [x] Draft indeholder executable R-snippet (H1 fix)
- [x] Cross-package contract-claim (H2 BFHcharts title-rendering)
- [x] Empirical claim (preview 2x render, cache-key composition)
- [x] Severity-vurdering driver scope (H2 Option A vs B vs C)

Particular Codex focus-asks:
1. H1: Shiny observer→output evaluation order. Vil `autogen_active=TRUE` (sat i LOW-pri observer) være synlig FØR `pdf_preview_image()` evalueres første gang ved tab-skift? Hvis output-rendering sker FØR observer-LOW-pri, så er fix-strategi forkert.
2. H1: Cross-tab race. Brug-case: bruger spam-skifter mellem tabs. Kan `autogen_active` blive låst TRUE hvis onFlushed ikke fyrer (fx hvis user navigerer væk inden flush)?
3. H2: BFHcharts post-cache title-injection. Eksisterer der API i BFHcharts til at adde titel POST-render uden at trigger re-layout? Hvis ej: pixel-equivalens kan ej garanteres → Option A er invasivt.
4. H2: Title-cache-key blev tilføjet 2026-05-08 efter Codex egen review (#H3). Vurder om current cycle's bekymring (cache-miss) er underordnet original bekymring (stale labels).

---

## Codex adversarial-review konsekvens (2026-05-16)

**Verdict:** needs-attention. H1 fix-recipe rejected. NY HIGH bug fundet. H2 Option A rejected.

### Bekræftet (verified empirisk)

- **H1 problem:** Preview rendres 2x ved tab-skift med ny data — confirmed via log + reactive-chain mapping.
- **NY HIGH bug — reactive chart_title cache-stale:** Cache-key reads `extra_params$chart_title` (fct_spc_bfh_facade.R:267) via R's `$`-partial-matching, men analysis-path passerer en `shiny::reactive` FUNCTION-OBJECT som `chart_title_reactive` (utils_server_visualization.R:293). Hash af samme function-object er IDENTISK selv om closed-over `input$indicator_title` ændres.

  **Empirisk reproduktion (Rscript):**
  ```r
  title_var <- "A"
  reactive_fn <- function() title_var
  h3 <- digest::digest(reactive_fn, algo = "xxhash64")  # d0bcc7dd6fae1973
  title_var <- "B"
  h4 <- digest::digest(reactive_fn, algo = "xxhash64")  # d0bcc7dd6fae1973
  identical(h3, h4)  # TRUE — STALE CACHE BUG
  ```

  Test-coverage (`tests/testthat/test-cache-key-target-text-chart-title.R:8-28`) dækker KUN string-baseret chart_title — function-objekter slap igennem.

- **H2 Option A rejected:** Codex verificerede BFHcharts-pipeline:
  - `bfh_qic` → `render_bfh_plot` → `bfh_spc_plot` anvender `BFHtheme::bfh_labs(title=...)` (plot_core.R:226-236)
  - Title-application sker INDE i render-pipeline før SPC-labels
  - Ingen exported API til post-render title-decoration uden re-layout
  - `target_text` driver label-content i `add_spc_labels` (fct_add_spc_labels.R:226-258) — kan ej fjernes fra cache-key
  - Verdict: Option B (accept miss, defer) — kun revisit hvis BFHcharts eksponerer post-cache display-API med pixel-regression-tests.

### Recalibreret

- **H1 fix:** Foreslået `req(!is_autogen_active(app_state))` REJECTED. Empirisk verificeret: `is_autogen_active()` bruger `shiny::isolate()` (utils_state_accessors.R:885-887) → flag-ændring invaliderer IKKE `pdf_preview_image` reactive. Hvis autogen genererer identisk auto_text (tab-revisit), sender `updateTextAreaInput()` alligevel besked til klient — men hvis værdien er identisk, fyrer ingen input-change → preview blokeres permanent indtil næste manuelle ændring.

  **Ny H1 fix-strategi:**
  1. **Skip `updateTextAreaInput`** i `register_analysis_autogen()` hvis `auto_text == current_value` (eliminerer tab-revisit-roundtrip).
  2. **Server-side effective analysis** i `pdf_preview_image`: prefer `app_state$ui$last_auto_analysis` over `debounced_analysis()` når user ikke har redigeret. Dette gør preview deterministisk synkron med autogen-completion uden afhængighed af klient-roundtrip.

- **M2 root-cause:** Auto-save 4x — `auto_save_trigger` ER single-instantiated (utils_server_session_helpers.R:272-310). Codex viser at 4x writes IKKE skyldes debounce-bug. Mulig årsag: andre call-sites kalder `autoSaveAppState()` direkte (uden debounce-trigger). Kræver dybere repro før fix.

### Dismissed

- **M1 (settings_save 3x dedupe):** Allerede implementeret via `last_settings_payload` + `identical()` check i utils_server_session_helpers.R:435-470. Log-output er fra FØR dedupe-check eller fra forskellig payload. Ikke et reelt problem.

- **M3 (Anhoej refresh):** Cache-aware. Negligible. Defer.

### Læring (ny pattern)

**Reactive-as-data anti-pattern:** Når en function/reactive-closure passeres som data til hash-baseret cache-key, hashes funktion-OBJECT (memory-reference) ikke return-value. Closed-over state-ændringer er usynlige for hash. Cache-key-callers SKAL evaluere reactives/funktioner FØR hashing, ej passere closures.

**Tilføj til feedback-memory:** `feedback_cache_key_value_resolution.md` — "Resolve reactive values BEFORE cache-key hashing. Function-objects with mutable closed-over state hash identically across state-changes."

---

## Implementation-plan (Phase 5)

### PR-A: NY HIGH — Fix reactive chart_title cache-stale-bug

**Branch:** `fix/cache-key-resolve-reactive-title-cycle-11-h2new`

**Scope:**
1. `R/fct_spc_bfh_facade.R:262-267`: Resolve title FØR cache-key generation:
   ```r
   resolved_title <- resolve_bfh_chart_title(
     extra_params$chart_title_reactive %||% extra_params$chart_title
   )
   cache_config <- list(
     ...
     chart_title = resolved_title,  # string, IKKE function
     ...
   )
   ```
2. `R/fct_spc_execute.R:66-68`: Brug samme resolved_title (eliminer double-resolution).
3. Drop R partial-matching `extra_params$chart_title` — passér eksplicit resolved.

**Tests:**
- `tests/testthat/test-cache-key-reactive-title.R`: Regression-test der ville have fanget bug.
  - Setup: same function-object, change closed-over `input$indicator_title`, generate cache-keys, assert NOT identical.
- No-regression: bekræft eksisterende string-title cache-key uændret.

**Severity-impact:** Hard runtime — analysis-tab cached title visualisering kan vise STALE titel til brugere. Kunne forklare incidents hvor "title-ændring virker ikke første gang".

### PR-B: H1 — Fix preview double-render

**Branch:** `fix/preview-double-render-cycle-11-h1`

**Scope:**

Step 1 — `R/mod_export_analysis.R:102-112`: Skip update-if-identical:
```r
if (!user_has_edited) {
  current_value <- shiny::isolate(input$pdf_improvement) %||% ""
  app_state$ui$last_auto_analysis <- auto_text  # server-state altid set
  if (identical(current_value, auto_text)) {
    return()  # ingen klient-roundtrip nødvendig
  }
  set_autogen_active(app_state, TRUE)
  session$onFlushed(function() set_autogen_active(app_state, FALSE), once = TRUE)
  shiny::updateTextAreaInput(session, "pdf_improvement", value = auto_text)
}
```

Step 2 — `R/mod_export_server.R:365`: Brug effective-analysis pattern:
```r
# Erstat: analysis_input <- debounced_analysis()
# Med:
analysis_input <- shiny::isolate({
  auto_text <- app_state$ui$last_auto_analysis %||% ""
  user_text <- debounced_analysis()
  if (nzchar(trimws(user_text)) && !identical(trimws(user_text), trimws(auto_text))) {
    user_text  # user har redigeret
  } else {
    auto_text  # under/efter autogen, brug server-state
  }
})
```

Reactive deps: `debounced_analysis()` + `app_state$ui$last_auto_analysis` (begge reactive). Preview invaliderer på enten.

**Tests:**
- `tests/testthat/test-export-preview-double-render.R`: Mock autogen-cycle + tab-skift, assert `pdf_preview_image` evaluation count == 1 (not 2).

**Severity-impact:** Sub-optimal performance + bruger-synlig flicker. 2 sek wasted per tab-skift.

### Defer / dismissed

- **H2-ORIG (chart_title i cache-key):** Defer per Option B verdict. Bevarer stale-label-fix fra 2026-05-08. PR-A løser separat reactive-stale bug.
- **M1 (settings_save dedupe):** DISMISSED — allerede implementeret.
- **M2 (AUTO_SAVE 4x):** DEFER pending separat repro-cycle. Mulige call-sites andre end debounce-trigger.
- **M3 (Anhoej dobbelt):** DEFER — cache-aware, negligible.

### Worktree-discipline

Begge PRs implementeres fra develop-baseret branch i samme tree. Atomic commits (én PR per finding). Manifest-konflikter resolves via `git merge origin/develop --no-edit` hvis merge-rækkefølge giver YAML-conflicts.

---

## Post-merge verifikation (2026-05-16 sen)

Bruger leverede dev-log efter PR #752 + #753 merget. H1-symptom delvist mitigeret men 2 renders forbliver. Analyse:

### H1 — observeret adfaerd

```
18:17:30  Export plot generated
18:17:30  settings_save pdf_improvement='...ustabilitet...'   <-- GAMMEL tekst
18:17:31  PDF preview PNG (1)
18:17:32  settings_save pdf_improvement='...varierer naturligt...'   <-- NY tekst!
18:17:34  PDF preview PNG (2)
```

**Visuel verifikation:** Bruger ser KORREKT tekst i begge previews (ej tom). 2 renders har FORSKELLIG content:
- Preview 1: med eksisterende `last_auto_analysis` fra foer skift-edits
- Preview 2: med ny analyse-tekst genberegnet af autogen-observer efter fresh SPC-compute (post-skift-edits)

Race: pdf_preview_image evaluerer FOER autogen-observer afslutter recompute. Server-state `last_auto_analysis` er stale ved foerste eval; opdateres efter.

### Option C verdict — accepteret

Tre fix-options blev overvejet:
- **A)** Defer preview til autogen-completion via reactiveVal-flag
- **B)** Lad autogen-observer trigger preview direkte (kobl reactive-chain)
- **C)** Acceptér 2 renders som "data-progression" (quick feedback + fresh content)

**Bruger valgte Option C** (2026-05-16). Rationale:
- Bruger ser instant preview-feedback med eksisterende tekst (ej tom)
- 2. preview opdateres med fresh content naar autogen er faerdig
- Bedre UX end at vente 1-2 sek paa fully-computed analyse-tekst foer foerste render
- 2 sek total compute-spildtid acceptable

**Dokumentation:** `R/mod_export_server.R:365-389` inline-kommentar forklarer expected behavior. Hvis senere optimering kraeves: Option A implementation via `reactiveVal`-flag.

### Andre observerede patterns (post-merge)

- ✅ **AUTO_SAVE-dedupe virker:** `settings_save sprunget over: payload uaendret` ses kl 18:17:20, 18:17:22, 18:17:27. M1 confirmed dismissed.
- ❌ **NY BUG (ikke cycle 11 scope):** BFHcharts `<COLLAPSE_ERROR: Can't extract column with n_col_name. Subscript n_col_name must be size 1, not 24.>` — fyrer ved hvert `bfh_qic`-kald uden `n_var` paa i-chart. Skal eskaleres til BFHcharts-repo som separat issue.
- ⚠️ **Trin 2 (analyse) skift-edits:** 3 separate compute-cycles ved 3 skift-edits (1.3 sek total). Korrekt adfaerd — debouncing ville give laggy feel.

### Cycle 11 closure

| Finding | Status |
|---------|--------|
| H1 | ✅ Mitigated + Option C accepted |
| H2-NEW | ✅ Fixed (#752) |
| H2-ORIG | ✅ Defer (Option B per Codex) |
| M1 | ✅ Dismissed (already implemented) |
| M2 | ⏸ Defer pending repro-cycle |
| M3 | ⏸ Defer (negligible) |

Cycle 11 lukket. Follow-up: BFHcharts COLLAPSE_ERROR + M2/M3 hvis kandidater for senere cycle.
