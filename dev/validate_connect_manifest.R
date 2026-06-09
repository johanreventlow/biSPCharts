#!/usr/bin/env Rscript
# Validate that Posit Connect manifest GitHub packages match DESCRIPTION.

fail <- function(...) {
  cat(sprintf(...), "\n", sep = "")
  quit(status = 1)
}

info <- function(...) cat(sprintf(...), "\n", sep = "")

read_description <- function(path = "DESCRIPTION") {
  if (!file.exists(path)) fail("FEJL: %s findes ikke", path)
  as.list(read.dcf(path)[1, ])
}

parse_deps <- function(text) {
  if (is.null(text) || is.na(text) || !nzchar(text)) {
    return(data.frame(package = character(), version = character()))
  }

  items <- trimws(unlist(strsplit(gsub("\n", " ", text), ",")))
  rows <- lapply(items[nzchar(items)], function(item) {
    match <- regmatches(item, regexec("^([A-Za-z0-9.]+)\\s*(?:\\(([^)]+)\\))?$", item))[[1]]
    if (length(match) == 0) return(NULL)
    version <- if (length(match) >= 3) match[[3]] else NA_character_
    data.frame(package = match[[2]], version = version, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, Filter(Negate(is.null), rows))
  if (is.null(out)) data.frame(package = character(), version = character()) else out
}

parse_remotes <- function(text) {
  if (is.null(text) || is.na(text) || !nzchar(text)) {
    return(data.frame(package = character(), repo = character(), ref = character()))
  }

  items <- trimws(unlist(strsplit(gsub("\n", " ", text), ",")))
  rows <- lapply(items[nzchar(items)], function(item) {
    match <- regmatches(item, regexec("^([^/]+)/([^@]+)(?:@(.+))?$", item))[[1]]
    if (length(match) == 0) return(NULL)
    ref <- if (length(match) >= 4 && nzchar(match[[4]])) match[[4]] else NA_character_
    data.frame(
      package = match[[3]],
      repo = paste(match[[2]], match[[3]], sep = "/"),
      ref = ref,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, Filter(Negate(is.null), rows))
  if (is.null(out)) data.frame(package = character(), repo = character(), ref = character()) else out
}

strip_operator <- function(version) {
  if (is.null(version) || is.na(version) || !nzchar(version)) return(NA_character_)
  sub("^>=\\s*", "", version)
}

version_ge <- function(actual, minimum) {
  if (is.na(minimum) || !nzchar(minimum)) return(TRUE)
  utils::compareVersion(actual, minimum) >= 0
}

manifest_package <- function(manifest, package) {
  pkg <- manifest$packages[[package]]
  if (is.null(pkg)) return(NULL)
  pkg$description
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  manifest_path <- if (length(args) >= 1) args[[1]] else "manifest.json"
  if (!file.exists(manifest_path)) fail("FEJL: %s findes ikke", manifest_path)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    fail("FEJL: R-pakken jsonlite er nødvendig for manifest-validering")
  }

  description <- read_description()
  imports <- parse_deps(description$Imports)
  suggests <- parse_deps(description$Suggests)
  deps <- rbind(imports, suggests)
  remotes <- parse_remotes(description$Remotes)
  manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)

  failures <- character(0)
  checked <- character(0)
  semver_tag_pattern <- "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
  # Fuld 40-char commit-SHA. Immutable -> deploy-stabil for tredjeparts-repos
  # vi ikke kan tagge (jf. exemption nedenfor + issue #445).
  full_sha_pattern <- "^[0-9a-f]{40}$"
  # Vores egne sibling-pakker: vi kontrollerer tags -> kraev vX.Y.Z.
  sibling_org_prefix <- "johanreventlow/"

  # Cycle 9 (maturity-audit Codex 2026-05-10): Forbidden file-pattern denylist.
  # release-tarball-audit forbyder allerede .DS_Store i tarball, men dette gate
  # validerer manifest.json ej forurenes med Finder/IDE-artefakter der bryder
  # deploy-reproducibility.
  forbidden_patterns <- list(
    list(pattern = "\\.DS_Store$", reason = "macOS Finder-artefakt"),
    list(pattern = "^\\.claude/", reason = "Claude-config (lokal-only)"),
    list(pattern = "^logs/", reason = "Runtime logs (rotation handled by Connect)"),
    list(pattern = "^\\.\\.Rcheck/", reason = "R CMD check output (build-artefakt)"),
    list(pattern = "\\.backup$", reason = "Backup-fil (lokal-only)")
  )

  manifest_files <- if (is.null(manifest$files)) character(0) else names(manifest$files)
  for (pattern_def in forbidden_patterns) {
    matches <- grep(pattern_def$pattern, manifest_files, value = TRUE, perl = TRUE)
    if (length(matches) > 0) {
      failures <- c(failures, sprintf(
        "Forbidden file(s) i manifest (%s): %s",
        pattern_def$reason,
        paste(matches, collapse = ", ")
      ))
    }
  }

  for (i in seq_len(nrow(remotes))) {
    remote <- remotes[i, ]
    pkg_desc <- manifest_package(manifest, remote$package)
    dep_row <- deps[deps$package == remote$package, ]
    is_required_import <- remote$package %in% imports$package

    # Ref-stabilitetskrav afhaenger af repo-ejerskab (issue #445 ramte en
    # MUTABEL feature-branch-ref, ikke immutable SHA'er):
    #   - Egne siblings (johanreventlow/*): kraev vX.Y.Z-tag. Vi kontrollerer
    #     deres tags, og tag-pinning er VERSIONING_POLICY-konventionen.
    #   - Tredjeparts (fx anhoej/pbcharts): utagget upstream vi ikke kan tagge.
    #     En fuld 40-char SHA er immutable og dermed lige saa deploy-stabil som
    #     et tag. Branch-navne afvises stadig (de er mutable, kernen i #445).
    is_sibling <- startsWith(remote$repo, sibling_org_prefix)
    if (!is.na(remote$ref)) {
      if (is_sibling && !grepl(semver_tag_pattern, remote$ref)) {
        failures <- c(failures, sprintf(
          "%s ref er ikke vX.Y.Z-tag: DESCRIPTION Remotes=%s (feature-branches er ikke deploy-stabile for egne siblings, jf. issue #445)",
          remote$package, remote$ref
        ))
      } else if (!is_sibling &&
                 !grepl(semver_tag_pattern, remote$ref) &&
                 !grepl(full_sha_pattern, remote$ref)) {
        failures <- c(failures, sprintf(
          "%s ref er hverken vX.Y.Z-tag eller fuld 40-char SHA: DESCRIPTION Remotes=%s (branch-refs er ikke deploy-stabile for tredjeparts-pakker, jf. issue #445)",
          remote$package, remote$ref
        ))
      }
    }

    if (is.null(pkg_desc)) {
      if (is_required_import) {
        failures <- c(failures, sprintf(
          "%s findes i DESCRIPTION Imports og Remotes, men mangler i %s",
          remote$package, manifest_path
        ))
      }
      next
    }

    checked <- c(checked, remote$package)

    manifest_repo <- paste(pkg_desc$GithubUsername %||% pkg_desc$RemoteUsername,
                           pkg_desc$GithubRepo %||% pkg_desc$RemoteRepo,
                           sep = "/")
    if (!identical(manifest_repo, remote$repo)) {
      failures <- c(failures, sprintf(
        "%s repo mismatch: DESCRIPTION=%s, manifest=%s",
        remote$package, remote$repo, manifest_repo
      ))
    }

    # Ref-match: ved SHA-pin (tredjeparts) registrerer remotes-install ofte
    # RemoteRef=HEAD mens den immutable SHA staar i RemoteSha/GithubSHA1.
    # Sammenlign derfor DESCRIPTION-SHA mod manifest-SHA, ikke mod RemoteRef.
    manifest_ref <- pkg_desc$GithubRef %||% pkg_desc$RemoteRef
    manifest_sha <- pkg_desc$GithubSHA1 %||% pkg_desc$RemoteSha
    ref_is_sha <- !is.na(remote$ref) && grepl(full_sha_pattern, remote$ref)
    if (!is.na(remote$ref)) {
      if (ref_is_sha) {
        if (!identical(manifest_sha, remote$ref)) {
          failures <- c(failures, sprintf(
            "%s SHA mismatch: DESCRIPTION Remotes=%s, manifest RemoteSha=%s",
            remote$package, remote$ref, manifest_sha %||% "(mangler)"
          ))
        }
      } else if (!identical(manifest_ref, remote$ref)) {
        failures <- c(failures, sprintf(
          "%s ref mismatch: DESCRIPTION Remotes=%s, manifest=%s",
          remote$package, remote$ref, manifest_ref
        ))
      }
    }

    if (nrow(dep_row) > 0) {
      minimum <- strip_operator(dep_row$version[[1]])
      if (!version_ge(pkg_desc$Version, minimum)) {
        failures <- c(failures, sprintf(
          "%s version mismatch: DESCRIPTION kræver >= %s, manifest har %s",
          remote$package, minimum, pkg_desc$Version
        ))
      }
    }
  }

  if (length(failures) > 0) {
    cat("Connect manifest er ude af sync:\n")
    for (failure in failures) cat("- ", failure, "\n", sep = "")
    cat("\nKør: Rscript dev/publish_prepare.R install && Rscript dev/publish_prepare.R manifest\n")
    quit(status = 1)
  }

  info("Connect manifest OK (%s)", paste(sort(unique(checked)), collapse = ", "))
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x) || !nzchar(x)) y else x
}

main()
