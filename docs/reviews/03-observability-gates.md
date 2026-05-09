# Cycle F — Observability + Quality Gates

**Status:** Claude review + Codex adversarial reconciled (2026-05-09). Område: structured logging, CI-gates, pre-push/pre-commit hooks, test-classification-manifest, lintr-config, observer-monitoring, shinylogs, audit-scripts.

**Codex peer-review konsekvens:** 3 fund recalibreret (H1 fix-strategi, H2 detection-bredde, H3 broken fix-snippet). 1 NYT fund (M3) afsløret af Codex's empiriske grep — test introduceret i Cycle B selv bryder pattern Cycle B lærte om.

**Worktree:** `/Users/johanreventlow/R/biSPCharts-reviews` på `review/program-base` (synced med develop @ ccb36ec1).

**Driver:** Cycle B post-merge fail-trail dokumenterede 2 gentagne `readLines(test_path(...))`-fejl + classify_tests YAML-duplicate-bug + log-context-filter-bug (pre-cycle). Cycle F formål: maskinelle gates der forhindrer recurrence.

---

## Findings (prioriteret)

### 🔴 H1 — Pre-push + pre-commit manifest-sync grep matcher kun stanza-overskrifter (HIGH)

**Lokation:**
- `dev/git-hooks/pre-push:139` (blokerende check)
- `dev/git-hooks/pre-commit:73` (warning-check)

**Symptom:** Begge hooks bruger `grep -E '^[+-]\s*(Imports|Remotes|Depends):'` til at detektere DESCRIPTION-ændringer. Pattern matcher KUN linjer der starter med stanza-overskriften (fx `+Imports:`). Tilføjelse af et nyt pakke-navn under en eksisterende stanza-overskrift matcher IKKE.

**Verifikation (typisk diff når ny dependency tilføjes):**
```
   Imports:
       BFHcharts (>= 0.7.2),
+      newpackage (>= 1.0),
       BFHllm (>= 0.1.1),
```
Linjen `+      newpackage (>= 1.0),` starter med `+      newpackage`, ikke `+Imports:` → grep returnerer tomt → gate aktiverer ikke.

**Konsekvens:** Den primære use-case (ny dependency uden manifest-regen) passerer silent. `~/.claude/fix-patterns.jsonl` dokumenterer recurrence=4 for "manifest-stale Connect Cloud-deploy". Gaten dækker ikke den faktiske recurrence.

**Foreslået fix (REVIDERET efter Codex):** Brug DCF-parse (ikke broad git-diff). Codex argumenterede: broad `git diff -- DESCRIPTION` blokerer ALLE DESCRIPTION-ændringer (Authors, Description-tekst, Date) selv hvor manifest-regen ikke er nødvendig. DCF-parse sammenligner kun `Imports`/`Remotes`/`Depends`-feltværdier mellem REMOTE_BASE og HEAD.

```bash
# pre-push:139 (og parallel i pre-commit:73)
if [ -n "$REMOTE_BASE" ]; then
  desc_changed=$(Rscript -e '
    args <- commandArgs(TRUE)
    base_desc <- system(sprintf("git show %s:DESCRIPTION", args[1]), intern = TRUE)
    head_desc <- readLines("DESCRIPTION")
    parse_imports <- function(lines) {
      d <- read.dcf(textConnection(lines), fields = c("Imports", "Remotes", "Depends"))
      paste(sort(unlist(strsplit(paste(d, collapse = ","), ","))), collapse = "|")
    }
    cat(if (parse_imports(base_desc) != parse_imports(head_desc)) "1" else "0")
  ' "$REMOTE_BASE" 2>/dev/null)
  manifest_changed=$(git diff --quiet "$REMOTE_BASE"...HEAD -- manifest.json || echo "1")
  if [ "$desc_changed" = "1" ] && [ "$manifest_changed" != "1" ]; then
    # ... blokér push med samme besked som nu
  fi
fi
```

Trade-off: kræver R i pre-push (allerede tilfældet for andre checks). Robust mod whitespace, kommentarer og rækkefølge-ændringer.

**Severity:** HIGH — eksisterende gate giver falsk tryghed; recurrence=4 historik beviser den faktiske risiko.

---

### 🟡 H2 — Lintr/pre-commit gap: ingen check for `readLines(test_path(...))`-antipattern (MEDIUM)

