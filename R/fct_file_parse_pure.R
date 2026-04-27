# fct_file_parse_pure.R
# Pure domain logic til fil-parsing - ingen Shiny-afhaengigheder
# Returnerer ParsedFile S3-struktur; side-effekter (notifikationer) haandteres af shim-laget.

#' Parser fil til data.frame (pure)
#'
#' Laeser CSV eller Excel-fil og returnerer en `ParsedFile`-struktur.
#' Ingen Shiny-afhaengigheder - kan unit-testes uden aktiv session.
#'
#' CSV-strategier afproeves i raekkefoelge:
#' 1. Semikolon-separator (dansk standard, decimal=komma)
#' 2. Auto-detect separator
#' 3. Komma-separator (engelsk standard)
#'
#' Excel: Returnerer foerste ark (eller specificeret ark via `encoding_hints$sheet`).
#' biSPCharts gem-format (ark "Data" + "Indstillinger") detekteres og returneres
#' med `meta$is_bispchart_format = TRUE`.
#'
#' @param path Character(1) - sti til fil (allerede valideret via `validate_safe_file_path`)
#' @param format Character(1) - `"csv"` eller `"excel"`. Default: auto-detect via filendelse.
#' @param encoding_hints Liste med valgfrie hints:
#'   - `encoding`: foretrukket encoding (default `"UTF-8"`)
#'   - `sheet`: Excel-ark-navn (default: foerste ark)
#' @return `ParsedFile` S3-objekt med:
#'   - `$data` - data.frame
#'   - `$meta` - liste med rows, cols, encoding, format, is_bispchart_format
#'   - `$warnings` - character vector med evt. advarsler
#' @return NULL hvis parsing fejler for alle strategier (fejlbesked i `attr(., "error")`)
#' @noRd
parse_file <- function(path, format = NULL, encoding_hints = NULL) {
  # Input-validering
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("parse_file: path skal vaere character(1)")
  }
  if (!file.exists(path)) {
    stop(paste0("parse_file: fil ikke fundet: ", path))
  }

  # Auto-detect format fra filendelse hvis ikke angivet
  if (is.null(format)) {
    ext <- tolower(tools::file_ext(path))
    format <- if (ext %in% c("xlsx", "xls")) "excel" else "csv"
  }

  hints <- encoding_hints %||% list()
  enc <- hints$encoding %||% UTF8_ENCODING

  if (format == "excel") {
    parse_excel_file(path, hints)
  } else {
    parse_csv_file(path, enc)
  }
}

#' @noRd
parse_csv_file <- function(path, encoding = "UTF-8") {
  warnings <- character(0)

  # Tre parsing-strategier - ingen af dem kalder Shiny
  data <- try_with_diagnostics(
    attempts = list(
      "semikolon-separator (dansk standard)" = function() {
        result <- readr::read_csv2(
          path,
          locale = readr::locale(
            decimal_mark = ",",
            grouping_mark = ".",
            encoding = encoding
          ),
          show_col_types = FALSE
        )
        if (ncol(result) < 2) stop(sprintf("Kun %d kolonne(r) fundet", ncol(result)))
        result
      },
      "auto-detect separator" = function() {
        result <- readr::read_delim(
          path,
          delim = NULL,
          locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
          show_col_types = FALSE,
          trim_ws = TRUE
        )
        if (ncol(result) < 2) stop(sprintf("Kun %d kolonne(r) fundet", ncol(result)))
        result
      },
      "komma-separator (engelsk standard)" = function() {
        result <- readr::read_csv(
          path,
          locale = readr::locale(
            decimal_mark = ".",
            grouping_mark = ",",
            encoding = encoding
          ),
          show_col_types = FALSE
        )
        if (ncol(result) < 2) stop(sprintf("Kun %d kolonne(r) fundet", ncol(result)))
        result
      }
    ),
    on_all_fail = function(errors) {
      # Log fejl - ingen showNotification her (shim-laget haandterer notifikationer)
      err_msg <- paste(names(errors), errors, sep = ": ", collapse = "; ")
      log_warn(
        "CSV-parsing fejlede for alle tre strategier",
        .context = "FILE_PARSE_PURE",
        details = list(errors = as.list(errors))
      )
      # Returner NULL - shim-laget tjekker for NULL og viser notifikation
      NULL
    }
  )

  if (is.null(data)) {
    return(NULL)
  }
  if (nrow(data) < 1) {
    return(NULL)
  }

  # Preprocessing (pure - ingen Shiny)
  file_info <- list(name = basename(path), size = file.info(path)$size)
  preprocessing_result <- preprocess_uploaded_data(data, file_info, session_id = NULL)
  data <- preprocessing_result$data

  if (!is.null(preprocessing_result$cleaning_log$empty_rows_removed)) {
    warnings <- c(
      warnings,
      paste(preprocessing_result$cleaning_log$empty_rows_removed, "tomme raekker fjernet")
    )
  }

  # Tilfoej standard SPC kolonner
  data <- ensure_standard_columns(data)
  data_frame <- as.data.frame(data)

  new_parsed_file(
    data = data_frame,
    format = "csv",
    encoding = encoding,
    warnings = warnings
  )
}

