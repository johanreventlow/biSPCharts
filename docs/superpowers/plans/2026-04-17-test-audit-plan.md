# Test Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementér et reproducerbart audit-script der kategoriserer alle ~124 testfiler i `tests/testthat/` og genererer en JSON + Markdown-rapport, som beslutningsgrundlag for refactoring-scope (issue #203).

**Architecture:** Ét hovedscript (`dev/audit_tests.R`) der orkestrerer tre faser (statisk analyse, isoleret kørsel via `callr`/`processx`, rapportgenerering). Funktionalitet modulariseret i `dev/audit/*.R`-helperfiler. Klassifikationslogik isoleret og unit-testet.

**Tech Stack:** R, `processx` (subproces), `jsonlite` (JSON), `pkgload` (pakke-loading), `testthat` (test-framework + unit-tests).

**Spec:** `docs/superpowers/specs/2026-04-17-test-audit-design.md`

---

## File Structure

**Nye filer:**
- `dev/audit_tests.R` — hovedscript med CLI-parsing og orkestrering (~120 LOC)
- `dev/audit/static_analysis.R` — Fase 1-helpers (~150 LOC)
- `dev/audit/dynamic_runner.R` — Fase 2-helpers (~150 LOC)
- `dev/audit/classifier.R` — klassifikations-logik (~80 LOC)
- `dev/audit/reporter.R` — JSON + Markdown + console output (~200 LOC)
- `tests/testthat/test-audit-classifier.R` — unit-tests for klassifikator og parsers (~250 LOC)
- `dev/audit-output/.gitkeep` — placeholder for rapport-output-dir

**Genererede filer:**
- `dev/audit-output/test-audit.json` — maskinlæsbar rapport (ikke i git)
- `docs/superpowers/specs/2026-04-17-test-audit-report.md` — menneskelæsbar (committes)

**Modificerede filer:**
- `.gitignore` — tilføj `dev/audit-output/*.json`

---

## Task 0: Setup feature branch og scaffolding

**Files:**
- Create: `dev/audit/` (directory)
- Create: `dev/audit-output/` (directory)
- Create: `dev/audit-output/.gitkeep`
- Modify: `.gitignore`

- [ ] **Step 1: Opret feature branch fra master**

```
git checkout master
git pull origin master
git checkout -b feat/test-audit-203
```

Expected: på branch `feat/test-audit-203`.

- [ ] **Step 2: Opret directory-struktur**

```
mkdir -p dev/audit dev/audit-output
touch dev/audit-output/.gitkeep
```

- [ ] **Step 3: Opdater .gitignore**

Tilføj følgende til `.gitignore`:

```
# Test audit output (rapporter genereres on-demand)
dev/audit-output/*.json
!dev/audit-output/.gitkeep
```

- [ ] **Step 4: Commit scaffolding**

```
git add dev/audit-output/.gitkeep .gitignore
git commit -m "chore(audit): opret scaffolding for test-audit (#203)"
```

---

## Task 1: Statisk analyse — `extract_function_calls()`

**Files:**
- Create: `dev/audit/static_analysis.R`
- Create: `tests/testthat/test-audit-classifier.R`

- [ ] **Step 1: Skriv failing test**

Opret `tests/testthat/test-audit-classifier.R`:

```r
# ==============================================================================
# TEST SUITE: Audit helpers (#203)
# ==============================================================================
#
# Unit-tests for statisk analyse, dynamiske parsers og klassifikator i
# dev/audit/. Kører uafhængigt af biSPCharts pakke-state via isolation.
# ==============================================================================

library(testthat)

audit_dir <- file.path(rprojroot::find_root(rprojroot::is_r_package), "dev", "audit")
source(file.path(audit_dir, "static_analysis.R"))

describe("extract_function_calls()", {
  it("ekstraherer funktionsnavne fra et simpelt R-script", {
    tmp <- tempfile(fileext = ".R")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c(
      "result <- my_function(x, y)",
      "other_fn(data) |> process()"
    ), tmp)

    calls <- extract_function_calls(tmp)
    expect_true(all(c("my_function", "other_fn", "process") %in% calls))
  })

  it("returnerer character(0) for tom fil", {
    tmp <- tempfile(fileext = ".R")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(character(0), tmp)

    calls <- extract_function_calls(tmp)
    expect_equal(calls, character(0))
  })

  it("ignorerer udkommenterede funktionskald", {
    tmp <- tempfile(fileext = ".R")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c(
      "real_fn()",
      "# commented_fn()"
    ), tmp)

    calls <- extract_function_calls(tmp)
    expect_true("real_fn" %in% calls)
    expect_false("commented_fn" %in% calls)
  })
})
```

- [ ] **Step 2: Kør testen for at verificere fejl**

```
Rscript -e "testthat::test_file('tests/testthat/test-audit-classifier.R')"
```

Expected: FAIL med "could not find function 'extract_function_calls'".

- [ ] **Step 3: Implementér `extract_function_calls()`**

Opret `dev/audit/static_analysis.R`:

```r
# ==============================================================================
# AUDIT: Statisk analyse af testfiler (#203)
# ==============================================================================

#' Ekstraher alle funktionsnavne der kaldes i en R-fil
#'
#' Bruger utils::getParseData() til at parse AST og hente tokens af type
#' SYMBOL_FUNCTION_CALL. Udkommenterede kald ignoreres naturligt (ikke del
#' af parse-traeet).
#'
#' @param file Sti til R-fil
#' @return Character vector af unikke funktionsnavne
extract_function_calls <- function(file) {
  parsed <- tryCatch(
    parse(file, keep.source = TRUE),
    error = function(e) NULL
  )
  if (is.null(parsed) || length(parsed) == 0) return(character(0))

  pd <- utils::getParseData(parsed)
  if (is.null(pd) || nrow(pd) == 0) return(character(0))

  calls <- pd$text[pd$token == "SYMBOL_FUNCTION_CALL"]
  unique(calls)
}
```

