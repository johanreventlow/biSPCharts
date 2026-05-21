# Cycle 12 — Preview-redundans-elimination (post-cycle-11 follow-up)

**Status:** Draft — afventer Codex adversarial-review.
**Område:** `pdf_preview_image` reactive — 2. redundant render i første-tab-besøg.
**Baseline:** Bruger leverede 2 dev-logs efter cycle 11 PR #752 + #753 + #757 merget. Logs viste at fix delvist virker.

---

## Empirisk evidens (post-cycle-11)

### Sekvens 1: Trin 2 → Trin 3 (første tab-besøg)

```
18:43:37  Export plot generated
18:43:37  settings_save active_tab='eksporter' pdf_improvement=''
18:43:38  PDF preview PNG generated (1)
18:43:39  settings_save pdf_improvement='Processen udviser ustabilitet...'
18:43:42  PDF preview PNG generated (2)
```

**Begge previews har SAMME tekst** — redundans, IKKE data-progression.

### Sekvens 2: Trin 3 → Trin 2 → Trin 3 (tab-revisit)

```
18:44:39  settings_save active_tab='analyser'  (tilbage til 2)
18:44:43  Export plot generated
18:44:43  settings_save active_tab='eksporter' pdf_improvement='Processen udviser...' (ALLEREDE fuld)
18:44:44  PDF preview PNG generated (1)
(intet preview 2)
```

**KUN 1 render!** Min cycle 11 fix's `skip-update-if-identical` rammer perfekt — `current_text` matcher allerede `auto_text` → `updateTextAreaInput` skippes.

---

## Sammenfatning

| ID | Severity | Bucket | Lokation |
|----|----------|--------|----------|
| H1 | MEDIUM | Sub-optimal performance (~1.5 sek wasted per første tab-besøg) | `R/mod_export_server.R:316-447` |
| D1 | DOC | Cycle 11 Option C-rationale er misvisende for simple-case | `R/mod_export_server.R:376-385`, `docs/reviews/11-*.md` |

---

## H1 [MEDIUM] — 2. preview-render i første tab-besøg er redundans

**Lokation:** `R/mod_export_server.R:337-447` (pdf_preview_image reactive)

**Symptom:**
Ved første tab-skift til eksport-tab (input$pdf_improvement initialt tom):
1. autogen-observer fyrer → `app_state$ui$last_auto_analysis = "..."`, `updateTextAreaInput("pdf_improvement", "...")`
2. pdf_preview_image evaluerer i samme reactive flush → render 1 med korrekt tekst (via `last_auto_analysis`)
3. Klient-roundtrip lander → `input$pdf_improvement = "..."`
4. `debounced_analysis()` invaliderer efter 1500ms debounce → pdf_preview_image **invaliderer downstream uanset om effective_analysis-return-value er ens**
5. Preview render 2 — SAMME tekst, redundant Typst→PNG roundtrip (~1.5 sek)

**Verifikation (kode-citat fra `R/mod_export_server.R:386-389`):**

```r
analysis_input <- compute_effective_analysis_text(
  user_text = debounced_analysis(),
  auto_text = app_state$ui$last_auto_analysis %||% ""
)
```

`debounced_analysis()` er en reactive dependency. Shiny invaliderer alle reactives der læser den, uanset om hver returnerede værdi er identisk. `pdf_preview_image` re-evaluerer derfor selv om `compute_effective_analysis_text` returnerer samme resultat.

**Verifikation (kode-citat fra `R/mod_export_analysis.R:102-116`):**

```r
if (!user_has_edited) {
  app_state$ui$last_auto_analysis <- auto_text
  if (identical(current_text, auto_text)) {
    return()  # CYCLE 11: tab-revisit skipper updateTextAreaInput
  }
  set_autogen_active(app_state, TRUE)
  session$onFlushed(function() set_autogen_active(app_state, FALSE), once = TRUE)
  shiny::updateTextAreaInput(session, "pdf_improvement", value = auto_text)
}
```

Cycle 11 skip-guard rammer KUN ved tab-revisit (input matcher allerede auto_text). Første-tab-besøg: input er tom, auto_text er ny → updateTextAreaInput kaldes → roundtrip → debounced invalidates → 2. render.

