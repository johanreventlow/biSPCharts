#!/usr/bin/env Rscript
# ==============================================================================
# poll_sibling_bumps.R
# ==============================================================================
# Poller sibling-pakker for nye git-tags + opretter chore(deps): PR per
# VERSIONING_POLICY.md §E. MAJOR-bumps producerer issue (manuel review)
# fremfor auto-PR. Designet til at koeres af GitHub Actions cron daglig.
#
# Adresserer manuel cross-repo bump-friction i biSPCharts udvikling.
#
# Env-vars:
#   DRY_RUN=1     -- log forventede actions men opret ej PR/issue
#   GH_TOKEN      -- gh CLI authentication (paakraevet)
#   GITHUB_PAT    -- privat repo-adgang (BFHchartsAssets)
#
# Exit-koder:
#   0 -- normal completion (kan have skipped pkger uden bump)
#   1 -- fatal error (DESCRIPTION ej parsbar, gh CLI mangler, etc.)
# ==============================================================================

SIBLINGS <- c("BFHcharts", "BFHtheme", "BFHllm", "BFHchartsAssets")
REPO_OWNER <- "johanreventlow"
DRY_RUN <- isTRUE(nzchar(Sys.getenv("DRY_RUN", "")) && Sys.getenv("DRY_RUN") != "0")

log_info <- function(...) cat("[INFO]", sprintf(...), "\n")
log_warn <- function(...) cat("[WARN]", sprintf(...), "\n")
log_error <- function(...) cat("[ERROR]", sprintf(...), "\n")
log_dry <- function(...) cat("[DRY-RUN]", sprintf(...), "\n")

# Sikker exec-wrapper bruger system2() (intet shell -> ingen injection).
run_cmd <- function(cmd, args, dry_skip = TRUE, ...) {
  if (DRY_RUN && dry_skip) {
    log_dry("%s %s", cmd, paste(args, collapse = " "))
    return(0)
  }
  system2(cmd, args, ...)
}

# --- DESCRIPTION parsing ---

read_description <- function() {
  if (!file.exists("DESCRIPTION")) {
    log_error("DESCRIPTION ej fundet")
    quit(status = 1)
  }
  as.list(read.dcf("DESCRIPTION")[1, ])
}

# Parse versionsnumre fra Imports/Suggests-feltet for én sibling.
parse_dep_version <- function(text, pkg) {
  if (is.null(text) || is.na(text) || !nzchar(text)) return(NA_character_)
  items <- trimws(unlist(strsplit(gsub("\n", " ", text), ",")))
  pattern <- sprintf("^%s\\s*(?:\\(>=\\s*([0-9.]+)\\))?\\s*$", pkg)
  for (item in items) {
    m <- regmatches(item, regexec(pattern, item))[[1]]
    if (length(m) >= 1 && nzchar(m[1])) {
      return(if (length(m) >= 2 && nzchar(m[2])) m[2] else NA_character_)
    }
  }
  NA_character_
}

# Parse Remotes ref for én sibling. Returnér tag-version uden 'v' eller NA.
parse_remote_ref <- function(text, pkg) {
  if (is.null(text) || is.na(text) || !nzchar(text)) return(NA_character_)
  items <- trimws(unlist(strsplit(gsub("\n", " ", text), ",")))
  pattern <- sprintf("^%s/%s@v?([0-9.]+)$", REPO_OWNER, pkg)
  for (item in items) {
    m <- regmatches(item, regexec(pattern, item))[[1]]
    if (length(m) >= 2 && nzchar(m[2])) return(m[2])
  }
  NA_character_
}

# --- GitHub tag fetching ---

get_latest_tag <- function(pkg) {
  url <- sprintf("https://github.com/%s/%s", REPO_OWNER, pkg)
  refs <- tryCatch(
    suppressWarnings(system2("git", c("ls-remote", "--tags", "--refs", url),
                              stdout = TRUE, stderr = TRUE)),
    error = function(e) {
      log_error("git ls-remote fejlede for %s: %s", pkg, conditionMessage(e))
      character(0)
    }
  )
  if (length(refs) == 0 || any(grepl("Authentication failed|Repository not found", refs))) {
    log_warn("Ingen tags hentet for %s (privat repo uden PAT?)", pkg)
    return(NULL)
  }

  tags <- sub(".*refs/tags/", "", refs)
  vtags <- grep("^v[0-9]+\\.[0-9]+\\.[0-9]+$", tags, value = TRUE)
  if (length(vtags) == 0) return(NULL)

  versions <- sub("^v", "", vtags)
  ord <- order(numeric_version(versions))
  highest_idx <- ord[length(ord)]
  list(tag = vtags[highest_idx], version = versions[highest_idx])
}

