## ADDED Requirements

### Requirement: chart-config SHALL derive kolonne-valg fra app_state mappings primært

`column_config` reactive i `R/utils_server_visualization.R` SHALL bruge `app_state$columns$mappings$<col>` som primær kilde for kolonne-valg (x_col, y_col, n_col) ved konstruktion af `VisualizationConfig`. `input$<col>`-værdier SHALL ikke læses direkte fra `manual_config()` ved chart-config-konstruktion.

Bruger-edits via dropdown propagerer fortsat til chart-config via etableret write-back-flow: `input$<col>`-observer (`R/utils_server_column_input.R::handle_column_input`) skriver til `app_state$columns$mappings$<col>` → `column_config` reactive invalideres → ny chart-config konstrueres.

#### Scenario: Ny data-upload med stale input-værdi

- **GIVEN** bruger har aktiv session med `input$x_column = "Dato"` fra forrige dataset
- **AND** ny data-upload indeholder kolonner `["Uge", "Værdi"]` (ingen "Dato")
- **AND** auto-detect har sat `app_state$columns$mappings$x_column = "Uge"`
- **WHEN** plot-render-pipeline evaluerer `column_config()` FØR `updateSelectizeInput` har flushed til klient
- **THEN** chart-config bygges med x_col = "Uge" (fra app_state-mappings)
- **AND** plot renderes uden empty-state
- **AND** ingen afhængighed af `input$x_column`-klient-roundtrip-timing

#### Scenario: Bruger-edit via dropdown opdaterer chart

- **GIVEN** plot renderer korrekt med x_col = "Uge"
- **WHEN** bruger vælger "Måned" i x_column-dropdown
- **THEN** `handle_column_input` skriver `app_state$columns$mappings$x_column = "Måned"`
- **AND** `column_config` reactive invalideres
- **AND** plot re-renderes med x_col = "Måned"

#### Scenario: Session uden auto-detect-resultat

- **GIVEN** session er startet uden data-upload
- **AND** `app_state$columns$mappings$y_column` er NULL eller ""
- **WHEN** `column_config()` evalueres
- **THEN** returnerer NULL gracefully
- **AND** plot viser empty-state-besked "Vælg en numerisk Y-akse-kolonne"
- **AND** ingen reactive-error eller exception

### Requirement: Modal-baseret kolonne-mapping skal commit'e via standard input-observer

Modal-dialog "Tildel kolonner" SHALL bruge eksisterende main UI input-IDs (`x_column`, `y_column`, `n_column`, `skift_column`, `frys_column`, `kommentar_column`). Selectize-init i modal SHALL trigge column-input-observers (`handle_column_input`) der opdaterer `app_state$columns$mappings`.

Ingen broad observer-guard (fx `modal_column_mapping_active`-flag) må suppress observers under modal-åbning. Modal-felter er funktionelt live inputs uden separat commit-knap.

#### Scenario: Modal-åbning re-synker stale state

- **GIVEN** `app_state$columns$mappings$x_column = "Uge"` (autodetekteret)
- **AND** `input$x_column = "Dato"` (stale fra forrige session, throttle endnu ej flushed)
- **WHEN** bruger trykker "Tildel kolonner"
- **THEN** modal åbner med selectize-felter pre-fyldt fra `app_state$columns$mappings`
- **AND** selectize-init emitter `input$x_column = "Uge"`
- **AND** `handle_column_input` skriver mapping (no-op hvis værdi uændret)
- **AND** plot opdateres til at vise korrekt data

#### Scenario: Bruger-selektion i modal commit'es

- **GIVEN** modal er åben
- **WHEN** bruger vælger "Måned" i modal's x_column-dropdown
- **THEN** `input$x_column = "Måned"` emittes
- **AND** `handle_column_input` skriver `app_state$columns$mappings$x_column = "Måned"`
- **AND** efter modal-luk vises plot med ny mapping
- **AND** ingen ekstra "Save"- eller "Commit"-knap krævet

### Requirement: Dead modal-pause-guard SHALL fjernes

`app_state$ui$modal_column_mapping_active`-flag SHALL ikke eksistere som check-point i observer-flow. Eksisterende reads i `R/utils_server_column_input.R:75-78` og `R/utils_server_events_chart.R:386-388` SHALL fjernes.

Rationale: flag har ingen producent (0 settere verificeret via `rg "modal_column_mapping_active\s*(<-|=)"`). Implementering som broad-guard ville bryde "Tildel kolonner"-modalens kommit-flow (samme input-IDs deles mellem main UI og modal).

#### Scenario: Audit-grep returnerer tomt efter cleanup

- **WHEN** `rg "modal_column_mapping_active" R/` kører efter cleanup
- **THEN** resultatet SHALL være tomt
- **AND** ingen orphan-state-felter i `R/state_management.R`'s `app_state$ui`-definition

### Requirement: Regression-test SHALL reproducere race pre-fix

`tests/testthat/test-upload-race-state-derived.R` SHALL teste at plot renderes korrekt umiddelbart efter data-upload, uden afhængighed af throttled UI-sync.

Test SHALL fejle hvis `column_config` regredierer til input-primær kilde.

#### Scenario: Plot renders med autodetekteret config efter upload

- **GIVEN** Shiny-test-app med dataset A indlæst (x = "Dato", y = "Tal")
- **AND** plot er renderet korrekt med initial config
- **WHEN** dataset B uploades med kolonner ["Uge", "Værdi"]
- **AND** test inspicerer plot output før throttle-window (250ms) er udløbet
- **THEN** plot output viser SPC-render med x_col = "Uge", y_col = "Værdi"
- **AND** ingen empty-state-besked ("Diagrammet kunne ikke genereres") observeres
