## 1. Regression-test først (TDD)

- [x] 1.1 Identificér eksisterende shinytest2-fixtures der kan genbruges (`tests/testthat/test-app-*` osv.) — N/A, brugte pure-function-test
- [x] 1.2 Opret `tests/testthat/test-upload-race-state-derived.R` med fixture for to datasæt (A: `Dato,Tal`; B: `Uge,Værdi`)
- [x] 1.3 Skriv test-scenario: load A → vælg kolonner → upload B → assert plot renderes med autodetekteret B-config (ikke empty-state) — implementeret som pure-funktion-test af `resolve_chart_config_state_first()`
- [x] 1.4 Verificér test FEJLER på nuværende kodebase (pre-fix) — verificeret: 8 FAIL inden helper-implementation
- [ ] 1.5 Tilføj entry i `dev/audit-output/test-classification.yaml` (manual entry — automatisk regen dropper nye entries)

## 2. Implementér state-derived column_config

- [x] 2.1 Læs `R/utils_server_visualization.R:46-126` for fuld kontekst af `manual_config()` + `column_config()`
- [x] 2.2 Omskriv `column_config()` (linje 62-126) til at læse `app_state$columns$mappings$<col>` som primær kilde via ny `resolve_chart_config_state_first()` helper
- [x] 2.3 Fjern `manual_config()`-reactive hvis ingen andre callers (verificér via `rg "manual_config\(" R/`) — fjernet, 0 callers tilbage
- [x] 2.4 Behold `chart_type`-source fra `input$chart_type` (orthogonal til kolonne-race)
- [x] 2.5 Behold session-restore-special-case (linje 71-81) — `app_state$columns$mappings$chart_type` er allerede state-derived
- [x] 2.6 Kør `devtools::load_all(); devtools::test(filter = "upload-race")` — test fra 1.4 SKAL nu passe — 16/16 pass

## 3. Fjern dead modal-guard

- [x] 3.1 Fjern `if (isTRUE(shiny::isolate(app_state$ui$modal_column_mapping_active))) return(invisible(NULL))` fra `R/utils_server_column_input.R:75-78`
- [x] 3.2 Fjern tilsvarende check fra `R/utils_server_events_chart.R:386-388`
- [x] 3.3 Verificér via `rg "modal_column_mapping_active" R/` — resultat skal være tomt — verificeret 0 hits
- [x] 3.4 Hvis flag eksisterer i `R/state_management.R`'s `app_state$ui`-init, fjern den derfra også (verificér via grep) — ej i state_management.R, kun reads (nu fjernet)

## 4. Regression-verifikation

- [x] 4.1 Kør fuld test-suite: `devtools::test()` — alle eksisterende tests skal passere — 226 success, 0 failed, 0 error
- [ ] 4.2 Manual rygtest: start app, upload nyt datasæt → plot skal renderes uden modal-tryk
- [ ] 4.3 Manual rygtest: skift kolonner via dropdown → plot opdateres
- [ ] 4.4 Manual rygtest: åbn "Tildel kolonner"-modal, vælg ny kolonne → plot opdateres efter modal-luk
- [ ] 4.5 Kør `R CMD check` på package — skal være clean
- [ ] 4.6 Kør `lintr::lint_dir("R/")` — ingen nye lint-warnings

## 5. Dokumentation + commit

- [ ] 5.1 Opdater inline-kommentarer i `R/utils_server_visualization.R` der referer til "manual_config" eller "input vinder"
- [ ] 5.2 Skriv NEWS.md-entry under `## Bug fixes`: dansk beskrivelse + reference til issue (oprettes ved /opsx:propose-step)
- [ ] 5.3 Commit Decision 1 (state-derived) som atomic commit
- [ ] 5.4 Commit Decision 2 (fjern dead-guard) som separat atomic commit
- [ ] 5.5 Opret draft PR mod develop med titel "fix(visualization): state-derived chart-config eliminates upload race (#issue)"
- [ ] 5.6 Reference `docs/reviews/10-upload-race.md` + Codex-recalibrering i PR-body

## 6. Audit-trail (post-merge)

- [ ] 6.1 Opdater `docs/reviews/README.md` tracker-tabel med Cycle 10 status
- [ ] 6.2 Tilføj læring til README "Læringer"-sektion: emit-timing distinguishes server-side completion fra client-flush
- [ ] 6.3 Tilføj memory-entry i `~/.claude/projects/.../memory/` om dual-state-source-pattern (state primær, input write-back)
- [ ] 6.4 Arkivér change via `/opsx:archive fix-upload-race-state-derived-config`
