# Design — add-excel-sheet-picker

## Kontekst

Eksisterende Excel-upload-flow i `R/utils_server_paste_data.R:150-216` har tre grene baseret på `readxl::excel_sheets()`:

1. **biSPCharts gem-format** (Data + Indstillinger findes) → `handle_excel_upload()` direkte (gendannelse uden paste-felt)
2. **Standard Excel** → `readxl::read_excel(datapath, col_names=TRUE)` (stiltiende første ark) → tab-formatter til paste-felt
3. **CSV/TXT** → `read_csv_detect_encoding()` → paste-felt

Gren 2 ignorerer ark efter det første. Denne change introducerer eksplicit ark-valg når der er flere relevante ark.

## Designvalg

### Valg 1: Hvor placeres dropdown'en visuelt?

**Valgt: B — dropdown ankret under "Indlæs XLS/CSV"-knappen**

Genbruger samme JS-toggle-mønster som eksisterende sample-data-dropdown (`R/ui_app_ui.R:817-840`). Bruger har bekræftet at dette match foretrukken UX.

Alternativ overvejet: Modal dialog. Forkastet — bryder med eksisterende paste-først UX og introducerer modale blokeringer, som ikke findes andre steder i appen.

Alternativ overvejet: Inline panel mellem knapper og paste-felt. Forkastet — afviger fra etableret dropdown-mønster.

### Valg 2: Auto-preload første ark vs. eksplicit valg?

**Valgt: Y — eksplicit valg, paste-felt forbliver tomt indtil bruger vælger**

Tvinger bevidst valg så bruger ikke ved en fejl analyserer forkert ark. Bruger har bekræftet denne adfærd.

Single-sheet og biSPCharts-format-flows er uændrede — auto-load gælder fortsat for dem.

### Valg 3: Berig ark-navne med metadata (række-tæller)?

**Valgt: Nej — rå ark-navne**

Brugerfeedback: rå navne er tilstrækkelige. Undgår ekstra `read_excel(n_max=0)`-kald per ark.

### Valg 4: Tomme ark-håndtering

**Valgt: Grå-ud, men klikbart**

Preflight-detektion via `read_excel(path, sheet=name, n_max=1)` per ark ved upload-tidspunkt. Ark med 0 rækker rendres med dæmpet styling i dropdown'en. Klik tillades stadig — brugeren ser blot et tomt paste-felt og kan vælge nyt ark.

Alternativ overvejet: helt deaktivér tomme ark. Forkastet — brugeren kan have legitime grunde til at se tomt ark (fejlsøgning, verificering).

### Valg 5: Detektion af biSPCharts gem-format

**Bekræftet: AND-check `"Data" %in% sheets && "Indstillinger" %in% sheets` er upåvirket af tilføjelse af "SPC-analyse"-ark**

Eksisterende detektion i `R/fct_file_parse_pure.R:157` og `R/utils_server_paste_data.R:171` kræver kun tilstedeværelse af `Data` + `Indstillinger`. Tredje ark (`SPC-analyse`, fra in-progress change `add-spc-analysis-sheet-to-excel-export`) ændrer ikke logikken.

Konsolidering af duplikeret detektion mellem `fct_file_parse_pure.R` og `utils_server_paste_data.R` er **ikke** del af denne change (refactor uden for scope).

## State management

Ny slot:

```r
app_state$session$pending_excel_upload <- list(
  datapath    = character(1),  # tempfile-sti
  name        = character(1),  # original filnavn
  sheets      = character(),   # ark-navne fra excel_sheets()
  empty_flags = logical()      # TRUE for ark med 0 rækker
)
```

Levetid: oprettes når multi-sheet upload detekteres → ryddes når bruger har valgt og parsing er fuldført, eller ved ny upload (overskrivning).

Hvorfor `app_state$session` og ikke modul-lokal `reactiveVal`: konsistens med øvrig session-state. Letter også eventuelt fremtidigt behov for at vise pending-status i debug-panel.

## Observer-arkitektur

```
direct_file_upload ──┬─ ext == csv/txt? ────────── eksisterende flow
                     │
                     └─ ext == xlsx/xls?
                           │
                           ├─ excel_sheets() + biSPCharts-detektion
                           │
                           ├─ biSPCharts → handle_excel_upload()  (uændret)
                           │
                           ├─ length(sheets) == 1 → read_excel() → paste (uændret)
                           │
                           └─ length(sheets) >= 2 (standard multi-sheet)
                                 │
                                 ├─ preflight per ark (n_max=1)
                                 ├─ gem app_state$session$pending_excel_upload
                                 ├─ render dropdown via insertUI/renderUI
                                 ├─ vis dropdown (shinyjs::show)
                                 └─ notification "Vælg faneblad"

selected_excel_sheet ──── læs valgt ark via parse_excel_file(hints=list(sheet=...))
                          ├─ tab-formatter til paste_data_input
                          ├─ ryd pending_excel_upload
                          ├─ skjul + tøm dropdown
                          └─ notification "X-ark indlæst"
```

