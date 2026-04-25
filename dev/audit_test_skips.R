#!/usr/bin/env Rscript
# Scans tests/testthat/*.R for skip() calls and categorises them.
# Output: dev/audit-output/skip-inventory.json + skip-inventory.md
#
# Categories:
#   environment  — skip_on_ci(), skip_if_not_installed(), skip_on_os(), skip_on_cran()
#   todo         — skip() whose message contains TODO, FIXME, or a GitHub #<number> reference
#   permanent    — all other skip() calls

suppressPackageStartupMessages({
  library(jsonlite)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

test_dir <- "tests/testthat"
test_files <- list.files(test_dir, pattern = "\\.R$", full.names = TRUE)

# --- helpers -----------------------------------------------------------

categorise_skip <- function(call_text, context_lines) {
  # Environment helpers are always environment category
  if (grepl("skip_on_ci|skip_if_not_installed|skip_on_os|skip_on_cran|skip_if_offline", call_text)) {
    return("environment")
  }
  # Plain skip() — look at the message string for signals
  msg <- gsub("(?s)skip\\s*\\((.*)\\)", "\\1", call_text, perl = TRUE)
  # Check message text AND the surrounding comment lines for TODO signals
  context_text <- paste(c(context_lines, msg), collapse = " ")
  if (grepl("TODO|FIXME|#[0-9]+", context_text, ignore.case = FALSE)) {
    return("todo")
  }
  return("permanent")
}

# Parse a single file: return data.frame of skip calls
parse_file <- function(path) {
  lines <- readLines(path, warn = FALSE)
  results <- list()

  i <- 1L
  while (i <= length(lines)) {
    line <- lines[[i]]

    # Match skip_on_*() or skip_if_*() or plain skip(
    if (grepl("\\bskip(_on_|_if_|\\s*\\()", line)) {
      # Grab up to 3 preceding lines as context for TODO detection
      context_start <- max(1L, i - 3L)
      context_lines <- lines[context_start:(i - 1L)]

      # Collect the full call (may span multiple lines) — simple heuristic
      call_buf <- line
      j <- i
      balance <- nchar(gsub("[^(]", "", line)) - nchar(gsub("[^)]", "", line))

      while (balance > 0 && j < length(lines)) {
        j <- j + 1L
        next_line <- lines[[j]]
        call_buf <- paste(call_buf, next_line)
        balance <- balance +
          nchar(gsub("[^(]", "", next_line)) -
          nchar(gsub("[^)]", "", next_line))
      }

      category <- categorise_skip(call_buf, context_lines)
      # Extract first 120 chars of message for display
      msg_snippet <- trimws(sub("^\\s*skip[^(]*\\(", "", call_buf))
      msg_snippet <- substr(msg_snippet, 1L, 120L)

      results[[length(results) + 1L]] <- list(
        file     = basename(path),
        line     = i,
        category = category,
        snippet  = msg_snippet
      )
    }
    i <- i + 1L
  }

  if (length(results) == 0L) return(data.frame())
  do.call(rbind, lapply(results, as.data.frame, stringsAsFactors = FALSE))
}

# --- main --------------------------------------------------------------

all_skips <- do.call(rbind, Filter(function(x) nrow(x) > 0, lapply(test_files, parse_file)))

if (is.null(all_skips) || nrow(all_skips) == 0L) {
  all_skips <- data.frame(file = character(), line = integer(),
                           category = character(), snippet = character(),
                           stringsAsFactors = FALSE)
}

# Summary counts
summary_counts <- as.list(table(all_skips$category))
summary_counts$total <- nrow(all_skips)

inventory <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  summary      = summary_counts,
  skips        = all_skips
)

outdir <- "dev/audit-output"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

writeLines(jsonlite::toJSON(inventory, pretty = TRUE, auto_unbox = TRUE),
           file.path(outdir, "skip-inventory.json"))

# --- markdown report ---------------------------------------------------

md_lines <- c(
  "# Skip Inventory",
  "",
  paste0("Generated: ", inventory$generated_at),
  "",
  "## Summary",
  "",
  paste0("| Category | Count |"),
  paste0("|----------|-------|"),
  paste0("| environment | ", summary_counts$environment %||% 0L, " |"),
  paste0("| todo        | ", summary_counts$todo        %||% 0L, " |"),
  paste0("| permanent   | ", summary_counts$permanent   %||% 0L, " |"),
  paste0("| **total**   | **", summary_counts$total, "** |"),
  "",
  "## Detail",
  ""
)

if (nrow(all_skips) > 0L) {
  for (cat in c("todo", "permanent", "environment")) {
    sub_df <- all_skips[all_skips$category == cat, ]
    if (nrow(sub_df) == 0L) next
    md_lines <- c(md_lines, paste0("### ", cat), "")
    for (k in seq_len(nrow(sub_df))) {
      md_lines <- c(md_lines,
        paste0("- `", sub_df$file[[k]], ":", sub_df$line[[k]], "` — ",
               sub_df$snippet[[k]]))
    }
    md_lines <- c(md_lines, "")
  }
}

writeLines(md_lines, file.path(outdir, "skip-inventory.md"))

cat(sprintf(
  "Skip inventory: %d total (%d environment, %d todo, %d permanent)\n",
  summary_counts$total,
  summary_counts$environment %||% 0L,
  summary_counts$todo        %||% 0L,
  summary_counts$permanent   %||% 0L
))
