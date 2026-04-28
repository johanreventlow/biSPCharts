## Context

biSPCharts producerer i dag Excel-downloads med to ark: `Data` (rå rækker) og `Indstillinger` (UI-metadata for round-trip-load). SPC-beregningerne (centrallinje, kontrolgrænser, Anhøj-statistik) er kun synlige i UI'et som plot + value-boxes. Per-part-værdier er især skjulte: når brugeren har defineret faseskift (`skift_column`), beregner BFHcharts/qicharts2 separate CL/UCL/LCL og separate Anhøj-statistik per part, men disse værdier kan ikke ekstraheres til klinisk dokumentation eller audit uden at genstarte app'en og aflæse dem manuelt.

Build-funktion: `R/fct_spc_file_save_load.R::build_spc_excel(data, metadata)` (106 linjer). Eneste kalder: `R/utils_server_wizard_gates.R:112`. SPC-resultatet (`bfh_qic_result`) er allerede tilgængeligt i `app_state` på download-tidspunktet (`bfh_qic_result$qic_data` med kolonnerne `cl`, `ucl`, `lcl`, `part`, `runs.signal`, `n.crossings`, `longest.run`).

Anhøj-derivation eksisterer som pure funktion `R/fct_spc_anhoej_derivation.R::derive_anhoej_results(qic_data, show_phases)`. Den filtrerer i dag til seneste part via `filter_latest_part()`; for per-part-rapportering har vi brug for at evaluere alle parts.

## Goals / Non-Goals

**Goals:**
- Ekspliciter SPC-beregningerne i en Excel-formidling brugeren kan dele/arkivere
- Per-part transparens: CL, UCL, LCL, Mean, Median, Anhøj-metrics, special cause-punkter
- Bevar eksisterende round-trip-egenskab (`Data` + `Indstillinger` parses uændret)
- Pure builder-funktioner (testbare uden Shiny)
- Dansk klinisk-venlig tone i kolonneoverskrifter og tolkninger

**Non-Goals:**
- Round-trip / parse af `SPC-analyse`-arket (informational only)
- UI-toggle eller config-flag til at slå arket fra
- Sheet-beskyttelse (`openxlsx::protectWorksheet`)
- Sigma per part, % out-of-limits, antal over/under CL (eksplicit droppet i explore)
- Modifikation af BFHcharts/qicharts2; al beregning baseret på eksisterende `qic_data`
- Generering af `SPC-analyse`-ark i andre eksport-formater (PDF, PNG bevares uændret)

## Decisions

### Decision 1: Pure builder-funktioner, separat fil

**Valgt:** Ny fil `R/fct_spc_excel_analysis.R` med pure funktioner pr. sektion (`build_overview_section`, `build_per_part_section`, `build_anhoej_section`, `build_special_cause_section`) + orkestrator `build_spc_analysis_sheet(qic_data, metadata, ...)` returnerer en `list(sheet_name, frames, layout)` som `build_spc_excel()` skriver til workbook.

**Alternativ overvejet:** Udvid `build_spc_excel()` direkte. Forkastet: filen vokser fra 106 → ~400 LOC; sværere at teste sektioner isoleret; bryder eksisterende SRP for `fct_spc_file_save_load.R` (gem/load-orchestrering).

**Rationale:**
- Pure funktioner → fuld testdækning uden Shiny eller workbook-mocking
- Sektion-isolation → robust over for fremtidige tilføjelser (sigma kan tilføjes som ekstra sektion uden at ændre eksisterende)
- `build_spc_excel()` forbliver "Excel-orchestrator" — al SPC-domænelogik samlet i `fct_spc_excel_analysis.R`

### Decision 2: Per-part Anhøj via ny pure-funktion `derive_anhoej_per_part()`

**Valgt:** Tilføj `derive_anhoej_per_part(qic_data) -> list of per-part anhoej-result + part-id`. Eksisterende `derive_anhoej_results()` uændret (back-compat).

**Alternativ overvejet:** Ekstendér `derive_anhoej_results()` med `per_part = TRUE`-flag. Forkastet: ændrer return-type kontraktbrud risiko; tests ville skulle dække begge return-shapes.

**Implementation:** Loop part-værdier i `qic_data$part`, kald `derive_anhoej_results(subset, show_phases = FALSE)` per subset, return liste af resultater med part-identifikator. Hvis `qic_data$part` mangler eller alle er NA: én "part" dækker hele datasættet.

### Decision 3: Genbrug `bfh_qic_result` fra `app_state`, fallback til regenerering

