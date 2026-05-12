## Context

Race-condition observeret i Connect Cloud 2026-05-12. SPC-plot viser empty-state efter ny data-upload indtil bruger åbner "Tildel kolonner"-modal (workaround).

**Pipeline-flow ved upload (pre-fix):**

```
upload → apply_state_transition(transition_upload_to_ready)  # resetter mappings
       → emit$auto_detection_started
       → autodetect_engine → apply_state_transition(transition_autodetect_complete)
            # ← skriver app_state$columns$mappings synkront her
       → emit$ui_sync_needed
            # ← throttled 250ms via shiny::throttle()
       → sync_ui_with_columns_unified
            # ← updateSelectizeInput(input$x_column, ...) — server-side
       → [Shiny flush til klient — async]
       → input$x_column = ny værdi
```

**Plot-pipeline kører parallelt:**

```
module_data_reactive (invalideret ved data-ændring)
  → chart_config_raw (debounce 150ms)
       → column_config()
            → manual_config()  # læser input$x_column DIREKTE
            → build_visualization_config(data = NULL, user_overrides = manual_cfg, ...)
                 # data=NULL skipper validation; manual vinder picker
       → create_chart_config_reactive  # validerer mod data, strips manglende y_col → NULL
  → spc_inputs (debounce 500ms)
  → spc_results
  → spc_plot
```

Vinder-race: hvis plot evalueres FØR throttled ui_sync flushed input til klient, læser `manual_config()` stale input fra forrige session → manual y_col matcher ikke nye kolonnenavne → chart_config returnerer NULL → empty plot.

**Codex-recalibreret konstatering (verified 2026-05-12):**

`emit$ui_sync_completed()` i `R/utils_server_events_ui.R:65` fyrer **lige efter** `sync_ui_with_columns_unified` server-side, **før** browser-roundtrip. Counter-baseret gating på `ui_sync_completed` (foreslået "Option A") er IKKE pålideligt — slipper stadig stale `input$<col>` gennem.

## Goals / Non-Goals

**Goals:**

- Eliminer race-window mellem auto-detect og plot-render.
- Bevar bruger-edits via dropdown (`input$<col>` → `app_state$columns$mappings$<col>` write-back er allerede etableret i `handle_column_input`).
- Cut input-roundtrip-afhængighed for chart-config-konstruktion.
- Fjern dead-code uden at bryde modal-workaround utilsigtet.
- Tilføj regression-test der ville have fanget pre-fix-bug.

**Non-Goals:**

- Refaktorering af throttle-værdier (250ms, 150ms, 500ms) — orthogonalt.
- Splittelse af `column_changed`-context i cache-invalidation (separate issue M1).
- Cleanup af duplicate auto-detect-flow i `new_session` (separate issue M2).
- Logging-format-cleanup (L1).
- Paste-parser header-detektion (L2).
- Implementér modal_column_mapping_active-guard (bryder modal-commits — fjern dead-code i stedet).

## Decisions

### Decision 1: `column_config` primær-kilde = `app_state$columns$mappings`

`column_config` reactive i `R/utils_server_visualization.R:62-126` omskrives. Pre-fix læser den `input$<col>` via `manual_config()` som **primær** + falder tilbage til auto-detect/mappings. Post-fix læser den `app_state$columns$mappings$<col>` direkte som primær.

**Rationale:**

- Auto-detect skriver `app_state$columns$mappings` **synkront** før `emit$ui_sync_needed` fyrer. State er altid frisk på plot-evaluation-tidspunkt.
- `handle_column_input` (`R/utils_server_column_input.R:65-122`) skriver bruger-edits fra `input$<col>` tilbage til `app_state$columns$mappings$<col>` ved hver dropdown-change. Bruger-edits propagerer derfor uden ekstra code-path.
- Single source of truth: `app_state$columns$mappings` bliver kanonisk for chart-config.
- Eliminerer "Codex Option A"-problem: ingen afhængighed af klient-roundtrip-bekræftelse.

**Alternativer overvejet:**

- *Gate på `ui_sync_completed`-counter:* Afvist — Codex-verified: counter fyrer pre-flush, slipper stadig stale input (`R/utils_server_events_ui.R:65`).
- *Drop throttle på initial sync efter `auto_detection_completed`:* Mindre invasive change men løser kun ét trigger-flow (upload); andre flows (session-restore, paste-data) ville stadig race. State-derived er general løsning.
- *Reactive der sammenligner input mod mappings og venter på match:* Mere kompleks, mere reactive-overhead, samme problem skaleret.

### Decision 2: Fjern dead `modal_column_mapping_active`-guard

