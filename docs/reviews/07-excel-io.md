# Cycle C — Excel I/O

**Status:** Claude review + Codex adversarial reconciled (2026-05-10). Område: 3-ark Excel download (Data + Indstillinger + SPC-analyse), multi-sheet upload med picker, Excel round-trip, locale-handling.

**Codex peer-review konsekvens:** 2 fix-recipes recalibreret (H1 phase_names ville skrive bogus integer part-IDs; H2 startsWith-snippet er pairwise-recycled = length-mismatch).

**Worktree:** `/Users/johanreventlow/R/biSPCharts-reviews` på `review/program-base` (synced med develop @ b565d7e8).

**Driver:** Per CLAUDE.md "Stable pipeline" — sandsynligvis lav-finding cycle. Verified: 1 MEDIUM (spec-divergens) + 2 LOW (defensive). Ingen kritiske correctness/security-bugs.

---

## Findings (prioriteret)

### 🟡 H1 — SPC-analyse-arket mangler `freeze_position` + `phase_names` (MEDIUM, spec-divergens)

**Lokation:**
- `R/utils_server_wizard_gates.R:122-133` (build af analysis_options)
- `R/utils_server_wizard_gates.R:158-164` (kald til build_spc_excel)
- Referencer: `extract_freeze_position()` i `R/fct_spc_bfh_params.R:37`
- Spec: `openspec/specs/excel-spc-analysis-sheet/spec.md:51`

**Symptom:** `analysis_options` sendt til `build_spc_excel()` mangler både `freeze_position` og `phase_names`. Feltet "Frozen til række" (Sektion A) er derfor altid tomt i exporterede Excel-filer; freeze-baseline-summary kan aldrig bygges. Phase-navn-kolonnen (Sektion B) er altid tom selv når brugeren har skift-kolonne.

**Verifikation:**

`R/utils_server_wizard_gates.R:122-133`:
```r
qic_data <- NULL
analysis_options <- list(
  pkg_versions = list(
    biSPCharts = tryCatch(as.character(utils::packageVersion("biSPCharts")), ...),
    BFHcharts = tryCatch(as.character(utils::packageVersion("BFHcharts")), ...)
  ),
  computed_at = Sys.time()
)
# MANGLER: freeze_position, phase_names
```

Spec-krav (`openspec/specs/excel-spc-analysis-sheet/spec.md:51`):
> sektion A SHALL angive ... 'Frozen til række: 25'

`extract_freeze_position()` (fct_spc_bfh_params.R:37) findes og kan kaldes på `data` + `metadata$frys_column`.

`build_spc_analysis_sheet()` har allerede options-hooks for begge inputs (fct_spc_excel_analysis.R:135, 170) — men de kaldes aldrig fra wizard_gates.

**Konsekvens:**
- Gemte Excel-filer matcher ikke informational-spec
- Bruger-vendt Sektion A er ufuldstændig
- Stiltiende kontrakt-brud (spec siger SHALL men implementation passer NULL)

**Foreslået fix (REVIDERET efter Codex):** Min original recipe `unique(as.character(qic_data$part))` ville skrive integer part-IDs (`1`, `2`, `3`) som "Phase-navn" — duplikerer Part-kolonnen og ser falsk ud som user-labels. Codex empirisk: `qic_data$part` er auto-genereret integer fra `part_var`-input, ej user-labels.

**Korrekt fix:** Implementer kun freeze_position. Lade phase_names = NULL indtil eksplicit label-source eksisterer:

```r
freeze_position <- extract_freeze_position(data, metadata$frys_column)

analysis_options <- list(
  pkg_versions = list(...),
  computed_at = Sys.time(),
  freeze_position = freeze_position
  # phase_names = NULL — vent til eksplicit label-column kontrakt eksisterer.
  # qic_data$part er integer-IDs ej user-labels (Codex 2026-05-10).
)
```

Hvis phase_names ønskes som faktiske labels: tilføj eksplicit label-column-kontrakt + regression-test der verificerer `Phase-navn` indeholder labels (ej numeric part-IDs).

**Test:** Verificer Sektion A "Frozen til række" populeres når `metadata$frys_column` er sat + data har frys-markeringer.

**Severity:** MEDIUM — spec-divergens, ej functional bug. SPC-analyse-ark er informational only (per CLAUDE.md), men har dokumenteret felter der mangler.

---

### 🟢 H2 — Excel formula injection via kolonne-navne ej saniteret (LOW, defensive)

**Lokation:** `R/fct_spc_file_save_load.R:50` + `R/utils_input_sanitization.R:159-184`

