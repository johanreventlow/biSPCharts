# utils_analytics_pins.R
# Log-aggregering fra shinylogs JSON-filer og publicering via pins

#' Laes shinylogs session-filer til data.frame
#'
#' @param log_directory Sti til log-mappe
#' @return data.frame med session-data (tom data.frame hvis ingen filer)
#' @export
read_shinylogs_sessions <- function(log_directory) {
  sessions_dir <- file.path(log_directory, "sessions")
  if (!dir.exists(sessions_dir)) return(data.frame())

  files <- list.files(sessions_dir, pattern = "\\.json$", full.names = TRUE)
  if (length(files) == 0) return(data.frame())

  sessions <- lapply(files, function(f) {
    tryCatch(
      jsonlite::fromJSON(f, simplifyVector = TRUE),
      error = function(e) {
        log_warn(paste("Kunne ikke laese session-fil:", basename(f)),
                 .context = LOG_CONTEXTS$analytics$pins)
        NULL
      }
    )
  })

  sessions <- Filter(Negate(is.null), sessions)
  if (length(sessions) == 0) return(data.frame())

  tryCatch(
    dplyr::bind_rows(sessions),
    error = function(e) {
      log_warn(paste("bind_rows fejlede:", e$message),
               .context = LOG_CONTEXTS$analytics$pins)
      data.frame()
    }
  )
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
  json_files <- list.files(log_directory, pattern = "\\.json$",
                           full.names = TRUE, recursive = TRUE)
  if (length(json_files) == 0) return(invisible(NULL))

  now <- Sys.time()
  for (f in json_files) {
    file_age_days <- as.numeric(difftime(now, file.info(f)$mtime, units = "days"))

    if (file_age_days > delete_after_days) {
      unlink(f)
      unlink(paste0(f, ".gz"))
    } else if (file_age_days > compress_after_days) {
      tryCatch({
        con <- gzfile(paste0(f, ".gz"), "wb")
        writeLines(readLines(f), con)
        close(con)
        unlink(f)
      }, error = function(e) {
        log_warn(paste("Komprimering fejlede:", basename(f), e$message),
                 .context = LOG_CONTEXTS$analytics$rotation)
      })
    }
  }
  invisible(NULL)
}

#' Aggreger logs og publicer til Connect Cloud via pins
#'
#' @param log_directory Sti til log-mappe
#' @export
aggregate_and_pin_logs <- function(log_directory = "logs/") {
  config <- get_analytics_config()
  sessions <- read_shinylogs_sessions(log_directory)

  if (nrow(sessions) == 0) {
    log_debug("Ingen sessions at aggregere",
              .context = LOG_CONTEXTS$analytics$pins)
    return(invisible(NULL))
  }

  safe_operation(
    "Pin analytics data",
    code = {
      if (requireNamespace("pins", quietly = TRUE) && nchar(Sys.getenv("CONNECT_SERVER")) > 0) {
        board <- pins::board_connect()
        pins::pin_write(board, sessions, config$pin_name,
                        type = "rds",
                        description = "biSPCharts analytics session data")
        log_info(paste("Analytics pin opdateret:", nrow(sessions), "sessions"),
                 .context = LOG_CONTEXTS$analytics$pins)
      } else {
        log_debug("Pins ikke tilgaengelig (ikke paa Connect Cloud)",
                  .context = LOG_CONTEXTS$analytics$pins)
      }
    },
    fallback = function(e) {
      log_warn(paste("Pin publicering fejlede:", e$message),
               .context = LOG_CONTEXTS$analytics$pins)
    },
    error_type = "processing"
  )

  rotate_log_files(log_directory)
  invisible(NULL)
}
