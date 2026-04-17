# ==============================================================================
# AUDIT: Klassifikator for testfiler (#203)
# ==============================================================================
#
# Prioriteret klassifikation (foerste match vinder):
#   1. stub              — < 3 test-blokke
#   2. skipped-all       — alle tests skipped
#   3. broken-missing-fn — missing functions fundet OG ingen tests bestaar (exit 0 eller 1)
#   4. broken-api-drift  — exit != 0, API drift-moenster fundet
#   5. broken-other      — exit != 0, andre aarsager
#   6. green-partial     — exit = 0, men n_fail > 0 (nogle tests bestaar)
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

  # broken-missing-fn: missing functions fundet — gaelder uanset exit_code,
  # da testthat med stop_on_failure=FALSE altid afslutter med exit 0 selvom
  # tests fejler med "could not find function".
  # Kraever desuden at ingen tests bestaar (ellers er det green-partial med fn-warning).
  if (length(dynamic$missing_functions) > 0L && dynamic$n_pass == 0L) {
    return("broken-missing-fn")
  }

  if (dynamic$exit_code != 0L) {
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
