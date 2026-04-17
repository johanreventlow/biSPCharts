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
