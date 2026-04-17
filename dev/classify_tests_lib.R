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

#' Auto-klassificér type-dimension fra filnavn + indhold.
#'
#' Prioriteret: første match vinder.
#'
#' @param filename Basename af testfil
#' @param file_contents Indhold som string
#' @return character(1): en af VALID_TYPES
auto_classify_type <- function(filename, file_contents) {
  # Prioritet 1: e2e-infrastruktur
  if (grepl("skip_on_ci\\(|AppDriver\\$new|shinytest2", file_contents)) {
    return("e2e")
  }

  # Prioritet 2: benchmark (filnavn)
  if (grepl("benchmark|performance", filename)) {
    return("benchmark")
  }

  # Prioritet 3: snapshot
  if (grepl("expect_snapshot|snapshot", file_contents) ||
      grepl("snapshot", filename)) {
    return("snapshot")
  }

  # Prioritet 4: policy-guard (filnavn)
  if (grepl("namespace|integrity|dependency|logging-debug", filename)) {
    return("policy-guard")
  }

  # Prioritet 5: integration (filnavn)
  if (grepl("^test-mod-|^test-e2e-|^test-integration-|workflow", filename)) {
    return("integration")
  }

  # Prioritet 6: fixture-based
  if (grepl('test_path\\(["\'][^"\']*\\.(csv|rds|xlsx|json)', file_contents)) {
    return("fixture-based")
  }

  # Default
  "unit"
}