## UI-rendering: insertUI vs renderUI

**Valgt: `renderUI` med tom placeholder ved app-init**

```r
# R/ui_app_ui.R — tilføj efter "Indlæs XLS/CSV"-knappen
shiny::div(
  id = "excel_sheet_dropdown",
  class = "excel-sheet-dropdown",
  style = "display: none;",
  shiny::uiOutput("excel_sheet_dropdown_items")
)
```

```r
# R/utils_server_paste_data.R — i upload-observer
output$excel_sheet_dropdown_items <- shiny::renderUI({
  pending <- app_state$session$pending_excel_upload
  if (is.null(pending)) return(NULL)
  build_excel_sheet_dropdown_items(pending$sheets, pending$empty_flags)
})
```

Hvorfor ikke `insertUI`: insertUI/removeUI risikerer ID-kollisioner ved gentagne uploads. `renderUI` med reaktiv afhængighed af `pending_excel_upload` rerender automatisk og rent.

## Pure helpers

Ny fil `R/fct_excel_sheet_detection.R`:

```r
#' List ark i Excel-fil med fejl-håndtering
#' @return character vector af ark-navne, eller NULL ved fejl
list_excel_sheets <- function(path) { ... }

#' Detekter tomme ark (ingen data-rækker udover header)
#' @return logical vector samme længde som sheets
detect_empty_sheets <- function(path, sheets) { ... }

#' Genkend biSPCharts gem-format
#' @return TRUE hvis Data + Indstillinger findes blandt ark
is_bispchart_excel_format <- function(sheets) { ... }
```

Disse er pure helpers (ingen Shiny-deps), testbare uden mock-session.

## JS-escaping af ark-navne

Ark-navne kan indeholde mellemrum, citationstegn og specialtegn. Eksisterende sample-dropdown bruger `sprintf("Shiny.setInputValue('selected_sample', '%s'", ds$id)` — sårbar over for citationstegn.

Brug `jsonlite::toJSON(name, auto_unbox = TRUE)` ved konstruktion af `onclick`-attribut:

```r
sheet_name_json <- jsonlite::toJSON(sheet_name, auto_unbox = TRUE)
onclick <- sprintf(
  "Shiny.setInputValue('selected_excel_sheet', %s, {priority: 'event'}); document.getElementById('excel_sheet_dropdown').style.display='none';",
  sheet_name_json
)
```

`htmltools::htmlEscape()` på label-tekst i dropdown-item.

## Test-strategi

**Pure-funktion tests** (`tests/testthat/test-excel-sheet-picker.R`):

- `list_excel_sheets()` — gyldig fil, korrupt fil (NULL retur), ikke-eksisterende fil
- `detect_empty_sheets()` — fil med tomme + udfyldte ark, fil med kun headers
- `is_bispchart_excel_format()` — biSPCharts 2-ark, biSPCharts 3-ark, standard 1-ark, standard multi-ark

**Observer tests** (`shiny::testServer()`):

- Upload single-sheet → ingen dropdown vises, paste-felt fyldes
- Upload biSPCharts-format → ingen dropdown, `handle_excel_upload()` kaldt
- Upload multi-sheet standard → `pending_excel_upload` sættes, paste-felt tomt, notification trigget
- `selected_excel_sheet` event → `parse_excel_file(hints=list(sheet=...))` kaldt, paste-felt fyldt, pending ryddet
- Re-upload før valg → pending overskrives med ny upload-info

**Snapshot/integration**: ingen — UI-rendering testes via observer-tests og manuel verifikation.

## Risici

| Risiko | Mitigering |
|--------|------------|
| Mange ark (10+) → uoverskuelig dropdown | Begræns til scrollable container (max-height + overflow-y), genbrug eksisterende sample-dropdown CSS |
| Preflight `n_max=1`-kald langsom på store filer | Acceptabel — `n_max=1` læser kun 1 række per ark; for 10 ark < 1s typisk |
| JS-injection via ark-navn | `jsonlite::toJSON()` + `htmltools::htmlEscape()` — strict |
| Bruger lukker tab/browser uden valg → `pending_excel_upload` lever videre | Acceptabel — ryddes ved næste upload eller session-end |
| Race: ny upload mens preflight kører på forrige | Sidste-vinder-semantik — observer overskriver `pending_excel_upload` |

## Out of scope

- Konsolidering af duplikeret biSPCharts-detektion mellem `fct_file_parse_pure.R` og `utils_server_paste_data.R`
- Sheet-picker for CSV-filer med multiple "tabs" (ikke et koncept i CSV)
- Persistent sheet-valg på tværs af sessioner (kompleksitet uden klar fordel)
- Preview af ark-indhold før valg (over-engineering for v1)
