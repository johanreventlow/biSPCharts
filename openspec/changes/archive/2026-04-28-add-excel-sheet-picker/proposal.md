## Why

Brugere kan i dag uploade Excel-filer (`.xlsx`, `.xls`), men appen indlæser stiltiende det første ark uanset hvad. Filer med flere relevante ark (fx separate måneder, afdelinger eller datasæt) kan derfor ikke analyseres uden manuel eksport af det rette ark først. Brugerne har bedt om mulighed for selv at vælge ark direkte i appen.

biSPCharts-genererede gem-filer (3 ark: `Data`, `Indstillinger`, `SPC-analyse`) skal fortsat genindlæses automatisk uden ark-valg, da deres struktur er fastlagt af appen selv.

## What Changes

- Ved upload af `.xlsx`/`.xls`-filer detekteres antal ark via `readxl::excel_sheets()`
- Hvis filen er biSPCharts gem-format (Data + Indstillinger findes) → uændret flow (eksisterende `handle_excel_upload()`)
- Hvis filen kun har ét ark → uændret flow (auto-indlæs første ark)
- Hvis filen har ≥ 2 ark og IKKE er biSPCharts-format → ny sheet-picker:
  - Paste-felt forbliver tomt indtil bruger eksplicit vælger ark
  - Dropdown ankret under "Indlæs XLS/CSV"-knappen, samme JS toggle-mønster som eksisterende sample-data-dropdown
  - Items renderes dynamisk ud fra detekterede ark-navne
  - Tomme ark vises grå-ud (ikke deaktiveret) baseret på preflight `n_max=1`-check
  - Notifikation: "Vælg faneblad fra menuen"
- Ny app_state-slot: `app_state$session$pending_excel_upload` holder midlertidig upload-info (datapath, filnavn, ark-navne, empty-flags) indtil bruger har valgt
- Ny observer på `input$selected_excel_sheet` læser valgt ark og fylder paste-feltet via samme tab-separerede formattering som eksisterende multi-ark-fallback

## Capabilities

### New Capabilities

- `excel-import`: Detektion og UI-flow for upload af Excel-filer, inkl. multi-ark sheet-picker og biSPCharts gem-format-genkendelse

### Modified Capabilities

<!-- Ingen — eksisterende session-persistence (gem-format restore) påvirkes ikke direkte; biSPCharts-detektion forbliver identisk -->

## Impact

**Affected code:**

- `R/utils_server_paste_data.R` — udvid multi-sheet-grenen i `direct_file_upload`-observer; ny observer på `input$selected_excel_sheet`
- `R/ui_app_ui.R` — tilføj tom container-div `#excel_sheet_dropdown` under "Indlæs XLS/CSV"-knappen + CSS-klasse (genbrug eller variant af `.sample-data-dropdown`)
- `R/state_management.R` — tilføj `app_state$session$pending_excel_upload` slot
- Nye filer: `R/fct_excel_sheet_detection.R` (pure helpers: `list_excel_sheets()`, `detect_empty_sheets()`, `is_bispchart_excel_format()`)
- Nye tests: `tests/testthat/test-excel-sheet-picker.R` (sheet-detektion, preflight, observer-adfærd via `shiny::testServer()`)

**Dependencies:**

- `readxl` (allerede brugt) — ingen nye runtime-deps
- `shinyjs` (allerede brugt) — JS toggle-mønster genbruges

**Brugerflow påvirkning:**

- Single-sheet Excel: uændret (auto-første-ark)
- biSPCharts gem-format: uændret (auto-restore)
- Multi-sheet standard Excel: nyt eksplicit valg-trin (én ekstra klik)

**Bagudkompatibilitet:**

- Ingen API-ændringer i `parse_excel_file()` — `hints$sheet`-parameter eksisterer allerede
- Eksisterende tests for biSPCharts-format og single-sheet skal fortsat passere
- Sample-dropdown UX uændret
