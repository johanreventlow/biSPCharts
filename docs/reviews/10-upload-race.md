# Cycle 10 — Upload-race: tom graf efter ny data-upload

**Dato:** 2026-05-12
**Trigger:** Bruger-observation på Connect Cloud: ny data-upload viste tom graf + manglende Anhøj-regler indtil bruger trykte "Tildel kolonner"-knap.
**Område:** Reactive-state-sync mellem auto-detect og selectizeInput; SPC-render-pipeline.

---

## Sammenfatning

Race-condition mellem auto-detect (sætter `app_state$columns$mappings`) og throttled UI-sync (250ms før `updateSelectizeInput` fyrer). SPC-render-pipeline læser `input$x_column` etc. DIREKTE via `manual_config()` i `utils_server_visualization.R:46-59` — pre-sync læser pipeline stale input-værdier fra forrige session.

"Tildel kolonner"-modal omgår race ved at åbne selectizeInputs med pre-fyldte `app_state$columns$mappings`-værdier → selectize-init-event triggerer column-observere → `handle_column_input` opdaterer state + invaliderer cache → plot re-renderer korrekt.

Modal-guard (`app_state$ui$modal_column_mapping_active`) er **dead code** — flag tjekkes 2 steder men sættes aldrig. Tilfældigt heldigt: hvis guard var aktiv, ville workaround-fixet ikke virke.

---

## H1 [HIGH] — Race auto-detect vs UI-sync efter upload (tom graf)

**Lokation:** `R/utils_server_events_ui.R:33-68`, `R/utils_server_visualization.R:46-59`, `R/mod_spc_chart_config.R:61-78`

**Symptom:** Efter ny upload med data der har andre kolonnenavne end forrige session, viser plot empty-state ("Diagrammet kunne ikke genereres") indtil bruger åbner "Tildel kolonner"-modal.

**Verifikation:**

Pipeline-rækkefølge ved upload:
1. `apply_state_transition(transition_upload_to_ready)` — resetter mappings
2. `emit$auto_detection_started` → `autodetect_engine` → `apply_state_transition(transition_autodetect_complete)` — sætter nye mappings i app_state
3. `emit$ui_sync_needed` → **throttled 250ms** (`R/utils_server_events_ui.R:33-38`):

```r
throttled_ui_sync <- shiny::throttle(
  shiny::reactive({
    app_state$events$ui_sync_requested
  }),
  millis = 250
)
```

4. `sync_ui_with_columns_unified` kalder `updateSelectizeInput` for hver `input$<col>` — først 250ms+ efter event-emit

**Imens** kører plot-pipeline parallelt — invalideret af data-ændring (ej input-ændring):
- `manual_config()` (`R/utils_server_visualization.R:46-59`) læser `input$x_column` direkte:

```r
x_col <- sanitize_selection(input$x_column)
y_col <- sanitize_selection(input$y_column)
n_col <- sanitize_selection(input$n_column)
```

- `column_config()` (`R/utils_server_visualization.R:98-113`) kalder `build_visualization_config(data = NULL, ...)` — **data=NULL skipper validation** → stale manual-værdi vinder picker:

```r
cfg <- build_visualization_config(
  data = NULL, # kolonne-validering sker i render-laget
  autodetect = autodetect_for_config,
  user_overrides = list(
    x_col = manual_cfg$x_col,
    y_col = manual_cfg$y_col,
    ...
  )
)
```

- `create_chart_config_reactive()` (`R/mod_spc_chart_config.R:62-78`) validerer mod data — strips ej-eksisterende kolonner til NULL, returner NULL hvis y_col ej i data:

```r
if (!is.null(config$y_col) && !(config$y_col %in% names(data))) {
  config$y_col <- NULL
}
...
if (is.null(config$y_col) || !(config$y_col %in% names(data))) {
  return(NULL)
}
```

- `spc_plot()` returner NULL → empty-state vises (`R/mod_spc_chart_server.R:186-205`).