- [ ] **Step 4: Kør testen igen**

```
Rscript -e "testthat::test_file('tests/testthat/test-audit-classifier.R')"
```

Expected: 3 PASS.

- [ ] **Step 5: Commit**

```
git add dev/audit/static_analysis.R tests/testthat/test-audit-classifier.R
git commit -m "feat(audit): tilfoej extract_function_calls (#203)"
```

---

## Task 2: Statisk analyse — resterende helpers

**Files:**
- Modify: `dev/audit/static_analysis.R`
- Modify: `tests/testthat/test-audit-classifier.R`

- [ ] **Step 1: Skriv failing tests for 4 resterende helpers**

Tilføj til `tests/testthat/test-audit-classifier.R`:

```r
describe("count_test_blocks()", {
  it("taeller test_that-blokke", {
    tmp <- tempfile(fileext = ".R")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c(
      'test_that("foo", { expect_true(TRUE) })',
      'test_that("bar", { expect_true(TRUE) })',
      'test_that("baz", { expect_true(TRUE) })'
    ), tmp)

    expect_equal(count_test_blocks(tmp), 3L)
  })

  it("taeller describe/it-blokke", {
    tmp <- tempfile(fileext = ".R")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c(
      'describe("group", {',
      '  it("first", { expect_true(TRUE) })',
      '  it("second", { expect_true(TRUE) })',
      '})'
    ), tmp)

    expect_equal(count_test_blocks(tmp), 2L)
  })

  it("ignorerer udkommenterede test-blokke", {
    tmp <- tempfile(fileext = ".R")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c(
      'test_that("real", { expect_true(TRUE) })',
      '# test_that("commented", { expect_true(TRUE) })'
    ), tmp)

    expect_equal(count_test_blocks(tmp), 1L)
  })
})

describe("detect_deprecation_marker()", {
  it("detekterer DEPRECATED oeverst i fil", {
    tmp <- tempfile(fileext = ".R")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c(
      "# DEPRECATED: 2025-10-10",
      "# This file will be removed"
    ), tmp)

    expect_true(detect_deprecation_marker(tmp))
  })

  it("returnerer FALSE for normale filer", {
    tmp <- tempfile(fileext = ".R")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c(
      "# Normal testfil",
      'test_that("foo", { expect_true(TRUE) })'
    ), tmp)

    expect_false(detect_deprecation_marker(tmp))
  })
})

describe("scan_test_files()", {
  it("finder alle test-*.R filer i en mappe", {
    tmp_dir <- tempfile()
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
    file.create(file.path(tmp_dir, "test-foo.R"))
    file.create(file.path(tmp_dir, "test-bar.R"))
    file.create(file.path(tmp_dir, "helper.R"))
    file.create(file.path(tmp_dir, "setup.R"))

    files <- scan_test_files(tmp_dir)
    expect_equal(length(files), 2L)
    expect_true(all(grepl("^test-", basename(files))))
  })
})
```

- [ ] **Step 2: Kør tests for at verificere fejl**

```
Rscript -e "testthat::test_file('tests/testthat/test-audit-classifier.R')"
```

Expected: FAIL for `count_test_blocks`, `detect_deprecation_marker`, `scan_test_files`.

- [ ] **Step 3: Implementér resterende helpers**

Tilføj til `dev/audit/static_analysis.R`:

```r
#' Tael aktive test_that og it-blokke
#'
#' Udkommenterede blokke ignoreres da de ikke er del af parse-traeet.
count_test_blocks <- function(file) {
  calls <- extract_function_calls(file)
  sum(calls %in% c("test_that", "it"))
}

#' Detekter deprecation-marker oeverst i testfil
#'
#' Matcher regex ^#\\s*DEPRECATED paa foerste 10 linjer.
detect_deprecation_marker <- function(file) {
  if (!file.exists(file)) return(FALSE)
  lines <- readLines(file, n = 10, warn = FALSE)
  any(grepl("^#\\s*DEPRECATED", lines, ignore.case = TRUE))
}

#' Find alle testfiler i en mappe
#'
#' Matcher kun filer der starter med test- og slutter med .R.
scan_test_files <- function(dir = "tests/testthat") {
  list.files(
    dir,
    pattern = "^test-.*\\.R$",
    full.names = TRUE,
    recursive = FALSE
  )
}

#' Liste af funktioner i biSPCharts namespace
list_r_exports <- function() {
  if (!"biSPCharts" %in% loadedNamespaces()) {
    pkgload::load_all(quiet = TRUE)
  }
  ns <- asNamespace("biSPCharts")
  names <- ls(envir = ns, all.names = FALSE)
  fns <- names[vapply(names, function(n) is.function(get(n, envir = ns)), logical(1))]
  fns
}

#' Tael LOC i fil
count_loc <- function(file) {
  if (!file.exists(file)) return(0L)
  length(readLines(file, warn = FALSE))
}
```

- [ ] **Step 4: Kør tests**

```
Rscript -e "testthat::test_file('tests/testthat/test-audit-classifier.R')"
```

Expected: Alle PASS.

- [ ] **Step 5: Commit**

