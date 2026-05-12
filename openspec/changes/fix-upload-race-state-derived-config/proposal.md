## Why

Efter ny data-upload viser SPC-plot empty-state ("Diagrammet kunne ikke genereres") indtil bruger åbner "Tildel kolonner"-modal som workaround. Race-condition mellem auto-detect (skriver til `app_state$columns$mappings`) og throttled UI-sync (250ms før `updateSelectizeInput` opdaterer `input$x_column` etc.): SPC-render-pipeline læser `input$<col>` direkte via `manual_config()` i `R/utils_server_visualization.R`, så plot kan render med stale input-værdier fra forrige session (kolonnenavne der ej findes i nyt data) → chart_config strips manglende y_col → return NULL → empty plot.

Bekræftet UX-bug i Connect Cloud (bruger-observation 2026-05-12). Modal-workaround er fragil (afhænger af dead modal-guard) og forværrer first-impression for nye brugere.

## What Changes

- `column_config` i `R/utils_server_visualization.R` SKAL skifte primær-kilde fra `input$<col>` til `app_state$columns$mappings$<col>`. Auto-detect skriver mappings synkront FØR ui_sync emittes — state-derived config er altid frisk på plot-render-tidspunkt.
- Input-observere (`R/utils_server_column_input.R::handle_column_input`) skriver bruger-edits tilbage til `app_state$columns$mappings` (eksisterende adfærd bibeholdes — ingen breaking change).
- Dead modal-guard `app_state$ui$modal_column_mapping_active` fjernes fra `R/utils_server_column_input.R:75-78` + `R/utils_server_events_chart.R:386`. 0 settere verificeret via `rg`. Broad-guard-implementation ville bryde modal-commits (modal-felter genbruger main UI input-IDs).
- Ny Shiny-test reproducerer race (stale input + ny data-upload + tidsmålt cascade), fejler pre-fix, passer post-fix.

Ingen breaking changes for brugere. Ingen ændring til public R-API.

## Capabilities

### New Capabilities

- `chart-config-state-source`: Definerer state-derived chart-config-konstruktion: `column_config` reactive læser primært fra `app_state$columns$mappings` (single source of truth), med `input$<col>` som sekundær for bruger-edits via observer-write-back. Eliminerer input-roundtrip-race ved data-load.

### Modified Capabilities

Ingen — nye `chart-config-state-source` capability er additiv. Eksisterende capabilities (`ui-update-service`, `spc-facade`, `session-persistence`) berøres ej på spec-niveau.

## Impact

**Berørt kode:**
- `R/utils_server_visualization.R` — `column_config` reactive omskrives (~30 linjer)
- `R/utils_server_column_input.R` — fjern dead guard L75-78
- `R/utils_server_events_chart.R` — fjern dead guard L386

**Berørt test-coverage:**
- Ny `tests/testthat/test-upload-race-state-derived.R` — Shiny-test for race
- Eksisterende `tests/testthat/test-utils_server_visualization*.R` — verificer ingen regression

**Risk:**
- Lav: state-derived path er allerede fallback i `build_visualization_config` (linje 53 i `R/fct_visualization_config_pure.R`). Promotion til primær reducerer fragilitet.
- Backward-kompatibilitet: bruger-edits via input bevares fordi `handle_column_input` allerede skriver til mappings (ingen ny adfærd kræves).

**Ude af scope (separate issues):**
- M1 `column_changed`-context-split i cache-invalidation
- M2 duplicate auto-detect ved new_session
- L1 malformede log-details
- L2 paste-data header-detektion

## Related

- Review-doc: `docs/reviews/10-upload-race.md` (Cycle 10, dual-review 2026-05-12)
- Codex adversarial-review: `/tmp/codex-cycle-10.txt`
- Origin observation: Bruger-test på Connect Cloud 2026-05-12
