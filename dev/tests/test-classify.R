# Tests for dev/classify_tests.R + dev/classify_tests_lib.R
# Kør: Rscript dev/tests/run_tests.R

library(testthat)

# Source library robustly — virker uanset working dir
.resolve_lib_path <- function() {
  candidates <- c(
    "dev/classify_tests_lib.R",
    file.path("..", "..", "dev", "classify_tests_lib.R"),
    file.path("..", "classify_tests_lib.R")
  )
  hit <- Filter(file.exists, candidates)
  if (length(hit) == 0) {
    stop("Kan ikke finde classify_tests_lib.R. Kør fra project-root.")
  }
  hit[[1]]
}
source(.resolve_lib_path())

test_that("VALID_TYPES indeholder alle 7 type-værdier", {
  expect_length(VALID_TYPES, 7)
  expect_true(all(c("policy-guard", "unit", "integration", "e2e",
                    "benchmark", "snapshot", "fixture-based") %in% VALID_TYPES))
})

test_that("VALID_HANDLINGS indeholder alle 7 handling-værdier", {
  expect_length(VALID_HANDLINGS, 7)
  expect_true(all(c("keep", "fix-in-phase-3", "merge-in-phase-2", "archive",
                    "rewrite", "blocked-by-change-1", "needs-triage") %in% VALID_HANDLINGS))
})

test_that("`%||%` returnerer b når a er NULL", {
  expect_equal(NULL %||% "fallback", "fallback")
  expect_equal("actual" %||% "fallback", "actual")
})

# ---- auto_classify_type ----

test_that("auto_classify_type identifies e2e via skip_on_ci()", {
  result <- auto_classify_type(
    "test-foo.R",
    file_contents = "test_that('x', { skip_on_ci(); app <- AppDriver$new() })"
  )
  expect_equal(result, "e2e")
})

test_that("auto_classify_type identifies e2e via shinytest2", {
  result <- auto_classify_type(
    "test-foo.R",
    file_contents = "library(shinytest2); skip_if_not_installed('shinytest2')"
  )
  expect_equal(result, "e2e")
})

test_that("auto_classify_type identifies benchmark from filename", {
  expect_equal(
    auto_classify_type("test-performance-benchmarks.R", ""),
    "benchmark"
  )
})

test_that("auto_classify_type identifies snapshot via expect_snapshot", {
  result <- auto_classify_type(
    "test-foo.R",
    file_contents = "test_that('x', { expect_snapshot(plot_output()) })"
  )
  expect_equal(result, "snapshot")
})

test_that("auto_classify_type identifies policy-guard from filename pattern", {
  expect_equal(auto_classify_type("test-namespace-integrity.R", ""), "policy-guard")
  expect_equal(auto_classify_type("test-dependency-namespace.R", ""), "policy-guard")
  expect_equal(auto_classify_type("test-logging-debug-cat.R", ""), "policy-guard")
})

test_that("auto_classify_type identifies integration from filename pattern", {
  expect_equal(auto_classify_type("test-mod-export.R", ""), "integration")
  expect_equal(auto_classify_type("test-e2e-workflows.R", ""), "integration")
})

test_that("auto_classify_type identifies fixture-based via test_path calls", {
  result <- auto_classify_type(
    "test-foo.R",
    file_contents = 'data <- read.csv(test_path("fixtures/data.csv"))'
  )
  expect_equal(result, "fixture-based")
})

test_that("auto_classify_type defaults to unit", {
  expect_equal(
    auto_classify_type("test-utils-parse.R", "test_that('x', { expect_equal(1, 1) })"),
    "unit"
  )
})

test_that("auto_classify_type e2e vinder over integration-filnavn", {
  result <- auto_classify_type(
    "test-mod-export.R",
    file_contents = "skip_on_ci(); app <- AppDriver$new()"
  )
  expect_equal(result, "e2e")
})

# ---- auto_classify_handling ----

test_that("auto_classify_handling returns keep for green", {
  expect_equal(auto_classify_handling("green", 10, 0), "keep")
})

test_that("auto_classify_handling returns fix-in-phase-3 for low-fail green-partial", {
  expect_equal(auto_classify_handling("green-partial", 10, 3), "fix-in-phase-3")
})

test_that("auto_classify_handling returns needs-triage for high-fail green-partial", {
  expect_equal(auto_classify_handling("green-partial", 2, 8), "needs-triage")
})

test_that("auto_classify_handling returns needs-triage for stub", {
  expect_equal(auto_classify_handling("stub", 0, 0), "needs-triage")
})