**Konsekvens:** Tom graf + ingen Anhøj-regler indtil:
- UI-sync throttle udløber + chart_config-debounce (150ms) + spc_inputs-debounce (500ms) cyklus genstartes — total ~900ms+
- ELLER bruger trykker "Tildel kolonner" → modal-init triggerer column-observere → input opdateres synkront

**Måling:** Loggen viser plot rendres ved 10:41:46 og 10:43:45 (export_pdf-trigger) med n_points=49 OG ved 10:44:02 (analysis context) — så plot virker når data og input stemmer. Bruger-observerede tom-graf-window er sandsynligvis mellem auto-detect-completion og throttle-expiry.

**Foreslået fix (Option A — anbefalet):**

Gate plot på `app_state$events$ui_sync_completed` i `create_spc_inputs_reactive` for at sikre input-værdier er flushed før render. Tilføj `shiny::req()` der watcher `ui_sync_completed`-counter til at have inkrementeret efter sidste `data_updated`-event.

**Foreslået fix (Option B):**

Drop throttle på initial sync efter `auto_detection_completed`. Throttle giver kun mening for rapid repeat-events; første sync efter auto-detect skal være synkron.

```r
# I auto_detection_completed observer:
sync_ui_with_columns_unified(app_state, input, output, session, ui_service)  # synkron
emit$ui_sync_completed()  # ej throttled
```

---

## H2 [HIGH] — Dead modal-guard (`modal_column_mapping_active`)

**Lokation:** `R/utils_server_column_input.R:75-78`, `R/utils_server_events_chart.R:386`

**Symptom:** Modal-guard-flag tjekkes 2 steder men sættes aldrig. Effekt: programmatic updates ved modal-åbning kører gennem column-observere uden guard.

**Verifikation:**

`R/utils_server_column_input.R:75-78`:

```r
if (isTRUE(shiny::isolate(app_state$ui$modal_column_mapping_active))) {
  # Modal is open - skip all observer logic
  return(invisible(NULL))
}
```

Grep-verifikation:
```
$ grep -rn "modal_column_mapping_active" R/
R/utils_server_column_input.R:75:    (read)
R/utils_server_events_chart.R:386: (read)
```

Ingen setter — flag forbliver NULL/FALSE. Guard er **dead code**.

**Tilfældig konsekvens:** Det er årsagen til at "Tildel kolonner"-modal-åbning fixer H1-race-bug. Hvis guard implementeres uden H1-fix, **bryder workaround** og bruger har ingen escape-hatch.

**Foreslået fix:**

To muligheder afhænger af intent:

(a) **Fjern dead-code** hvis modal-pause-design er forladt. Behold ej-fungerende guards giver false-confidence.

(b) **Implementér** ved `show_column_mapping_modal()` (set TRUE før show, FALSE i modal-close-callback). MEN: dette KRÆVER H1-fix først, ellers ryger workaround.

Anbefalet rækkefølge: Fix H1 → implementér H2(b) korrekt, eller fjern H2-guards helt.

---

## M1 [MEDIUM] — `column_changed`-context mangler i cache-invalidation-known-list

**Lokation:** `R/utils_qic_cache_invalidation.R:73-104`

**Symptom:** 28x `WARN: [QIC_CACHE] Unknown update context - clearing cache conservatively: column_changed` på 16 sekunder (10:42:29-10:42:45) — ramt af add-row-handler-spam.

**Verifikation:**

`R/utils_qic_cache_invalidation.R:73-104` definerer kendte contexts:

```r
structural_changes <- c(
  "upload", "column_added", "column_removed",
  "load", "new", "file_upload",
  "paste_data", "session_file_loaded",
  "new_session", "session_restore"
)
...
value_changes <- c(
  "table_cells_edited", "value_change",
  "edit", "modify", "change"
)
```

`column_changed` ej i nogen liste → falder til fallback (linje 169-188) → conservative full clear.

