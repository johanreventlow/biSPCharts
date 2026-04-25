#!/usr/bin/env Rscript
if (nzchar(Sys.getenv("R_TESTS"))) quit(status = 0L)

# Run All Tests — tynd wrapper omkring canonical runner (§3.3.3)
#
# Canonical entrypoint: tests/run_canonical.R
# Kører ALLE tests (unit + integration + performance) som EN pkgload-
# baseret session for at undgå state-leaks mellem separate R-processer.

source("tests/run_canonical.R")
run_canonical_tests(scope = "all", stop_on_failure = TRUE)