**Lokation:**
- `.lintr:14-21` (custom-rules sektion)
- `dev/git-hooks/pre-commit` (mangler grep-check)

**Symptom:** Tests der scanner `R/`-kilder via `readLines(test_path("../../R/foo.R"))` virker i `devtools::test()` (source-tree-adgang) men FEJLER i R CMD check (pakken installeres uden plain `.R`-filer). Dokumenteret 2× i Cycle B alene (PR #669 + #675).

**Verifikation:** `.lintr` indeholder kun `seed_rng_linter` som custom rule. Pre-commit har grep-checks for non-ASCII (linje 43-65) og state-disciplin (linje 84+) men ingen for source-tree-test-pattern. Memory `feedback_post_merge_ci_gotchas.md` punkt 2 dokumenterer "GENTAGEN FEJL — verificeret 2× i Cycle B" — manuelt dokumenteret pattern fanger ikke nye instances uden maskinel håndhævelse.

**Codex empirisk fund (BLOKKERING):** Codex grep'ede tree og fandt at **eksisterende test `tests/testthat/test-navigation-no-double-emit.R:14-17` allerede bruger den problematiske pattern** — bare med variable-assigned path:
```r
source_file <- testthat::test_path("..", "..", "R", "fct_file_operations.R")
skip_if_not(file.exists(source_file), "fct_file_operations.R ikke fundet")
source_lines <- readLines(source_file, warn = FALSE)
```

Min foreslåede grep `readLines\s*\(\s*(testthat::)?test_path` ville **ikke** matche dette (variabel mellem `readLines(` og `test_path(`). Se `M3` for konsekvens af denne specifikke test.

**Foreslået fix (REVIDERET efter Codex):** Custom lintr-regel modeleret efter `dev/lintr_seed_rng.R` (durable solution). Detekterer:
- Direkte: `readLines(test_path(...))`, `readLines(testthat::test_path(...))`
- Variable-baseret: `x <- test_path(...); readLines(x)` (track assignment-flow inden for samme test_that-blok)
- Wrapper: `readLines(file.path(test_path(...), ...))`

Implementation-skitse:

```r
# dev/lintr_no_test_source_read.R
no_test_source_read_linter <- function() {
  lintr::Linter(function(source_expression) {
    pd <- source_expression$parsed_content
    if (is.null(pd)) return(list())
    
    # Find alle test_path()-kald + deres assignment-targets
    test_path_calls <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$text == "test_path", ]
    # Track assigned variables (LEFT_ASSIGN parent)
    # Find readLines(...)-kald hvor argument = enten test_path() direkte
    # eller variable assigned fra test_path()
    # ...
  })
}
```

Plug-in i `.lintr` linje 18 i `custom`-listen.

**Pre-commit grep som temporary stopgap:** `grep -nE 'readLines.*test_path|readLines.*\.\./.*\.R'` fanger 80% af tilfælde. Tydeligt dokumenteret som "ikke komplet — lintr-regel er den durable løsning".

**Severity:** MEDIUM — ej user-facing fejl, men gentagen dev-friction der koster CI-cycles + mental load.

---

### 🟡 H3 — `classify_tests::merge_with_existing()` overskriver manuelt-tilføjede entries uden `reviewed: true` (MEDIUM)

**Lokation:** `dev/classify_tests_lib.R:146-165`

**Symptom:** Hvis bruger manuelt tilføjer `rationale:`/`merge_with:`/`reviewer:` til en entry uden samtidigt at sætte `reviewed: true` (typisk midlertidig anmærkning før formel review), bliver hele entry'en silent overskrevet ved næste `Rscript dev/classify_tests.R`-kørsel.

**Verifikation (kode-citat):**
```r
lapply(auto_entries, function(auto) {
  existing <- existing_by_file[[auto$file]]
  if (is.null(existing) || !isTRUE(existing$reviewed)) {
    return(auto)        # ← Linje 158-159: silent overwrite hvis reviewed != TRUE
  }
  # Bevar existing, men sync audit_category fra auto
  existing$audit_category <- auto$audit_category
  existing
})
```

Sidegevinst-bug: filer der findes i `tests/testthat/` men ikke i `audit_data$files` falder helt ud af manifestet — `auto_entries` bygges alene fra audit-data (linje 89: `lapply(audit_data$files, ...)`). Dette matcher memory-pattern: "classify_tests.R regenererer fra forældet audit-JSON og dropper entries; tilføj nye test-filer manuelt".

**Konsekvens:** Manuelt arbejde tabes silent. Hver Cycle har krævet manuel re-add af test-classification-entries efter `classify_tests`-kørsel. Friction-skala: lav per-instance, men cumulative + gentagen.

**Foreslået fix (REVIDERET efter Codex):** Mit oprindelige snippet brugte `is.character(x) && nzchar(x)` — **fejler på character-vektorer af længde >1** (R-fejl: "the condition has length > 1") OG fanger ikke YAML-list-felter. `merge_with` er per manifest-schema "liste af filnavne" → kunne være `c("file1.R", "file2.R")` → snippet crasher.

Korrekt fix bruger en `has_value()`-predikat der håndterer alle field-typer:

```r
has_value <- function(x) {
  if (is.null(x)) return(FALSE)
  if (length(x) == 0) return(FALSE)
  # Scalar string: tom = no value
  if (is.character(x) && length(x) == 1) return(nzchar(x))
  # Vector/list: any non-NA, non-empty element
  any(!is.na(x) & nzchar(as.character(x)), na.rm = TRUE)
}

merge_with_existing <- function(auto_entries, existing_manifest) {
  if (is.null(existing_manifest) || is.null(existing_manifest$files)) {
    return(auto_entries)
  }
  existing_by_file <- setNames(
    existing_manifest$files,
    vapply(existing_manifest$files, `[[`, character(1), "file")
  )
  preservable_fields <- c("rationale", "merge_with", "reviewer",
                          "reviewed_date", "handling")
  lapply(auto_entries, function(auto) {
    existing <- existing_by_file[[auto$file]]
    if (is.null(existing)) return(auto)
    merged <- auto
    for (field in preservable_fields) {
      if (has_value(existing[[field]])) merged[[field]] <- existing[[field]]
    }
    merged$reviewed <- isTRUE(existing$reviewed)
    merged
  })
}
```

**Test-coverage (KRÆVET):**
```r
test_that("merge_with_existing preserves multi-item merge_with", {
  auto <- list(list(file = "test-foo.R", audit_category = "unit"))
  existing <- list(files = list(list(
    file = "test-foo.R",
    rationale = "consolidated with bar+baz",
    merge_with = c("test-bar.R", "test-baz.R"),
    reviewed = FALSE
  )))
  result <- merge_with_existing(auto, existing)
  expect_equal(result[[1]]$merge_with, c("test-bar.R", "test-baz.R"))
  expect_equal(result[[1]]$rationale, "consolidated with bar+baz")
})
```

Bonus: tilføj filesystem-scan i `auto_classify()` så test-filer udenfor audit-data bevares (audit-data kan være forældet uden at det skal koste manifest-entries).

**Severity:** MEDIUM — silent data-loss, men workaround-kendt (manuel re-add).

---

### 🟡 H4 — TEST_EXIT-check er dead code under `set -e` (LOW-MEDIUM, fragility)

**Lokation:** `dev/git-hooks/pre-push:30, 207, 226, 251-255`

**Symptom:** `set -euo pipefail` på linje 30 betyder shell aborter øjeblikkeligt ved første non-zero exit fra `Rscript - <<REOF`. Linjerne `TEST_EXIT=$?` (207, 226) og det matchende check `if [ "$TEST_EXIT" -ne 0 ]; then exit 1; fi` (251) nås aldrig ved fejl.

**Verifikation:**
```bash
set -euo pipefail
...
  Rscript - <<'REOF'
  ...
  REOF
  TEST_EXIT=$?     # line 207 — uncovered branch under set -e
...
if [ "$TEST_EXIT" -ne 0 ]; then    # line 251
  exit 1
fi
```

**Konsekvens:** Funktionel adfærd er korrekt (Rscript-fejl ⇒ shell aborter via set -e). MEN safety-net'et ser komplet ud uden at være det. Hvis nogen senere fjerner `set -e` (fx for selektiv error-handling), bryder gaten lydløst — fejlede tests vil ikke blokere push.

**Foreslået fix:** Enten (a) fjern `TEST_EXIT`-checks som vildledende dead code + tilføj kommentar om at `set -e` styrer fejl, eller (b) wrap heredoc i `set +e; Rscript ...; TEST_EXIT=$?; set -e` så check'et bliver reelt. Option (a) er mindst kode-ændring.

**Severity:** LOW — ingen nuværende impact, men trap-risiko ved senere refactor.

---

### 🟡 H5 — CI-gate-asymmetri: develop-push får ikke warning-gate (LOW, design tradeoff)

**Lokation:** `.github/workflows/R-CMD-check.yaml:73-77, 80-85, 128-132`

**Symptom:** Smoke-job (alle pushes inkl. develop) bruger `error-on: '"error"'` med `--no-tests`. Warning-gate (`error-on: '"warning"'` + tests) kører kun på `pull_request → master` eller tag-push:

```yaml
# R-CMD-check (smoke, alle pushes):
error-on: '"error"'
args: 'c("--no-manual", "--no-tests")'

# R-CMD-check-gate (warning + tests, kun PR→master + tags):
if: >
  (github.event_name == 'pull_request' && github.base_ref == 'master') ||
  (github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v'))
```

**Konsekvens:** Nye WARNINGs introduceret via PR→develop slipper igennem merge. De fanges først ved senere develop→master release-PR — på det tidspunkt er warning-source begravet i mange commits og bisect bliver dyrere. Memory `feedback_post_merge_ci_gotchas.md` dokumenterer tre separate hotfix-PRs i Cycle A alene drevet af denne asymmetri.

**Foreslået fix:** Tilføj `pull_request → develop` til gate's `if`-betingelse:

```yaml
if: >
  (github.event_name == 'pull_request' && github.base_ref == 'master') ||
  (github.event_name == 'pull_request' && github.base_ref == 'develop') ||
  (github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v'))
```

Cost: hver PR→develop får tests + warning-gate (~5-10 min ekstra CI-tid per PR). Benefit: warnings fanges ved PR-tidspunkt → bisect peger på rigtig PR.

Alternativ: behold develop-push smoke-only men tilføj pre-merge-gate til ALLE PRs uanset target. Mere konservativt: kun develop-push får `error-on: '"warning"'` (uden tests, hurtig).

**Severity:** LOW — design tradeoff (CI-cost vs catch-rate). Anbefaling: implementer hvis cycle-frekvensen rev op igen, ellers monitor.

---

### 🟢 M1 — Doc-comment om context-filter på `log_warn`/`log_error` er stale post-#662 (TRIVIAL)

**Lokation:** `R/utils_logging.R:469-470` (log_error roxygen) + tilsvarende på log_warn

**Symptom:** PR #662 fjernede `.should_log_context()`-check fra log_warn + log_error (verified develop:line 440-444, 493-498). Men roxygen-doc-comment har stadig:

```r
#' **Kontekst-filtrering:**
#' Understoetter samme kontekst-filtrering som `log_debug()` via `spc.debug.context` option.
```

Dette er nu MISVISENDE — funktionen ignorerer eksplicit filter (per inline NOTE-blok linje 440-444 + 493-498).

**Foreslået fix:** Erstat doc-section med:
```r
#' **Kontekst-filtrering:**
#' WARN/ERROR-niveau er bevidst eksempt fra `spc.debug.context`-filtret
#' (warnings/errors skal altid synes uafhængigt af aktive debug-contexts).
```

**Severity:** TRIVIAL — confused-by-doc, ej functional. Quick fix sammen med andre commits.

---

### 🔴 M3 — `test-navigation-no-double-emit.R` er silent-skipping i R CMD check (MEDIUM, NYT — Codex empirisk fund)

**Lokation:** `tests/testthat/test-navigation-no-double-emit.R:14-17`

**Symptom:** Test introduceret i Cycle B M2 (commit 7fca1d14, 2026-05-09) for at forhindre regression af `navigation_changed` double-emit-pattern. Test bruger:

```r
source_file <- testthat::test_path("..", "..", "R", "fct_file_operations.R")
skip_if_not(file.exists(source_file), "fct_file_operations.R ikke fundet")
source_lines <- readLines(source_file, warn = FALSE)
```

I `devtools::test()`: source_file findes → grep kører → test enforcer regression. **I R CMD check:** source_file findes IKKE (pakken installeres uden plain `.R`-filer i `<pkg>/R/`-tree fra test-perspektiv) → `skip_if_not()` skipper silent → **regression IKKE enforced i CI-gate**.

**Verifikation (Codex empirisk grep + min Read):** Filens linje 14+17 bekræftet. `skip_if_not(file.exists(source_file), ...)` linje 15 = explicit silent-skip-mechanism.

**Konsekvens:** Test introduceret i Cycle B for at fange double-emit-regression. Test ser ud som beskyttelse i pre-merge CI. **Aktivt false confidence:** test passerer altid (skipped) i R CMD check — hvis nogen genindfører double-emit, fanger gate det ikke. Værre end ingen test, fordi fremtidigt review ser test-filen og tror beskyttelse er på plads.

**Ekstra-uheldigt:** Filen blev introduceret i SAMME Cycle B hvor vi lærte om antipattern. To timer efter PR #669-fixet readLines-pattern, blev pattern genindført i ny test under skip_if_not-cover. Eksakt det `feedback_post_merge_ci_gotchas.md` punkt 2 advarer om: "DOKUMENTERET MØNSTER FANGER IKKE NYE TILFÆLDE UDEN SHJEKKLISTE".

**Foreslået fix:** Konverter til `body()`-introspection af `handle_file_load` / `load_excel_data` / etc.:

```r
test_that("fct_file_operations.R indeholder ikke direct emit$navigation_changed efter data_updated", {
  require_internal("handle_file_load", mode = "function")  # eller relevant funktions-navn
  body_text <- paste(deparse(body(handle_file_load)), collapse = "\n")
  
  # Find positions af data_updated + navigation_changed-emits
  data_updated_pos <- gregexpr("emit\\$data_updated", body_text)[[1]]
  nav_changed_pos <- gregexpr("emit\\$navigation_changed", body_text)[[1]]
  
  # Verificér ingen navigation_changed i kort afstand efter data_updated
  for (du_pos in data_updated_pos) {
    nearby <- nav_changed_pos[nav_changed_pos > du_pos & nav_changed_pos < du_pos + 200]
    expect_length(nearby, 0)
  }
})
```

Eller hvis funktionerne ej er eksporteret/findbare via `body()`: ophæv test til integration-test der reelt trigger file-load + tæller emit-kald via mock-emit.

**Severity:** MEDIUM — eksisterende false-positive-beskyttelse er værre end ingen beskyttelse. Skal fixes som del af H2-implementation (lintr-regel ville fanget dette OG begge readLines-fejl Cycle B fixede).

---

### 🟢 M2 — `.redact_secrets()` matcher kun field-NAMES, ej værdier (LOW, defense-in-depth)

**Lokation:** `R/utils_logging.R:250-263`

**Symptom:** Redaction-pattern `"(?i)(key|token|pat|password|secret|credential)"` matcher kun `names(details)`. Følgende lækker hvis det videregives til `details`-parameter:
- Værdier der ligner CPR-numre (`DDMMYY-XXXX`) under field-name `user_id`
- API-key-værdier under field-name `api_response`
- Email-adresser under field-name `submitted_by`

Eksempel:
```r
log_info("User action", details = list(user_id = "120875-1234"))
# Logs: "User action [user_id=120875-1234]" — CPR i log
```

**Konsekvens (kalibreret threat-model):** Memory dokumenterer biSPCharts ej håndterer PHI på normal vis (kvalitetsdata på domain-joined hospital-PCs). PHI-grade redaction er overdrevet. MEN: defense-in-depth opportunity hvis log-ouputs en dag eksporteres til ekstern observability-platform eller delt-disk.

**Foreslået fix (KUN hvis bruger ønsker):** Tilføj value-pattern-match som supplement:

```r
.redact_secrets <- function(details) {
  if (is.null(details) || length(details) == 0) return(details)
  secret_field_pattern <- "(?i)(key|token|pat|password|secret|credential)"
  # Defense-in-depth: redact values der ligner CPR/api-keys uanset field-navn
  cpr_pattern <- "\\b\\d{6}-\\d{4}\\b"
  apikey_pattern <- "\\b[A-Za-z0-9_]{32,}\\b"
  lapply(seq_along(details), function(i) {
    nm <- names(details)[i]
    val <- details[[i]]
    if (!is.null(nm) && grepl(secret_field_pattern, nm, perl = TRUE)) return("***REDACTED***")
    if (is.character(val) && length(val) == 1) {
      if (grepl(cpr_pattern, val)) return("***CPR-REDACTED***")
      if (grepl(apikey_pattern, val) && nchar(val) > 32) return("***KEY-REDACTED***")
    }
    val
  }) |> setNames(names(details))
}
```

**Severity:** LOW — afhænger af om logs nogensinde forlader hospital-tier. Defer indtil konkret krav opstår.

---

## Dismissed (verificeret afvist)

### ❌ Pre-cycle: log_warn/log_error context-filter-bypass — FIXED PR #662

Tidligere session etablerede dette som åben bug. Verificeret nu på develop (`R/utils_logging.R:440-444, 493-498`) at PR #662 fjernede `.should_log_context()`-check fra begge funktioner. Inline NOTE-kommentarer dokumenterer eksplicit at WARN/ERROR er eksempt. Regression-test landede i `tests/testthat/test-logging.R`.

### ❌ `loadDataLocally`/`clearDataLocally` "silent failure" — NOT silent

`R/utils_local_storage.R:252-254, 269-271` har `fallback = function(e) { # Load failed silently }` — kommentaren er misvisende. `safe_operation()` (R/utils_error_handling.R:91-161) logger `log_error()` med 3-level fallback INDEN fallback-funktionen kaldes. Faktisk logging sker. Eneste reelle problem: kommentar læser misvisende.

**Trivial-fix:** Opdater kommentar til `# Fallback: log allerede skrevet via safe_operation, intet yderligere needed`. Inkluder evt. i M1-doc-cleanup-commit.

### ❌ `fct_spc_validate.R` har 0 log-kald

Validate kaster `spc_input_error` via `spc_abort()`. Errors propagerer til `compute_spc_results_bfh` (facade), som har `safe_operation` i `mod_spc_chart_compute.R:264-288` med eksplicit `log_error("Graf-generering fejlede:", e$message, .context = "SPC_PIPELINE")`. Validation-fejl ER logget — bare på outer-layer ikke i validate self.

**Mini-finding (ej action):** Outer log mangler structured `details` om hvilken validation-regel fejlede (x_var, y_var, chart_type). Forbedring kunne være `log_error(..., details = list(rule = ..., x_var = ..., y_var = ...))`. Defer indtil konkret debug-issue opstår.

---

## Filer der modificeres ved implementation (REVIDERET efter Codex)

| Prio | Fil | Ændring |
|------|-----|---------|
| H1 | `dev/git-hooks/pre-push:139` + `dev/git-hooks/pre-commit:73` | DCF-parse comparison af Imports/Remotes/Depends mellem REMOTE_BASE og HEAD |
| H2 | `dev/lintr_no_test_source_read.R` (NY) + `.lintr:18` (plug-in) | Custom lintr-regel der detekterer source-tree-reads (også via variable-assignment) |
| M3 | `tests/testthat/test-navigation-no-double-emit.R:13-36` | Konverter til `body()`-introspection eller integration-test |
| H3 | `dev/classify_tests_lib.R:146-165` + ny test | `has_value()`-predicate-baseret merge der håndterer list-felter; regression-test for multi-item `merge_with` |
| H4 | `dev/git-hooks/pre-push:207, 226, 251-255` | Fjern `TEST_EXIT` dead code + dokumenter `set -e`-styring |
| H5 | `.github/workflows/R-CMD-check.yaml:80-85` | Tilføj `pull_request → develop` til gate-trigger |
| M1 | `R/utils_logging.R:469-470` (+ log_warn) | Opdater stale doc-section om context-filter |
| M2 | `R/utils_logging.R:250-263` | (DEFER) Value-pattern-redaction kun hvis ønsket |

---

## Verifikation efter implementation

**H1 manifest-grep regression-test:**
```bash
# Setup: branch der KUN ændrer pakke-navn under eksisterende stanza
git checkout -b test-h1-fix
sed -i.bak 's/BFHcharts (>= 0\.7\.2)/BFHcharts (>= 0.7.2),\n  newpackage (>= 1.0)/' DESCRIPTION
git add DESCRIPTION && git commit -m "test: add new dep without manifest"
git push  # → SKAL fail med manifest-stale-error
```

**H2 readLines+test_path regression:**
```bash
# Setup: stage en test der bruger antipattern
echo 'test_that("bad", { readLines(test_path("../../R/foo.R")) })' > tests/testthat/test-bad.R
git add tests/testthat/test-bad.R && git commit  # → SKAL fail med antipattern-besked
```

**H3 classify_tests merge-bevarelse:**
```bash
# Manuelt rediger en entry til at have rationale uden reviewed: true
# Kør: Rscript dev/classify_tests.R
# Verificér: rationale bevaret i output
```

**H4 dead-code:** Code-review før merge — ingen runtime-test nødvendig.

**H5 CI gate:** Næste PR→develop SKAL trigger gate-job. Verificér via `gh pr checks <PR>`.

---

## Konsolideret prioritering (REVIDERET efter Codex)

| Rank | ID | Område | Forventet gevinst | Risiko |
|------|----|--------|-------------------|--------|
| 1 | H1 | Pre-push/pre-commit DCF-parse manifest-check | Forhindrer recurrence=4-fejl maskinelt + ej falsk-positiv blokering | Lav (R i pre-push allerede etableret) |
| 2 | H2 + M3 | Custom lintr-regel for source-tree-reads + fix eksisterende test | Forhindrer 2 verificerede gentagne fejl + fjerner false-positive beskyttelse | Lav-Medium (kræver lintr-impl) |
| 3 | H3 | `has_value()`-baseret classify_tests merge + regression-test | Stop silent data-loss på manifest, korrekt list-handling | Lav (test required) |
| 4 | M1 | Doc-cleanup post-#662 | Konsistens; quick win | Triviel |
| 5 | H4 | TEST_EXIT dead code | Defense mod fremtidig refactor | Triviel |
| 6 | H5 | CI gate til PR→develop | Tidligere warning-detection | Medium (CI-cost) |
| — | M2 | Value-pattern-redaction | Defense-in-depth | DEFER til konkret krav |

---

## Codex adversarial-review konsekvens (2026-05-09)

Codex's verdict: **needs-attention** — ej "no-ship" på findingen-niveau, men 3 specifikke fix-detaljer skal recalibreres.

**Bekræftet:**
- H1 confirmed (anbefaler DCF-parse, ej broad git-diff)
- H2 confirmed BUT undersized (eksisterende variable-assigned pattern misses)
- H3 confirmed BUT broken fix-snippet (length>1 character-vector + list-felt-handling)
- H4 confirmed dead code, ingen aktuel impact
- H5 confirmed cost/policy tradeoff
- M1 confirmed trivial
- M2 confirmed teknisk, immateriel under threat-model

**Recalibreringer integreret i ovenstående:**
1. **H1 fix-strategy:** DCF-parse via Rscript (precis, robust mod whitespace), ikke broad `git diff -- DESCRIPTION` (falsk-positive på Author/Description-tekst-ændringer)
2. **H2 detection-tilgang:** Custom lintr-regel (durable) over grep (stopgap). Lintr fanger variable-assigned + wrapper-patterns; grep gør ikke.
3. **H3 fix-snippet:** `has_value()`-predikat der håndterer NULL, length-0, scalar string, vector, list. Mit oprindelige `is.character(x) && nzchar(x)` errored på multi-item `merge_with`.

**Bonus-finding (ej Cycle F):** Codex's første pass (off-target) fandt ægte bug i deferred Cycle B `multi-tab-conflict-detection`-OpenSpec-proposal — bruger nonexistent `schema_version`-key i stedet for faktiske `version`-key (per `LOCAL_STORAGE_SCHEMA_VERSION` + `autoSaveAppState`). Skal fixes når proposal aktiveres.

---

## Læringer (Cycle F)

1. **Codex empiriske grep finder false-confidence-tests.** M3 (Cycle B's egen test bryder pattern Cycle B lærte om) ville aldrig være fundet uden Codex's `rg`-scan. Mit subagent-review missede pattern under skip_if_not-cover.

2. **Lintr/grep-distinktionen er reel.** Codex argumenterede stærk for lintr over grep: variable-assigned patterns + wrappers gør grep utilstrækkelig. Vores eksisterende test beviser pointet empirisk.

3. **Fix-snippet code-review er essentiel.** Mit H3-snippet ville crashed runtime på multi-item `merge_with` — Codex fanget via type-analyse. Lesson: kør foreslåede snippets gennem mental type-check FØR commit.

4. **Off-target Codex-runs har værdi.** Første pass review'ede uventet diff-area (deferred Cycle B work) men fandt reel bug. Behold output som bonus-fund snarere end re-run-spild.

5. **Documenterede memory-mønstre er ikke nok uden maskinelle gates.** Cycle B introducerede `test-navigation-no-double-emit.R` MED kendskab til readLines-pattern fra PR #669 to timer tidligere. Manuel diskpline failer; lintr-regel ville have blokeret commit.