Emit-sites:
- `R/utils_server_column_management.R:185` (confirm_column_names)
- `R/utils_server_column_management.R:281` (handle_add_column)
- `R/utils_server_column_management.R:469` (add_row)

**Konsekvens:** Funktionelt korrekt (cache cleares), men:
- Log-støj (WARN-level, 28x på 16s)
- Mister selektiv prefix-invalidation-mulighed (full clear i stedet for spc_<chart_type>_-prefix)

**Foreslået fix:**

Klassificér `column_changed` korrekt baseret på emit-kontekst:
- `add_row` (data-shape unchanged, kun nye NA-rows) → **cosmetic/value_change** — selektiv prefix-clear
- `add_column` / rename → **structural** — full clear

Splittes til to contexts: `row_added` (value_change-bucket) + `column_added` (allerede i structural list).

---

## M2 [MEDIUM] — Duplicate auto-detect ved new_session

**Lokation:** `R/utils_server_server_management.R:589, 664`

**Symptom:** `[AUTO_DETECT_CACHE] Auto-detection completed and cached` logget 2x i samme sekund (10:42:25).

**Verifikation:**

```r
# Linje 589:
emit$data_updated(context = "new_session")  # cascade → auto_detection_started → autodetect_engine(trigger_type="file_upload")

# Linje 664:
autodetect_result <- autodetect_engine(
  data = new_data,
  trigger_type = "session_start", # Session reset behandles som ny session start
  app_state = app_state,
  emit = emit
)
```

Begge kører for samme dataset.

**Konsekvens:** ~50-100ms ekstra arbejde per session-reset. Ikke kritisk men dead-effort.

**Foreslået fix:** Fjern direct-call (linje 664). Lad cascade håndtere auto-detect.

---

## L1 [LOW] — Malformede `[FILE_UPLOAD_FLOW]` log-details

**Lokation:** `R/fct_file_validation.R:596-604`

**Symptom:** Log-output har duplikerede keys:
```
[FILE_UPLOAD_FLOW] Data preprocessing completed [filename=pasted_data, cleaning_log=TRUE, original_dimensions=48, final_dimensions=3, filename=48, cleaning_log=3, original_dimensions=48, final_dimensions=3, filename=48, cleaning_log=3]
```

**Verifikation:**

```r
log_info("Data preprocessing completed",
  .context = "FILE_UPLOAD_FLOW",
  details = list(
    filename = file_info$name,
    cleaning_log = cleaning_log,
    original_dimensions = original_dims,   # likely c(48, 5)
    final_dimensions = final_dims          # likely c(48, 3)
  )
)
```

Logger flattener vektorer ved at gentage key per element. `cleaning_log` er sandsynligvis list med >1 element.

**Konsekvens:** Debugging-friktion. Ingen UX-impact.

**Foreslået fix:** Pre-collapse vektorer til scalar-strings før details-list:

```r
details = list(
  filename = file_info$name,
  cleaning_log_count = length(cleaning_log),
  original_dimensions = paste(original_dims, collapse = "x"),
  final_dimensions = paste(final_dims, collapse = "x")
)
```

---

## L2 [LOW] — Paste-data header-detektion mis-parser

**Lokation:** Sandsynligvis `R/utils_server_paste_data.R` eller relateret parser.

**Symptom:** Pasted data fik kolonnenavne `Skift, Frys, Uge.17, Column_20, Column_30` ved 10:45:47. "Uge.17" ligner data-værdi der landede som header. `Column_20/30` er auto-genererede fallback-navne for tomme headers.

**Konsekvens:** Bidragyder til broken-upload-UX. Auto-detect kører på dårlige kolonnenavne → mappings sub-optimal.

**Status:** Adskilt fra H1-race. Ej dybt verificeret i denne cycle. Foreslå separat issue + dedikeret review-cycle på paste-parser.

---

## Foreslået implementation-rækkefølge

