#!/usr/bin/env Rscript
# ==============================================================================
# install_git_hooks.R
# ==============================================================================
# §3.1.2 af harden-test-suite-regression-gate openspec change.
#
# Installerer biSPCharts git-hooks ved at oprette symlinks fra .git/hooks/
# til dev/git-hooks/. Idempotent — kan køres flere gange uden sideeffekter.
#
# Usage:
#   Rscript dev/install_git_hooks.R
#   Rscript dev/install_git_hooks.R --force   # Overskriv eksisterende hooks
#   Rscript dev/install_git_hooks.R --uninstall
#
# Hooks installeret:
#   - pre-push: dev/git-hooks/pre-push (lintr + testthat full suite)
#
# NB: pre-commit-hook håndteres separat (eksisterer allerede direkte i
# .git/hooks/pre-commit via pre-existing workflow, ikke symlink).
# ==============================================================================

install_git_hooks <- function(force = FALSE, uninstall = FALSE) {
  project_root <- tryCatch(
    {
      # Find repo root via rev-parse
      trimws(system2("git", c("rev-parse", "--show-toplevel"),
        stdout = TRUE, stderr = TRUE
      ))
    },
    error = function(e) {
      stop("Ikke i et git repository: ", conditionMessage(e))
    }
  )

  hooks_source <- file.path(project_root, "dev", "git-hooks")
  hooks_target <- file.path(project_root, ".git", "hooks")

  if (!dir.exists(hooks_source)) {
    stop("dev/git-hooks/ findes ikke — er du i biSPCharts-repoet?")
  }

  if (!dir.exists(hooks_target)) {
    stop(".git/hooks/ findes ikke — er dette et git repository?")
  }

  # Liste hooks der skal installeres (kun filer uden extension)
  hook_files <- list.files(hooks_source, full.names = FALSE)
  hook_files <- hook_files[!grepl("\\.(md|txt|sample)$", hook_files)]

  if (length(hook_files) == 0) {
    message("Ingen hooks fundet i dev/git-hooks/")
    return(invisible(NULL))
  }

  for (hook_name in hook_files) {
    target_path <- file.path(hooks_target, hook_name)
    source_path <- file.path(hooks_source, hook_name)

    if (uninstall) {
      if (file.exists(target_path)) {
        file.remove(target_path)
        message(sprintf("✗ Fjernet: .git/hooks/%s", hook_name))
      } else {
        message(sprintf("  (skipped) %s findes ikke", hook_name))
      }
      next
    }

    # Tjek om target allerede er korrekt symlink (resolve relativ path
    # relativt til .git/hooks/ target-mappen, ikke cwd)
    if (file.exists(target_path)) {
      existing_link <- tryCatch(Sys.readlink(target_path), error = function(e) "")
      if (nzchar(existing_link)) {
        resolved <- if (startsWith(existing_link, "/")) {
          existing_link
        } else {
          file.path(hooks_target, existing_link)
        }
        resolved_norm <- tryCatch(
          normalizePath(resolved, mustWork = FALSE),
          error = function(e) resolved
        )
        source_norm <- normalizePath(source_path, mustWork = FALSE)
        if (resolved_norm == source_norm) {
          message(sprintf("✓ %s: symlink allerede korrekt", hook_name))
          next
        }
      }

      if (!force) {
        message(sprintf(
          "⚠ %s findes allerede i .git/hooks/ — brug --force for at overskrive",
          hook_name
        ))
        next
      }

      file.remove(target_path)
    }

    # Opret relativ symlink for bedre portabilitet
    # .git/hooks/pre-push → ../../dev/git-hooks/pre-push
    relative_source <- file.path("..", "..", "dev", "git-hooks", hook_name)
    ok <- file.symlink(relative_source, target_path)

    if (ok) {
      # Verifiér at target er executable
      Sys.chmod(target_path, mode = "0755")
      message(sprintf("✓ Installeret: .git/hooks/%s → %s", hook_name, relative_source))
    } else {
      warning(sprintf("Kunne ikke oprette symlink for %s", hook_name), call. = FALSE)
    }
  }

  if (!uninstall) {
    message("")
    message("═════════════════════════════════════════════════════════════════")
    message(" Git hooks installeret!")
    message("═════════════════════════════════════════════════════════════════")
    message(" Test hook:             PREPUSH_MODE=fast git push --dry-run")
    message(" Bypass (nyttigt nu):   SKIP_PREPUSH=1 git push")
    message(" Fuld dokumentation:    docs/CONFIGURATION.md §Git Hooks")
    message("")
    message(" ⚠ VIGTIG: Pre-push vil blokere push indtil #239-paraply er")
    message("   lukket (43 fails + 21 errors i suite). Brug SKIP_PREPUSH=1")
    message("   indtil da. Se CLAUDE.md §6 for detaljer.")
    message("")
  }

  invisible(TRUE)
}

# CLI entry point
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  force_flag <- "--force" %in% args
  uninstall_flag <- "--uninstall" %in% args

  install_git_hooks(force = force_flag, uninstall = uninstall_flag)
}
