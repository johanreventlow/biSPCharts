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

#' Auto-klassificér handling-dimension fra audit-kategori.
#'
#' @param category character(1): audit-kategori
#' @param n_pass integer
#' @param n_fail integer
#' @return character(1)
auto_classify_handling <- function(category, n_pass, n_fail) {
  if (category == "green") return("keep")
  if (category == "skipped-all") return("keep")
  if (category == "broken-missing-fn") return("blocked-by-change-1")
  if (category == "stub") return("needs-triage")

  if (category == "green-partial") {
    total <- n_pass + n_fail
    if (total == 0) return("needs-triage")
    if (n_fail / total >= 0.5) return("needs-triage")
    return("fix-in-phase-3")
  }

  "needs-triage"
}

#' Orkestrér auto-klassifikation for alle filer i audit-JSON.
#'
#' @param audit_data list: parsed audit-JSON
#' @param tests_dir character(1): sti til tests/testthat/
#' @return list af manifest-entries
auto_classify <- function(audit_data, tests_dir) {
  lapply(audit_data$files, function(f) {
    file_path <- file.path(tests_dir, f$file)
    contents <- if (file.exists(file_path)) {
      paste(readLines(file_path, warn = FALSE), collapse = "\n")
    } else {
      ""
    }

    list(
      file = f$file,
      audit_category = f$category,
      type = auto_classify_type(f$file, contents),
      handling = auto_classify_handling(
        f$category,
        f$n_pass %||% 0L,
        f$n_fail %||% 0L
      ),
      reviewed = FALSE
    )
  })
}

MANIFEST_HEADER <- c(
  "# Test Classification Manifest",
  "#",
  "# Audit source: dev/audit-output/test-audit.json",
  "# Purpose: Ground truth for test-file classification",
  "#",
  "# Fields:",
  "#   audit_category: read-only reference (sync'd fra test-audit.json)",
  "#   type:           policy-guard|unit|integration|e2e|benchmark|snapshot|fixture-based",
  "#   handling:       keep|fix-in-phase-3|merge-in-phase-2|archive|rewrite|blocked-by-change-1|needs-triage",
  "#   merge_with:     (optional) liste af filnavne",
  "#   rationale:      (påkrævet når handling != keep)",
  "#   reviewed:       bool",
  "#   reviewer:       github-username (når reviewed: true)",
  "#   reviewed_date:  ISO date (når reviewed: true)",
  "",
  ""
)

#' Skriv manifest til YAML med header-kommentar.
write_manifest <- function(manifest, path) {
  yaml_body <- yaml::as.yaml(manifest, indent = 2, indent.mapping.sequence = TRUE)
  writeLines(c(MANIFEST_HEADER, yaml_body), path)
  invisible(path)
}

#' Læs manifest fra YAML-fil.
read_manifest <- function(path) {
  if (!file.exists(path)) {
    stop("Manifest ikke fundet: ", path)
  }
  yaml::read_yaml(path)
}

#' Merge auto-klassifikation med eksisterende manifest, bevarer reviewed: true.
merge_with_existing <- function(auto_entries, existing_manifest) {
  if (is.null(existing_manifest) || is.null(existing_manifest$files)) {
    return(auto_entries)
  }

  existing_by_file <- setNames(
    existing_manifest$files,
    vapply(existing_manifest$files, `[[`, character(1), "file")
  )

  lapply(auto_entries, function(auto) {
    existing <- existing_by_file[[auto$file]]
    if (is.null(existing) || !isTRUE(existing$reviewed)) {
      return(auto)
    }
    # Bevar existing, men sync audit_category fra auto
    existing$audit_category <- auto$audit_category
    existing
  })
}

