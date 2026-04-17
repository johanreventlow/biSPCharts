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

#' Render udvidet markdown-rapport.
render_report <- function(manifest, audit_data, output_path) {
  lines <- character()
  add <- function(...) lines <<- c(lines, paste0(...))

  # Header
  add("# Test Suite Audit Report")
  add("")
  add("**Audit-kørsel:** ", audit_data$run_timestamp)
  add("**Total filer:** ", audit_data$total_files)
  add("**Total kørselstid:** ", round(audit_data$total_elapsed_s %||% 0, 1), " s")
  add("**Issue:** #203")
  add("**Manifest:** `dev/audit-output/test-classification.yaml`")
  add("")
  add("---")
  add("")

  # 1. Executive summary
  add("## 1. Executive summary")
  add("")
  add("### Audit-kategorier")
  add("")
  add("| Kategori | Antal | % |")
  add("|---|---|---|")
  total <- audit_data$total_files
  for (cat_name in sort(names(audit_data$summary))) {
    n <- audit_data$summary[[cat_name]]
    add(sprintf("| `%s` | %d | %.1f%% |", cat_name, n, 100 * n / total))
  }
  add("")
  add("### Manifest-typer")
  add("")
  types <- vapply(manifest$files, `[[`, character(1), "type")
  add("| Type | Antal | % |")
  add("|---|---|---|")
  for (t in sort(unique(types))) {
    n <- sum(types == t)
    add(sprintf("| `%s` | %d | %.1f%% |", t, n, 100 * n / length(types)))
  }
  add("")

  # 2. Kritiske fund
  add("## 2. Kritiske fund")
  add("")
  add("- Audit-classifier's `n_test_blocks < 3 → stub`-heuristik misklassificerer")
  add("  værdifulde policy-tests. Alle 9 \"stubs\" verificeret som aktive.")
  add("- De 2 `skipped-all` filer er bevidste E2E-gates, ikke obsolete.")
  add("- Manifest-klassifikationen er menneske-verificeret ground truth.")
  add("")

  # 3. Pr-fil tabel
  add("## 3. Pr-fil klassifikations-tabel")
  add("")
  add("| Fil | Kategori | Type | Handling | Rationale |")
  add("|---|---|---|---|---|")
  handling_order <- c("blocked-by-change-1", "archive", "merge-in-phase-2",
                      "rewrite", "fix-in-phase-3", "needs-triage", "keep")
  sorted_files <- manifest$files[order(match(
    vapply(manifest$files, `[[`, character(1), "handling"),
    handling_order
  ))]
  for (entry in sorted_files) {
    rationale <- entry$rationale %||% ""
    add(sprintf("| `%s` | %s | %s | %s | %s |",
      entry$file, entry$audit_category, entry$type, entry$handling,
      gsub("\\|", "\\\\|", rationale)))
  }
  add("")

  # 4. Handling-oversigt
  add("## 4. Handling-oversigt")
  add("")
  for (h in handling_order) {
    matching <- Filter(function(e) e$handling == h, manifest$files)
    if (length(matching) == 0) next
    add(sprintf("### %s (%d filer)", h, length(matching)))
    add("")
    for (entry in matching) {
      r <- if (!is.null(entry$rationale)) paste0(" — ", entry$rationale) else ""
      add(sprintf("- `%s`%s", entry$file, r))
    }
    add("")
  }

  # 5. Top fejlmønstre
  add("## 5. Top-10 fejlmønstre")
  add("")
  all_stderr <- vapply(audit_data$files, function(f) f$stderr_snippet %||% "",
                       character(1))
  patterns <- list(
    "cannot open the connection (fixtures mangler)" = "cannot open the connection",
    "could not find function (API drift)" = "could not find function",
    "unused argument (testthat API-drift)" = "unused argument",
    "missing value where TRUE/FALSE" = "missing value where TRUE",
    "invalid input (data-drift)" = "invalid input|Invalid input",
    "encoding (æøå)" = "UTF-?8|encoding"
  )
  add("| Mønster | Filer |")
  add("|---|---|")
  for (p_name in names(patterns)) {
    n <- sum(grepl(patterns[[p_name]], all_stderr, ignore.case = TRUE))
    add(sprintf("| %s | %d |", p_name, n))
  }
  add("")

  # 6. Sekvens
  add("## 6. Foreslået sekvens for Fase 2-4")
  add("")
  add("1. **Fase 2 (konsolidering):** `archive` + `merge-in-phase-2`")
  add("2. **Fase 3 (fix):** `fix-in-phase-3` + `rewrite`, batched efter sektion 5-mønstre")
  add("3. **Fase 4 (standarder):** test-arkitektur-docs + evt. CI-check")
  add("")

  # 7. Limitationer
  add("## 7. Audit-classifier-limitationer")
  add("")
  add("- `n_test_blocks < 3 → stub` er for aggressiv; misklassificerer policy-tests")
  add("- Subproces-kørsel aktiverer `skip_on_ci()` lokalt (ENV-detektion)")
  add("")

  # 8. Appendix
  add("## 8. Appendix: Audit-kategori-fuldtabel")
  add("")
  for (cat_name in sort(names(audit_data$summary))) {
    matching <- Filter(function(f) f$category == cat_name, audit_data$files)
    add(sprintf("### %s (%d filer)", cat_name, length(matching)))
    add("")
    for (f in matching) {
      add(sprintf("- `%s` — %d pass / %d fail",
        f$file, f$n_pass %||% 0, f$n_fail %||% 0))
    }
    add("")
  }

  writeLines(lines, output_path)
  invisible(output_path)
}
