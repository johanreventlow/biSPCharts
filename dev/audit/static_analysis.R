# ==============================================================================
# AUDIT: Statisk analyse af testfiler (#203)
# ==============================================================================

#' Ekstraher alle funktionsnavne der kaldes i en R-fil
#'
#' Bruger utils::getParseData() til at parse AST og hente tokens af type
#' SYMBOL_FUNCTION_CALL. Udkommenterede kald ignoreres naturligt (ikke del
#' af parse-traeet).
#'
#' @param file Sti til R-fil
#' @return Character vector af unikke funktionsnavne
extract_function_calls <- function(file) {
  parsed <- tryCatch(
    parse(file, keep.source = TRUE),
    error = function(e) NULL
  )
  if (is.null(parsed) || length(parsed) == 0) return(character(0))

  pd <- utils::getParseData(parsed)
  if (is.null(pd) || nrow(pd) == 0) return(character(0))

  calls <- pd$text[pd$token == "SYMBOL_FUNCTION_CALL"]
  unique(calls)
}