```
git add dev/audit/static_analysis.R tests/testthat/test-audit-classifier.R
git commit -m "feat(audit): tilfoej count_test_blocks, detect_deprecation_marker, scan_test_files (#203)"
```

---

## Task 3: Dynamic runner — output-parsers

**Files:**
- Create: `dev/audit/dynamic_runner.R`
- Modify: `tests/testthat/test-audit-classifier.R`

- [ ] **Step 1: Skriv failing tests**

Tilføj til `tests/testthat/test-audit-classifier.R`:

```r
source(file.path(audit_dir, "dynamic_runner.R"))

describe("parse_testthat_output()", {
  it("parser standard testthat-summary", {
    stdout <- c(
      "Loading biSPCharts",
      "Testing foo.R",
      "[ FAIL 2 | WARN 0 | SKIP 1 | PASS 15 ]"
    )
    result <- parse_testthat_output(stdout)
    expect_equal(result$n_pass, 15L)
    expect_equal(result$n_fail, 2L)
    expect_equal(result$n_skip, 1L)
  })

  it("haandterer manglende summary", {
    stdout <- c("Loading biSPCharts", "Error in test")
    result <- parse_testthat_output(stdout)
    expect_equal(result$n_pass, 0L)
    expect_equal(result$n_fail, 0L)
    expect_equal(result$n_skip, 0L)
  })
})

describe("extract_missing_functions()", {
  it("ekstraherer funktionsnavne fra could-not-find-function", {
    stderr <- c(
      'Error in foo() : could not find function "my_missing_fn"',
      'Error: could not find function "another_missing"'
    )
    fns <- extract_missing_functions(stderr)
    expect_true(all(c("my_missing_fn", "another_missing") %in% fns))
  })

  it("returnerer character(0) hvis ingen match", {
    stderr <- c("Error: some other error")
    expect_equal(extract_missing_functions(stderr), character(0))
  })

  it("deduplikerer gentagne manglende funktioner", {
    stderr <- c(
      'could not find function "foo"',
      'could not find function "foo"',
      'could not find function "bar"'
    )
    fns <- extract_missing_functions(stderr)
    expect_equal(sort(fns), c("bar", "foo"))
  })
})

describe("detect_api_drift()", {
  it("detekterer unused argument", {
    stderr <- c("Error: unused argument (some_param = 5)")
    expect_true(detect_api_drift(stderr))
  })

  it("detekterer argument missing", {
    stderr <- c('Error: argument "x" is missing, with no default')
    expect_true(detect_api_drift(stderr))
  })

  it("returnerer FALSE for missing-function fejl", {
    stderr <- c('could not find function "foo"')
    expect_false(detect_api_drift(stderr))
  })
})
```

- [ ] **Step 2: Kør tests**

```
Rscript -e "testthat::test_file('tests/testthat/test-audit-classifier.R')"
```

Expected: FAIL.

- [ ] **Step 3: Implementér parsers**

Opret `dev/audit/dynamic_runner.R`:

```r
# ==============================================================================
# AUDIT: Dynamic runner (#203)
# ==============================================================================

#' Parse testthat ProgressReporter output til taelletal
parse_testthat_output <- function(stdout) {
  pattern <- "\\[\\s*FAIL\\s+(\\d+)\\s*\\|\\s*WARN\\s+\\d+\\s*\\|\\s*SKIP\\s+(\\d+)\\s*\\|\\s*PASS\\s+(\\d+)\\s*\\]"
  matches <- regmatches(stdout, regexec(pattern, stdout))
  hits <- Filter(function(m) length(m) > 1, matches)

  if (length(hits) == 0) {
    return(list(n_pass = 0L, n_fail = 0L, n_skip = 0L))
  }

  last <- hits[[length(hits)]]
  list(
    n_fail = as.integer(last[2]),
    n_skip = as.integer(last[3]),
    n_pass = as.integer(last[4])
  )
}

#' Ekstraher manglende funktionsnavne fra stderr
extract_missing_functions <- function(stderr) {
  if (length(stderr) == 0) return(character(0))
  text <- paste(stderr, collapse = "\n")
  pattern <- "could not find function\\s+[\"']([^\"']+)[\"']"
  matches <- regmatches(text, gregexpr(pattern, text))[[1]]
  if (length(matches) == 0) return(character(0))

  fns <- sub(pattern, "\\1", matches)
  unique(fns)
}

#' Detekter API-drift-moenstre i stderr
detect_api_drift <- function(stderr) {
  if (length(stderr) == 0) return(FALSE)
  text <- paste(stderr, collapse = "\n")
  patterns <- c(
    "unused argument",
    "argument .* is missing, with no default",
    "formal argument .* matched by multiple",
    "unknown parameter"
  )
  any(vapply(patterns, function(p) grepl(p, text), logical(1)))
}
```

- [ ] **Step 4: Kør tests**

```
Rscript -e "testthat::test_file('tests/testthat/test-audit-classifier.R')"
```

Expected: Alle PASS.

- [ ] **Step 5: Commit**

```
git add dev/audit/dynamic_runner.R tests/testthat/test-audit-classifier.R
git commit -m "feat(audit): tilfoej testthat output-parsers (#203)"
```

---

## Task 4: Dynamic runner — isoleret subproces

**Files:**
- Modify: `dev/audit/dynamic_runner.R`

- [ ] **Step 1: Implementér `run_test_file_isolated()`**

Tilføj til `dev/audit/dynamic_runner.R`:

