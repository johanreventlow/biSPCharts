## Why

Brugere har behov for indsigt i de faktiske SPC-beregninger bag deres charts — især ved phase-opdelte data, hvor centrallinje (CL), kontrolgrænser og Anhøj-statistik varierer per part. Denne information er i dag kun tilgængelig visuelt i UI'et og kan ikke gemmes til klinisk dokumentation, audit eller efterbehandling. Eksport af centrallinje-værdier per part og Anhøj-regler per part vil understøtte kvalitetsarbejde og kommunikation med kolleger uden at de skal genkøre app'en.

## What Changes

- Tilføj tredje ark `SPC-analyse` til biSPCharts Excel-download (read-only, informational; ikke round-trip)
- Arket har 4 sektioner:
  - **A. Oversigt:** Charttype, antal observationer, antal parts, freeze-info, y-akse-enhed, beregningsdato, biSPCharts/BFHcharts-version, target-værdi + Δ til CL, samlede ooc-række-indekser, freeze-baseline summary, dansk tolkning
  - **B. Per-part statistik:** én række per part — Part │ Phase-navn │ Fra │ Til │ N │ Centrallinje (cl) │ Øvre grænse (ucl) │ Nedre grænse (lcl) │ Mean │ Median │ Target │ Δ til CL
  - **C. Anhøj-regler per part:** Part │ Længste serie (longest_run) │ Maks tilladt (longest_run_max) │ Antal kryds (n_crossings) │ Min krævet (n_crossings_min) │ Runs-signal │ Crossings-signal │ Samlet signal │ Dansk tolkning
  - **D. Special cause-punkter:** Række │ Dato │ Værdi │ Centrallinje (cl) │ Øvre grænse (ucl) │ Nedre grænse (lcl) │ Out-of-limits │ Runs-signal │ Notes │ Nævner (p/u-charts)
- Y-værdier i UI-valgt enhed; enhed indlejret i kolonne-overskrift (fx `Centrallinje (cl, timer)`)
- Run-charts: tomme `ucl`/`lcl`-celler (struktur-konsistens)
- `parse_spc_excel()` skal fortsat ignorere ukendte sheets — round-trip-egenskab uændret
- Anhøj-beregning per part udvider `derive_anhoej_results()` (eller wrapper) til at acceptere part-subsets af `qic_data`

## Capabilities

### New Capabilities
- `excel-spc-analysis-sheet`: Generering af informational `SPC-analyse`-ark i Excel-export; per-part centrallinje, kontrolgrænser, Anhøj-statistik og special cause-punkter; ikke round-trip-able

### Modified Capabilities
<!-- Ingen — `session-persistence` og `export-preview` påvirkes ikke; Excel build_spc_excel() er ikke dækket af eksisterende spec endnu. -->

## Impact

**Affected code:**
- `R/fct_spc_file_save_load.R` — udvid `build_spc_excel()` (eller introducér ny `build_spc_analysis_sheet()` orkestrator) til at tilføje tredje ark
- `R/fct_spc_anhoej_derivation.R` — udvid `derive_anhoej_results()` til per-part anvendelse (eller wrapper-funktion)
- `R/utils_server_wizard_gates.R` — kald til `build_spc_excel()` får adgang til `bfh_qic_result` (allerede tilgængelig via app_state)
- Nye filer (sandsynligt): `R/fct_spc_excel_analysis.R` (sektioner-builders), `tests/testthat/test-fct_spc_excel_analysis.R`

**Dependencies:**
- `openxlsx` (allerede brugt) — ingen nye runtime-deps
- `qicharts2` via eksisterende `qic_data` (allerede del af `bfh_qic_result`)

**Round-trip-egenskab:**
- Eksisterende `Data` + `Indstillinger`-ark uændrede
- `parse_spc_excel()` testes for at ignorere `SPC-analyse`-ark lydløst (regression-test)

**Performance:**
- Per-part Anhøj-beregning: O(N_parts × N_obs_per_part) — trivielt for normale N (<10 parts, <1000 obs); test med edge case 50+ parts

**Ikke i scope:**
- Round-trip / parse af `SPC-analyse`-ark (informational only)
- UI-toggle for at slå arket fra (altid med)
- Sheet-beskyttelse (fri redigering)
- Sigma per part, antal over/under CL, % out-of-limits (ekspliciteret droppet i explore-fase)
- Modifikation af BFHcharts/qicharts2 (al beregning sker via eksisterende `qic_data` output)

## Related

- GitHub issue: #343
