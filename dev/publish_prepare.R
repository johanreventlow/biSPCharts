#!/usr/bin/env Rscript
# dev/publish_prepare.R
#
# Forbered biSPCharts til Posit Connect Cloud-deployment.
#
# Script'et kører i to faser (hver i egen R-session for at undgå
# inkonsistent session-state mellem install og writeManifest):
#
#   Rscript dev/publish_prepare.R install    # Installér siblings + bump DESCRIPTION
#   Rscript dev/publish_prepare.R manifest   # Kør tests + regenerér manifest.json
#
# Orkestreres af /publish-to-connect slash-kommandoen, men kan også
# køres standalone (så skal git-operationer håndteres manuelt bagefter).
#
# Exit codes:
#   0 = success (fase færdig)
#   1 = forventet fejl (pre-flight, tests, osv.)

suppressPackageStartupMessages({
  required_pkgs <- c("remotes", "rsconnect", "devtools", "desc")
  missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace,
                                        logical(1), quietly = TRUE)]
  if (length(missing_pkgs) > 0) {
    cat(sprintf("FEJL: manglende R-pakker: %s\n",
                paste(missing_pkgs, collapse = ", ")))
    cat("Installér med: install.packages(c(\"",
        paste(missing_pkgs, collapse = "\", \""), "\"))\n", sep = "")
    quit(status = 1)
  }
})

SIBLINGS <- list(
  BFHcharts = "johanreventlow/BFHcharts",
  BFHtheme  = "johanreventlow/BFHtheme",
  BFHllm    = "johanreventlow/BFHllm"
)

log_step <- function(n, total, msg) {
  cat(sprintf("\n-> Trin %d/%d: %s\n", n, total, msg))
}
log_info <- function(msg)  cat(sprintf("  %s\n", msg))
log_ok   <- function(msg)  cat(sprintf("  [OK] %s\n", msg))
log_warn <- function(msg)  cat(sprintf("  [ADVARSEL] %s\n", msg))
log_fail <- function(msg) {
  cat(sprintf("  [FEJL] %s\n", msg))
  quit(status = 1)
}

