# ==============================================================================
# .Rprofile — biSPCharts project-level R startup
# ==============================================================================
# §3.1.3 af harden-test-suite-regression-gate openspec change.
#
# Kører automatisk når R startes i dette projekt-directory. Tjekker om
# pre-push git-hook er installeret og advarer hvis ikke.
#
# ⚠ SECURITY: Denne fil eksekveres automatisk ved hver R-session-start i
# projekt-directory — den udgør en supply-chain overflade. ENHVER ændring
# til .Rprofile SKAL reviewes ekstra grundigt (PR-reviewer tjekker manuelt
# for auto-executing kode, netværkskald, fil-skrivning uden for logs).
# Se .github/pull_request_template.md for review-checklist (#247 M5).
# ==============================================================================

local({
  # Kør kun tjek i interaktive sessioner (ikke i Rscript/CI)
  if (!interactive()) {
    return(invisible(NULL))
  }

  # Tjek om vi er i git repository
  project_root <- tryCatch(
    getwd(),
    error = function(e) NULL
  )
  if (is.null(project_root)) {
    return(invisible(NULL))
  }

  hook_path <- file.path(project_root, ".git", "hooks", "pre-push")
  source_path <- file.path(project_root, "dev", "git-hooks", "pre-push")

  # Tjek kun hvis vi faktisk er i biSPCharts-repoet
  if (!file.exists(source_path)) {
    return(invisible(NULL))
  }

  hook_installed <- file.exists(hook_path)
  hook_is_correct_symlink <- FALSE

  if (hook_installed) {
    link_target <- tryCatch(Sys.readlink(hook_path), error = function(e) "")
    if (nzchar(link_target)) {
      resolved <- if (startsWith(link_target, "/")) {
        link_target
      } else {
        file.path(dirname(hook_path), link_target)
      }
      hook_is_correct_symlink <- tryCatch(
        normalizePath(resolved, mustWork = FALSE) ==
          normalizePath(source_path, mustWork = FALSE),
        error = function(e) FALSE
      )
    }
  }

  if (!hook_is_correct_symlink) {
    message(
      "\n",
      "═════════════════════════════════════════════════════════════════\n",
      " ⚠ biSPCharts pre-push hook ikke installeret\n",
      "═════════════════════════════════════════════════════════════════\n",
      " Installation:  Rscript dev/install_git_hooks.R\n",
      " Rationale:     §3.1 af harden-test-suite-regression-gate\n",
      "                (lintr + testthat gate ved git push)\n",
      " Note:          Gate vil blokere push indtil #239-paraply er lukket.\n",
      "                Brug SKIP_PREPUSH=1 git push til midlertidig bypass.\n",
      "═════════════════════════════════════════════════════════════════\n"
    )
  }

  invisible(NULL)
})