#' @noRd
parse_excel_file <- function(path, hints = list()) {
  warnings <- character(0)
  sheet <- hints$sheet %||% NULL

  excel_sheets <- tryCatch(
    readxl::excel_sheets(path),
    error = function(e) {
      stop(paste0("Kan ikke laese Excel-fil: ", e$message))
    }
  )

  # Detect biSPCharts gem-format
  is_bispchart_format <- "Data" %in% excel_sheets && "Indstillinger" %in% excel_sheets

  if (is_bispchart_format) {
    data_raw <- readxl::read_excel(path, sheet = "Data", col_names = TRUE)
    data_raw <- ensure_standard_columns(data_raw)
    data_frame <- as.data.frame(data_raw)

    # Parser Indstillinger-ark
    metadata <- tryCatch(
      parse_spc_excel(path, sheets = excel_sheets),
      error = function(e) {
        log_debug(conditionMessage(e), .context = "FILE_PARSE_PURE")
        NULL
      }
    )

    result <- new_parsed_file(
      data = data_frame,
      format = "excel",
      encoding = "UTF-8",
      warnings = warnings
    )
    result$meta$is_bispchart_format <- TRUE
    result$meta$saved_metadata <- metadata
    return(result)
  }

  # Standard Excel-fil
  read_sheet <- sheet %||% excel_sheets[1]
  data_raw <- readxl::read_excel(path, sheet = read_sheet, col_names = TRUE)
  data_raw <- ensure_standard_columns(data_raw)
  data_frame <- as.data.frame(data_raw)

  result <- new_parsed_file(
    data = data_frame,
    format = "excel",
    encoding = "UTF-8",
    warnings = warnings
  )
  result$meta$is_bispchart_format <- FALSE
  result
}

#' Konstruer ParsedFile S3-objekt
#' @noRd
new_parsed_file <- function(data, format, encoding, warnings = character()) {
  structure(
    list(
      data = data,
      meta = list(
        rows     = nrow(data),
        cols     = ncol(data),
        encoding = encoding,
        format   = format
      ),
      warnings = warnings
    ),
    class = "ParsedFile"
  )
}

#' Print-metode for ParsedFile
#' @export
print.ParsedFile <- function(x, ...) {
  cat(sprintf(
    "ParsedFile: %d raekker x %d kolonner [%s/%s]\n",
    x$meta$rows, x$meta$cols, x$meta$format, x$meta$encoding
  ))
  if (length(x$warnings) > 0) {
    cat("Advarsler:\n")
    cat(paste0("  - ", x$warnings, collapse = "\n"), "\n")
  }
  invisible(x)
}
