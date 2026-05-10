# Cycle D — Data Validation + Dansk Parsing

**Status:** Claude review + Codex adversarial reconciled (2026-05-10). Område: CSV/Excel parsing, danish locale (decimal-comma, dato-formater, æøå), encoding (UTF-8/latin1), column-type-autodetect, NA-handling, input-validering.

**Codex peer-review konsekvens:** 3 fix-recipes recalibreret (H2 ville crasje runtime, M1 ville silent-corrupt point-decimaler, H3 threshold=0.5 ville reject sparse clinical-paste-data). H1 confirmed standalone.

**Worktree:** `/Users/johanreventlow/R/biSPCharts-reviews` på `review/program-base` (synced med develop @ 17dfb72f).

**Driver:** biSPCharts håndterer kvalitetsdata fra hospital-PCer (dansk locale, danske dato-formater, decimal-komma, latin1-eksporter fra Excel). Data-fidelity = patient-sikkerhed via correct SPC-aggregering. Cycle D leder reelle correctness-bugs i parsing-pipeline.

---

## Findings (prioriteret efter REEL clinical-data-fidelity-impact)

### 🔴 H1 — `is_column_numeric()` afviser danish-comma decimal-strings (HIGH, empirisk bekræftet)

**Lokation:** `R/fct_spc_helpers.R:15-25` + call-sites:
- `R/mod_spc_chart_server.R:196` (Y-axis-validering)
- `R/utils_spc_chart_ui_helpers.R:76` (UI-helper)

**Symptom:** Heuristikken bruger `as.numeric(as.character(non_na))` der ikke håndterer komma som decimal-separator. Karakter-kolonner med danske tal (`"12,5"`, `"0,73"`, `"3,14"`) returnerer success-rate 0 → falsk-negativ → "Den valgte Y-akse-kolonne indeholder ikke numeriske data"-fejl.

**Verifikation (empirisk):**
```r
source("R/fct_spc_helpers.R")
is_column_numeric(c("12,5", "0,73", "3,14"))  # FALSE — BUG
is_column_numeric(c("12.5", "0.73", "3.14"))  # TRUE  — punktum-form OK
```

Kode-citat:
```r
is_column_numeric <- function(col, threshold = 0.5) {
  if (is.numeric(col)) { return(TRUE) }
  non_na <- col[!is.na(col)]
  if (length(non_na) == 0) { return(TRUE) }
  parsed <- suppressWarnings(as.numeric(as.character(non_na)))  # ← bug: ej danish-aware
  sum(!is.na(parsed)) / length(non_na) >= threshold
}
```

**Konsekvens:** Klinisk Y-akse-validering viser falsk fejl hver gang kolonnen er karakter-typed med komma-decimaler — typisk efter:
- localStorage-roundtrip (JSON-serialisering preserves character-type)
- CSV-parsing falder tilbage til komma-strategi
- Excel-eksport hvor numeric-kolonne blev gemt som tekst

Bruger får tomt diagram + uklar fejl. Worst case: bruger tror appen er broken.

**Foreslået fix:** Skift til `parse_danish_number(as.character(non_na))` (samme pattern bruges allerede i `fct_autodetect_helpers.R:226, 433, 513`):
```r
parsed <- parse_danish_number(as.character(non_na))
```

**Severity:** HIGH — direkte clinical-data-fidelity-impact + hyppig user-facing fejl.

---

### 🔴 H2 — CSV-upload har ingen latin1/Windows-1252 fallback (HIGH, asymmetri med paste-flow)

**Lokation:** `R/fct_file_parse_pure.R:56-142` (parse_csv_file alle 3 strategier) + `R/fct_file_operations.R:443` (caller)

**Symptom:** `parse_csv_file` antager UTF-8 (`enc <- hints$encoding %||% UTF8_ENCODING`) og forsøger ALDRIG latin1, selv om `read_csv_detect_encoding` (`fct_file_operations.R:15-26`) allerede implementerer fallbacken — men den bruges KUN i paste-flow.

**Verifikation:**
- `R/utils_server_paste_data.R:246`: `text_content <- read_csv_detect_encoding(file_info$datapath)` ✓ med fallback
- `R/fct_file_operations.R:443`: `parse_file(file_path, format = "csv")` ✗ INGEN encoding_hints

```r
# parse_csv_file kaldes uden hints:
hints <- encoding_hints %||% list()
enc <- hints$encoding %||% UTF8_ENCODING  # → altid UTF-8 i upload-flow
```

**Konsekvens:** CSV eksporteret fra dansk Excel/Windows = Windows-1252. Disse filer parses med korrumperede æøå:
- Mojibake i kolonnenavne (autodetect fejler)
- Mojibake i dato-strings (dato-parse fejler)
- Crash hvis ugyldig UTF-8-byte-sekvens

