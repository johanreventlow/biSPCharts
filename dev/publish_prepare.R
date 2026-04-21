#!/usr/bin/env Rscript
# dev/publish_prepare.R
#
# Forbered biSPCharts til Posit Connect Cloud-deployment.
#
# Script'et kører i to faser (hver i egen R-session for at undgå
# inkonsistent session-state mellem install og writeManifest):
#
#   Rscript dev/publish_prepare.R install   # Installér siblings + bump DESCRIPTION
#   Rscript dev/publish_prepare.R manifest  # Kør tests + regenerér manifest.json
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
  BFHtheme  = "johanreventlow/BFHtheme"
  # BFHllm midlertidigt fjernet — reaktivér når AI-suggestions genindføres.
  # BFHllm    = "johanreventlow/BFHllm"
)

gate_log_step <- function(n, total, msg) {
  cat(sprintf("\n-> Trin %d/%d: %s\n", n, total, msg))
}
gate_log_info <- function(msg)  cat(sprintf("  %s\n", msg))
gate_log_ok   <- function(msg)  cat(sprintf("  [OK] %s\n", msg))
gate_log_warn <- function(msg)  cat(sprintf("  [ADVARSEL] %s\n", msg))
gate_log_fail <- function(msg) {
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
    gate_log_fail(sprintf("Kunne ikke hente tags for %s", repo))
  }
  tags <- sub(".*refs/tags/", "", out)
  tags <- grep("^v[0-9]+\\.[0-9]+\\.[0-9]+$", tags, value = TRUE)
  if (length(tags) == 0) {
    gate_log_fail(sprintf("Ingen vX.Y.Z-tags fundet for %s", repo))
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

  gate_log_step(1, total, "Hent seneste tags fra GitHub")
  tag_info <- lapply(names(SIBLINGS), function(pkg) {
    repo <- SIBLINGS[[pkg]]
    tag <- fetch_latest_tag(repo)
    dep <- current_dep_info(pkg)
    list(pkg = pkg, repo = repo, tag = tag, version = strip_v(tag),
         current_lower = dep$version, dep_type = dep$type)
  })
  for (info in tag_info) {
    gate_log_info(sprintf("%-12s seneste=%s  DESCRIPTION-lower=%s",
                     info$pkg, info$tag,
                     ifelse(is.na(info$current_lower), "(ingen)", info$current_lower)))
  }

  gate_log_step(2, total, "Valider tag-versioner mod DESCRIPTION")
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
      gate_log_warn(sprintf("MAJOR-bump for %s: %s → %s (kan indeholde breaking changes)",
                       info$pkg, info$current_lower, info$version))
      any_major <- TRUE
    }
  }
  if (length(behind) > 0) {
    cat("\n")
    for (b in behind) gate_log_warn(b)
    gate_log_fail("GitHub-tags er bagud ift. DESCRIPTION. Push manglende tags til sibling-repoer først.")
  }
  if (!any_major) gate_log_ok("Ingen MAJOR-bumps, ingen bagud-tags")

  gate_log_step(3, total, "Installér siblings fra tags")
  for (info in tag_info) {
    target <- sprintf("%s@%s", info$repo, info$tag)
    gate_log_info(sprintf("Installerer %s ...", target))
    res <- tryCatch(
      remotes::install_github(target, upgrade = "never", quiet = TRUE,
                              force = TRUE),
      error = function(e) e
    )
    if (inherits(res, "error")) {
      gate_log_fail(sprintf("install_github(%s) fejlede: %s", target, res$message))
    }
    gate_log_ok(sprintf("%s@%s installeret", info$pkg, info$tag))
  }

  gate_log_step(4, total, "Auto-bump DESCRIPTION lower-bounds")
  bumps <- character(0)
  for (info in tag_info) {
    if (is.na(info$current_lower)) {
      gate_log_info(sprintf("%s: ingen lower-bound i DESCRIPTION — skipper", info$pkg))
      next
    }
    if (!identical(info$version, info$current_lower) &&
        semver_ge(info$version, info$current_lower)) {
      bump_description(info$pkg, info$version, info$dep_type)
      bumps <- c(bumps, sprintf("%s %s → %s (%s)", info$pkg,
                                info$current_lower, info$version,
                                info$dep_type))
      gate_log_ok(sprintf("%s: bumpet %s → %s i %s", info$pkg,
                     info$current_lower, info$version, info$dep_type))
    } else {
      gate_log_info(sprintf("%s: ingen bump nødvendig (DESCRIPTION har %s)",
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
  # §4.3.1 Full 5-step publish-gate — kører i rækkefølge:
  #   1. lintr::lint_package()
  #   2. testthat via canonical entrypoint (§3.3)
  #   3. E2E-suite via tests/e2e/run_e2e.R (§4.1)
  #   4. covr-threshold-check (§4.2)
  #   5. rsconnect::writeManifest()
  #
  # §4.3.2 Hver fase logger struktureret output til
  # dev/audit-output/publish-gate-<timestamp>.log
  #
  # Bypass (midlertidig, indtil #239-paraply er lukket):
  #   SKIP_PUBLISH_GATE=1 Rscript dev/publish_prepare.R manifest
  # Springer trin 2-4 over (lintr, testthat, E2E, coverage) og kører
  # kun pre-flight load + writeManifest. Matcher SKIP_PREPUSH-pattern
  # fra pre-push hook (§3.1). Dokumenteret i ADR-017.
  skip_gate <- toupper(Sys.getenv("SKIP_PUBLISH_GATE", "0")) %in% c("1", "TRUE")
  total <- if (skip_gate) 2L else 6L

  # §4.3.2 Setup struktureret log-fil
  gate_log_dir <- file.path(getwd(), "dev", "audit-output")
  if (!dir.exists(gate_log_dir)) {
    dir.create(gate_log_dir, recursive = TRUE)
  }
  gate_log <- file.path(
    gate_log_dir,
    sprintf("publish-gate-%s.log", format(Sys.time(), "%Y%m%d-%H%M%S"))
  )
  writeLines(
    c(
      sprintf("# Publish-gate run %s", format(Sys.time())),
      sprintf("# R version: %s", R.version.string),
      sprintf("# Bypass (SKIP_PUBLISH_GATE=1): %s", skip_gate),
      ""
    ),
    gate_log
  )

  if (skip_gate) {
    cat("\n⚠ SKIP_PUBLISH_GATE=1 — springer trin 2-4 over\n")
    cat("  (lintr, testthat, E2E, coverage)\n")
    cat("  Kører kun pre-flight load + writeManifest\n\n")
  }

  log_gate <- function(step, status, message = "") {
    line <- sprintf("[%s] step=%d status=%s %s",
      format(Sys.time(), "%H:%M:%S"), step, status, message)
    cat(line, "\n", file = gate_log, append = TRUE, sep = "")
  }

  # Trin 0 (pre-flight): Load biSPCharts (beholder fra original publish-gate)
  gate_log_step(1, total, "Load biSPCharts (devtools::load_all)")
  res <- tryCatch(devtools::load_all(".", quiet = TRUE),
                  error = function(e) e)
  if (inherits(res, "error")) {
    log_gate(0, "FAIL", res$message)
    gate_log_fail(sprintf("load_all() fejlede: %s", res$message))
  }
  log_gate(0, "OK", "biSPCharts loaded")
  gate_log_ok("Pakken loader uden fejl")

  if (!skip_gate) {
    # Trin 1: lintr
    gate_log_step(2, total, "Kør lintr::lint_package() (§4.3.1 trin 1)")
    lint_res <- tryCatch(
      {
        lints <- lintr::lint_package()
        errors <- purrr::keep(lints, ~ .x$type == "error")
        if (length(errors) > 0) {
          stop(sprintf("%d lintr ERROR(s) fundet", length(errors)))
        }
        warnings_ct <- length(purrr::keep(lints, ~ .x$type == "warning"))
        list(ok = TRUE, warnings = warnings_ct)
      },
      error = function(e) e
    )
    if (inherits(lint_res, "error")) {
      log_gate(1, "FAIL", lint_res$message)
      gate_log_fail(sprintf("lintr fejlede: %s", lint_res$message))
    }
    log_gate(1, "OK", sprintf("%d warnings (non-blocking)", lint_res$warnings))
    gate_log_ok(sprintf("lintr OK (%d warnings, ingen ERRORs)", lint_res$warnings))

    # Trin 2: testthat via canonical (§3.3)
    gate_log_step(3, total, "Kør testthat-tests via canonical (§4.3.1 trin 2)")
    canonical_path <- file.path(getwd(), "tests", "run_canonical.R")
    test_res <- tryCatch(
      {
        source(canonical_path, local = TRUE)
        run_canonical_tests(scope = "unit", stop_on_failure = TRUE)
      },
      error = function(e) e
    )
    if (inherits(test_res, "error")) {
      log_gate(2, "FAIL", test_res$message)
      gate_log_fail(sprintf("Tests fejlede: %s", test_res$message))
    }
    log_gate(2, "OK", "canonical testthat passed")
    gate_log_ok("Alle tests bestået")

    # Trin 3: E2E-suite (§4.1.4 + §4.3.1 trin 3)
    gate_log_step(4, total, "Kør E2E-suite (§4.3.1 trin 3)")
    e2e_path <- file.path(getwd(), "tests", "e2e", "run_e2e.R")
    if (file.exists(e2e_path)) {
      e2e_res <- tryCatch(
        {
          source(e2e_path, local = TRUE)
          run_e2e()
        },
        error = function(e) e
      )
      if (inherits(e2e_res, "error")) {
        log_gate(3, "FAIL", e2e_res$message)
        gate_log_fail(sprintf("E2E fejlede: %s", e2e_res$message))
      }
      log_gate(3, "OK", "E2E passed or Chrome-skipped")
      gate_log_ok("E2E OK (eller skipped ved Chrome-mangel)")
    } else {
      log_gate(3, "SKIP", "tests/e2e/run_e2e.R ikke fundet")
      cat("  [skipped] tests/e2e/run_e2e.R ikke fundet\n")
    }

    # Trin 4: Coverage threshold — fjernet fra publish-gate (for tidskrævende,
    # ikke relevant for deploy-sikkerhed). Kør via GitHub Actions eller on-demand:
    #   Rscript tests/coverage.R
    gate_log_step(5, total, "Coverage-check (skipped — kør via GH Actions)")
    log_gate(4, "SKIP", "coverage fjernet fra publish-gate — ikke deploy-kritisk")
  } else {
    log_gate(1, "SKIP", "SKIP_PUBLISH_GATE=1")
    log_gate(2, "SKIP", "SKIP_PUBLISH_GATE=1")
    log_gate(3, "SKIP", "SKIP_PUBLISH_GATE=1")
    log_gate(4, "SKIP", "SKIP_PUBLISH_GATE=1")
  }

  # Trin 5: writeManifest (kun hvis trin 1-4 grønne ELLER skip_gate)
  gate_log_step(total, total, "Regenerér manifest.json (§4.3.1 trin 5)")
  res <- tryCatch(
    rsconnect::writeManifest(appDir = "."),
    error = function(e) e
  )
  if (inherits(res, "error")) {
    log_gate(5, "FAIL", res$message)
    gate_log_fail(sprintf("writeManifest() fejlede: %s", res$message))
  }
  log_gate(5, "OK", "manifest.json regenereret")
  gate_log_ok("manifest.json regenereret")

  cat("\n[FASE manifest FÆRDIG]\n")
  cat(sprintf("\nPublish-gate log: %s\n", gate_log))
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
    gate_log_fail("Skal køres fra biSPCharts project root")
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