```r
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Koer een testfil i isoleret subproces via processx
#'
#' Starter en Rscript-subproces der loader biSPCharts via pkgload::load_all()
#' og koerer testthat::test_file(). stdout/stderr fanges separat.
#' Timeout haandteres af processx.
#'
#' @param file Sti til testfil
#' @param timeout Sekunder (default 60)
#' @param pkg_root Sti til biSPCharts repo root
#' @return list med exit_code, stdout, stderr, elapsed_s, timed_out
run_test_file_isolated <- function(file, timeout = 60, pkg_root = getwd()) {
  start_time <- Sys.time()

  r_code <- sprintf(
    'setwd("%s"); pkgload::load_all(quiet = TRUE); testthat::test_file("%s", reporter = testthat::ProgressReporter$new(show_praise = FALSE), stop_on_failure = FALSE)',
    pkg_root, file
  )

  result <- tryCatch({
    processx::run(
      command = file.path(R.home("bin"), "Rscript"),
      args = c("-e", r_code),
      timeout = timeout,
      error_on_status = FALSE
    )
  }, system_command_timeout_error = function(e) {
    list(status = 124L, stdout = "", stderr = "TIMEOUT", timeout = TRUE)
  }, error = function(e) {
    list(status = 1L, stdout = "", stderr = as.character(e$message), timeout = FALSE)
  })

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  list(
    exit_code = as.integer(result$status %||% 1L),
    stdout = strsplit(result$stdout %||% "", "\n", fixed = TRUE)[[1]],
    stderr = strsplit(result$stderr %||% "", "\n", fixed = TRUE)[[1]],
    elapsed_s = elapsed,
    timed_out = isTRUE(result$timeout)
  )
}
```

- [ ] **Step 2: Smoke-test manuelt**

Kør i R-konsol:

```r
source("dev/audit/dynamic_runner.R")
result <- run_test_file_isolated(
  "tests/testthat/test-config_chart_types.R",
  timeout = 30,
  pkg_root = getwd()
)
str(result)
```

Expected: Liste med `exit_code = 0`, stdout indeholder FAIL/PASS-summary-linje.

- [ ] **Step 3: Commit**

```
git add dev/audit/dynamic_runner.R
git commit -m "feat(audit): tilfoej run_test_file_isolated (#203)"
```

---

## Task 5: Classifier

**Files:**
- Create: `dev/audit/classifier.R`
- Modify: `tests/testthat/test-audit-classifier.R`

- [ ] **Step 1: Skriv failing tests for 7 kategorier**

Tilføj til `tests/testthat/test-audit-classifier.R`:

```r
source(file.path(audit_dir, "classifier.R"))

describe("classify_file()", {
  it("klassificerer stub ved faa test-blokke", {
    static <- list(n_test_blocks = 1L)
    dynamic <- list(exit_code = 0L, n_pass = 1L, n_fail = 0L, n_skip = 0L,
                    missing_functions = character(0), api_drift_detected = FALSE)
    expect_equal(classify_file(static, dynamic), "stub")
  })

  it("klassificerer skipped-all", {
    static <- list(n_test_blocks = 10L)
    dynamic <- list(exit_code = 0L, n_pass = 0L, n_fail = 0L, n_skip = 10L,
                    missing_functions = character(0), api_drift_detected = FALSE)
    expect_equal(classify_file(static, dynamic), "skipped-all")
  })

  it("klassificerer broken-missing-fn", {
    static <- list(n_test_blocks = 10L)
    dynamic <- list(exit_code = 1L, n_pass = 0L, n_fail = 0L, n_skip = 0L,
                    missing_functions = c("missing_fn"), api_drift_detected = FALSE)
    expect_equal(classify_file(static, dynamic), "broken-missing-fn")
  })

  it("klassificerer broken-api-drift", {
    static <- list(n_test_blocks = 10L)
    dynamic <- list(exit_code = 1L, n_pass = 0L, n_fail = 0L, n_skip = 0L,
                    missing_functions = character(0), api_drift_detected = TRUE)
    expect_equal(classify_file(static, dynamic), "broken-api-drift")
  })

  it("klassificerer broken-other som fallback", {
    static <- list(n_test_blocks = 10L)
    dynamic <- list(exit_code = 1L, n_pass = 0L, n_fail = 0L, n_skip = 0L,
                    missing_functions = character(0), api_drift_detected = FALSE)
    expect_equal(classify_file(static, dynamic), "broken-other")
  })

  it("klassificerer green-partial", {
    static <- list(n_test_blocks = 10L)
    dynamic <- list(exit_code = 0L, n_pass = 5L, n_fail = 3L, n_skip = 0L,
                    missing_functions = character(0), api_drift_detected = FALSE)
    expect_equal(classify_file(static, dynamic), "green-partial")
  })

  it("klassificerer green", {
    static <- list(n_test_blocks = 10L)
    dynamic <- list(exit_code = 0L, n_pass = 10L, n_fail = 0L, n_skip = 0L,
                    missing_functions = character(0), api_drift_detected = FALSE)
    expect_equal(classify_file(static, dynamic), "green")
  })

  it("prioriterer stub over broken", {
    static <- list(n_test_blocks = 1L)
    dynamic <- list(exit_code = 1L, n_pass = 0L, n_fail = 0L, n_skip = 0L,
                    missing_functions = c("fn"), api_drift_detected = FALSE)
    expect_equal(classify_file(static, dynamic), "stub")
  })
})
```

- [ ] **Step 2: Kør tests**

```
Rscript -e "testthat::test_file('tests/testthat/test-audit-classifier.R')"
```

Expected: FAIL.

- [ ] **Step 3: Implementér `classify_file()`**