`handle_upload_error`-meddelelsen anbefaler "Gem som UTF-8" — manuel workaround. Appen burde fallback automatisk (paste-flow gør det).

**Foreslået fix (REVIDERET efter Codex):** Min original recipe `read_csv_detect_encoding(path)$encoding` ville fejle runtime. `read_csv_detect_encoding()` returnerer character-vektor af lines (ikke objekt med encoding-field). Korrekt fix:

**Option A (refactor helper):** Ændr `read_csv_detect_encoding()` til at returnere `list(encoding = "UTF-8"|"latin1", text = lines)`:
```r
read_csv_detect_encoding <- function(file_path) {
  text <- readLines(file_path, warn = FALSE, encoding = "UTF-8")
  if (length(text) > 0 && !all(validEnc(text))) {
    text <- readLines(file_path, warn = FALSE, encoding = "latin1")
    return(list(encoding = "latin1", text = text))
  }
  list(encoding = "UTF-8", text = text)
}
```
Derefter brug i upload-flow:
```r
detected <- read_csv_detect_encoding(file_path)
parse_file(file_path, format = "csv",
           encoding_hints = list(encoding = detected$encoding))
```

**Option B (latin1 som 4. strategi):** Tilføj direct latin1-fallback i `parse_csv_file`:
```r
# Efter strategi 3 (komma+latin1-encoding-arg):
result <- safe_op(... encoding = "latin1" ...)
```

**Test:** Latin1 CSV med dansk header (`Måned;Antal\nJan;5`) skal parses korrekt. Header-name skal forblive `Måned` (ej mojibake).

**Severity:** HIGH — Excel→CSV-eksport er typisk dansk-hospital-flow.

---

### 🔴 H3 — `handle_paste_data` numeric-validering er dead code (HIGH, empirisk bekræftet)

**Lokation:** `R/fct_file_operations.R:576-587`

**Symptom:** Validering `has_numeric <- any(vapply(data, is_column_numeric, logical(1), threshold = 0))` er trivielt TRUE for enhver ej-tom kolonne. `threshold = 0` betyder `0/N >= 0` = altid TRUE.

**Verifikation (empirisk):**
```r
source("R/fct_spc_helpers.R")
is_column_numeric(c("foo", "bar"), threshold = 0)  # TRUE — DEAD CHECK
```

Kode-citat (line 576-587):
```r
has_numeric <- any(vapply(data, is_column_numeric, logical(1), threshold = 0))
# has_numeric = TRUE for ren tekst input!
if (!has_numeric) {
  # Aldrig naas
  ...
}
```

**Konsekvens:** Brugere kan paste ren tekst (kopieret prosa fra Word med tab-stops, error-strings, hjælpetekst) → validering tillader → sat som `current_data` → crasher downstream i SPC-pipeline med uklar `spc_input_error`.

**Foreslået fix (REVIDERET efter Codex):** Codex argumenterede at `threshold = 0.5` (Y-axis-quality-heuristik) er for aggressivt for paste-admission. Sparse clinical-paste-data (mange blanks/suppression-markers) kunne blive afvist trods valid numeric-kolonne.

**Korrekt fix — admission-specifik heuristik (≥1 column med ≥2 parsed numeric values):**
```r
# I handle_paste_data validering
parse_count <- function(col) {
  if (is.numeric(col)) return(sum(!is.na(col)))
  parsed <- parse_danish_number(as.character(col))
  sum(!is.na(parsed))
}
numeric_counts <- vapply(data, parse_count, integer(1))
has_numeric <- any(numeric_counts >= 2)  # mindst én column med >=2 parsed values
if (!has_numeric) {
  # Fritekst-afvisning
}
```

**Test (3 cases):**
- Pure prose paste (kopieret tekst fra Word) → `has_numeric = FALSE` → afvises ✓
- Normal numeric table (5 kolonner med tal) → `has_numeric = TRUE` → tillades ✓
- Sparse numeric (1 numeric col med 2 værdier + 4 char cols) → `has_numeric = TRUE` → tillades (admission-fornødent)

**Severity:** HIGH — input-validering helt deaktiveret. Påvirker paste-data flow.

---

### 🟡 M1 — `parse_danish_number()` håndterer ikke tusind-separator-punktum (MEDIUM)

**Lokation:** `R/utils_danish_locale.R:38-46`

**Symptom:** Funktionen fjerner mellemrum, %, ‰ — men efterlader punktum. Dansk format `"1.234,56"` → efter komma-substitution: `"1.234.56"` → `as.numeric` = NA.

**Verifikation:**
```r
x_cleaned <- gsub("[%‰]", "", x_cleaned)
x_cleaned <- gsub("\\s+", "", x_cleaned)
x_normalized <- gsub(",", ".", x_cleaned)
result <- suppressWarnings(as.numeric(x_normalized))
```