# --- Bump-detection ---

is_bump_needed <- function(current, latest) {
  if (is.na(current) || is.null(current)) return(FALSE)
  numeric_version(latest) > numeric_version(current)
}

is_major_bump <- function(current, latest) {
  if (is.na(current) || is.null(current)) return(FALSE)
  cur_v <- as.integer(strsplit(as.character(current), "\\.")[[1]])[1]
  new_v <- as.integer(strsplit(as.character(latest), "\\.")[[1]])[1]
  cur_v != new_v
}

# --- DESCRIPTION update ---

update_description_file <- function(pkg, new_version) {
  desc_lines <- readLines("DESCRIPTION", encoding = "UTF-8")

  # Update Imports/Suggests-version (mønster: "    pkg (>= X.Y.Z),")
  imports_pattern <- sprintf("(\\s*%s\\s*\\(>=\\s*)[0-9.]+(\\)\\s*,?\\s*)$", pkg)
  desc_lines <- sub(imports_pattern, sprintf("\\1%s\\2", new_version), desc_lines, perl = TRUE)

  # Update Remotes-ref (mønster: "    owner/pkg@v0.10.3,")
  remote_pattern <- sprintf("(%s/%s@v?)[0-9.]+", REPO_OWNER, pkg)
  desc_lines <- sub(remote_pattern, sprintf("\\1%s", new_version), desc_lines, perl = TRUE)

  if (DRY_RUN) {
    log_dry("Ville opdatere DESCRIPTION for %s -> %s", pkg, new_version)
    return(invisible(NULL))
  }
  writeLines(desc_lines, "DESCRIPTION")
}

# --- PR/issue helpers ---

branch_exists <- function(branch_name) {
  refs <- suppressWarnings(system2("git",
    c("ls-remote", "--heads", "origin", branch_name),
    stdout = TRUE, stderr = FALSE))
  length(refs) > 0
}

open_pr_exists <- function(branch_name) {
  out <- suppressWarnings(system2("gh",
    c("pr", "list", "--head", branch_name, "--state", "open", "--json", "number"),
    stdout = TRUE, stderr = FALSE))
  any(grepl("\"number\"", out))
}

open_issue_exists <- function(title) {
  out <- suppressWarnings(system2("gh",
    c("issue", "list", "--search", title, "--state", "open", "--json", "title"),
    stdout = TRUE, stderr = FALSE))
  any(grepl(title, out, fixed = TRUE))
}

# --- PR creation (PATCH/MINOR-bumps) ---

create_bump_pr <- function(pkg, current, latest_version) {
  branch <- sprintf("chore/deps-bump-%s-%s", tolower(pkg), latest_version)

  if (branch_exists(branch)) {
    log_info("Branch %s findes allerede paa remote -- skip", branch); return(invisible(NULL))
  }
  if (open_pr_exists(branch)) {
    log_info("Aaben PR for %s findes allerede -- skip", branch); return(invisible(NULL))
  }

  log_info("Opretter bump-PR: %s %s -> %s (branch=%s)",
           pkg, current, latest_version, branch)

  if (DRY_RUN) {
    log_dry("Ville oprette branch %s + DESCRIPTION-edit + manifest-regen + PR", branch)
    return(invisible(NULL))
  }

  if (run_cmd("git", c("checkout", "-b", branch), dry_skip = FALSE) != 0) {
    log_error("Kunne ej oprette branch %s", branch); return(invisible(NULL))
  }

  update_description_file(pkg, latest_version)

  log_info("Regenererer manifest.json")
  if (system2("Rscript", "dev/_regen_manifest.R") != 0) {
    log_error("Manifest-regen fejlede for %s -- aborter bump", pkg)
    system2("git", c("checkout", "develop"))
    system2("git", c("branch", "-D", branch))
    return(invisible(NULL))
  }

  if (system2("Rscript", c("dev/validate_connect_manifest.R", "manifest.json")) != 0) {
    log_error("Manifest-validation fejlede for %s -- aborter bump", pkg)
    system2("git", c("checkout", "develop"))
    system2("git", c("branch", "-D", branch))
    return(invisible(NULL))
  }

  system2("git", c("add", "DESCRIPTION", "manifest.json"))
  msg <- sprintf("chore(deps): bump %s to %s", pkg, latest_version)
  system2("git", c("commit", "-m", msg))
  system2("git", c("push", "-u", "origin", branch))

  body <- sprintf(
    "Auto-bump af `%s` til v%s.\n\nDetekteret af `sibling-bump-poller` (cron daglig 07:00 UTC).\n\n## Aendret\n- `DESCRIPTION:Imports/Suggests` lower-bound\n- `DESCRIPTION:Remotes` ref\n- `manifest.json` regenereret\n\n## Verifikation\n- [ ] CI groen (R-CMD-check, validate-manifest)\n- [ ] NEWS-entry tilfoejes manuelt hvis cross-repo migration noedvendig (per VERSIONING §C)\n\n## Reference\nPer `VERSIONING_POLICY.md` §E: separat `chore(deps):`-PR per sibling-bump.\n\nSibling release: https://github.com/%s/%s/releases/tag/v%s",
    pkg, latest_version, REPO_OWNER, pkg, latest_version
  )

  system2("gh", c("pr", "create",
                  "--base", "develop",
                  "--head", branch,
                  "--title", msg,
                  "--body", body,
                  "--label", "deps"))

  system2("git", c("checkout", "develop"))
}

