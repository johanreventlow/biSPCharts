# utils_analytics_pins.R
# Log-aggregering fra shinylogs JSON-filer og publicering via pins

#' Laes shinylogs session-filer til data.frame
#'
#' Delegerer til \code{read_shinylogs_all()} og returnerer kun sessions-elementet.
#'
#' @param log_directory Sti til log-mappe
#' @return data.frame med session-data (tom data.frame hvis ingen filer)
#' @export
read_shinylogs_sessions <- function(log_directory) {
  read_shinylogs_all(log_directory)$sessions
}

#' Laes alle shinylogs kategorier til navngivet liste
#'
#' Laeser sessions, inputs, outputs og errors fra shinylogs log-directory.
#'
#' @param log_directory Sti til log-mappe
#' @return Navngivet liste med 4 data.frames: sessions, inputs, outputs, errors
#' @export
read_shinylogs_all <- function(log_directory) {
  categories <- c("sessions", "inputs", "outputs", "errors")

  result <- lapply(stats::setNames(categories, categories), function(cat) {
    cat_dir <- file.path(log_directory, cat)
    if (!dir.exists(cat_dir)) {
      return(data.frame())
    }

    files <- list.files(cat_dir, pattern = "\\.json$", full.names = TRUE)
    if (length(files) == 0) {
      return(data.frame())
    }

    entries <- lapply(files, function(f) {
      tryCatch(
        jsonlite::fromJSON(f, simplifyVector = TRUE),
        error = function(e) {
          log_warn(paste("Kunne ikke laese", cat, "fil:", basename(f)),
            .context = LOG_CONTEXTS$analytics$pins
          )
          NULL
        }
      )
    })

    entries <- Filter(Negate(is.null), entries)
    if (length(entries) == 0) {
      return(data.frame())
    }

    tryCatch(
      dplyr::bind_rows(entries),
      error = function(e) {
        log_warn(paste("bind_rows fejlede for", cat, ":", e$message),
          .context = LOG_CONTEXTS$analytics$pins
        )
        data.frame()
      }
    )
  })

  result
}

#' Roter log-filer (komprimer gamle, slet meget gamle)
#'
#' @param log_directory Sti til log-mappe
#' @param compress_after_days Komprimer filer aeldre end dette (default: 90)
#' @param delete_after_days Slet filer aeldre end dette (default: 365)
#' @export
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

#' Aggreger logs og sync til analytics-storage
#'
#' Prioriteret backend:
#' 1. GitHub privat repo (GITHUB_PAT + PIN_REPO_URL sat) — append-model,
#'    hver session-afslutning skriver én .rds-fil til data-repo.
#' 2. Posit Connect Server pins (CONNECT_SERVER sat) — legacy/lokal dev.
#' 3. No-op hvis ingen backend er konfigureret.
#'
#' @param log_directory Sti til log-mappe
#' @param session_id Shiny session token (bruges i filnavn for GitHub-backend)
#' @export
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
        "— pin sync overspringes. Tjek om shinylogs::track_usage",
        "faktisk flushes foer onSessionEnded."
      ),
      .context = LOG_CONTEXTS$analytics$pins
    )
    return(invisible(NULL))
  }

  safe_operation(
    "Sync analytics data",
    code = {
      if (nchar(Sys.getenv("GITHUB_PAT")) > 0 &&
        nchar(Sys.getenv("PIN_REPO_URL")) > 0) {
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
              "GitHub sync fejlede — reason:", result$reason,
              if (!is.null(result$error)) paste("-", result$error)
            ),
            .context = LOG_CONTEXTS$analytics$pins
          )
        }
      } else if (requireNamespace("pins", quietly = TRUE) &&
        nchar(Sys.getenv("CONNECT_SERVER")) > 0) {
        board <- pins::board_connect()
        pins::pin_write(board, all_data, config$pin_name,
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
