#!/usr/bin/env Rscript
# Kører alle dev-tests manuelt. Ikke del af publish-gate.
suppressPackageStartupMessages(library(testthat))
# Source library i test-env før tests kører
source("dev/classify_tests_lib.R", local = FALSE)
test_dir("dev/tests", reporter = "summary")