test_that("auto_classify_handling returns keep for skipped-all", {
  expect_equal(auto_classify_handling("skipped-all", 0, 0), "keep")
})

test_that("auto_classify_handling returns blocked-by-change-1 for broken-missing-fn", {
  expect_equal(auto_classify_handling("broken-missing-fn", 0, 0), "blocked-by-change-1")
})

test_that("auto_classify_handling returns needs-triage for ukendt kategori", {
  expect_equal(auto_classify_handling("broken-other", 0, 0), "needs-triage")
})

test_that("auto_classify_handling 50% boundary er needs-triage", {
  expect_equal(auto_classify_handling("green-partial", 5, 5), "needs-triage")
})

# ---- auto_classify ----

test_that("auto_classify processerer alle filer i audit-JSON", {
  mock_audit <- list(
    run_timestamp = "2026-04-17T14:00:00+0200",
    files = list(
      list(file = "test-namespace-integrity.R", category = "stub",
           n_pass = 1L, n_fail = 0L, n_skip = 0L),
      list(file = "test-parse.R", category = "green",
           n_pass = 10L, n_fail = 0L, n_skip = 0L)
    )
  )

  tmp_dir <- tempfile("testfiles-")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  writeLines("test_that('x', { expect_equal(1,1) })",
             file.path(tmp_dir, "test-namespace-integrity.R"))
  writeLines("test_that('y', { expect_equal(2,2) })",
             file.path(tmp_dir, "test-parse.R"))

  result <- auto_classify(mock_audit, tmp_dir)

  expect_length(result, 2)
  ns_entry <- Filter(function(e) e$file == "test-namespace-integrity.R", result)[[1]]
  expect_equal(ns_entry$type, "policy-guard")
  expect_equal(ns_entry$handling, "needs-triage")
  expect_equal(ns_entry$reviewed, FALSE)
  expect_equal(ns_entry$audit_category, "stub")

  p_entry <- Filter(function(e) e$file == "test-parse.R", result)[[1]]
  expect_equal(p_entry$type, "unit")
  expect_equal(p_entry$handling, "keep")
})

# ---- write_manifest / read_manifest ----

test_that("write_manifest/read_manifest round-tripper", {
  manifest <- list(
    metadata = list(total_files = 1L, audit_run = "t",
      manifest_schema_version = "1.0",
      review_status = list(reviewed = 0L, unreviewed = 1L, needs_triage = 0L)),
    files = list(
      list(file = "test-a.R", audit_category = "green", type = "unit",
           handling = "keep", reviewed = FALSE)
    )
  )

  tmp <- tempfile(fileext = ".yaml")
  on.exit(unlink(tmp), add = TRUE)

  write_manifest(manifest, tmp)
  expect_true(file.exists(tmp))
  content <- paste(readLines(tmp), collapse = "\n")
  expect_match(content, "Test Classification Manifest")

  restored <- read_manifest(tmp)
  expect_length(restored$files, 1)
  expect_equal(restored$files[[1]]$type, "unit")
})

# ---- merge_with_existing ----

test_that("merge_with_existing bevarer reviewed: true entries", {
  existing_entry <- list(
    file = "test-a.R", audit_category = "stub",
    type = "policy-guard", handling = "keep",
    rationale = "Policy-guard misklassificeret", reviewed = TRUE,
    reviewer = "johanreventlow", reviewed_date = "2026-04-17"
  )
  auto_entry <- list(
    file = "test-a.R", audit_category = "stub",
    type = "unit", handling = "needs-triage", reviewed = FALSE
  )

  result <- merge_with_existing(
    auto_entries = list(auto_entry),
    existing_manifest = list(files = list(existing_entry))
  )

  expect_length(result, 1)
  expect_equal(result[[1]]$type, "policy-guard")
  expect_equal(result[[1]]$handling, "keep")
  expect_true(result[[1]]$reviewed)
  expect_equal(result[[1]]$reviewer, "johanreventlow")
})

test_that("merge_with_existing synker audit_category fra auto til reviewed entries", {
  existing_entry <- list(
    file = "test-a.R", audit_category = "broken-missing-fn",
    type = "unit", handling = "blocked-by-change-1",
    rationale = "Venter på Change 1", reviewed = TRUE,
    reviewer = "j", reviewed_date = "2026-04-10"
  )
  auto_entry <- list(
    file = "test-a.R", audit_category = "green",
    type = "unit", handling = "keep", reviewed = FALSE
  )

  result <- merge_with_existing(
    list(auto_entry), list(files = list(existing_entry))
  )
  expect_equal(result[[1]]$audit_category, "green")
  expect_true(result[[1]]$reviewed)
})