Test: `parse_danish_number("1.234,56")` → NA. Hospital-data fra Excel kan eksporteres med formattering-tusind-separatorer.

**Konsekvens:** Tællere/nævnere over 1000 i kolonne-decimal-format afvises som NA. Kan **bortfalde data uden brugerens viden** i autodetect og y-værdi-parsing.

**Foreslået fix (REVIDERET efter Codex — eksplicit ambiguity-policy):**

Min original recipe ville silent-corrupt valid point-decimaler: `parse_danish_number("1.234")` ville blive `1234` i stedet for `1.234` (Codex-bekymring).

**Korrekt fix:** Strip kun grouping-dots HVIS komma-decimal er til stede (entydig dansk format-signal):
```r
parse_danish_number <- function(x) {
  if (length(x) == 0) return(numeric(0))
  x_cleaned <- as.character(x)
  x_cleaned <- gsub("[%‰]", "", x_cleaned)
  x_cleaned <- gsub("\\s+", "", x_cleaned)
  
  # Cycle D M1 (Codex 2026-05-10): kun strip grouping-dots HVIS komma er til stede.
  # Dansk format "1.234,56" har komma som decimal -> punktum er grouping.
  # Uden komma kan "1.234" være enten 1234 (dansk grouping) eller 1.234 (point-decimal,
  # fx engelsk-eksport). Bevar konservativt som point-decimal -> as.numeric "1.234" = 1.234.
  has_comma_decimal <- grepl(",", x_cleaned, fixed = TRUE)
  if (any(has_comma_decimal)) {
    x_cleaned[has_comma_decimal] <- gsub(
      "(?<=\\d)\\.(?=\\d{3}(\\D|$))",
      "",
      x_cleaned[has_comma_decimal],
      perl = TRUE
    )
  }
  
  x_normalized <- gsub(",", ".", x_cleaned)
  result <- suppressWarnings(as.numeric(x_normalized))
  result
}
```

**Test (regression-coverage):**
- `parse_danish_number("1.234,56")` → 1234.56 (dansk grouping + decimal)
- `parse_danish_number("1.234")` → 1.234 (point-decimal preserved — INGEN silent corruption)
- `parse_danish_number("12,5")` → 12.5 (dansk decimal uden grouping)
- `parse_danish_number("1.234.567,89")` → 1234567.89 (multi-grouping + decimal)
- `parse_danish_number("1,234,567")` → NA (malformed multiple commas — fail loudly)
- `parse_danish_number("12.5")` → 12.5 (engelsk decimal preserved)

**Severity:** MEDIUM — silent data-loss for store tal med eksplicit dansk format.

---

### 🟢 L1 — `detect_csv_delimiter` auto-detect strategi mangler encoding (LOW)

**Lokation:** `R/utils_csv_delimiter_detection.R:42-56`

**Symptom:** Strategi 1 (semikolon) og 3 (komma) sender `encoding = encoding` til `readr::locale()`. Strategi 2 (auto-detect) sender intet encoding-argument.

**Verifikation:**
```r
fn = function() {
  readr::read_delim(
    path,
    delim = NULL,
    locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
    # ← Mangler: encoding = encoding
    ...
```

**Konsekvens:** Hvis semikolon-strategi fejler (fx fil med tab-separator) og auto-detect skal håndtere latin1-headers, vil header-preview-parsing kunne misfortolke æøå. Lav reel impact da semikolon/komma-strategier fungerer som primary fallback.

**Foreslået fix:** Tilføj `encoding = encoding` i `readr::locale()`-kaldet.

**Severity:** LOW — defensive, lav frekvens.

---

## Status — Cycle F H7 follow-up

### `R/fct_spc_validate.R` — UFIKSERET (0 log-kald, ingen structured details)

Cycle F H7 dokumenterede at fct_spc_validate.R har 0 log-kald og at outer-layer logger fejl uden details. Status check (Cycle D):

**Verifikation:** Filen har stadig 0 `log_*`-kald + alle 13 `spc_abort()`-kald sender kun `class = "spc_input_error"` uden strukturerede metadata via `...`, selvom `spc_abort` accepterer `...` (`utils_error_handling.R:292`).

```r
spc_abort("x_var parameter er paakraevet ...", class = "spc_input_error")
# spc_abort signatur: function(message, class, ..., call = ...)
# rlang::abort modtager ... men x_var/y_var/chart_type sendes aldrig
```

**Konsekvens:** Outer-layer logger fanger fejlmeddelelse uden context (hvilken bruger, hvilken konfiguration). Diagnose af produktionsfejl kræver ekstra brugerkontakt.

**Foreslået fix:** Tilføj `details = list(x_var = x_var, y_var = y_var, chart_type = chart_type)` til hvert `spc_abort()`-kald — eller log struktureret før abort.

