# excel-spc-analysis-sheet Specification

## Purpose
TBD - created by archiving change add-spc-analysis-sheet-to-excel-export. Update Purpose after archive.
## Requirements
### Requirement: Excel-download SHALL inkludere `SPC-analyse`-ark

Når brugeren downloader sin biSPCharts-session som Excel-fil, SHALL den genererede `.xlsx`-fil indeholde et tredje ark ved navn `SPC-analyse` ud over de eksisterende `Data`- og `Indstillinger`-ark. Arket SHALL være read-only/informational og SHALL ikke kræves for round-trip-genindlæsning.

#### Scenario: Standard download med kontrol-chart og parts

- **GIVEN** brugeren har uploadet data, valgt et kontrol-chart (fx `p`) og defineret faseskift med 3 parts
- **WHEN** brugeren trigger Excel-download via wizard-gate
- **THEN** den producerede `.xlsx`-fil SHALL have præcis 3 ark: `Data`, `Indstillinger`, `SPC-analyse`
- **AND** `SPC-analyse`-arket SHALL indeholde sektioner A (Oversigt), B (Per-part statistik), C (Anhøj-regler per part), D (Special cause-punkter)

#### Scenario: Download med run-chart uden parts

- **GIVEN** brugeren har valgt `run`-chart uden faseskift
- **WHEN** Excel-download trigges
- **THEN** `SPC-analyse`-arket SHALL eksistere
- **AND** sektion B SHALL indeholde præcis én række (én "part" dækker hele datasættet)
- **AND** UCL/LCL-cellerne i sektion B og D SHALL være tomme (run-charts har ingen kontrolgrænser)

### Requirement: `SPC-analyse`-arket SHALL bevare round-trip-egenskaben

`parse_spc_excel()` SHALL fortsat kunne læse `Indstillinger`-arket fra Excel-filer med tre ark. Tilstedeværelsen af `SPC-analyse`-arket SHALL ikke ændre output fra `parse_spc_excel()`.

#### Scenario: Round-trip via 3-ark Excel-fil

- **GIVEN** en Excel-fil genereret af biSPCharts med 3 ark inkl. `SPC-analyse`
- **WHEN** `parse_spc_excel(file_path)` kaldes
- **THEN** returneret named list SHALL være identisk med den `metadata`-liste der oprindelig blev sendt til `build_spc_excel()`
- **AND** ingen felter fra `SPC-analyse`-arket SHALL lække ind i metadata

#### Scenario: Bagudkompatibilitet med 2-ark filer

- **GIVEN** en eksisterende Excel-fil med kun `Data` + `Indstillinger`-ark (gemt før denne change)
- **WHEN** `parse_spc_excel(file_path)` kaldes
- **THEN** funktionen SHALL returnere metadata uden fejl
- **AND** brugeren SHALL kunne genindlæse session som før

### Requirement: Sektion A (Oversigt) SHALL indeholde computational kontekst

Sektion A SHALL angive: charttype, antal observationer, antal parts, freeze-info, y-akse-enhed, beregningsdato, biSPCharts-version, BFHcharts-version, target-værdi (hvis sat), Δ til CL (hvis target sat), out-of-control række-indekser samlet, freeze-baseline summary (hvis frozen), dansk tolkning af samlet Anhøj-status.

#### Scenario: Komplet oversigt for kontrol-chart med target og freeze

- **GIVEN** brugeren har konfigureret p-chart med 50 obs, 2 parts, frozen til række 25, target = 0.05
- **WHEN** Excel-download genereres
- **THEN** sektion A SHALL angive `Charttype: p`, `Antal observationer: 50`, `Antal parts: 2`, `Frozen til række: 25`, `Target: 0.05`
- **AND** sektion A SHALL angive `Δ til CL` for hver part hvis target er sat
- **AND** sektion A SHALL angive freeze-baseline (CL/LCL/UCL gældende ved row 25)
- **AND** beregningsdato (ISO 8601) og pakke-versioner SHALL være til stede

#### Scenario: Out-of-control samlet liste

- **GIVEN** der er signal-punkter ved række 7, 12, 19
- **WHEN** sektion A genereres
- **THEN** feltet `Out-of-control rækker` SHALL indeholde teksten `"7, 12, 19"`

### Requirement: Sektion B (Per-part statistik) SHALL have én række per part

Sektion B SHALL have kolonner: `Part`, `Phase-navn`, `Fra (række)`, `Til (række)`, `N`, `Centrallinje (cl, <enhed>)`, `Øvre grænse (ucl, <enhed>)`, `Nedre grænse (lcl, <enhed>)`, `Mean (<enhed>)`, `Median (<enhed>)`, `Target (<enhed>)`, `Δ til CL (<enhed>)`. `<enhed>` SHALL være den UI-valgte y-akse-enhed.

#### Scenario: Tids-y-akse i UI-enhed

- **GIVEN** y-akse-enhed er "timer", CL = 150 minutter (kanonisk intern repræsentation)
- **WHEN** sektion B genereres
- **THEN** kolonne-overskriften SHALL være `Centrallinje (cl, timer)`
- **AND** celle-værdien SHALL være `2.5` (ikke `150`)

#### Scenario: Phase-navne hvis sat af bruger

- **GIVEN** brugeren har navngivet faser via `skift_column` med tekst-værdier "Baseline", "Intervention"
- **WHEN** sektion B genereres
- **THEN** `Phase-navn`-kolonnen SHALL indeholde "Baseline" og "Intervention"
- **AND** hvis ingen phase-navne sat: kolonnen SHALL være tom

### Requirement: Sektion C (Anhøj-regler per part) SHALL anvende `derive_anhoej_per_part()`

