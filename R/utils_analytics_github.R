# utils_analytics_github.R
# Sync shinylogs-aggregat til privat GitHub repo (append-model).
#
# Hver Shiny-session skriver en enkelt .rds-fil til sessions/ mappen.
# Se bispcharts-analytics-data repo for layout.

#' Indsæt PAT i HTTPS git-URL for autentificering
#'
#' Omsætter `https://github.com/owner/repo.git` til
#' `https://x-access-token:<PAT>@github.com/owner/repo.git`
#' som gert::git_clone/push kan bruge.
#'
#' @param url HTTPS git URL
#' @param pat GitHub Personal Access Token
#' @return URL med indlejret PAT
#' @keywords internal
inject_pat_into_url <- function(url, pat) {
  if (!startsWith(url, "https://")) {
    stop("PIN_REPO_URL skal vaere HTTPS (fandt: ", url, ")", call. = FALSE)
  }
  sub("^https://", paste0("https://x-access-token:", pat, "@"), url)
}

#' Byg sorterbart filnavn til session-data
#'
#' Format: `<YYYYMMDDTHHMMSSZ>_<session-prefix>.rds`. Lexikografisk
#' sortering svarer til kronologisk sortering. Session prefix er
#' foerste 8 tegn af session_id (eller "s<unix-epoch>" hvis NULL).
#'
#' @param session_id Shiny session token (eller NULL)
#' @param timestamp POSIXct tidspunkt (default: Sys.time())
#' @return Filnavn som tegnstreng
#' @keywords internal
build_session_filename <- function(session_id = NULL, timestamp = Sys.time()) {
  ts_str <- format(timestamp, "%Y%m%dT%H%M%SZ", tz = "UTC")
  prefix <- if (is.null(session_id) || nchar(session_id) == 0) {
    paste0("s", as.integer(timestamp))
  } else if (nchar(session_id) >= 8) {
    substr(session_id, 1, 8)
  } else {
    session_id
  }
  paste0(ts_str, "_", prefix, ".rds")
}

#' Sync analytics-data til privat GitHub repo
#'
#' Kloner data-repo, skriver en ny .rds-fil til sessions/, commit'er
#' og pusher. Retry med rebase ved fast-forward-konflikt.
#'
#' Kraever env vars:
#' - GITHUB_PAT: Fine-grained PAT med contents:write paa data-repo
#' - PIN_REPO_URL: HTTPS URL til data-repo
#' - PIN_REPO_BRANCH: Valgfri (default: "main")
#'
#' @param all_data Navngivet liste fra read_shinylogs_all()
#' @param session_id Shiny session token (bruges i filnavn)
#' @param max_retries Antal push-retries ved konflikt (default: 3)
#' @return Liste med success (bool) + reason/filename/error
#' @keywords internal
sync_logs_to_github <- function(all_data,
                                session_id = NULL,
                                max_retries = 3L) {
  pat <- Sys.getenv("GITHUB_PAT")
  repo_url <- Sys.getenv("PIN_REPO_URL")
  branch <- Sys.getenv("PIN_REPO_BRANCH")
  if (nchar(branch) == 0) branch <- "main"

  if (nchar(pat) == 0 || nchar(repo_url) == 0) {
    return(list(success = FALSE, reason = "env_not_set"))
  }

  total_rows <- sum(vapply(all_data, nrow, integer(1)))
  if (total_rows == 0) {
    return(list(success = FALSE, reason = "empty_data"))
  }

  if (!requireNamespace("gert", quietly = TRUE)) {
    return(list(success = FALSE, reason = "gert_not_installed"))
  }

  tmp_dir <- tempfile("bispcharts-sync-")
  on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  auth_url <- inject_pat_into_url(repo_url, pat)
  filename <- build_session_filename(session_id)

  tryCatch(
    {
      gert::git_clone(
        url = auth_url,
        path = tmp_dir,
        branch = branch,
        verbose = FALSE
      )

      sessions_dir <- file.path(tmp_dir, "sessions")
      dir.create(sessions_dir, showWarnings = FALSE, recursive = TRUE)
      saveRDS(all_data, file.path(sessions_dir, filename))

      gert::git_add("sessions/", repo = tmp_dir)
      commit_msg <- sprintf(
        "data: %d sessions, %d inputs, %d outputs, %d errors",
        nrow(all_data$sessions), nrow(all_data$inputs),
        nrow(all_data$outputs), nrow(all_data$errors)
      )
      gert::git_commit(
        message = commit_msg,
        author = "bispcharts-bot <bot@users.noreply.github.com>",
        repo = tmp_dir
      )

      for (attempt in seq_len(max_retries)) {
        push_result <- tryCatch(
          {
            gert::git_push(
              remote = "origin",
              refspec = paste0("refs/heads/", branch),
              repo = tmp_dir,
              verbose = FALSE
            )
            list(ok = TRUE)
          },
          error = function(e) {
            list(ok = FALSE, error = conditionMessage(e))
          }
        )

        if (push_result$ok) {
          return(list(
            success = TRUE,
            filename = filename,
            attempt = attempt
          ))
        }

        if (attempt < max_retries) {
          # Rebase mod remote, proev igen
          try(
            gert::git_pull(
              repo = tmp_dir,
              rebase = TRUE,
              verbose = FALSE
            ),
            silent = TRUE
          )
        }
      }

      list(
        success = FALSE, reason = "push_failed",
        error = push_result$error
      )
    },
    error = function(e) {
      list(
        success = FALSE, reason = "clone_or_commit_failed",
        error = conditionMessage(e)
      )
    }
  )
}