**Symptom:** `sanitize_csv_output()` saniterer kun cell-værdier i character-kolonner via `dplyr::across(where(is.character))`. Kolonne-navne (data.frame `names`) prefixes ikke med `'` selvom de starter med `=`/`+`/`-`/`@`. Hvis bruger uploader CSV med fx kolonnen `=cmd|...`, overlever den round-trip og forbliver formel-eksekverbar i Excel.

**Verifikation:**

`R/utils_input_sanitization.R:167-181`:
```r
data <- data |>
  dplyr::mutate(
    dplyr::across(
      dplyr::where(is.character),
      ~ { dplyr::if_else(!is.na(.x) & substr(.x, 1, 1) %in% formula_chars,
                          paste0("'", .x), .x) }
    )
  )
# names(data) ikke saniteret
```

Headers udskrives uændret af `openxlsx::writeData(rowNames=FALSE)` (default `colNames=TRUE`).

**Konsekvens (kalibreret threat-model):** Smal CVE-flade — kræver:
1. Bevidst manipuleret upload med formel-prefixed header
2. Tredjepart åbner downloadet fil
3. Tredjepart dobbeltklikker på header-celle (Excel auto-formula-execution efter explicit edit)

biSPCharts-trusselsmodel (memory: kalibreret intern hospital-PC, kvalitetsdata, ej PHI) gør reel risiko meget lav.

**Foreslået fix (REVIDERET efter Codex):** Min original snippet var **defekt**: `startsWith(names, c("=","+","-","@"))` er pairwise-vectorized/recycled (R recycler korteste vektor til længste), ej "any prefix matches". For 3 names returnerer den length-4 logical → subscript-mismatch-error.

**Korrekt fix:** Use `vapply` med `any()`:
```r
formula_chars <- c("=", "+", "-", "@")
bad <- vapply(
  names(safe_data),
  function(nm) any(startsWith(nm, formula_chars)),
  logical(1)
)
names(safe_data)[bad] <- paste0("'", names(safe_data)[bad])
```

