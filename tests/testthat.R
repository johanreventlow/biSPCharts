# testthat.R
# Test runner for SPC App

library(testthat)

# NOTE: shinytest2 must NOT be loaded here — library(shinytest2) initializes
# a chromote session that hangs in non-interactive Rscript environments.
# Tests that need shinytest2 should load it inside their own test blocks.

# Test directory
test_check("claude_spc")
