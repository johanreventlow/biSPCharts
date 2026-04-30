## 1. Audit (FÆRDIG 2026-04-30)

- [x] 1.1 `grep -rn "pending_programmatic_inputs\|programmatic_token_counter\|queued_updates" R/ tests/` — kortlæg alle referencer (39+22 linjer fundet)
- [x] 1.2 Identificér producenter for hvert felt — `pending_programmatic_inputs`+`programmatic_token_counter` har INGEN produktionsproducenter; `queued_updates` aktivt brugt af queue-system
- [x] 1.3 Verificér via git log — producent for `pending_programmatic_inputs` introduceret i `216acec5`, fjernet i senere refaktor uden consumer-cleanup

## 2. Slet dead state fra app_state$ui

- [x] 2.1 Fjern `pending_programmatic_inputs = list()` fra `R/state_management.R:221`
- [x] 2.2 Fjern `programmatic_token_counter = 0L` fra `R/state_management.R:222`
- [x] 2.3 Tilføj kommentar der dokumenterer `queued_updates` som legitim session-global queue (bibeholdes)
- [x] 2.4 Verificér at `app_state$ui` stadig initialiseres korrekt (Shiny reactiveValues ej har orphan-felter)

## 3. Ryd observer-bodies

- [x] 3.1 `R/utils_server_events_chart.R:117-119` — fjern chart_type pending_token-check
- [x] 3.2 `R/utils_server_events_chart.R:177-181` — fjern y_axis_unit pending_token-check (incl. early-return)
- [x] 3.3 `R/utils_server_events_chart.R:287-291` — fjern n_column pending_token-check (incl. early-return)
- [x] 3.4 `R/utils_server_column_input.R:86-90` — fjern col_name pending_token-check
- [x] 3.5 Verificér at observer-logic stadig respekterer `app_state$ui$updating_programmatically`-guard hvor relevant (eksisterer i n_column-observer)

## 4. Test-cleanup

- [x] 4.1 Slet `tests/testthat/test-ui-token-management.R` (kun plumbing-tests af dead state)
- [x] 4.2 Fjern `pending_programmatic_inputs` + `programmatic_token_counter` fra `tests/testthat/helper-fixtures.R`
- [x] 4.3 Fjern referencer i `tests/testthat/test-event-system-observers.R` (2 linjer + omdøb test der havde misvisende navn)
- [x] 4.4 Fjern referencer i `tests/testthat/test-column-observer-consolidation.R` (slet dead-state-test + ryd 4 fixtures)
- [x] 4.5 Fjern reference i `tests/testthat/test-mod-spc-chart-comprehensive.R:199`
- [x] 4.6 Verificér at fjernelse ikke bryder test-fixture-shape (felter må ikke længere initialiseres, men `queued_updates` bibeholdes hvor relevant)

## 5. Validering

- [x] 5.1 `grep -rn "pending_programmatic_inputs\|programmatic_token_counter" R/` returnerer tomt
- [x] 5.2 `grep -rn "pending_programmatic_inputs\|programmatic_token_counter" tests/` returnerer tomt
- [x] 5.3 `devtools::test()` — fuld test-suite grøn (5544 PASS, 1 unrelated flaky perf-fail)
- [ ] 5.4 Manuel test: chart-type-skift + kolonne-mapping virker uændret (programmatisk UI-update via `safe_programmatic_ui_update()` + `queued_updates`-queue stadig aktiv) — DEFERRED til user
- [x] 5.5 `openspec validate extract-ui-tokens-to-observer-env --strict`

## 6. Release

- [ ] 6.1 PR til develop fra `feat/extract-ui-tokens-to-observer-env`
- [ ] 6.2 NEWS.md entry (interne ændringer): "Fjernet dead token-tracking-state fra `app_state$ui`"
- [ ] 6.3 CI grøn
- [ ] 6.4 Merge
