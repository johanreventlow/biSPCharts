# ==============================================================================
# AUDIT: Dynamic runner (#203)
# ==============================================================================

#' Parse testthat ProgressReporter output til taelletal
parse_testthat_output <- function(stdout) {
  pattern <- "\\[\\s*FAIL\\s+(\\d+)\\s*\\|\\s*WARN\\s+\\d+\\s*\\|\\s*SKIP\\s+(\\d+)\\s*\\|\\s*PASS\\s+(\\d+)\\s*\\]"
  matches <- regmatches(stdout, regexec(pattern, stdout))
  hits <- Filter(function(m) length(m) > 1, matches)

  if (length(hits) == 0) {
    return(list(n_pass = 0L, n_fail = 0L, n_skip = 0L))
  }

  last <- hits[[length(hits)]]
  list(
    n_fail = as.integer(last[2]),
    n_skip = as.integer(last[3]),
    n_pass = as.integer(last[4])
  )
}

#' Ekstraher manglende funktionsnavne fra stderr
extract_missing_functions <- function(stderr) {
  if (length(stderr) == 0) return(character(0))
  text <- paste(stderr, collapse = "\n")
  pattern <- "could not find function\\s+[\"']([^\"']+)[\"']"
  matches <- regmatches(text, gregexpr(pattern, text))[[1]]
  if (length(matches) == 0) return(character(0))

  fns <- sub(pattern, "\\1", matches)
  unique(fns)
}

#' Detekter API-drift-moenstre i stderr
detect_api_drift <- function(stderr) {
  if (length(stderr) == 0) return(FALSE)
  text <- paste(stderr, collapse = "\n")
  patterns <- c(
    "unused argument",
    "argument .* is missing, with no default",
    "formal argument .* matched by multiple",
    "unknown parameter"
  )
  any(vapply(patterns, function(p) grepl(p, text), logical(1)))
}