# --- Issue creation (MAJOR-bumps) ---

create_major_bump_issue <- function(pkg, current, latest_version) {
  title <- sprintf("[manual review] %s v%s er en MAJOR bump", pkg, latest_version)

  if (open_issue_exists(title)) {
    log_info("MAJOR-bump-issue findes allerede aaben for %s", pkg)
    return(invisible(NULL))
  }

  log_info("Opretter MAJOR-bump-issue: %s", title)

  if (DRY_RUN) {
    log_dry("Ville oprette issue: %s", title)
    return(invisible(NULL))
  }

  body <- sprintf(
    "`%s` har tagget v%s -- det er en MAJOR-bump (current: %s).\n\nPer `VERSIONING_POLICY.md` §A skal MAJOR-bumps reviewes manuelt foer downstream-bump:\n\n1. Laes `%s` NEWS for breaking changes\n2. Vurdér konsekvens for biSPCharts kald-sites (bfh_qic, target_value, etc.)\n3. Implementér noedvendige tilpasninger\n4. Aaben manuel `chore(deps):`-PR med baade DESCRIPTION-bump + kald-site-aendringer\n5. Tilfoej Breaking changes-sektion til NEWS hvis migration paavirker brugere\n\n## Sibling release\nhttps://github.com/%s/%s/releases/tag/v%s\n\n## Auto-skip\nDenne issue blev oprettet automatisk af `sibling-bump-poller` (cron daglig). Auto-PR er bevidst skippet for MAJOR-bumps for at undgaa breaking change uden review.",
    pkg, latest_version, current, pkg, REPO_OWNER, pkg, latest_version
  )

  system2("gh", c("issue", "create",
                  "--title", title,
                  "--body", body,
                  "--label", "deps"))
}

# --- Main ---

main <- function() {
  log_info("sibling-bump-poller start (DRY_RUN=%s)", DRY_RUN)

  # Verificer gh CLI tilgaengelig (sikker via system2 + which)
  if (!nzchar(Sys.which("gh")) && !DRY_RUN) {
    log_error("gh CLI ej tilgaengelig"); quit(status = 1)
  }

  desc <- read_description()

  log_info("Polling %d siblings: %s",
           length(SIBLINGS), paste(SIBLINGS, collapse = ", "))

  bump_pr_count <- 0
  bump_issue_count <- 0

  for (pkg in SIBLINGS) {
    cat("\n")
    log_info("=== %s ===", pkg)

    # Determinér current version: foretraek Remotes (mest reliable),
    # fallback til Imports/Suggests-version
    current <- parse_remote_ref(desc$Remotes, pkg)
    if (is.na(current)) current <- parse_dep_version(desc$Imports, pkg)
    if (is.na(current)) current <- parse_dep_version(desc$Suggests, pkg)

    if (is.na(current)) {
      log_warn("%s ej fundet i DESCRIPTION (Remotes/Imports/Suggests) -- skip", pkg)
      next
    }

    latest <- get_latest_tag(pkg)
    if (is.null(latest)) {
      log_warn("Ingen valid tag fundet for %s -- skip", pkg); next
    }

    log_info("%s: current=%s, latest=%s", pkg, current, latest$version)

    if (!is_bump_needed(current, latest$version)) {
      log_info("%s ajour -- ingen action", pkg); next
    }

    if (is_major_bump(current, latest$version)) {
      log_info("%s MAJOR-bump -> opret issue", pkg)
      create_major_bump_issue(pkg, current, latest$version)
      bump_issue_count <- bump_issue_count + 1
    } else {
      log_info("%s MINOR/PATCH-bump -> opret auto-PR", pkg)
      create_bump_pr(pkg, current, latest$version)
      bump_pr_count <- bump_pr_count + 1
    }
  }

  cat("\n")
  log_info("Done -- PRs: %d, Issues: %d", bump_pr_count, bump_issue_count)
}

main()
