# ==============================================================================
# AUDIT: Rapportgenerering (#203)
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Beregn summary-statistikker fra fil-resultater
compute_summary <- function(files) {
  categories <- vapply(files, function(f) f$category, character(1))
  summary_counts <- as.list(table(categories))

  all_missing <- unlist(lapply(files, function(f) f$missing_functions %||% character(0)))
  if (length(all_missing) > 0) {
    tab <- table(all_missing)
    tab_sorted <- sort(tab, decreasing = TRUE)
    top_10 <- head(tab_sorted, 10)
    top_missing <- lapply(names(top_10), function(fn) {
      files_with_fn <- vapply(files, function(f) {
        fn %in% (f$missing_functions %||% character(0))
      }, logical(1))
      list(
        fn = fn,
        n_files = as.integer(top_10[[fn]]),
        files = vapply(files[files_with_fn], function(f) f$file, character(1))
      )
    })
  } else {
    top_missing <- list()
  }

  list(
    summary = summary_counts,
    top_missing_functions = top_missing
  )
}

#' Skriv maskinlaesbar JSON-rapport
write_json_report <- function(results, path) {
  jsonlite::write_json(
    results,
    path = path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null"
  )
  invisible(path)
}