**Valgt:** `build_spc_analysis_sheet()` accepterer pre-computed `qic_data` som input (caller's ansvar at hente). Hvis `app_state$bfh_qic_result` er gyldig på download-tidspunktet, bruges den; ellers regenererer wizard-gate via `compute_spc_results_bfh()` før kald.

**Alternativ overvejet:** Lade `build_spc_analysis_sheet()` selv regenerere. Forkastet: bryder pure-funktion-princippet; introducerer Shiny/state-kobling i Excel-modul.

**Edge case:** Hvis `bfh_qic_result` er fejl (typed `spc_error`) eller utilgængelig: `SPC-analyse`-arket springer over (ikke-blokerende), `Data`+`Indstillinger` skrives uændret, log-warning udsendes. Excel-download fejler ikke pga. analysis-sheet-fejl.

### Decision 4: Y-enhed: UI-valgt (ikke kanoniske minutter)

**Valgt:** Tids-y-akse-værdier konverteres tilbage til UI-valgt enhed (`y_axis_unit`) før skrivning. Enhed indlejres i kolonne-overskrift: `Centrallinje (cl, timer)`, `Mean (timer)`, `Δ til CL (timer)`.

**Alternativ overvejet:** Skriv i kanoniske minutter med separat enheds-celle. Forkastet: brugeren læser arket parallelt med UI'et; mismatch mellem visning (timer) og ark (minutter) skaber forvirring.

**Implementation:** Brug eksisterende reverse-konvertering (omvendt af `parse_time_to_minutes` i `R/fct_spc_prepare.R`). Hvis ingen reverse-helper findes: tilføj `format_time_from_minutes(minutes, target_unit)`.

### Decision 5: Run-charts: tomme UCL/LCL-celler

**Valgt:** Run-charts har ingen UCL/LCL i `qic_data`. Skriv `NA` (Excel-tom celle) i de pågældende kolonner. Sektion D's `Out-of-limits`-kolonne skrives `NEJ` (eller tom) for run-charts.

**Rationale:** Konsistent kolonnestruktur uanset chart-type forenkler downstream-parsing og brugerens læsning. Sektion A angiver allerede `Charttype = run` → læser ved tomme celler er forventet.

### Decision 6: Dansk + qic-konvention i kolonneoverskrifter

**Valgt:** `Centrallinje (cl)`, `Øvre grænse (ucl)`, `Nedre grænse (lcl)`, `Længste serie (longest_run)`, `Antal kryds (n_crossings)`, etc.

**Rationale:** Dansk primær for klinisk målgruppe; qic-konvention i parentes som teknisk reference for brugere der vil koble til litteratur (qicharts2-docs, Anhøj's manifest). Help-modulet linker allerede til qicharts2/Anhøj med engelske termer.

### Decision 7: Dansk tolkning som afledt felt

**Valgt:** Tilføj `interpret_anhoej_signal_da(anhoej_result) -> character` der mapper signal-flag til dansk klinisk-venlig tekst:

| Signal | Dansk tolkning |
|--------|----------------|
| `anhoej_signal == FALSE` | "Stabil proces (ingen særskilt årsag)" |
| `runs_signal == TRUE && crossings_signal == FALSE` | "Særskilt årsag: lang serie" |
| `runs_signal == FALSE && crossings_signal == TRUE` | "Særskilt årsag: for få mediankryds" |
| `runs_signal == TRUE && crossings_signal == TRUE` | "Særskilt årsag: lang serie + få kryds" |

Funktionen er pure og testbar isoleret.

## Risks / Trade-offs

[**Risk:** `bfh_qic_result` mismatch mod `Data`-arket (cache stale)] → Mitigation: regenerér `qic_data` ved download-trigger hvis cache-key ikke matcher current `app_state$data` snapshot. Eksisterende cache-invalidation i `R/utils_spc_cache.R` håndterer dette; tests dækker scenariet.

[**Risk:** Mange parts (50+) med store datasæt → langsom Excel-build] → Mitigation: per-part Anhøj-loop er O(N_parts × N_obs); test med 100 parts × 10000 obs (>1M cell-ops). Performance-budget: Excel-build <500ms ekstra. Ingen indikation på at det bliver et problem; benchmark som regression-test.

[**Risk:** Tids-y-akse reverse-konvertering tab af præcision (float)] → Mitigation: brug eksplicit decimal-formattering med 4 decimaler i Excel-cellerne; rapportér både UI-værdi og evt. afvigelse.

[**Risk:** Notes-kolonne (sektion D) kan indeholde fortrolige patientdata] → Mitigation: notes-kolonne er allerede en del af `Data`-arket (round-trip); samme privacy-model gælder. Ingen ny privacy-eksponering.

[**Risk:** `parse_spc_excel()` regression — fremtidig refactor kan fejlagtigt læse `SPC-analyse`-arket] → Mitigation: regression-test der bygger Excel med alle 3 ark, parser med `parse_spc_excel()`, asserter at `Indstillinger`-felter er identiske med input-metadata (ingen lækage fra `SPC-analyse`).

[**Risk:** Edge case — qic_data tom eller mangler `part`-kolonne] → Mitigation: graceful fallback til "1 part" dækker hele datasættet; hvis datasættet er tomt: `SPC-analyse`-arket skippes med log-warning, Excel-download fortsætter.

## Migration Plan

Ingen migrering nødvendig:
- Eksisterende Excel-filer (med 2 ark) parses fortsat korrekt
- Nye downloads får 3. ark; round-trip-egenskab uændret
- Ingen API/data-model-ændring; kun additivt

Rollback-strategi: revert af PR + redeploy. Brugere oplever blot at `SPC-analyse`-arket forsvinder fra fremtidige downloads; eksisterende Excel-filer er upåvirkede.

## Open Questions

Ingen åbne — alle product-beslutninger truffet i explore-fase. Implementation-detaljer (præcis kolonne-rækkefølge, Excel-formattering som farver/borders) fastlægges under tasks-execution; kosmetiske valg dokumenteres i kommentarer i `fct_spc_excel_analysis.R`.
