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
