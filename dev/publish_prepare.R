#!/usr/bin/env Rscript
# dev/publish_prepare.R
#
# Forbered biSPCharts til Posit Connect Cloud-deployment.
#
# Script'et kører i to faser (hver i egen R-session for at undgå
# inkonsistent session-state mellem install og writeManifest):
#
#   Rscript dev/publish_prepare.R install                # Installér siblings + bump DESCRIPTION
#   Rscript dev/publish_prepare.R manifest               # Kør tests + regenerér manifest.json
#   Rscript dev/publish_prepare.R manifest --skip-tests  # Spring tests over (nødpublish, anti-pattern)
#
# Orkestreres af /publish-to-connect slash-kommandoen, men kan også
# køres standalone (så skal git-operationer håndteres manuelt bagefter).
#
# Exit codes:
#   0 = success (fase færdig)
#   1 = forventet fejl (pre-flight, tests, osv.)

ensure_writable_libpath <- function() {
  writable <- vapply(.libPaths(), function(p) file.access(p, 2) == 0,
                     logical(1))
  if (any(writable)) return(invisible(NULL))

  user_lib <- Sys.getenv("R_LIBS_USER", unset = "")
  if (!nzchar(user_lib)) {
    cat("FEJL: ingen skrivbar libpath og R_LIBS_USER er ikke sat.\n")
    quit(status = 1)
  }
  user_lib <- path.expand(user_lib)
  if (!dir.exists(user_lib)) {
    cat(sprintf("Opretter R_LIBS_USER: %s\n", user_lib))
    ok <- dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
    if (!ok || !dir.exists(user_lib)) {
      cat(sprintf("FEJL: kunne ikke oprette %s\n", user_lib))
      quit(status = 1)
    }
  }
  .libPaths(c(user_lib, .libPaths()))
  if (file.access(user_lib, 2) != 0) {
    cat(sprintf("FEJL: %s er stadig ikke skrivbar efter oprettelse.\n",
                user_lib))
    quit(status = 1)
  }
  invisible(NULL)
}

ensure_writable_libpath()

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

current_dep_info <- function(pkg) {
  d <- desc::desc(file = "DESCRIPTION")
  deps <- d$get_deps()
  row <- deps[deps$package == pkg, ]
  if (nrow(row) == 0) {
    return(list(version = NA_character_, type = NA_character_))
  }
  ver <- row$version[1]
  type <- row$type[1]
  if (is.na(ver) || ver == "*") {
    return(list(version = NA_character_, type = type))
  }
  list(version = sub("^>=\\s*", "", ver), type = type)
}

current_lower_bound <- function(pkg) current_dep_info(pkg)$version

bump_description <- function(pkg, new_version, dep_type) {
  d <- desc::desc(file = "DESCRIPTION")
  d$set_dep(pkg, type = dep_type, version = sprintf(">= %s", new_version))
  d$write()
}

phase_install <- function() {
  total <- 4

  log_step(1, total, "Hent seneste tags fra GitHub")
  tag_info <- lapply(names(SIBLINGS), function(pkg) {
    repo <- SIBLINGS[[pkg]]
    tag <- fetch_latest_tag(repo)
    dep <- current_dep_info(pkg)
    list(pkg = pkg, repo = repo, tag = tag, version = strip_v(tag),
         current_lower = dep$version, dep_type = dep$type)
  })
  for (info in tag_info) {
    log_info(sprintf("%-12s seneste=%s  DESCRIPTION-lower=%s",
                     info$pkg, info$tag,
                     ifelse(is.na(info$current_lower), "(ingen)", info$current_lower)))
  }

  log_step(2, total, "Valider tag-versioner mod DESCRIPTION")
  behind <- character(0)
  any_major <- FALSE
  for (info in tag_info) {
    if (is.na(info$current_lower)) next
    # GitHub-tag er ældre end DESCRIPTION lower-bound -> downgrade-risiko
    if (!semver_ge(info$version, info$current_lower) &&
        !identical(info$version, info$current_lower)) {
      behind <- c(behind, sprintf("%s: DESCRIPTION kræver >= %s, men seneste GitHub-tag er %s",
                                  info$pkg, info$current_lower, info$tag))
    }
    if (is_major_bump(info$version, info$current_lower)) {
      log_warn(sprintf("MAJOR-bump for %s: %s → %s (kan indeholde breaking changes)",
                       info$pkg, info$current_lower, info$version))
      any_major <- TRUE
    }
  }
  if (length(behind) > 0) {
    cat("\n")
    for (b in behind) log_warn(b)
    log_fail("GitHub-tags er bagud ift. DESCRIPTION. Push manglende tags til sibling-repoer først.")
  }
  if (!any_major) log_ok("Ingen MAJOR-bumps, ingen bagud-tags")

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
      bump_description(info$pkg, info$version, info$dep_type)
      bumps <- c(bumps, sprintf("%s %s → %s (%s)", info$pkg,
                                info$current_lower, info$version,
                                info$dep_type))
      log_ok(sprintf("%s: bumpet %s → %s i %s", info$pkg,
                     info$current_lower, info$version, info$dep_type))
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

phase_manifest <- function(skip_tests = FALSE) {
  total <- 3

  log_step(1, total, "Load biSPCharts (devtools::load_all)")
  res <- tryCatch(devtools::load_all(".", quiet = TRUE),
                  error = function(e) e)
  if (inherits(res, "error")) {
    log_fail(sprintf("load_all() fejlede: %s", res$message))
  }
  log_ok("Pakken loader uden fejl")

  if (skip_tests) {
    log_step(2, total, "Kør testthat-tests")
    log_warn("--skip-tests aktiveret: springer test-suite over (anti-pattern)")
    log_warn("Denne kørsel bør kun bruges til nødpublish mens test-refactor er i gang")
  } else {
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
  }

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
    cat("Brug: Rscript dev/publish_prepare.R <install|manifest> [--skip-tests]\n")
    quit(status = 1)
  }
  phase <- args[1]
  skip_tests <- "--skip-tests" %in% args[-1]

  if (!file.exists("DESCRIPTION") ||
      !grepl("Package:\\s*biSPCharts", readLines("DESCRIPTION", n = 5))[1]) {
    log_fail("Skal køres fra biSPCharts project root")
  }

  switch(phase,
    "install"  = phase_install(),
    "manifest" = phase_manifest(skip_tests = skip_tests),
    {
      cat(sprintf("Ukendt fase: %s (forventet: install|manifest)\n", phase))
      quit(status = 1)
    }
  )
}

main()
