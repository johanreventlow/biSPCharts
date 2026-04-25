#!/usr/bin/env Rscript
if (nzchar(Sys.getenv("R_TESTS"))) quit(status = 0L)

# Run Performance Tests — tynd wrapper omkring canonical runner (§3.3.3)
#
# Canonical entrypoint: tests/run_canonical.R
# Denne wrapper beholdes for bagudkompatibilitet.

source("tests/run_canonical.R")
run_canonical_tests(scope = "performance", stop_on_failure = TRUE)
