# ==============================================================================
# CLASSIFY TESTS — funktionsbibliotek (sourceable uden side-effekter)
# ==============================================================================
#
# Dette er pure functions. Ingen CLI-parsing, ingen main(). Bruges af både
# dev/classify_tests.R (CLI-entry) og dev/tests/test-classify.R (TDD).
# ==============================================================================

# Null-coalescing helper (undgår rlang-afhængighed)
`%||%` <- function(a, b) if (is.null(a)) b else a

# Konstanter for schema-validering
VALID_TYPES <- c("policy-guard", "unit", "integration", "e2e", "benchmark",
                 "snapshot", "fixture-based")
VALID_HANDLINGS <- c("keep", "fix-in-phase-3", "merge-in-phase-2", "archive",
                     "rewrite", "blocked-by-change-1", "needs-triage")