| Prio | Finding | Recommendation |
|------|---------|----------------|
| **P0** | H1 race | Fix først — kerne UX-bug |
| **P0** | H2 dead-guard | Beslut: implementér efter H1 ELLER fjern dead-code |
| **P1** | M1 column_changed-context | Splittes til row_added + column_added |
| **P2** | M2 duplicate autodetect | Cleanup |
| **P2** | L1 log-format | Logging hygiejne |
| **P3** | L2 paste-parser | Separat cycle |

---

## Codex adversarial-review konsekvens (2026-05-12)

**Verdict:** needs-attention — NO-SHIP for doc som implementation-guide før fix-recipes revideres.

### Bekræftet (verified empirisk)

**H1 stale-input path bekræftet** (men timing-claim over-claimed):
- `manual_config` læser input direkte (`R/utils_server_visualization.R:48-58`)
- `build_visualization_config(data = NULL)` skipper validation, manual vinder picker (`R/utils_server_visualization.R:98-113`)
- `create_chart_config_reactive` strips ej-eksisterende y_col → NULL → empty plot (`R/mod_spc_chart_config.R:61-78`)

Verifikation: kode-citater inspiceret i alle 3 lokationer. Path teknisk reproducerbar.

**H2 dead-guard bekræftet** men forslag bryder modal:
- `modal_column_mapping_active` har 0 settere
- Verifikation: `rg "modal_column_mapping_active\s*(<-|=)" R` = 0 hits. Confirmed.

**L1 log-fix runtime-korrekt** — confirmed.

### Recalibreret (Codex objections med empirisk støtte)

**H1 Option A (gate på `ui_sync_completed`) er IKKE pålidelig fix:**

Reproduktion (verified empirisk i `R/utils_server_events_ui.R:46-65`):

```r
safe_operation(... code = {
  sync_ui_with_columns_unified(...)  # server-side updateSelectizeInput
  ...
})
emit$ui_sync_completed()  # IMMEDIATELY efter — pre-flush
```

`emit$ui_sync_completed()` fyrer **lige efter** `updateSelectizeInput`-server-kald, **før** browser-roundtrip. Counter er ikke bevis for at `input$x_column` er opdateret klient-side. Gate på den counter kan stadig release plot med stale input.

**Recalibreret fix-retning:** Brug **state-derived validated mappings** i stedet for input ved chart-config-konstruktion. To muligheder:

(a) `column_config` skifter kilde fra `input$<col>` til `app_state$columns$mappings$<col>` direkte (auto-detect skriver dertil før ui_sync emittes).

(b) Tilføj reactive der watcher `app_state$columns$mappings` ændringer + sammenligner med input — vent på match.

Option (a) er mere robust: cuts input-roundtrip-afhængighed helt.

**H2 broad-modal-guard breaker modal-commits:**

Verificeret cross-cutting design-issue: modal-felter genbruger main UI input-IDs (`R/utils_ui_app_layout.R:617-663`):

```r
modal_select("x_column", "Tid/kategori (X-akse)", ...)
modal_select("y_column", "Tæller (Y-akse)", ...)
```

Ingen separat Save-knap. User-selektioner i modal commit'es via samme `input$x_column`-observer der ville være skipped af guard.

**Recalibreret fix-retning:**
- Fjern dead-guard ELLER
- Guard kun initial-population (release efter `session$onFlushed`) ELLER
- Separat modal input-IDs + explicit commit-path

**M1 add_row-context er IKKE value_change-bucket:**

Reproduktion (verified `R/mod_spc_chart_state.R:107-113` + `R/mod_spc_chart_inputs.R:203-205`):

```r
# state.R:108
non_empty_rows <- apply(data, 1, function(row) any(!is.na(row)))
if (any(non_empty_rows)) {
  filtered_data <- data[non_empty_rows, ]
  ...
# inputs.R:205
data_hash = digest::digest(data, algo = "xxhash64")  # hash af filtered data
```

`add_row` tilføjer all-NA-row → filteret væk → data_hash uændret → chart-cache **invalideres ikke uanset context**. Sætte til value_change-bucket er stadig unødig cache-churn.