Opret `dev/audit/classifier.R`:

```r
# ==============================================================================
# AUDIT: Klassifikator for testfiler (#203)
# ==============================================================================
#
# Prioriteret klassifikation (foerste match vinder):
#   1. stub              — < 3 test-blokke
#   2. skipped-all       — alle tests skipped
#   3. broken-missing-fn — exit != 0, missing functions fundet
#   4. broken-api-drift  — exit != 0, API drift-moenster fundet
#   5. broken-other      — exit != 0, andre aarsager
#   6. green-partial     — exit = 0, men n_fail > 0
#   7. green             — alle tests pass
# ==============================================================================

#' Klassificer een testfil
classify_file <- function(static, dynamic) {
  if (static$n_test_blocks < 3L) {
    return("stub")
  }

  if (dynamic$exit_code == 0L &&
      dynamic$n_pass == 0L &&
      dynamic$n_fail == 0L &&
      dynamic$n_skip > 0L) {
    return("skipped-all")
  }

  if (dynamic$exit_code != 0L) {
    if (length(dynamic$missing_functions) > 0L) {
      return("broken-missing-fn")
    }
    if (isTRUE(dynamic$api_drift_detected)) {
      return("broken-api-drift")
    }
    return("broken-other")
  }

  if (dynamic$n_fail > 0L) {
    return("green-partial")
  }

  "green"
}
```

- [ ] **Step 4: Kør tests**

```
Rscript -e "testthat::test_file('tests/testthat/test-audit-classifier.R')"
```

Expected: Alle 8 PASS.

- [ ] **Step 5: Commit**

```
git add dev/audit/classifier.R tests/testthat/test-audit-classifier.R
git commit -m "feat(audit): tilfoej classify_file med 7 kategorier (#203)"
```

---

## Task 6: Reporter — JSON-output

**Files:**
- Create: `dev/audit/reporter.R`
- Modify: `tests/testthat/test-audit-classifier.R`

- [ ] **Step 1: Skriv failing test**

Tilføj til `tests/testthat/test-audit-classifier.R`:

```r
source(file.path(audit_dir, "reporter.R"))

describe("write_json_report()", {
  it("skriver valid JSON med forventede felter", {
    results <- list(
      run_timestamp = "2026-04-17T10:00:00+02:00",
      biSPCharts_version = "0.2.0",
      r_version = "4.5.2",
      total_files = 2L,
      total_elapsed_s = 5.2,
      summary = list(green = 1L, `broken-missing-fn` = 1L),
      top_missing_functions = list(
        list(fn = "missing_fn", n_files = 1L, files = list("test-foo.R"))
      ),
      files = list(
        list(file = "test-foo.R", category = "broken-missing-fn", n_tests = 5L)
      )
    )

    tmp <- tempfile(fileext = ".json")
    on.exit(unlink(tmp), add = TRUE)
    write_json_report(results, tmp)

    parsed <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
    expect_equal(parsed$total_files, 2L)
    expect_equal(parsed$summary$green, 1L)
    expect_equal(parsed$files[[1]]$file, "test-foo.R")
  })
})
```

- [ ] **Step 2: Kør test**

```
Rscript -e "testthat::test_file('tests/testthat/test-audit-classifier.R')"
```

Expected: FAIL.

- [ ] **Step 3: Implementér reporter**

Opret `dev/audit/reporter.R`:

```r
# ==============================================================================
# AUDIT: Rapportgenerering (#203)
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Beregn summary-statistikker fra fil-resultater
compute_summary <- function(files) {
  categories <- vapply(files, function(f) f$category, character(1))
  summary_counts <- as.list(table(categories))

  all_missing <- unlist(lapply(files, function(f) f$missing_functions %||% character(0)))
  if (length(all_missing) > 0) {
    tab <- table(all_missing)
    tab_sorted <- sort(tab, decreasing = TRUE)
    top_10 <- head(tab_sorted, 10)
    top_missing <- lapply(names(top_10), function(fn) {
      files_with_fn <- vapply(files, function(f) {
        fn %in% (f$missing_functions %||% character(0))
      }, logical(1))
      list(
        fn = fn,
        n_files = as.integer(top_10[[fn]]),
        files = vapply(files[files_with_fn], function(f) f$file, character(1))
      )
    })
  } else {
    top_missing <- list()
  }

  list(
    summary = summary_counts,
    top_missing_functions = top_missing
  )
}

#' Skriv maskinlaesbar JSON-rapport
write_json_report <- function(results, path) {
  jsonlite::write_json(
    results,
    path = path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null"
  )
  invisible(path)
}
```

- [ ] **Step 4: Kør tests**

```
Rscript -e "testthat::test_file('tests/testthat/test-audit-classifier.R')"
```

Expected: Alle PASS.

- [ ] **Step 5: Commit**

```
git add dev/audit/reporter.R tests/testthat/test-audit-classifier.R
git commit -m "feat(audit): tilfoej write_json_report og compute_summary (#203)"
```

---

## Task 7: Reporter — Markdown + console summary

**Files:**
- Modify: `dev/audit/reporter.R`

- [ ] **Step 1: Implementér Markdown-rapport**

Tilføj til `dev/audit/reporter.R`:

