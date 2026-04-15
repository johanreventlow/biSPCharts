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
    if (!dir.exists(cat_dir)) return(data.frame())

    files <- list.files(cat_dir, pattern = "\\.json$", full.names = TRUE)
    if (length(files) == 0) return(data.frame())

    entries <- lapply(files, function(f) {
      tryCatch(
        jsonlite::fromJSON(f, simplifyVector = TRUE),
        error = function(e) {
          log_warn(paste("Kunne ikke laese", cat, "fil:", basename(f)),
                   .context = LOG_CONTEXTS$analytics$pins)
          NULL
        }
      )
    })

    entries <- Filter(Negate(is.null), entries)
    if (length(entries) == 0) return(data.frame())

    tryCatch(
      dplyr::bind_rows(entries),
      error = function(e) {
        log_warn(paste("bind_rows fejlede for", cat, ":", e$message),
                 .context = LOG_CONTEXTS$analytics$pins)
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
  all_data <- read_shinylogs_all(log_directory)

  total_rows <- sum(vapply(all_data, nrow, integer(1)))
  if (total_rows == 0) {
    log_debug("Ingen data at aggregere",
              .context = LOG_CONTEXTS$analytics$pins)
    return(invisible(NULL))
  }

  safe_operation(
    "Pin analytics data",
    code = {
      if (requireNamespace("pins", quietly = TRUE) && nchar(Sys.getenv("CONNECT_SERVER")) > 0) {
        board <- pins::board_connect()
        pins::pin_write(board, all_data, config$pin_name,
                        type = "rds",
                        description = paste(
                          "biSPCharts analytics:",
                          nrow(all_data$sessions), "sessions,",
                          nrow(all_data$inputs), "inputs,",
                          nrow(all_data$outputs), "outputs,",
                          nrow(all_data$errors), "errors"
                        ))
        log_info(paste("Analytics pin opdateret:",
                       nrow(all_data$sessions), "sessions,",
                       nrow(all_data$inputs), "inputs,",
                       nrow(all_data$outputs), "outputs,",
                       nrow(all_data$errors), "errors"),
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