Sektion C SHALL have kolonner: `Part`, `Længste serie (longest_run)`, `Maks tilladt (longest_run_max)`, `Antal kryds (n_crossings)`, `Min krævet (n_crossings_min)`, `Runs-signal`, `Crossings-signal`, `Samlet signal`, `Dansk tolkning`. Værdier SHALL være per-part og beregnes via en pure funktion `derive_anhoej_per_part(qic_data)`.

#### Scenario: Per-part Anhøj-evaluering

- **GIVEN** `qic_data` med 3 parts, hvor part 1 udløser runs-signal og part 3 udløser crossings-signal
- **WHEN** `derive_anhoej_per_part(qic_data)` kaldes
- **THEN** funktionen SHALL returnere en liste med 3 elementer
- **AND** part 1's `runs_signal` SHALL være `TRUE`, `crossings_signal` SHALL være `FALSE`
- **AND** part 3's `crossings_signal` SHALL være `TRUE`
- **AND** sektion C SHALL afspejle disse værdier én række per part

#### Scenario: Dansk tolkning ved kombineret signal

- **GIVEN** part 2 har både `runs_signal = TRUE` og `crossings_signal = TRUE`
- **WHEN** `interpret_anhoej_signal_da(anhoej_result)` kaldes
- **THEN** funktionen SHALL returnere `"Særskilt årsag: lang serie + få kryds"`

#### Scenario: Stabil proces

- **GIVEN** alle Anhøj-flag er `FALSE` for en part
- **WHEN** `interpret_anhoej_signal_da()` kaldes
- **THEN** returnerer `"Stabil proces (ingen særskilt årsag)"`

### Requirement: Sektion D (Special cause-punkter) SHALL liste alle ooc-rækker

Sektion D SHALL have kolonner: `Række`, `Dato`, `Værdi (<enhed>)`, `Centrallinje (cl, <enhed>)`, `Øvre grænse (ucl, <enhed>)`, `Nedre grænse (lcl, <enhed>)`, `Out-of-limits`, `Runs-signal`, `Notes`, `Nævner (n)`. Hver række SHALL repræsentere et datapunkt der enten er `out-of-limits` (uden for kontrolgrænser) eller del af en `runs.signal`-serie.

#### Scenario: Punkt uden for kontrolgrænser

- **GIVEN** række 7 har `value = 0.09`, `cl = 0.045`, `ucl = 0.078` → out-of-limits
- **WHEN** sektion D genereres
- **THEN** række 7 SHALL være med, `Out-of-limits` SHALL være `JA`
- **AND** hvis brugeren har en kommentar i `kommentar_column` for række 7: `Notes`-cellen SHALL indeholde teksten

#### Scenario: Punkt på lang serie men inden for grænser

- **GIVEN** række 12 har `runs.signal = TRUE` men er inden for kontrolgrænser
- **WHEN** sektion D genereres
- **THEN** række 12 SHALL være med, `Out-of-limits` SHALL være `NEJ`, `Runs-signal` SHALL være `JA`

#### Scenario: Ingen special cause-punkter

- **GIVEN** datasæt uden out-of-limits og uden runs-signal
- **WHEN** sektion D genereres
- **THEN** sektionens header SHALL være til stede
- **AND** under header SHALL en besked angive `"Ingen special cause-punkter detekteret"`

#### Scenario: P/U-chart med nævner

- **GIVEN** chart-type er `p` med `n_column` sat til "Patienter"
- **WHEN** sektion D genereres for et special cause-punkt
- **THEN** `Nævner (n)`-kolonnen SHALL indeholde værdien fra `n_column` for den pågældende række

### Requirement: Generering SHALL være ikke-blokerende

Hvis `bfh_qic_result` er utilgængelig, fejlbehæftet (typed `spc_error`), eller `qic_data` er tomt på download-tidspunktet, SHALL `SPC-analyse`-arket springes over uden at blokere Excel-download. `Data`- og `Indstillinger`-ark SHALL skrives som hidtil.

#### Scenario: SPC-beregning fejler

- **GIVEN** `app_state$bfh_qic_result` er `NULL` eller en `spc_error`-instans
- **WHEN** Excel-download trigges
- **THEN** Excel-filen SHALL genereres med `Data` + `Indstillinger` (uden `SPC-analyse`-ark)
- **AND** en log-warning med kontekst `EXCEL_EXPORT` SHALL skrives via `log_warn()`
- **AND** brugeren SHALL ikke se en blokerende fejl

#### Scenario: Tomt datasæt

- **GIVEN** `qic_data` har 0 rækker
- **WHEN** `build_spc_analysis_sheet()` kaldes
- **THEN** funktionen SHALL returnere `NULL` (eller en sentinel der signalerer skip)
- **AND** Excel-filen SHALL produceres uden `SPC-analyse`-ark

### Requirement: Pure builder-funktioner SHALL være Shiny-uafhængige

Sektions-builders (`build_overview_section`, `build_per_part_section`, `build_anhoej_section`, `build_special_cause_section`) og orkestrator (`build_spc_analysis_sheet`) SHALL være pure: ingen Shiny-afhængighed, ingen `app_state`-reads, ingen side-effekter. Alle nødvendige inputs (qic_data, metadata, package-versioner, beregningsdato) SHALL leveres som funktions-argumenter.

#### Scenario: Test af sektion-builder uden Shiny

- **GIVEN** et statisk `qic_data` data.frame fra fixture
- **WHEN** `build_per_part_section(qic_data, y_axis_unit = "timer")` kaldes i en testthat-kontekst uden Shiny session
- **THEN** funktionen SHALL returnere en data.frame med korrekt antal rækker (= antal parts)
- **AND** ingen `reactiveValues`/`session`-objekter SHALL kræves