```r
#' Skriv menneskelaesbar Markdown-rapport
write_markdown_report <- function(results, path) {
  lines <- c()

  lines <- c(lines,
    "# Test Audit Report",
    "",
    sprintf("**Dato:** %s", results$run_timestamp),
    sprintf("**biSPCharts version:** %s", results$biSPCharts_version),
    sprintf("**R version:** %s", results$r_version),
    sprintf("**Total filer:** %d", results$total_files),
    sprintf("**Total koerselstid:** %.1f s", results$total_elapsed_s),
    "",
    "---",
    ""
  )

  lines <- c(lines,
    "## Executive Summary",
    "",
    "| Kategori | Antal | % af total |",
    "|----------|-------|-----------|"
  )
  for (cat_name in names(results$summary)) {
    n <- results$summary[[cat_name]]
    pct <- 100 * n / results$total_files
    lines <- c(lines, sprintf("| `%s` | %d | %.1f%% |", cat_name, n, pct))
  }
  lines <- c(lines, "", "---", "")

  if (length(results$top_missing_functions) > 0) {
    lines <- c(lines,
      "## Top-10 Manglende R-funktioner",
      "",
      "| Funktion | Antal filer |",
      "|----------|-------------|"
    )
    for (item in results$top_missing_functions) {
      lines <- c(lines, sprintf("| `%s` | %d |", item$fn, item$n_files))
    }
    lines <- c(lines, "", "---", "")
  }

  category_order <- c(
    "broken-missing-fn", "broken-api-drift", "broken-other",
    "green-partial", "skipped-all", "stub", "green"
  )

  for (cat_name in category_order) {
    files_in_cat <- Filter(function(f) f$category == cat_name, results$files)
    if (length(files_in_cat) == 0) next

    lines <- c(lines,
      sprintf("## Kategori: `%s` (%d filer)", cat_name, length(files_in_cat)),
      ""
    )

    for (f in files_in_cat) {
      lines <- c(lines, sprintf("### `%s`", f$file))
      lines <- c(lines,
        sprintf("- LOC: %d", f$loc %||% 0),
        sprintf("- Test-blokke: %d", f$n_test_blocks %||% 0),
        sprintf("- Pass/Fail/Skip: %d / %d / %d",
                f$n_pass %||% 0, f$n_fail %||% 0, f$n_skip %||% 0)
      )
      if (length(f$missing_functions %||% character(0)) > 0) {
        lines <- c(lines, sprintf("- Manglende funktioner: `%s`",
                                   paste(f$missing_functions, collapse = "`, `")))
      }
      if (!is.null(f$stderr_snippet) && nzchar(f$stderr_snippet)) {
        lines <- c(lines, "", "```", f$stderr_snippet, "```")
      }
      lines <- c(lines, "")
    }
    lines <- c(lines, "---", "")
  }

  lines <- c(lines,
    "## Scope-forslag",
    "",
    generate_scope_suggestion(results),
    ""
  )

  writeLines(lines, path)
  invisible(path)
}

#' Generer scope-forslag baseret paa fordeling
generate_scope_suggestion <- function(results) {
  s <- results$summary
  total <- results$total_files
  broken <- (s$`broken-missing-fn` %||% 0) +
            (s$`broken-api-drift` %||% 0) +
            (s$`broken-other` %||% 0)
  green <- (s$green %||% 0) + (s$`green-partial` %||% 0)
  stubs <- (s$stub %||% 0) + (s$`skipped-all` %||% 0)

  lines <- c(
    sprintf("- **Green:** %d af %d (%.0f%%)", green, total, 100 * green / total),
    sprintf("- **Broken:** %d af %d (%.0f%%)", broken, total, 100 * broken / total),
    sprintf("- **Stubs/skipped:** %d af %d (%.0f%%)", stubs, total, 100 * stubs / total),
    ""
  )

  suggestion <- if (broken / total > 0.5) {
    "**Anbefaling: Omfattende scope** - mere end halvdelen brudt."
  } else if (broken / total > 0.2) {
    "**Anbefaling: Moderat scope** - batched proposals pr. funktionsgruppe."
  } else {
    "**Anbefaling: Minimal scope** - fokuser paa de faa braekkede filer."
  }

  paste(c(lines, suggestion), collapse = "\n")
}

#' Print kort oversigt til konsol
print_console_summary <- function(results) {
  cat("\n")
  cat("========================================\n")
  cat("  Test Audit Summary\n")
  cat("========================================\n")
  cat(sprintf("Total filer:     %d\n", results$total_files))
  cat(sprintf("Koerselstid:     %.1f s\n", results$total_elapsed_s))
  cat("\n")
  cat("Fordeling pr. kategori:\n")
  for (cat_name in names(results$summary)) {
    cat(sprintf("  %-22s %d\n", cat_name, results$summary[[cat_name]]))
  }
  cat("========================================\n")
}
```

- [ ] **Step 2: Manuel sanity-check**

Kør i R-konsol:

```r
source("dev/audit/reporter.R")
fake_results <- list(
  run_timestamp = "2026-04-17T10:00:00+02:00",
  biSPCharts_version = "0.2.0",
  r_version = "4.5.2",
  total_files = 3L,
  total_elapsed_s = 5.2,
  summary = list(green = 2L, `broken-missing-fn` = 1L),
  top_missing_functions = list(
    list(fn = "missing_fn", n_files = 1L, files = list("test-foo.R"))
  ),
  files = list(
    list(file = "test-foo.R", category = "broken-missing-fn", loc = 100L,
         n_test_blocks = 5L, n_pass = 0L, n_fail = 0L, n_skip = 0L,
         missing_functions = c("missing_fn"), stderr_snippet = "Error ..."),
    list(file = "test-bar.R", category = "green", loc = 50L,
         n_test_blocks = 3L, n_pass = 3L, n_fail = 0L, n_skip = 0L),
    list(file = "test-baz.R", category = "green", loc = 60L,
         n_test_blocks = 4L, n_pass = 4L, n_fail = 0L, n_skip = 0L)
  )
)
tmp <- tempfile(fileext = ".md")
write_markdown_report(fake_results, tmp)
cat(readLines(tmp), sep = "\n")
print_console_summary(fake_results)
```

