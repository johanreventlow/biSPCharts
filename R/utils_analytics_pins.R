# utils_analytics_pins.R
# Log-aggregering fra shinylogs JSON-filer og publicering via pins

#' Laes shinylogs session-filer til data.frame
#'
#' Delegerer til \code{read_shinylogs_all()} og returnerer kun sessions-elementet.
#'
#' @param log_directory Sti til log-mappe
#' @return data.frame med session-data (tom data.frame hvis ingen filer)
#' @keywords internal
read_shinylogs_sessions <- function(log_directory) {
  read_shinylogs_all(log_directory)$sessions
}

#' Laes alle shinylogs kategorier til navngivet liste
#'
#' Laeser `shinylogs_*.json`-filer som shinylogs::store_json skriver
#' direkte i log_directory (en fil per session, samlet struktur:
#' session/inputs/outputs/errors). Delegerer til
#' shinylogs::read_json_logs hvis pakken er tilgaengelig, ellers
#' fallback til manuel parsing.
#'
#' @param log_directory Sti til log-mappe
#' @return Navngivet liste med 4 data.frames: sessions, inputs, outputs, errors
#' @keywords internal
read_shinylogs_all <- function(log_directory) {
  empty_result <- list(
    sessions = data.frame(),
    inputs = data.frame(),
    outputs = data.frame(),
    errors = data.frame()
  )

  if (!dir.exists(log_directory)) {
    return(empty_result)
  }

  json_files <- list.files(
    log_directory,
    pattern = "^shinylogs_.*\\.json$",
    full.names = TRUE,
    recursive = FALSE
  )
  json_files <- json_files[file.size(json_files) > 0]
  if (length(json_files) == 0) {
    return(empty_result)
  }

  # Brug shinylogs' egen parser hvis tilgaengelig -- den haandterer
  # to_dt-konverteringer og setTime-parsing korrekt
  if (requireNamespace("shinylogs", quietly = TRUE)) {
    parsed <- tryCatch(
      shinylogs::read_json_logs(log_directory),
      error = function(e) {
        log_warn(paste("shinylogs::read_json_logs fejlede:", e$message),
          .context = LOG_CONTEXTS$analytics$pins
        )
        NULL
      }
    )
    if (!is.null(parsed)) {
      # shinylogs returnerer session/inputs/errors/outputs (session singular)
      # -- vi normaliserer til sessions/inputs/outputs/errors
      return(list(
        sessions = as.data.frame(parsed$session %||% data.frame()),
        inputs = as.data.frame(parsed$inputs %||% data.frame()),
        outputs = as.data.frame(parsed$outputs %||% data.frame()),
        errors = as.data.frame(parsed$errors %||% data.frame())
      ))
    }
  }

  # Fallback: manuel parsing hvis shinylogs ikke er tilgaengelig
  entries <- lapply(json_files, function(f) {
    tryCatch(
      jsonlite::fromJSON(f, simplifyVector = TRUE),
      error = function(e) {
        log_warn(paste("Kunne ikke laese", basename(f), ":", e$message),
          .context = LOG_CONTEXTS$analytics$pins
        )
        NULL
      }
    )
  })
  entries <- purrr::compact(entries)
  if (length(entries) == 0) {
    return(empty_result)
  }

  bind_safe <- function(lst) {
    dfs <- purrr::compact(lst)
    if (length(dfs) == 0) {
      return(data.frame())
    }
    tryCatch(dplyr::bind_rows(dfs), error = function(e) data.frame())
  }

  list(
    sessions = bind_safe(lapply(entries, function(e) as.data.frame(e$session))),
    inputs = bind_safe(lapply(entries, function(e) as.data.frame(e$inputs))),
    outputs = bind_safe(lapply(entries, function(e) as.data.frame(e$outputs))),
    errors = bind_safe(lapply(entries, function(e) as.data.frame(e$errors)))
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Roter log-filer (komprimer gamle, slet meget gamle)
#'
#' @param log_directory Sti til log-mappe
#' @param compress_after_days Komprimer filer aeldre end dette (default: 90)
#' @param delete_after_days Slet filer aeldre end dette (default: 365)
#' @keywords internal
rotate_log_files <- function(log_directory,
                             compress_after_days = ANALYTICS_CONFIG$log_compress_after_days,
                             delete_after_days = ANALYTICS_CONFIG$log_retention_days) {
  json_files <- list.files(log_directory,
    pattern = "\\.json$",
    full.names = TRUE, recursive = TRUE
  )
  if (length(json_files) == 0) {
    return(invisible(NULL))
  }

  now <- Sys.time()
  for (f in json_files) {
    file_age_days <- as.numeric(difftime(now, file.info(f)$mtime, units = "days"))

    if (file_age_days > delete_after_days) {
      unlink(f)
      unlink(paste0(f, ".gz"))
    } else if (file_age_days > compress_after_days) {
      tryCatch(
        {
          con <- gzfile(paste0(f, ".gz"), "wb")
          writeLines(readLines(f), con)
          close(con)
          unlink(f)
        },
        error = function(e) {
          log_warn(paste("Komprimering fejlede:", basename(f), e$message),
            .context = LOG_CONTEXTS$analytics$rotation
          )
        }
      )
    }
  }
  invisible(NULL)
}

#' Tilladte kolonner i analytics-upload (allowlist)
#'
#' Definerer praecist hvilke kolonner der maa optaede i persisterede
#' analytics-filer. Alle andre kolonner droppes foer upload.
#' Brug `filter_shinylogs_allowlist()` til at anvende filteret.
#'
#' Opdater `docs/ANALYTICS_PRIVACY.md` naar denne liste aendres.
#'
#' @format Named list med vectors af tilladte kolonnenavne
#' @keywords internal
SHINYLOGS_ALLOWLIST <- list(
  sessions = c("session_hash", "app", "server_connected", "server_disconnected"),
  inputs   = c("session_hash", "name", "timestamp", "value"),
  outputs  = c("session_hash", "name", "timestamp"),
  errors   = c("session_hash", "name", "timestamp", "redacted_message")
)

#' Filtrer shinylogs-data til allowlistede kolonner
#'
#' Hash'er sessionid-kolonnen, redacterer fejlbeskeder og beholder
#' kun kolonner fra \code{SHINYLOGS_ALLOWLIST}.
#'
#' @param all_data Navngivet liste fra \code{read_shinylogs_all()}
#' @return Filtreret liste med samme struktur
#' @keywords internal
filter_shinylogs_allowlist <- function(all_data) {
  hash_col <- function(df) {
    if ("sessionid" %in% names(df) && nrow(df) > 0) {
      df$session_hash <- vapply(as.character(df$sessionid), sanitize_session_token, character(1L))
      df$sessionid <- NULL
    }
    df
  }

  keep_allowed <- function(df, allowed) {
    df[, intersect(names(df), allowed), drop = FALSE]
  }

  processed <- lapply(all_data, hash_col)
  if (nrow(processed$errors) > 0) {
    processed$errors <- redact_error_messages(processed$errors)
  }

  list(
    sessions = keep_allowed(processed$sessions, SHINYLOGS_ALLOWLIST$sessions),
    inputs   = keep_allowed(processed$inputs, SHINYLOGS_ALLOWLIST$inputs),
    outputs  = keep_allowed(processed$outputs, SHINYLOGS_ALLOWLIST$outputs),
    errors   = keep_allowed(processed$errors, SHINYLOGS_ALLOWLIST$errors)
  )
}

#' Rediger sensitive data i shinylogs errors-dataframe
#'
#' Anvender PAT-redaction paa \code{error}-kolonnen og omdoeber
#' den til \code{redacted_message} saa allowlist-filteret kan matche.
#'
#' @param errors_df data.frame fra shinylogs errors-element
#' @return data.frame med \code{redacted_message}-kolonne
#' @keywords internal
redact_error_messages <- function(errors_df) {
  if (nrow(errors_df) == 0) {
    return(errors_df)
  }
  if ("error" %in% names(errors_df)) {
    errors_df$redacted_message <- vapply(
      as.character(errors_df$error),
      redact_pat_in_url,
      character(1L)
    )
    errors_df$error <- NULL
  }
  errors_df
}

#' Aggreger logs og sync til analytics-storage
#'
#' Prioriteret backend:
#' 1. GitHub privat repo (GITHUB_PAT + PIN_REPO_URL sat) -- append-model,
#'    hver session-afslutning skriver en .rds-fil til data-repo.
#' 2. Posit Connect Server pins (CONNECT_SERVER sat) -- legacy/lokal dev.
#' 3. No-op hvis ingen backend er konfigureret.
#'
#' @param log_directory Sti til log-mappe
#' @param session_id Shiny session token (bruges i filnavn for GitHub-backend)
#' @keywords internal
aggregate_and_pin_logs <- function(log_directory = "logs/",
                                   session_id = NULL) {
  config <- get_analytics_config()

  log_info(
    paste(
      "aggregate_and_pin_logs kaldt | log_dir:", log_directory,
      "| exists:", dir.exists(log_directory),
      "| wd:", getwd()
    ),
    .context = LOG_CONTEXTS$analytics$pins
  )

  # Disk-introspection: hvad indeholder log_directory og undermapper?
  if (dir.exists(log_directory)) {
    all_files <- list.files(log_directory,
      recursive = TRUE,
      full.names = FALSE, all.files = TRUE,
      include.dirs = FALSE, no.. = TRUE
    )
    subdirs <- list.dirs(log_directory, recursive = FALSE, full.names = FALSE)
    log_info(
      paste(
        "Disk-introspection |",
        "subdirs:", if (length(subdirs) > 0) paste(subdirs, collapse = ",") else "(ingen)",
        "| files:", length(all_files),
        if (length(all_files) > 0) paste("| first:", all_files[1]) else ""
      ),
      .context = LOG_CONTEXTS$analytics$pins
    )
  }

  all_data <- read_shinylogs_all(log_directory)

  total_rows <- sum(vapply(all_data, nrow, integer(1)))
  log_info(
    sprintf(
      "Log-aggregering: %d sessions, %d inputs, %d outputs, %d errors (total=%d)",
      nrow(all_data$sessions), nrow(all_data$inputs),
      nrow(all_data$outputs), nrow(all_data$errors), total_rows
    ),
    .context = LOG_CONTEXTS$analytics$pins
  )

  if (total_rows == 0) {
    log_warn(
      paste(
        "Ingen shinylogs data fundet i", log_directory,
        "\u2014 pin sync overspringes. Tjek om shinylogs::track_usage",
        "faktisk flushes foer onSessionEnded."
      ),
      .context = LOG_CONTEXTS$analytics$pins
    )
    return(invisible(NULL))
  }

  safe_operation(
    "Sync analytics data",
    code = {
      github_sync_enabled <- isTRUE(golem::get_golem_options("analytics.github_sync_enabled"))
      if (github_sync_enabled &&
        nchar(safe_getenv("GITHUB_PAT")) > 0 &&
        nchar(safe_getenv("PIN_REPO_URL")) > 0) {
        result <- sync_logs_to_github(all_data, session_id = session_id)
        if (isTRUE(result$success)) {
          log_info(
            paste(
              "Analytics synket til GitHub:", result$filename,
              "(attempt", result$attempt, ")"
            ),
            .context = LOG_CONTEXTS$analytics$pins
          )
        } else {
          log_warn(
            paste(
              "GitHub sync fejlede \u2014 reason:", result$reason,
              if (!is.null(result$error)) paste("-", result$error)
            ),
            .context = LOG_CONTEXTS$analytics$pins
          )
        }
      } else if (requireNamespace("pins", quietly = TRUE) &&
        nchar(safe_getenv("CONNECT_SERVER")) > 0) {
        board <- pins::board_connect()
        safe_pin_data <- filter_shinylogs_allowlist(all_data)
        pins::pin_write(board, safe_pin_data, config$pin_name,
          type = "rds",
          description = paste(
            "biSPCharts analytics:",
            nrow(all_data$sessions), "sessions,",
            nrow(all_data$inputs), "inputs,",
            nrow(all_data$outputs), "outputs,",
            nrow(all_data$errors), "errors"
          )
        )
        log_info(
          paste(
            "Analytics pin opdateret (Connect Server):",
            nrow(all_data$sessions), "sessions"
          ),
          .context = LOG_CONTEXTS$analytics$pins
        )
      } else {
        log_debug("Ingen analytics-backend konfigureret (GITHUB_PAT/PIN_REPO_URL eller CONNECT_SERVER)",
          .context = LOG_CONTEXTS$analytics$pins
        )
      }
    },
    fallback = function(e) {
      log_warn(paste("Analytics sync fejlede:", e$message),
        .context = LOG_CONTEXTS$analytics$pins
      )
    },
    error_type = "processing"
  )

  rotate_log_files(log_directory)
  invisible(NULL)
}
