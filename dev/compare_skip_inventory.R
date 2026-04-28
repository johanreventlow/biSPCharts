#!/usr/bin/env Rscript
# Compare two skip-inventory JSON files and report newly introduced TODO skips.

fail <- function(...) {
  cat(sprintf(...), "\n", sep = "")
  quit(status = 1)
}

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  fail("FEJL: R-pakken jsonlite er nødvendig")
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  fail("Brug: Rscript dev/compare_skip_inventory.R <base.json> <head.json>")
}

base_path <- args[[1]]
head_path <- args[[2]]
if (!file.exists(base_path)) fail("FEJL: base inventory mangler: %s", base_path)
if (!file.exists(head_path)) fail("FEJL: head inventory mangler: %s", head_path)

read_skips <- function(path) {
  inventory <- jsonlite::fromJSON(path)
  skips <- inventory$skips
  if (is.null(skips) || nrow(skips) == 0) {
    return(data.frame(file = character(), line = integer(),
                      category = character(), snippet = character()))
  }
  skips
}

normalize_snippet <- function(x) gsub("[[:space:]]+", " ", trimws(x))

skip_key <- function(skips) {
  paste(skips$file, skips$category, normalize_snippet(skips$snippet), sep = "\r")
}

base <- read_skips(base_path)
head <- read_skips(head_path)

base_todo <- base[base$category == "todo", , drop = FALSE]
head_todo <- head[head$category == "todo", , drop = FALSE]
new_todo <- head_todo[!skip_key(head_todo) %in% skip_key(base_todo), , drop = FALSE]

if (nrow(new_todo) == 0) {
  cat("Ingen nye TODO-skips.\n")
  quit(status = 0)
}

cat("Nye TODO-skips:\n")
for (i in seq_len(nrow(new_todo))) {
  cat(sprintf(
    "- %s:%s — %s\n",
    new_todo$file[[i]],
    new_todo$line[[i]],
    normalize_snippet(new_todo$snippet[[i]])
  ))
}