**Recalibreret fix-retning:**
- `column_added`/`column_renamed` → structural (full clear)
- `row_added` → cosmetic eller intet QIC-clear (men stadig data_updated for table/autosave)
- `table_cells_edited` → value (allerede dækket)

**M2 duplicate autodetect-claim er ej empirisk bevist:**

Static-path-analyse viser linje 589 emit + linje 664 direct-call. MEN frozen_state-guard (`R/fct_autodetect_unified.R:108-118`) kan skip cascade-side hvis direct-call sat `frozen_until_next_trigger=TRUE` først. Logget "duplicate" er sandsynligvis 2 separate datasæt (én session_reset + én cascade), ikke ægte dobbeltarbejde.

**Recalibreret fix-retning:** Test først (record trigger_type-kald under `reset_to_empty_session`), så vælg ejer. Ej refactor blindt.

**L2 paste-parser provenance forkert:**

Verificeret (`R/fct_file_validation.R:554-566`): `Column_20`/`Column_30` kommer fra `make.names` + lokal `X→Column_`-rewrite, ej readr empty-name-fallback. Numeriske header-celler (`20`, `30`) → `X20`/`X30` via make.names → `Column_20`/`Column_30` lokalt.

**Recalibreret target:** Header-row-misdetektion (data-row som header), ej empty-headers.

### Recipes der ER runtime-korrekt

| ID | Status |
|----|--------|
| L1 | Log-detail fix — keep |
| H2 fjern-dead-code | Safe — keep som option |

### Impact-bucketing (Codex-saves)

- **Hard runtime-crash saves:** 1 — H2(b)-recipe ville suppress all modal column-input observers → user-selektioner committes ikke → user kan ikke fix kolonner via modal (modsat intent)
- **Semantic / silent-corruption saves:** 1 — Option A gate på `ui_sync_completed` slipper stadig stale input gennem (false-confidence fix)
- **Sub-optimal cleanup:** 2 — M1 row_added-bucket-mis-klassificering, L2 parser-target-misdiagnosis
- **No-impact / cleanup:** L1 (Codex bekræftede uændret)

**Total: 2 high-impact recipe-saves** før H1+H2 ville blive implementeret som beskrevet.

### Læring

**Ny pattern:** *Emit-timing distinguishes server-side completion fra client-roundtrip completion*. Counter-based gates på `ui_sync_completed` falder for præcis dette: emitten fyrer efter `updateSelectizeInput`-kald, ej efter `input$<col>` er flushed til klient og tilbage. Dokumentér i `feedback_emit_timing_vs_client_flush.md`.

**Ny pattern:** *Modal-felter med delt input-ID påvirker observer-guard-design*. Hvis dropdown-IDs deles mellem main-UI og modal-content, kan guards på input-events ikke skelne mellem programmatic-population og user-commit. Skal være enten time-window-guard (release efter flush) eller separate IDs + commit-button.

### Konsekvens for opgaver

**P0 (H1 race):** Recipe **revideres**. Fix skal være state-derived mappings i chart-config (Option a), ej `ui_sync_completed`-gate.

**P0 (H2 dead guard):** Anbefal **fjern dead-code** med mindre projekt har konkret use-case. Implementér aldrig som broad-guard.

**P1 (M1):** Splittes `column_changed` til row_added (no-clear) + column_added (structural). Cache-impact-analyse FØR implementation.

**P2 (M2):** Test først, ej refactor blindt.

**P3 (L2):** Header-row-detektion-fix, ej empty-header-handling.

### Foreslået næste skridt

1. Bruger beslutter scope: separate issues per finding, eller OpenSpec-proposal for race-fix?
2. Hvis race-fix prioriteres: skriv test først der reproducerer race (Shiny test med stale input + ny data + tidsmålt cascade).
3. Implementer state-derived chart-config (Option a) — kompakt fix der eliminerer race-window helt.