**Konsekvens:**
- Wasted compute: ~1.5 sek per første tab-besøg (1 ekstra Typst→PNG roundtrip)
- Minor visuel flicker (samme content men render gentages)
- Cycle 11 Option C-docs (PR #757) baserede sig på data-progression-argument der IKKE gælder her — kun ved skift-edits mellem renders. I simple-case er det redundans.

---

## Foreslået fix-options

### Option A: reactiveVal-diff-check (anbefalet)

Wrap `compute_effective_analysis_text` i `reactiveVal` der kun opdateres ved REEL value-change.

**Implementation (preliminært — afventer Codex):**

```r
# I mod_export_server.R, FØR pdf_preview_image:
effective_analysis_val <- shiny::reactiveVal("")

shiny::observe({
  new_text <- compute_effective_analysis_text(
    user_text = debounced_analysis(),
    auto_text = app_state$ui$last_auto_analysis %||% ""
  )
  current <- shiny::isolate(effective_analysis_val())
  if (!identical(new_text, current)) {
    effective_analysis_val(new_text)
  }
})

# I pdf_preview_image:
analysis_input <- effective_analysis_val()
```

**Mekanik:**
- Observer læser begge dependencies (debounced_analysis + last_auto_analysis)
- Beregner effective text
- Sammenligner med forrige (isolated read)
- KUN opdaterer reactiveVal hvis ny værdi differer
- `reactiveVal` invaliderer ej downstream ved no-op writes (Shiny convention)
- pdf_preview_image læser kun reactiveVal — invalideres kun ved reel change

**Edge cases at verificere:**
1. **Første-tab-besøg:** observer fyrer, sætter effective_analysis_val til auto_text. pdf_preview_image evaluerer, renderer med auto_text. Klient-roundtrip lander → debounced_analysis invaliderer observer. Observer beregner nyt: user_text=auto_text, auto_text=auto_text → effective=auto_text. Compare with current=auto_text → identical → SKIP reactiveVal-update. pdf_preview_image fyres IKKE. **1 render only.**
2. **Tab-revisit:** updateTextAreaInput skippes (cycle 11). debounced_analysis-input ikke ændret. Observer fyrer ikke. **1 render only.** (samme som nu)
3. **Skift-data-progression:** autogen-observer recomputer → ny auto_text → last_auto_analysis aendrer → observer fyrer → ny effective text → reactiveVal opdateres → pdf_preview_image re-render med NY tekst. **1 render per data-change (korrekt).**
4. **Bruger redigerer manuelt:** debounced_analysis ændres til ny user_text. Observer fyrer → effective=user_text (differer fra auto_text). reactiveVal opdateres. pdf_preview_image render med user-text. **1 render per edit (korrekt).**

**Risiko:**
- Observer kører selv hvis effective ikke ændres — billig (string-compare) men ekstra reactive node
- Initialisering: effective_analysis_val("") starter tom. Hvis pdf_preview_image evaluerer FØR observer har sat værdi første gang, render med "". → workaround: observer-priority HIGH for at fyre før output-rendering

### Option B: bindEvent med ignoreNULL/ignoreInit på debounced_analysis

Brug `shiny::bindEvent` eller `observeEvent(..., ignoreEqual = TRUE)` til at filtrere no-op changes.

```r
pdf_preview_image <- shiny::reactive({
  # ... existing guards ...
}) |> shiny::bindEvent(
  # Kun fyre paa state-derived changes
  app_state$ui$last_auto_analysis,
  app_state$data$current_data,
  input$export_title,
  # ... ej debounced_analysis (forhindrer roundtrip-trigger)
  ignoreNULL = FALSE
)
```

**Risiko:** Kompliceret — bindEvent har ej tail-fired ignoreEqual semantics som metaReactive. Sandsynligvis ej egnet.

### Option C: Acceptér 2 renders i første-besøg (status quo)

Tilbagekald PR #757's Option C-rationale (data-progression) som misvisende. Acceptér 1.5 sek wasted som "lille flicker ved første-besøg, fix sker kun ved revisit".

**Rationale:** Lille perf-impact, undgår ekstra reactive-kompleksitet. Pragmatisk.

---

## D1 [DOC] — Cycle 11 Option C-rationale revision

**Lokation:** `R/mod_export_server.R:376-385`, `docs/reviews/11-export-preview-ineffektivitet.md`

**Symptom:**
Inline-kommentar i mod_export_server.R og review-doc 11's Option C-sektion forklarer 2 renders som "data-progression" (quick feedback + fresh content). Empirisk verificeret at dette KUN gælder ved data-edits mellem renders. Simple-case (rent tab-skift uden edits) har 2 renders med samme tekst = redundans.

**Konsekvens:** Misvisende rationale. Fremtidig dev der ser kommentaren tror behavior er intentional, ej redundans.

**Foreslået fix:**
- Hvis Option A implementeres: fjern hele Option C-rationale-blok (cycle 12 H1 fix elimineret 2. render)
- Hvis Option C bevares: revider tekst til at sondre mellem simple-case (redundans) og data-progression-case

---

## Codex-trigger-decision (Phase 2)

Run Codex YES — trigger-criteria mødt:
- [x] Draft indeholder executable R-snippet (Option A reactiveVal pattern)
- [x] Empirical claim (2 dev-logs viser 2 vs 1 render i forskellige scenarier)
- [x] Severity-vurdering driver implementation (A vs B vs C beslutning)
- [x] Recent failure pattern: cycle 11 H1 fix-recipe blev rejected af Codex pga isolate()-gotcha — risk for samme mønster i cycle 12

Particular Codex focus-asks:
1. **Option A correctness:** Vil `reactiveVal`-diff-check elimere 2. render i første-tab-besøg-scenarie? Verificer Shiny invalidation-semantik for `reactiveVal()`-writes hvor ny værdi er identical med eksisterende.
2. **Observer-ordering:** Kan pdf_preview_image evaluere FØR observer har sat effective_analysis_val første gang? Hvad sker hvis observer er priority MEDIUM/LOW men output renders først?
3. **Race ved tab-skift:** Tab-skift trigger SAMTIDIG autogen-observer (LOW=10) OG effective-analysis-observer (foreslået ny). Hvilken kører først? Hvis autogen kører efter effective-observer, vil effective bruge stale last_auto_analysis = "".
4. **Initialisering-default:** `reactiveVal("")` starter tom. Hvis pdf_preview_image læser før observer sat værdi, render med "". Bør initialiseres til app_state$ui$last_auto_analysis ved server-init?
5. **Cross-tab-state:** Hvis bruger har 2 sessions åbne, deler de samme reactiveVal-instans (per session, så nej — men bekræft).
6. **Alternative pattern:** Findes der enklere Shiny-idiom for "kun invalidér på reel value-change"? `metaReactive`, `observeEvent(ignoreEqual=TRUE)`, eller `reactivePoll`?

---

## Codex adversarial-review konsekvens (2026-05-16 sen)

**Verdict:** needs-attention. Option A korrekt mekanik MEN priority-ordering MANGLER. Option B `ignoreEqual` eksisterer IKKE i Shiny 1.13.0. D1 confirmed.

### Bekraeftet (verified empirisk)

- **H1 problem:** Confirmed via Codex source-inspektion af Shiny 1.13.0 `reactiveVal$set()` — returnerer FOER invalidation hvis `identical(old, new)`. Mekanikken bag Option A er korrekt.
- **D1 problem:** Cycle 11 Option C-rationale misvisende for simple-case. Confirmed.

### Recalibreret

- **Option A priority-ordering:** Codex Shiny 1.13.0 flush-simulation viste at default-priority observer (priority 0) IKKE garanteres at fyre FOER pdf_preview_image output-render. Reproducerede priority-0 fejl-mode: efter autogen opdaterer last_auto_analysis, kan allerede-queued output evaluere FOER min nye observer kører, render med `eff=""`, derefter render igen efter effective_analysis_val sat. **Option A som dokumenteret kan REGRESSE cycle 11 fra "2 identiske renders" til "1 tom + 1 fuld render".**

  **Recalibrering:** Tilfoej eksplicit `priority = OBSERVER_PRIORITIES$PLOT_GENERATION` (600) til observer — mellem autogen (750) og default outputs (0). Garanterer observer kører:
  - EFTER autogen-observer (priority 750) → last_auto_analysis er sat
  - FOER output-rendering (priority 0) → reactiveVal populated foer foerste render

- **Option B dismissed:** `observeEvent(..., ignoreEqual = TRUE)` eksisterer IKKE i Shiny 1.13.0 (formals: `ignoreNULL`, `ignoreInit`, `once`). `bindEvent()` filtrerer trigger-events ej value-equality. Skip Option B fra implementation-paths.

### Verified empirisk (via Codex Shiny simulation)

Codex koerede lokal Shiny flush-simulation med priority-0 observer + output. Reproducerede regression-scenarie hvor priority-0 ordering ej garanteret. Confirms recalibrering noedvendig.

### Laering (ny pattern)

**Reactive-ordering anti-pattern:** `shiny::observe()` uden eksplicit priority = priority 0 = ingen garanti om order vs outputs. Hver gang observer SAETTER state der laeses af outputs, kraever priority > output-priority (default 0). Brug projekt-konvention OBSERVER_PRIORITIES — vaelg level der matcher data-flow-position (STATE_MANAGEMENT > AUTO_DETECT > DATA_PROCESSING > UI_SYNC > PLOT_GENERATION > STATUS_UPDATES).

**Tilfoej til feedback-memory:** `feedback_shiny_observer_priority_ordering.md` — "observers der setter state for downstream outputs SKAL have eksplicit priority > 0 for at fyre foer output-rendering. Default observe() er priority 0 = race med outputs."

---

## Implementation-plan (Phase 5) — POST-RECONCILE

### PR-A: Option A med priority-ordering

**Branch:** `fix/preview-redundans-elimination-cycle-12-h1`

**Scope:**

`R/mod_export_server.R` — Tilfoej reactiveVal-wrap med priority-ordered observer:

```r
# Cycle 12 H1 (Codex 2026-05-16): reactiveVal-diff-check eliminerer
# redundant 2. preview-render i foerste-tab-besoeg. Priority PLOT_GENERATION
# (600) sikrer observer fyrer EFTER autogen (UI_SYNC=750) men FOER outputs
# (default 0).
effective_analysis_val <- shiny::reactiveVal(
  shiny::isolate(app_state$ui$last_auto_analysis %||% "")
)

shiny::observe(
  {
    new_text <- compute_effective_analysis_text(
      user_text = debounced_analysis(),
      auto_text = app_state$ui$last_auto_analysis %||% ""
    )
    current <- shiny::isolate(effective_analysis_val())
    if (!identical(new_text, current)) {
      effective_analysis_val(new_text)
    }
  },
  priority = OBSERVER_PRIORITIES$PLOT_GENERATION
)

# pdf_preview_image:
analysis_input <- effective_analysis_val()
```

`R/mod_export_server.R:386-389` — Erstat compute_effective_analysis_text-inline-kald med `effective_analysis_val()`.

`R/mod_export_server.R:376-385` — Fjern Option C-rationale-blok (cycle 11). Tilfoej cycle 12 referencer.

### PR-B: D1 — Cycle 11 docs revision

Hvis PR-A implementeres: Cycle 11 review-doc Option C-sektion bliver historisk note. Tilfoej "SUPERSEDED af cycle 12" markering.

### Tests

`tests/testthat/test-export-preview-redundans-elimination.R`:
- Test 1: Observer fyrer kun ved reel value-change (mock reactive context, verify reactiveVal-write-count)
- Test 2: effective_analysis_val ikke invalideret ved no-op compute (`identical()`-skip)
- Test 3: priority-ordering pa observer == `OBSERVER_PRIORITIES$PLOT_GENERATION`

Integration-test (manual eller shinytest2): tab-skift fra trin 2 til 3 = **1 preview-render only** (verificeret via log).

### Risiko-vurdering

- ✅ Mekanikken bag Option A er Shiny-source-verified
- ✅ Priority-ordering eliminerer kendt race
- ⚠️ Reactive-chain bliver ÉN ekstra reactive-node (observer + reactiveVal) — minimal overhead
- ⚠️ Initial value: `reactiveVal(isolate(app_state$ui$last_auto_analysis %||% ""))` — hvis last_auto_analysis er NULL ved server-init, starter med "". Observer fyrer ved foerste reactive-cycle og opdaterer. OK.