Test-coverage skal dække:
- 1-column data (edge: vapply returnerer length-1)
- 3-column data (Codex's empirisk demonstrerede bug-case)
- Reordered prefix (`=` ej altid første formula_char)

ELLER tilføj dedikeret helper i `utils_input_sanitization.R` der saniterer både values + names.

**Severity:** LOW — defensive, kalibreret threat-model gør reel risiko meget lav. Defer indtil shared-disk-export-flow eksisterer.

---

### 🟢 H3 — Validator-krav til Indstillinger-ark altid opfyldt (header behandles som data) (LOW, parser-inkonsistens)

**Lokation:** `R/fct_file_validation.R:210-218` vs. `R/fct_spc_file_save_load.R:218-227`

**Symptom:** Validator kalder `read_excel(skip=2, col_names=c("key","value"))`. Når `col_names` er en character vector tolker readxl første ikke-skipped række som data — ergo "Felt"/"Værdi"-headeren bliver indlæst som første data-række. `nrow(settings) == 0` rammer kun hvis arket er fuldstændigt tomt fra row 3 nedefter; et ark med kun header passerer.

**Verifikation:**

`R/fct_file_validation.R:210-216`:
```r
settings <- read_excel(skip = 2, col_names = c("key", "value"))
# Header bliver første data-row
```

vs. `R/fct_spc_file_save_load.R:218-227` (parser):
```r
read_excel(col_names = TRUE)  # Inkonsistent med validator
```

**Konsekvens:** Beskadiget Indstillinger-ark (kun header, ingen data) passerer validator → falder gennem til `parse_spc_excel()` der returnerer NULL → restore degraderer til "tabs som almindelig Excel". Graceful degradation virker, men inkonsistent med intentionen om at fange korrupte filer tidligt (per kommentar `R/fct_file_validation.R:189-191`).

**Foreslået fix:** Brug samme parser-kontrakt (`col_names = TRUE`) i validator, eller tilføj `nrow(settings) < 1` med justeret skip.

**Severity:** LOW — graceful degradation virker; validator-fejlen rammer kun edge-case (manuelt redigeret Excel med kun header).

---

## VERIFIED SAFE

- **Multi-sheet biSPCharts-detektion** (`R/utils_server_paste_data.R:207`, `R/fct_excel_sheet_detection.R:95-100`): "Data" + "Indstillinger" kræves; ekstra sheets (SPC-analyse + andre) bryder ikke detektionen.
- **Round-trip header-row alignment** (`INDSTILLINGER_HEADER_ROWS = 2L`): write `startRow=3` matcher read `skip=2, col_names=TRUE` korrekt.
- **ZIP-bomb guard** (`R/fct_file_validation.R:158-176`): kører via `unzip(list=TRUE)` før `read_excel`; sequencing korrekt i `setup_file_upload` og `setup_paste_data_observers`.
- **Filename byte-cap** (`spc_save_filename` `R/utils_server_wizard_gates.R:97-109`): bruger `str_trunc(safe_title, 50)` → max ~100 UTF-8 bytes + suffix; sikkert under 255-byte FS-grænse. Cycle E NEW3-bekymringen aktualiseres ej her.
- **Date/POSIXct paste-text** (`excel_data_to_paste_text`): test-coverage `tests/testthat/test-utils-server-paste-data.R:39-48` bekræfter Date-type bevares ved `[[i]]`-extract.
- **CSV formula injection** (cell-værdier): saniteres for alle tre data-arks character-kolonner via `sanitize_csv_output()`.
- **Sheet-picker JS-injection**: `jsonlite::toJSON(sheet_name, auto_unbox = TRUE)` JSON-escaper sheet-navne i `build_excel_sheet_dropdown_items` (`R/utils_server_paste_data.R:387-394`); label vises via `htmltools::htmlEscape`.
- **Tomme rækker preprocessing** (`R/fct_file_validation.R:531-547`): `dplyr::if_all` predicate håndterer mixed types (numeric/logical/character) korrekt.

---

## Logic Trace

**Excel save:** `download_spc_file` → `spc_save_content()` (utils_server_wizard_gates.R:111) → `collect_metadata(input)` + `build_export_plot()` → `build_spc_excel(data, metadata, qic_data, analysis_options)` → `build_spc_analysis_sheet()` (når qic_data ≠ NULL) → `.write_spc_analysis_sheet()` → `saveWorkbook()`.

**Brudt link (H1):** `analysis_options` mangler `freeze_position`/`phase_names` → Sektion A `Frozen til række` + Sektion B `Phase-navn` altid tomme.

**Excel load:** `direct_file_upload` → `validate_uploaded_file()` (zip-bomb + Indstillinger-skim) → `list_excel_sheets` + `is_bispchart_excel_format` → hvis biSPCharts → `handle_excel_upload` → `parse_file → parse_excel_file` → `parse_spc_excel(sheets=...)` → restore via `apply_state_transition`. Ellers single-sheet direct-read eller multi-sheet picker (`pending_excel_upload` → `selected_excel_sheet` observer).

---

## Filer der modificeres ved implementation

| Prio | Fil | Ændring |
|------|-----|---------|
| H1 | `R/utils_server_wizard_gates.R:122-133` | Ekstraher freeze_position + phase_names i analysis_options |
| H2 | `R/utils_input_sanitization.R` | (DEFER) Header-sanitization som dedikeret helper |
| H3 | `R/fct_file_validation.R:210-218` | Brug col_names=TRUE for parity med parser |

---

## Konsolideret prioritering

| Rank | ID | Område | Forventet gevinst | Risiko |
|------|----|--------|-------------------|--------|
| 1 | H1 | Freeze_position + phase_names i analysis_options | Spec-compliance + complete Sektion A/B | Lav (kræver 1 helper-call + test) |
| 2 | H3 | Validator-parity med parser | Tidlig fejl-detection for korrupte ark | Triviel |
| — | H2 | (DEFER) Header-sanitization | Defense-in-depth | Trusselsmodel-kalibreret = lav prio |

---

## Codex adversarial-review konsekvens (2026-05-10)

Verdict: **needs-attention** — H1 + H2 + H3 confirmed, men 2 fix-recipes broken/risky:

**Bekræftet:**
- H1: Spec-divergens real (analysis_options mangler freeze_position + phase_names)
- H2: Header-injection real (kalibreret LOW per threat-model)
- H3: Validator-inkonsistens real (graceful degradation virker)
- Verified safe: alle 7 punkter confirmed

**Recalibreret:**
1. **H1 phase_names recipe BROKEN:** Min `unique(as.character(qic_data$part))` ville skrive integer part-IDs (1, 2, 3) som "Phase-navn" — duplikerer Part-kolonnen og ser falsk ud som user-labels. Codex empirisk: `qic_data$part` er auto-genereret integer fra `part_var`-input, ej user-labels. **Korrekt:** Implementer kun `freeze_position`. Lade `phase_names = NULL` indtil eksplicit label-source kontrakt eksisterer.

2. **H2 startsWith snippet DEFEKT:** Min `startsWith(names, c("=","+","-","@"))` er pairwise-vectorized/recycled — for 3 names returnerer length-4 logical → subscript-mismatch-error. **Korrekt:** `vapply(names, function(nm) any(startsWith(nm, formula_chars)), logical(1))`.

**Læring:** R's `startsWith` recycler arguments pairwise (klassisk fælde). Codex empirisk verificerede via R-session: 3 names + 4 prefixes → length-4 result.