#' Validér manifest mod schema + konsistens-regler.
#' @return list(valid = bool, errors = character vector)
validate_manifest <- function(manifest, tests_dir, audit_data = NULL) {
  errors <- character()

  audit_by_file <- if (!is.null(audit_data)) {
    setNames(
      vapply(audit_data$files, `[[`, character(1), "category"),
      vapply(audit_data$files, `[[`, character(1), "file")
    )
  } else NULL

  manifest_files <- vapply(manifest$files, `[[`, character(1), "file")

  for (entry in manifest$files) {
    file <- entry$file

    if (!entry$type %in% VALID_TYPES) {
      errors <- c(errors, sprintf("[%s] ukendt type: '%s'", file, entry$type))
    }

    if (!entry$handling %in% VALID_HANDLINGS) {
      errors <- c(errors, sprintf("[%s] ukendt handling: '%s'", file, entry$handling))
    }

    if (isTRUE(entry$reviewed) && entry$handling == "needs-triage") {
      errors <- c(errors, sprintf(
        "[%s] reviewed:true må ikke have placeholder handling 'needs-triage'", file))
    }

    has_merge_with <- !is.null(entry$merge_with) && length(entry$merge_with) > 0
    if (has_merge_with && entry$handling != "merge-in-phase-2") {
      errors <- c(errors, sprintf(
        "[%s] merge_with udfyldt men handling '%s' (forventet 'merge-in-phase-2')",
        file, entry$handling))
    }

    if (!is.null(audit_by_file) && file %in% names(audit_by_file)) {
      expected <- audit_by_file[[file]]
      if (!is.null(expected) && !is.null(entry$audit_category) &&
          entry$audit_category != expected) {
        errors <- c(errors, sprintf(
          "[%s] audit_category '%s' matcher ikke JSON '%s'",
          file, entry$audit_category, expected))
      }
    }

    if (!is.null(entry$handling) && entry$handling != "keep" &&
        entry$handling != "needs-triage" &&
        (is.null(entry$rationale) || nchar(entry$rationale) == 0)) {
      errors <- c(errors, sprintf(
        "[%s] handling '%s' kræver rationale", file, entry$handling))
    }

    if (isTRUE(entry$reviewed)) {
      if (is.null(entry$reviewer) || nchar(entry$reviewer) == 0) {
        errors <- c(errors, sprintf("[%s] reviewed:true kræver reviewer", file))
      }
      if (is.null(entry$reviewed_date) || nchar(entry$reviewed_date) == 0) {
        errors <- c(errors, sprintf("[%s] reviewed:true kræver reviewed_date", file))
      }
    }
  }

  # Symmetrisk merge_with
  for (entry in manifest$files) {
    if (!is.null(entry$merge_with) && length(entry$merge_with) > 0) {
      for (target_file in entry$merge_with) {
        target_entries <- Filter(function(e) e$file == target_file, manifest$files)
        if (length(target_entries) == 0) {
          errors <- c(errors, sprintf(
            "[%s] merge_with peger på '%s' der mangler i manifest",
            entry$file, target_file))
        } else {
          target <- target_entries[[1]]
          if (is.null(target$merge_with) || !(entry$file %in% target$merge_with)) {
            errors <- c(errors, sprintf(
              "[%s <-> %s] asymmetrisk merge_with-relation",
              entry$file, target_file))
          }
        }
      }
    }
  }

  # Filer i filesystem dækket
  filesystem_files <- list.files(tests_dir, pattern = "^test-.*\\.R$")
  missing_in_manifest <- setdiff(filesystem_files, manifest_files)
  if (length(missing_in_manifest) > 0) {
    errors <- c(errors, sprintf(
      "Filer i %s mangler i manifest: %s",
      tests_dir, paste(missing_in_manifest, collapse = ", ")))
  }

  orphaned <- setdiff(manifest_files, filesystem_files)
  if (length(orphaned) > 0) {
    errors <- c(errors, sprintf(
      "Forældet entry (fil eksisterer ikke): %s",
      paste(orphaned, collapse = ", ")))
  }

  list(valid = length(errors) == 0, errors = errors)
}