**Severity:** LOW (fra cycle F-vurdering — observability-gap, ej functional bug).

---

## Filer der modificeres ved implementation

| Prio | Fil | Ændring |
|------|-----|---------|
| H1 | `R/fct_spc_helpers.R:15-25` | `parse_danish_number()` i stedet for `as.numeric()` |
| H2 | `R/fct_file_parse_pure.R:30-51` ELLER `R/fct_file_operations.R:443` | latin1-fallback i CSV-upload-flow |
| H3 | `R/fct_file_operations.R:576-587` | `threshold = 0.5` (eller separat heuristik) |
| M1 | `R/utils_danish_locale.R:38-46` | tusind-sep-detection FØR komma-substitution |
| L1 | `R/utils_csv_delimiter_detection.R:42-56` | tilføj `encoding = encoding` til auto-detect-strategi |
| (defer) | `R/fct_spc_validate.R` | Cycle F H7 — structured details (defer indtil concrete debug-need) |

---

## Verifikation efter implementation

**H1 regression:**
```r
test_that("is_column_numeric accepterer danish-comma decimal-strings", {
  expect_true(is_column_numeric(c("12,5", "0,73", "3,14")))
  expect_true(is_column_numeric(c("12.5", "0.73", "3.14")))  # eksisterende
  expect_false(is_column_numeric(c("foo", "bar")))  # negative
})
```

**H2 regression:**
```r
# Setup: latin1-encoded CSV med dansk header
test_that("parse_file håndterer latin1-CSV gracefully", {
  latin1_path <- tempfile(fileext = ".csv")
  writeBin(iconv("Måned;Antal\nJan;5", to = "latin1", toRaw = TRUE)[[1]], latin1_path)
  result <- parse_file(latin1_path, format = "csv")
  expect_equal(names(result$data), c("Måned", "Antal"))
})
```

**H3 regression:**
```r
test_that("handle_paste_data afviser ren tekst", {
  text_data <- "foo\tbar\nbaz\tqux"
  result <- handle_paste_data(text_data, app_state = ..., session_id = "test")
  expect_null(result)  # eller forventet error-toast
})
```

**M1 regression:**
```r
test_that("parse_danish_number håndterer tusind-separator", {
  expect_equal(parse_danish_number("1.234,56"), 1234.56)
  expect_equal(parse_danish_number("12,5"), 12.5)  # uændret
})
```

---

## Konsolideret prioritering

| Rank | ID | Område | Forventet gevinst | Risiko |
|------|----|--------|-------------------|--------|
| 1 | H1 | `is_column_numeric` danish-aware | Eliminér falsk Y-axis-fejl for komma-decimaler | Triviel (1 line + import) |
| 2 | H3 | paste-data threshold-fix | Genaktivér dead validering | Triviel (1 line) |
| 3 | H2 | CSV-upload latin1-fallback | Auto-håndter Windows-Excel-eksport | Lav (test-coverage krævet) |
| 4 | M1 | tusind-sep-detection | Forhindr silent data-loss | Lav (regex + tests) |
| 5 | L1 | auto-detect encoding | Defensive | Triviel |
| (defer) | F-H7 | spc_validate structured details | Observability | DEFER |

---

## Codex adversarial-review konsekvens (2026-05-10)

Verdict: **needs-attention** — H1 confirmed standalone, men 3 fix-recipes broken/risky:

**Bekræftet:**
- H1: confirmed empirisk + uafhængigt af Codex
- H2: asymmetri korrekt identificeret
- H3: dead-code-empirisk korrekt identificeret
- M1: silent-data-loss for tusind-separator confirmed
- L1: encoding-arg gap confirmed

**Recalibreret:**
1. **H2 fix-recipe runtime-broken:** Min `read_csv_detect_encoding(path)$encoding` ville fejle pga. funktion returnerer character-vektor (lines), ej objekt. Korrekt: refactor helper til at returnere `list(encoding, text)`.
2. **M1 regex silent-corrupts:** Min `(?<=\\d)\\.(?=\\d{3}(\\D|$))`-regex ville turn `1.234` til `1234` for engelsk point-decimal-format. Korrekt: kun strip grouping-dots hvis komma-decimal er til stede (entydigt dansk format-signal).
3. **H3 threshold=0.5 for aggressivt:** Sparse clinical-paste-data (1 numeric col + 4 char cols) kunne afvises. Korrekt: admission-specifik heuristik (`≥1 column med ≥2 parsed numeric values`) i stedet for kvalitetstærskel.

**Læring:** Y-axis-quality-heuristik (threshold 0.5) ≠ paste-admission-heuristik (≥1 numeric column). Genbrug af samme funktion til to forskellige formål kan være anti-pattern. Codex fanget via semantik-analyse.
