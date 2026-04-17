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

#' Skriv menneskelaesbar Markdown-rapport
write_markdown_report <- function(results, path) {
  lines <- c()

  lines <- c(lines,
    "# Test Audit Report",
    "",
    sprintf("**Dato:** %s", results$run_timestamp),
    sprintf("**biSPCharts version:** %s", results$biSPCharts_version),
    sprintf("**R version:** %s", results$r_version),
    sprintf("**Total filer:** %d", results$total_files),
    sprintf("**Total koerselstid:** %.1f s", results$total_elapsed_s),
    "",
    "---",
    ""
  )

  lines <- c(lines,
    "## Executive Summary",
    "",
    "| Kategori | Antal | % af total |",
    "|----------|-------|-----------|"
  )
  for (cat_name in names(results$summary)) {
    n <- results$summary[[cat_name]]
    pct <- 100 * n / results$total_files
    lines <- c(lines, sprintf("| `%s` | %d | %.1f%% |", cat_name, n, pct))
  }
  lines <- c(lines, "", "---", "")

  if (length(results$top_missing_functions) > 0) {
    lines <- c(lines,
      "## Top-10 Manglende R-funktioner",
      "",
      "| Funktion | Antal filer |",
      "|----------|-------------|"
    )
    for (item in results$top_missing_functions) {
      lines <- c(lines, sprintf("| `%s` | %d |", item$fn, item$n_files))
    }
    lines <- c(lines, "", "---", "")
  }

  category_order <- c(
    "broken-missing-fn", "broken-api-drift", "broken-other",
    "green-partial", "skipped-all", "stub", "green"
  )

  for (cat_name in category_order) {
    files_in_cat <- Filter(function(f) f$category == cat_name, results$files)
    if (length(files_in_cat) == 0) next

    lines <- c(lines,
      sprintf("## Kategori: `%s` (%d filer)", cat_name, length(files_in_cat)),
      ""
    )

    for (f in files_in_cat) {
      lines <- c(lines, sprintf("### `%s`", f$file))
      lines <- c(lines,
        sprintf("- LOC: %d", f$loc %||% 0),
        sprintf("- Test-blokke: %d", f$n_test_blocks %||% 0),
        sprintf("- Pass/Fail/Skip: %d / %d / %d",
                f$n_pass %||% 0, f$n_fail %||% 0, f$n_skip %||% 0)
      )
      if (length(f$missing_functions %||% character(0)) > 0) {
        lines <- c(lines, sprintf("- Manglende funktioner: `%s`",
                                   paste(f$missing_functions, collapse = "`, `")))
      }
      if (!is.null(f$stderr_snippet) && nzchar(f$stderr_snippet)) {
        lines <- c(lines, "", "```", f$stderr_snippet, "```")
      }
      lines <- c(lines, "")
    }
    lines <- c(lines, "---", "")
  }

  lines <- c(lines,
    "## Scope-forslag",
    "",
    generate_scope_suggestion(results),
    ""
  )

  writeLines(lines, path)
  invisible(path)
}

#' Generer scope-forslag baseret paa fordeling
generate_scope_suggestion <- function(results) {
  s <- results$summary
  total <- results$total_files
  broken <- (s$`broken-missing-fn` %||% 0) +
            (s$`broken-api-drift` %||% 0) +
            (s$`broken-other` %||% 0)
  green <- (s$green %||% 0) + (s$`green-partial` %||% 0)
  stubs <- (s$stub %||% 0) + (s$`skipped-all` %||% 0)

  lines <- c(
    sprintf("- **Green:** %d af %d (%.0f%%)", green, total, 100 * green / total),
    sprintf("- **Broken:** %d af %d (%.0f%%)", broken, total, 100 * broken / total),
    sprintf("- **Stubs/skipped:** %d af %d (%.0f%%)", stubs, total, 100 * stubs / total),
    ""
  )

  suggestion <- if (broken / total > 0.5) {
    "**Anbefaling: Omfattende scope** - mere end halvdelen brudt."
  } else if (broken / total > 0.2) {
    "**Anbefaling: Moderat scope** - batched proposals pr. funktionsgruppe."
  } else {
    "**Anbefaling: Minimal scope** - fokuser paa de faa braekkede filer."
  }

  paste(c(lines, suggestion), collapse = "\n")
}

#' Print kort oversigt til konsol
print_console_summary <- function(results) {
  cat("\n")
  cat("========================================\n")
  cat("  Test Audit Summary\n")
  cat("========================================\n")
  cat(sprintf("Total filer:     %d\n", results$total_files))
  cat(sprintf("Koerselstid:     %.1f s\n", results$total_elapsed_s))
  cat("\n")
  cat("Fordeling pr. kategori:\n")
  for (cat_name in names(results$summary)) {
    cat(sprintf("  %-22s %d\n", cat_name, results$summary[[cat_name]]))
  }
  cat("========================================\n")
}