Expected: Velformet Markdown med sektioner + scope-forslag. Console summary printet.

- [ ] **Step 3: Commit**

```
git add dev/audit/reporter.R
git commit -m "feat(audit): tilfoej Markdown-rapport og console summary (#203)"
```

---

## Task 8: Main script — CLI + orkestrering

**Files:**
- Create: `dev/audit_tests.R`

- [ ] **Step 1: Implementér hovedscript**

Opret `dev/audit_tests.R`:

```r
#!/usr/bin/env Rscript

# ==============================================================================
# AUDIT TESTS — hovedscript (#203)
# ==============================================================================
#
# Usage:
#   Rscript dev/audit_tests.R
#   Rscript dev/audit_tests.R --filter='test-auto'
#   Rscript dev/audit_tests.R --timeout=120
#   Rscript dev/audit_tests.R --output-dir=dev/audit-output
# ==============================================================================

suppressPackageStartupMessages({
  library(processx)
  library(jsonlite)
  library(pkgload)
})

project_root <- getwd()
audit_dir <- file.path(project_root, "dev", "audit")
source(file.path(audit_dir, "static_analysis.R"))
source(file.path(audit_dir, "dynamic_runner.R"))
source(file.path(audit_dir, "classifier.R"))
source(file.path(audit_dir, "reporter.R"))

parse_args <- function(args) {
  defaults <- list(
    filter = NULL,
    output_dir = "dev/audit-output",
    timeout = 60L,
    report_md = "docs/superpowers/specs/2026-04-17-test-audit-report.md"
  )

  for (arg in args) {
    if (grepl("^--filter=", arg)) {
      defaults$filter <- sub("^--filter=", "", arg)
    } else if (grepl("^--output-dir=", arg)) {
      defaults$output_dir <- sub("^--output-dir=", "", arg)
    } else if (grepl("^--timeout=", arg)) {
      defaults$timeout <- as.integer(sub("^--timeout=", "", arg))
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript dev/audit_tests.R [--filter=<regex>] [--output-dir=<path>] [--timeout=<sec>]\n")
      quit(save = "no", status = 0)
    }
  }

  defaults
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))

  cat("Loading biSPCharts package...\n")
  pkgload::load_all(quiet = TRUE)

  cat("Scanning testfiler...\n")
  all_files <- scan_test_files("tests/testthat")
  if (!is.null(args$filter)) {
    all_files <- all_files[grepl(args$filter, basename(all_files))]
  }
  cat(sprintf("  Fundet %d filer.\n", length(all_files)))

  if (length(all_files) == 0) {
    stop("Ingen testfiler matchede filteret.")
  }

  cat("Henter R-exports...\n")
  r_exports <- list_r_exports()
  cat(sprintf("  Fundet %d funktioner i R/.\n", length(r_exports)))

  cat(sprintf("\nKoerer audit (timeout %ds pr. fil)...\n", args$timeout))
  dir.create(args$output_dir, showWarnings = FALSE, recursive = TRUE)
  start_total <- Sys.time()

  results <- lapply(seq_along(all_files), function(i) {
    file <- all_files[i]
    cat(sprintf("  [%d/%d] %s ... ", i, length(all_files), basename(file)))

    static <- list(
      file = basename(file),
      loc = count_loc(file),
      last_modified = file.info(file)$mtime,
      n_test_blocks = count_test_blocks(file),
      has_deprecation_marker = detect_deprecation_marker(file),
      function_calls = extract_function_calls(file)
    )
    static$missing_functions_static <- setdiff(static$function_calls, r_exports)

    dyn_raw <- run_test_file_isolated(file, timeout = args$timeout, pkg_root = project_root)
    parsed <- parse_testthat_output(dyn_raw$stdout)
    missing_rt <- extract_missing_functions(dyn_raw$stderr)
    drift <- detect_api_drift(dyn_raw$stderr)

    dynamic <- list(
      exit_code = dyn_raw$exit_code,
      elapsed_s = dyn_raw$elapsed_s,
      n_pass = parsed$n_pass,
      n_fail = parsed$n_fail,
      n_skip = parsed$n_skip,
      missing_functions = missing_rt,
      api_drift_detected = drift,
      timed_out = isTRUE(dyn_raw$timed_out),
      stderr_snippet = substr(paste(dyn_raw$stderr, collapse = "\n"), 1, 500)
    )

    category <- classify_file(static, dynamic)

    cat(sprintf("%s (%.1fs)\n", category, dynamic$elapsed_s))

    c(static, dynamic, list(category = category))
  })

  total_elapsed <- as.numeric(difftime(Sys.time(), start_total, units = "secs"))

  summary_info <- compute_summary(results)
  final <- list(
    run_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    biSPCharts_version = as.character(utils::packageVersion("biSPCharts")),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    total_files = length(results),
    total_elapsed_s = total_elapsed,
    summary = summary_info$summary,
    top_missing_functions = summary_info$top_missing_functions,
    files = results
  )

  json_path <- file.path(args$output_dir, "test-audit.json")
  md_path <- args$report_md
  dir.create(dirname(md_path), showWarnings = FALSE, recursive = TRUE)

  write_json_report(final, json_path)
  write_markdown_report(final, md_path)
  print_console_summary(final)

  cat(sprintf("\nJSON: %s\n", json_path))
  cat(sprintf("MD:   %s\n", md_path))
}

if (!interactive() && sys.nframe() == 0L) {
  main()
}
```