test_that("merge_with_existing tilføjer nye auto-entries", {
  auto_entries <- list(
    list(file = "test-old.R", audit_category = "green", type = "unit",
         handling = "keep", reviewed = FALSE),
    list(file = "test-new.R", audit_category = "green", type = "unit",
         handling = "keep", reviewed = FALSE)
  )
  existing <- list(files = list(
    list(file = "test-old.R", audit_category = "green", type = "unit",
         handling = "keep", reviewed = TRUE, reviewer = "j", reviewed_date = "2026-04-17")
  ))

  result <- merge_with_existing(auto_entries, existing)
  expect_length(result, 2)
})

test_that("merge_with_existing overskriver reviewed:false entries", {
  existing_entry <- list(
    file = "test-a.R", audit_category = "x", type = "unit",
    handling = "needs-triage", reviewed = FALSE
  )
  auto_entry <- list(
    file = "test-a.R", audit_category = "green-partial",
    type = "policy-guard", handling = "fix-in-phase-3", reviewed = FALSE
  )

  result <- merge_with_existing(list(auto_entry), list(files = list(existing_entry)))
  expect_equal(result[[1]]$type, "policy-guard")
})

test_that("merge_with_existing håndterer NULL existing_manifest", {
  auto <- list(list(file = "test-a.R", type = "unit", handling = "keep", reviewed = FALSE))
  result <- merge_with_existing(auto, NULL)
  expect_equal(result, auto)
})

# ---- validate_manifest ----

valid_entry <- function(overrides = list()) {
  base <- list(
    file = "test-x.R", audit_category = "green",
    type = "unit", handling = "keep", reviewed = FALSE
  )
  modifyList(base, overrides)
}

mock_audit <- function(files_cats) {
  list(files = lapply(names(files_cats), function(f) {
    list(file = f, category = files_cats[[f]])
  }))
}

setup_test_dir <- function(files) {
  tmp <- tempfile("testfiles-")
  dir.create(tmp)
  for (f in files) writeLines("", file.path(tmp, f))
  tmp
}

