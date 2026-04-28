## ADDED Requirements

### Requirement: Excel-upload SHALL detektere antal ark og biSPCharts-format

Når brugeren uploader en `.xlsx`- eller `.xls`-fil via "Indlæs XLS/CSV"-knappen, SHALL appen kalde `readxl::excel_sheets()` for at bestemme antal ark og kontrollere om filen er biSPCharts gem-format (defineret som tilstedeværelse af både `Data`- og `Indstillinger`-ark).

#### Scenario: Single-sheet Excel læses automatisk

- **GIVEN** brugeren uploader en Excel-fil med præcis ét ark
- **WHEN** filen er valideret
- **THEN** appen SHALL læse det ene ark via `readxl::read_excel()`
- **AND** appen SHALL fylde paste-feltet med tab-separeret repræsentation
- **AND** sheet-picker-dropdown SHALL ikke vises

#### Scenario: biSPCharts gem-format genkendes

- **GIVEN** brugeren uploader en Excel-fil med ark `Data`, `Indstillinger` og `SPC-analyse`
- **WHEN** filen er valideret
- **THEN** appen SHALL genkende filen som biSPCharts gem-format
- **AND** appen SHALL kalde `handle_excel_upload()` direkte (auto-gendannelse)
- **AND** sheet-picker-dropdown SHALL ikke vises

#### Scenario: Standard multi-sheet Excel udløser sheet-picker

- **GIVEN** brugeren uploader en Excel-fil med ≥ 2 ark, hvor enten `Data` eller `Indstillinger` mangler
- **WHEN** filen er valideret
- **THEN** appen SHALL gemme upload-info i `app_state$session$pending_excel_upload`
- **AND** appen SHALL vise sheet-picker-dropdown'en
- **AND** paste-feltet SHALL forblive tomt
- **AND** appen SHALL vise notifikation om at bruger skal vælge ark

### Requirement: Sheet-picker SHALL vise alle ark som klikbare items

Sheet-picker-dropdown'en SHALL rendre én knap per detekteret ark med arkets rå navn som label. Items SHALL være ankret visuelt under "Indlæs XLS/CSV"-knappen og SHALL bruge samme JS-toggle-mønster som eksisterende sample-data-dropdown.

#### Scenario: Tre-ark Excel rendres som tre items

- **GIVEN** uploadet fil har ark `["Q1", "Q2", "Q3"]`
- **WHEN** dropdown'en rendres
- **THEN** dropdown'en SHALL indeholde tre `<button>`-elementer
- **AND** hver button SHALL vise det rå ark-navn som label
- **AND** klik på en button SHALL sætte `input$selected_excel_sheet` til ark-navnet

#### Scenario: Ark-navn med specialtegn escapes korrekt

- **GIVEN** uploadet fil har ark med navn `Data "med" citater`
- **WHEN** dropdown-item rendres
- **THEN** label-teksten SHALL HTML-escapes korrekt (ingen rå citationstegn brydende HTML)
- **AND** `onclick`-attributten SHALL JSON-escape ark-navnet (ingen JS-syntax-fejl)
- **AND** klik SHALL korrekt sende ark-navnet til serveren

#### Scenario: Tomme ark vises grå-ud men forbliver klikbare

- **GIVEN** uploadet fil har ark `["Data1", "TomtArk"]`, hvor `TomtArk` ikke har data-rækker
- **WHEN** dropdown'en rendres
- **THEN** `TomtArk`-item SHALL have CSS-klasse `excel-sheet-item--empty` (dæmpet styling)
- **AND** items SHALL fortsat være klikbart
- **AND** klik på `TomtArk` SHALL fylde paste-feltet med tomt indhold (ingen crash)

### Requirement: Valgt ark SHALL indlæses og fylde paste-feltet

Når brugeren vælger et ark via dropdown'en (event `input$selected_excel_sheet`), SHALL appen læse det valgte ark og fylde `paste_data_input` med tab-separeret tekst-repræsentation, identisk med eksisterende multi-sheet-fallback-logik.

#### Scenario: Valgt ark fylder paste-felt korrekt

- **GIVEN** `app_state$session$pending_excel_upload` er sat med en multi-sheet-fil
- **WHEN** `input$selected_excel_sheet` udløses med ark-navn `"Q2"`
- **THEN** appen SHALL kalde `readxl::read_excel(path, sheet="Q2", col_names=TRUE)`
- **AND** appen SHALL formattere data til tab-separeret tekst med komma-decimal for numeriske værdier
- **AND** `paste_data_input` SHALL opdateres med den genererede tekst
- **AND** sheet-picker-dropdown SHALL skjules
- **AND** `app_state$session$pending_excel_upload` SHALL ryddes (sættes til `NULL`)
- **AND** appen SHALL vise notifikation om succesfuld indlæsning

#### Scenario: Re-upload mens pending er sat

- **GIVEN** `app_state$session$pending_excel_upload` er sat fra tidligere upload
- **WHEN** brugeren uploader en ny multi-sheet-fil
- **THEN** `app_state$session$pending_excel_upload` SHALL overskrives med ny upload-info
- **AND** dropdown'en SHALL re-rendres med ark-navne fra ny fil
- **AND** ingen data fra forrige pending-upload SHALL lække ind i ny tilstand

### Requirement: Pure helpers SHALL kunne bruges uafhængigt af Shiny

Sheet-detektion og biSPCharts-format-genkendelse SHALL implementeres som pure funktioner i `R/fct_excel_sheet_detection.R`, så de kan testes uden Shiny-session-mock og genbruges fra både upload-observer og parse-pipeline.

#### Scenario: list_excel_sheets returnerer ark-navne

- **GIVEN** en gyldig Excel-fil-sti
- **WHEN** `list_excel_sheets(path)` kaldes
- **THEN** funktionen SHALL returnere character vector af ark-navne
- **AND** funktionen SHALL returnere `NULL` hvis filen er korrupt eller ikke kan læses

#### Scenario: detect_empty_sheets identificerer tomme ark

- **GIVEN** Excel-fil med ark `["FuldData", "TomtArk"]`
- **WHEN** `detect_empty_sheets(path, c("FuldData", "TomtArk"))` kaldes
- **THEN** funktionen SHALL returnere `c(FALSE, TRUE)`
- **AND** funktionen SHALL fungere ved at læse `n_max=1` per ark (effektivt)

#### Scenario: is_bispchart_excel_format kræver Data + Indstillinger

- **GIVEN** ark-vektor `c("Data", "Indstillinger", "SPC-analyse")`
- **WHEN** `is_bispchart_excel_format(sheets)` kaldes
- **THEN** funktionen SHALL returnere `TRUE`
- **AND** ark-vektor `c("Data", "Q2")` SHALL returnere `FALSE` (mangler Indstillinger)
- **AND** ark-vektor `c("Sheet1")` SHALL returnere `FALSE`