- [ ] **Step 2: Smoke-test med lille filter**

```
Rscript dev/audit_tests.R --filter='test-config_chart_types' --timeout=30
```

Expected:
- Script koerer igennem
- JSON + MD genereres
- Console viser summary med 1 fil

- [ ] **Step 3: Commit**

```
git add dev/audit_tests.R
git commit -m "feat(audit): tilfoej hovedscript med CLI og orkestrering (#203)"
```

---

## Task 9: Smoke-test paa 3 kendte filer

**Files:** (Ingen nye — verifikation)

- [ ] **Step 1: Identificer 3 reference-filer**

Vælg:
1. **Forventet green:** `test-config_chart_types.R` (konfiguration, minimale deps)
2. **Forventet broken-missing-fn:** `test-utils_validation_guards.R` (har `validate_data_or_return` missing)
3. **Forventet skipped-all:** `test-anhoej-rules.R` (har `skip()`-kald pga. BFHcharts-migration, jf. commit 834445d)

- [ ] **Step 2: Koer audit filtreret paa de 3 filer**

```
Rscript dev/audit_tests.R --filter='test-(config_chart_types|utils_validation_guards|anhoej-rules)' --timeout=60
```

- [ ] **Step 3: Verificer output**

Aabn `dev/audit-output/test-audit.json` og tjek:
- `test-config_chart_types.R` → `category: "green"`
- `test-utils_validation_guards.R` → `category: "broken-missing-fn"` og `missing_functions` indeholder kendte navne
- `test-anhoej-rules.R` → `category: "skipped-all"` eller `green-partial`

Hvis kategorier afviger: debug ved at koere testfilen manuelt:

```
Rscript -e "pkgload::load_all(); testthat::test_file('tests/testthat/test-utils_validation_guards.R')"
```

Sammenlign output mod auditens rapport.

- [ ] **Step 4: Commit eventuelle fixes**

Hvis smoke-test afsloerer bugs:

```
git add dev/audit/
git commit -m "fix(audit): ret klassifikations-edge-case fra smoke-test (#203)"
```

---

## Task 10: Fuld koersel + rapport-generering

**Files:**
- Create: `dev/audit-output/test-audit.json` (genereret)
- Create: `docs/superpowers/specs/2026-04-17-test-audit-report.md` (genereret)

- [ ] **Step 1: Koer fuld audit**

```
Rscript dev/audit_tests.R --timeout=60 2>&1 | tee dev/audit-output/audit-run.log
```

Expected koerselstid: ~3-5 minutter (124 filer × 1-3s hver + subproces-overhead).

Hvis koerslen overstiger 15 min: stop (Ctrl-C), reducer `--timeout` eller brug `--filter` til batches.

- [ ] **Step 2: Verificer output-filer eksisterer**

```
ls -l dev/audit-output/test-audit.json
ls -l docs/superpowers/specs/2026-04-17-test-audit-report.md
```

Begge skal findes og vaere non-empty.

- [ ] **Step 3: Stikproeve-verifikation**

Aabn rapporten og verificer:
- Executive summary viser fordeling paa tvaers af 7 kategorier
- Top-10 missing functions matcher forventning (fra issue #203: `detect_columns_with_cache`, `apply_metadata_update`, etc.)
- Scope-forslag er rimeligt ift. fordelingen

- [ ] **Step 4: Commit rapport**

```
git add docs/superpowers/specs/2026-04-17-test-audit-report.md dev/audit-output/audit-run.log
git commit -m "docs(audit): tilfoej test-audit-rapport for #203

Resultat af fuld audit paa 124 testfiler. Rapport danner grundlag
for naeste brainstorm-runde om refactoring-scope."
```

---

## Task 11: Push branch og rapporter

**Files:** (Ingen — kun git-operation)

- [ ] **Step 1: Push feature branch**

**VENT PAA EKSPLICIT GODKENDELSE FRA MAINTAINER** foer push.

Naar godkendt:

```
git push -u origin feat/test-audit-203
```

- [ ] **Step 2: Informer maintainer**

Rapporter tilbage:
- Branch pushed: `feat/test-audit-203`
- PR-URL: `https://github.com/johanreventlow/biSPCharts/compare/feat/test-audit-203`
- Rapport klar: `docs/superpowers/specs/2026-04-17-test-audit-report.md`

**Naeste skridt for maintaineren:**
1. Review rapporten
2. Ny brainstorm-runde med reelle data
3. Beslut scope: minimal / moderat / omfattende
4. Opret ny OpenSpec-change for det valgte scope

---

## Verification Checklist (foer PR)

- [ ] Alle unit-tests i `test-audit-classifier.R` passerer
- [ ] `Rscript dev/audit_tests.R --help` viser brugsvejledning
- [ ] Smoke-test (Task 9) matcher forventning
- [ ] Fuld koersel (Task 10) producerer baade JSON og MD
- [ ] Rapport er menneskelaesbar og indeholder alle sektioner
- [ ] Ingen `browser()` eller debug `print()` i `dev/audit/`
- [ ] `.gitignore` ignorerer `dev/audit-output/*.json`
- [ ] Commit-historik er atomisk

---

## Afhaengigheder

Hvis ikke allerede installeret:

```r
install.packages(c("processx", "jsonlite", "pkgload", "rprojroot"))
```

Alle er lette dependencies uden transitiv kompleksitet.