fetch_latest_tag <- function(repo) {
  gh_available <- nzchar(Sys.which("gh"))
  if (gh_available) {
    out <- tryCatch(
      system2("gh",
              c("api", sprintf("repos/%s/tags", repo),
                "--jq", ".[].name"),
              stdout = TRUE, stderr = TRUE),
      error = function(e) character(0)
    )
    if (length(out) > 0 && !inherits(out, "try-error")) {
      tags <- grep("^v[0-9]+\\.[0-9]+\\.[0-9]+$", out, value = TRUE)
      if (length(tags) > 0) return(pick_highest_semver_tag(tags))
    }
  }

  url <- sprintf("https://github.com/%s.git", repo)
  out <- tryCatch(
    system2("git",
            c("ls-remote", "--tags", "--refs", url),
            stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  if (length(out) == 0 || inherits(out, "try-error")) {
    log_fail(sprintf("Kunne ikke hente tags for %s", repo))
  }
  tags <- sub(".*refs/tags/", "", out)
  tags <- grep("^v[0-9]+\\.[0-9]+\\.[0-9]+$", tags, value = TRUE)
  if (length(tags) == 0) {
    log_fail(sprintf("Ingen vX.Y.Z-tags fundet for %s", repo))
  }
  pick_highest_semver_tag(tags)
}

pick_highest_semver_tag <- function(tags) {
  parts <- do.call(rbind, lapply(tags, function(t) {
    m <- regmatches(t, regexec("^v(\\d+)\\.(\\d+)\\.(\\d+)$", t))[[1]]
    as.integer(m[2:4])
  }))
  ord <- order(-parts[, 1], -parts[, 2], -parts[, 3])
  tags[ord[1]]
}

strip_v <- function(tag) sub("^v", "", tag)

semver_ge <- function(a, b) {
  pa <- as.integer(strsplit(a, "\\.")[[1]])
  pb <- as.integer(strsplit(b, "\\.")[[1]])
  for (i in seq_along(pa)) {
    if (pa[i] > pb[i]) return(TRUE)
    if (pa[i] < pb[i]) return(FALSE)
  }
  TRUE
}

is_major_bump <- function(new, old) {
  ma <- as.integer(strsplit(new, "\\.")[[1]][1])
  mb <- as.integer(strsplit(old, "\\.")[[1]][1])
  ma > mb
}

current_lower_bound <- function(pkg) {
  d <- desc::desc(file = "DESCRIPTION")
  deps <- d$get_deps()
  row <- deps[deps$package == pkg, ]
  if (nrow(row) == 0) return(NA_character_)
  ver <- row$version[1]
  if (is.na(ver) || ver == "*") return(NA_character_)
  sub("^>=\\s*", "", ver)
}

bump_description <- function(pkg, new_version) {
  d <- desc::desc(file = "DESCRIPTION")
  d$set_dep(pkg, type = "Imports", version = sprintf(">= %s", new_version))
  d$write()
}

phase_install <- function() {
  total <- 4

  log_step(1, total, "Hent seneste tags fra GitHub")
  tag_info <- lapply(names(SIBLINGS), function(pkg) {
    repo <- SIBLINGS[[pkg]]
    tag <- fetch_latest_tag(repo)
    current <- current_lower_bound(pkg)
    list(pkg = pkg, repo = repo, tag = tag, version = strip_v(tag),
         current_lower = current)
  })
  for (info in tag_info) {
    log_info(sprintf("%-12s seneste=%s  DESCRIPTION-lower=%s",
                     info$pkg, info$tag,
                     ifelse(is.na(info$current_lower), "(ingen)", info$current_lower)))
  }

  log_step(2, total, "Advar ved MAJOR-bumps")
  any_major <- FALSE
  for (info in tag_info) {
    if (!is.na(info$current_lower) &&
        is_major_bump(info$version, info$current_lower)) {
      log_warn(sprintf("MAJOR-bump for %s: %s → %s (kan indeholde breaking changes)",
                       info$pkg, info$current_lower, info$version))
      any_major <- TRUE
    }
  }
  if (!any_major) log_ok("Ingen MAJOR-bumps detekteret")

  log_step(3, total, "Installér siblings fra tags")
  for (info in tag_info) {
    target <- sprintf("%s@%s", info$repo, info$tag)
    log_info(sprintf("Installerer %s ...", target))
    res <- tryCatch(
      remotes::install_github(target, upgrade = "never", quiet = TRUE,
                              force = TRUE),
      error = function(e) e
    )
    if (inherits(res, "error")) {
      log_fail(sprintf("install_github(%s) fejlede: %s", target, res$message))
    }
    log_ok(sprintf("%s@%s installeret", info$pkg, info$tag))
  }

  log_step(4, total, "Auto-bump DESCRIPTION lower-bounds")
  bumps <- character(0)
  for (info in tag_info) {
    if (is.na(info$current_lower)) {
      log_info(sprintf("%s: ingen lower-bound i DESCRIPTION — skipper", info$pkg))
      next
    }
    if (!identical(info$version, info$current_lower) &&
        semver_ge(info$version, info$current_lower)) {
      bump_description(info$pkg, info$version)
      bumps <- c(bumps, sprintf("%s %s → %s", info$pkg,
                                info$current_lower, info$version))
      log_ok(sprintf("%s: bumpet %s → %s", info$pkg,
                     info$current_lower, info$version))
    } else {
      log_info(sprintf("%s: ingen bump nødvendig (DESCRIPTION har %s)",
                       info$pkg, info$current_lower))
    }
  }

  cat("\n---BUMP-SUMMARY---\n")
  if (length(bumps) > 0) {
    cat(paste(bumps, collapse = "\n"), "\n", sep = "")
  } else {
    cat("(ingen bumps)\n")
  }
  cat("---END-BUMP-SUMMARY---\n")

  cat("\n[FASE install FÆRDIG]\n")
}

phase_manifest <- function() {
  total <- 3

  log_step(1, total, "Load biSPCharts (devtools::load_all)")
  res <- tryCatch(devtools::load_all(".", quiet = TRUE),
                  error = function(e) e)
  if (inherits(res, "error")) {
    log_fail(sprintf("load_all() fejlede: %s", res$message))
  }
  log_ok("Pakken loader uden fejl")

  log_step(2, total, "Kør testthat-tests")
  test_res <- tryCatch(
    devtools::test(".", stop_on_failure = TRUE, stop_on_warning = FALSE,
                   reporter = testthat::SummaryReporter$new()),
    error = function(e) e
  )
  if (inherits(test_res, "error")) {
    log_fail(sprintf("Tests fejlede: %s", test_res$message))
  }
  log_ok("Alle tests bestået")

  log_step(3, total, "Regenerér manifest.json")
  res <- tryCatch(
    rsconnect::writeManifest(appDir = ".", quiet = TRUE),
    error = function(e) e
  )
  if (inherits(res, "error")) {
    log_fail(sprintf("writeManifest() fejlede: %s", res$message))
  }
  log_ok("manifest.json regenereret")

  cat("\n[FASE manifest FÆRDIG]\n")
  cat("\nHUSK: opdater NEWS.md hvis denne publish leder til en egentlig release.\n")
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1) {
    cat("Brug: Rscript dev/publish_prepare.R <install|manifest>\n")
    quit(status = 1)
  }
  phase <- args[1]

  if (!file.exists("DESCRIPTION") ||
      !grepl("Package:\\s*biSPCharts", readLines("DESCRIPTION", n = 5))[1]) {
    log_fail("Skal køres fra biSPCharts project root")
  }

  switch(phase,
    "install"  = phase_install(),
    "manifest" = phase_manifest(),
    {
      cat(sprintf("Ukendt fase: %s (forventet: install|manifest)\n", phase))
      quit(status = 1)
    }
  )
}

main()