test_that("validate_manifest passerer gyldigt manifest", {
  tmp <- setup_test_dir(c("test-x.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  manifest <- list(files = list(valid_entry()))
  result <- validate_manifest(manifest, tmp, mock_audit(list("test-x.R" = "green")))
  expect_true(result$valid)
})

test_that("validate_manifest: ukendt type", {
  tmp <- setup_test_dir(c("test-x.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  result <- validate_manifest(
    list(files = list(valid_entry(list(type = "ufo")))),
    tmp, mock_audit(list("test-x.R" = "green")))
  expect_false(result$valid)
  expect_true(any(grepl("ukendt type", result$errors, ignore.case = TRUE)))
})

test_that("validate_manifest: ukendt handling", {
  tmp <- setup_test_dir(c("test-x.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  result <- validate_manifest(
    list(files = list(valid_entry(list(handling = "invalid")))),
    tmp, mock_audit(list("test-x.R" = "green")))
  expect_false(result$valid)
  expect_true(any(grepl("ukendt handling", result$errors, ignore.case = TRUE)))
})

test_that("validate_manifest: reviewed:true + needs-triage", {
  tmp <- setup_test_dir(c("test-x.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  entry <- valid_entry(list(
    handling = "needs-triage", reviewed = TRUE,
    reviewer = "j", reviewed_date = "2026-04-17"
  ))
  result <- validate_manifest(list(files = list(entry)), tmp,
    mock_audit(list("test-x.R" = "green")))
  expect_false(result$valid)
  expect_true(any(grepl("placeholder", result$errors, ignore.case = TRUE)))
})

test_that("validate_manifest: asymmetrisk merge_with", {
  tmp <- setup_test_dir(c("test-a.R", "test-b.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  entry_a <- valid_entry(list(file = "test-a.R", handling = "merge-in-phase-2",
    merge_with = list("test-b.R"), rationale = "x"))
  entry_b <- valid_entry(list(file = "test-b.R"))
  result <- validate_manifest(list(files = list(entry_a, entry_b)), tmp,
    mock_audit(list("test-a.R" = "green", "test-b.R" = "green")))
  expect_false(result$valid)
  expect_true(any(grepl("asymmetrisk", result$errors, ignore.case = TRUE)))
})

test_that("validate_manifest: merge_with uden merge-handling", {
  tmp <- setup_test_dir(c("test-a.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  entry <- valid_entry(list(file = "test-a.R", handling = "keep",
    merge_with = list("test-b.R")))
  result <- validate_manifest(list(files = list(entry)), tmp,
    mock_audit(list("test-a.R" = "green")))
  expect_false(result$valid)
  expect_true(any(grepl("merge_with", result$errors, ignore.case = TRUE)))
})

test_that("validate_manifest: audit-kategori-mismatch", {
  tmp <- setup_test_dir(c("test-x.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  result <- validate_manifest(
    list(files = list(valid_entry(list(audit_category = "green")))),
    tmp, mock_audit(list("test-x.R" = "green-partial")))
  expect_false(result$valid)
  expect_true(any(grepl("audit_category", result$errors, ignore.case = TRUE)))
})

test_that("validate_manifest: handling != keep uden rationale", {
  tmp <- setup_test_dir(c("test-x.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  entry <- valid_entry(list(
    handling = "fix-in-phase-3", reviewed = TRUE,
    reviewer = "j", reviewed_date = "2026-04-17"
  ))
  result <- validate_manifest(list(files = list(entry)), tmp,
    mock_audit(list("test-x.R" = "green")))
  expect_false(result$valid)
  expect_true(any(grepl("rationale", result$errors, ignore.case = TRUE)))
})

test_that("validate_manifest: reviewed:true uden reviewer", {
  tmp <- setup_test_dir(c("test-x.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  entry <- valid_entry(list(reviewed = TRUE, reviewed_date = "2026-04-17"))
  result <- validate_manifest(list(files = list(entry)), tmp,
    mock_audit(list("test-x.R" = "green")))
  expect_false(result$valid)
  expect_true(any(grepl("reviewer", result$errors, ignore.case = TRUE)))
})

test_that("validate_manifest: manglende fil i manifest", {
  tmp <- setup_test_dir(c("test-a.R", "test-b.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  result <- validate_manifest(
    list(files = list(valid_entry(list(file = "test-a.R")))),
    tmp, mock_audit(list("test-a.R" = "green", "test-b.R" = "green")))
  expect_false(result$valid)
  expect_true(any(grepl("mangler", result$errors, ignore.case = TRUE)))
})

test_that("validate_manifest: forældet entry", {
  tmp <- setup_test_dir(c("test-a.R"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  manifest <- list(files = list(
    valid_entry(list(file = "test-a.R")),
    valid_entry(list(file = "test-b.R"))
  ))
  result <- validate_manifest(manifest, tmp,
    mock_audit(list("test-a.R" = "green")))
  expect_false(result$valid)
  expect_true(any(grepl("forældet|eksisterer ikke", result$errors, ignore.case = TRUE)))
})

# ---- render_report ----

test_that("render_report producerer markdown med forventede sektioner", {
  manifest <- list(
    metadata = list(total_files = 2L, audit_run = "2026-04-17T14:00:00+0200",
      manifest_schema_version = "1.0",
      review_status = list(reviewed = 2L, unreviewed = 0L, needs_triage = 0L)),
    files = list(
      list(file = "test-a.R", audit_category = "green", type = "unit",
           handling = "keep", reviewed = TRUE,
           reviewer = "j", reviewed_date = "2026-04-17"),
      list(file = "test-b.R", audit_category = "stub", type = "policy-guard",
           handling = "keep", rationale = "Policy-guard",
           reviewed = TRUE, reviewer = "j", reviewed_date = "2026-04-17")
    )
  )

  audit_data <- list(
    run_timestamp = "2026-04-17T14:00:00+0200",
    total_files = 2L, total_elapsed_s = 120,
    summary = list(green = 1L, stub = 1L),
    files = list(
      list(file = "test-a.R", category = "green",
           n_pass = 10L, n_fail = 0L, stderr_snippet = ""),
      list(file = "test-b.R", category = "stub",
           n_pass = 1L, n_fail = 0L, stderr_snippet = "")
    )
  )

  tmp <- tempfile(fileext = ".md")
  on.exit(unlink(tmp), add = TRUE)
  render_report(manifest, audit_data, tmp)

  content <- paste(readLines(tmp), collapse = "\n")
  expect_match(content, "# Test Suite Audit Report")
  expect_match(content, "## 1. Executive summary")
  expect_match(content, "## 2. Kritiske fund")
  expect_match(content, "## 3. Pr-fil klassifikations-tabel")
  expect_match(content, "## 4. Handling-oversigt")
  expect_match(content, "## 5. Top-10 fejlmønstre")
  expect_match(content, "## 6. Foreslået sekvens")
  expect_match(content, "## 7. Audit-classifier-limitationer")
  expect_match(content, "## 8. Appendix")
  expect_match(content, "test-a\\.R")
  expect_match(content, "test-b\\.R")
})