`R/utils_server_column_input.R:75-78` og `R/utils_server_events_chart.R:386-388` checker `app_state$ui$modal_column_mapping_active`-flag som aldrig sættes (0 settere via `rg`).

**Rationale (Codex-verified):**

- Implementér som broad-guard (set TRUE ved modal-open, FALSE ved close) ville **bryde modal-commits**: modal-felter genbruger main UI input-IDs (`R/utils_ui_app_layout.R:617-663` — `modal_select("x_column", ...)` osv.). Ingen separat Save-knap. Bruger-selektioner inde i modal commit'es via samme observer guard'en ville skip.
- "Tildel kolonner"-modal er nuværende workaround for race; broad-guard ville faktisk forværre UX.
- Decision 1 fjerner race-need for workaround → guard er ej kun dead, men også utiltænkt.

**Alternativer overvejet:**

- *Implementér time-window-guard (release efter onFlushed):* Kompleks. Ikke nødvendigt når Decision 1 fjerner underliggende race.
- *Separate modal input-IDs + explicit commit-knap:* Større UX-redesign. Out of scope.

### Decision 3: Test reproducerer race via timing-kontrolleret cascade

Ny `tests/testthat/test-upload-race-state-derived.R` bruger `shinytest2` til at:

1. Indlæs dataset A med kolonner `["Dato", "Tal"]` → vælg `x=Dato, y=Tal`.
2. Verificer plot renders korrekt.
3. Upload dataset B med kolonner `["Uge", "Værdi"]`.
4. Inspicer plot **FØR** ui_sync-throttle-window er udløbet (eller med deterministisk throttle-mock).
5. Pre-fix: plot empty-state vises.
6. Post-fix: plot renders med autodetekteret config fra dataset B.

Test SHALL fail pre-fix og pass post-fix.

**Alternativer overvejet:**

- *Unit-test af `column_config`-reactive isoleret:* For fragil — reactive-context kræves. Shiny-integration er bedste niveau.
- *Pure-function-test af nye state-source-logik:* Tilføjes som komplement, men hovedregression-coverage er Shiny-test.

## Risks / Trade-offs

**Risk:** `app_state$columns$mappings` kunne være stale hvis auto-detect ikke kører (fx ved manual session-create uden upload).
→ **Mitigation:** `transition_upload_to_ready` resetter `auto_detect.completed = FALSE`; `column_config` håndterer mappings = NULL fallback gracefully (returner NULL → empty-state med passende besked).

**Risk:** Bruger-edit via dropdown skriver til `app_state$columns$mappings` via `handle_column_input` — der er guard-check `if (isTRUE(modal_column_mapping_active)) return()`. Hvis Decision 2 fjerner guard, fungerer write-back. Hvis vi beholder guard, virker write-back ikke alligevel (dead flag).
→ **Mitigation:** Decision 2 fjerner guard. Behold `handle_column_input`-write-back-path.

**Risk:** Eksisterende tests kunne fejle hvis de mocker `input$<col>` for column_config-test.
→ **Mitigation:** Søg `tests/` for `input\$x_column.*column_config` patterns. Opdater til mock af `app_state$columns$mappings$x_column` i stedet.

**Risk:** Performance — `app_state$columns$mappings` er reactive; flere reactive dependencies kan øge invalidation-kæder.
→ **Mitigation:** `column_config` er allerede afhængig af `app_state$columns$auto_detect$results` (via current path). At skifte til `mappings` er sideways move. Eksisterende debounce-pipeline (150ms + 500ms) absorberer extra invalidations.

**Trade-off:** State-derived chart-config kobler plot-render tættere til `app_state$columns$mappings`. Hvis `handle_column_input` har en bug der ikke skriver bruger-edit til state, mister bruger graf-response. Acceptabel: write-back er allerede etableret og test-dækket.

## Migration Plan

Ej breaking — ingen public R-API ændring, ingen UI-flow-ændring. Single PR + Shiny-test.

**Trinvis:**

1. Skriv failing Shiny-test for race (TDD).
2. Implementér Decision 1 (omskriv `column_config`).
3. Verificer test passer.
4. Implementér Decision 2 (fjern dead-guard) som separat commit i samme PR.
5. Manual rygtest: upload nyt datasæt → plot renderes uden modal-tryk.
6. Merge til develop, deploy via standard Connect Cloud-flow.

**Rollback:**

Single revert af PR — `column_config` falder tilbage til input-driven. Modal-workaround stadig tilgængelig (fungerer pga dead guard).

## Open Questions

Ingen åbne — fix-retning empirisk verificeret + Codex-recalibreret.
