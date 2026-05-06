# fct_file_validation.R
# Fil-validering, fejlhaandtering og data preprocessing for uploads
# Udtrukket fra fct_file_operations.R for bedre separation of concerns

# ENHANCED FILE VALIDATION ===================================================

## Enhanced file validation with comprehensive checks
check_file_size <- function(file_info) {
  max_size_mb <- get_max_file_size_mb()
  if (file_info$size > max_size_mb * 1024 * 1024) {
    if (file_info$size > 100 * 1024 * 1024) {
      log_warn("Extremely large file upload attempt - potential DoS",
        component = "[FILE_SECURITY]",
        details = list(
          filename = file_info$name,
          size_mb = round(file_info$size / (1024 * 1024), 2),
          max_allowed_mb = max_size_mb
        )
      )
    }
    return(list(valid = FALSE, message = paste("Filst\u00f8rrelse overskrider maksimum p\u00e5", max_size_mb, "MB")))
  }
  list(valid = TRUE, message = NULL)
}

check_row_count_csv <- function(file_info) {
  if (tolower(tools::file_ext(file_info$name)) != "csv") {
    return(list(valid = TRUE, message = NULL))
  }
  row_error <- tryCatch(
    {
      con <- file(file_info$datapath, "r")
      on.exit(close(con), add = TRUE)
      line_count <- 0
      while (length(readLines(con, n = 1)) > 0) {
        line_count <- line_count + 1
        if (line_count > get_max_upload_line_count()) break
      }
      if (line_count > get_upload_warning_row_count()) {
        log_warn("Large row count detected - performance risk",
          component = "[FILE_SECURITY]",
          details = list(filename = file_info$name, estimated_rows = line_count)
        )
      }
      if (line_count > get_max_upload_line_count()) {
        paste0(
          "CSV fil har for mange r\u00e6kker (maksimum ",
          format(get_max_upload_line_count(), big.mark = "."),
          ")"
        )
      } else {
        NULL
      }
    },
    error = function(e) {
      log_warn("Kunne ikke validere antal r\u00e6kker",
        component = "[FILE_VALIDATION]",
        details = list(filename = file_info$name, error = e$message)
      )
      NULL
    }
  )
  if (!is.null(row_error)) list(valid = FALSE, message = row_error) else list(valid = TRUE, message = NULL)
}

check_extension <- function(file_ext) {
  if (!validate_file_extension(file_ext)) {
    return(list(valid = FALSE, message = "Ikke-tilladt filtype. Kun CSV, Excel tilladt"))
  }
  list(valid = TRUE, message = NULL)
}

check_mime_type <- function(file_info, file_ext) {
  file_header <- readBin(file_info$datapath, what = "raw", n = 8)
  is_valid_mime <- switch(tolower(trimws(file_ext)),
    "csv" = !any(file_header[1:4] == as.raw(c(0x50, 0x4B, 0x03, 0x04))),
    "xlsx" = identical(file_header[1:4], as.raw(c(0x50, 0x4B, 0x03, 0x04))),
    "xls" = {
      identical(file_header[1:8], as.raw(c(0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1))) ||
        identical(file_header[1:4], as.raw(c(0x09, 0x08, 0x10, 0x00))) ||
        identical(file_header[1:4], as.raw(c(0x50, 0x4B, 0x03, 0x04)))
    },
    FALSE
  )
  if (!is_valid_mime) {
    log_warn("MIME type mismatch detected - potential file masquerading",
      component = "[FILE_SECURITY]",
      details = list(
        filename = file_info$name,
        extension = file_ext,
        header_bytes = as.character(file_header[1:8])
      )
    )
    return(list(valid = FALSE, message = "Filtype stemmer ikke overens med indhold"))
  }
  list(valid = TRUE, message = NULL)
}

validate_uploaded_file <- function(file_info, session_id = NULL) {
  if (!file.exists(file_info$datapath)) {
    return(list(valid = FALSE, errors = c("Uploaded fil findes ikke eller er beskadiget")))
  }

  if (file_info$size == 0) {
    return(list(valid = FALSE, errors = c("Uploaded fil er tom")))
  }

  file_ext <- tools::file_ext(file_info$name)

  checks <- list(
    check_file_size(file_info),
    check_row_count_csv(file_info),
    check_extension(file_ext)
  )

  errors <- unlist(purrr::map(checks, function(r) if (!r$valid) r$message else NULL))

  # MIME check only when basic checks pass (avoids reading header on clearly invalid files)
  if (length(errors) == 0) {
    mime_result <- check_mime_type(file_info, file_ext)
    if (!mime_result$valid) errors <- c(errors, mime_result$message)
  }

  # Type-specific deep validation only when format checks pass
  if (length(errors) == 0) {
    type_result <- if (tolower(file_ext) %in% c("xlsx", "xls")) {
      validate_excel_file(file_info$datapath)
    } else if (tolower(file_ext) == "csv") {
      validate_csv_file(file_info$datapath)
    } else {
      list(valid = TRUE, errors = character(0))
    }
    errors <- c(errors, type_result$errors)
  }

  if (length(errors) > 0) {
    log_warn("File validation failed",
      .context = "FILE_UPLOAD_FLOW",
      details = list(filename = file_info$name, file_size = file_info$size, validation_errors = errors)
    )
  } else {
    log_info("File validation successful",
      .context = "FILE_UPLOAD_FLOW",
      details = list(filename = file_info$name, file_size = file_info$size, file_extension = file_ext)
    )
  }

  list(valid = length(errors) == 0, errors = errors)
}

## Excel file specific validation
validate_excel_file <- function(file_path) {
  errors <- character(0)

  # ZIP-BOMB GUARD (#449): xlsx er et ZIP-arkiv. En lille fil kan
  # ekspandere til GB ukomprimeret. readxl::read_excel() ekspanderer
  # fuld ZIP før den respekterer n_max, så size-validering på disk
  # alene er utilstrækkelig. Tjek total ukomprimeret størrelse via
  # utils::unzip(list = TRUE) før vi rører read_excel.
  zip_check <- tryCatch(
    {
      entries <- utils::unzip(file_path, list = TRUE)
      total_mb <- sum(entries$Length, na.rm = TRUE) / (1024 * 1024)
      list(ok = TRUE, total_mb = total_mb)
    },
    error = function(e) list(ok = FALSE, error = e$message)
  )

  if (isTRUE(zip_check$ok)) {
    limit_mb <- get_max_xlsx_uncompressed_mb()
    if (zip_check$total_mb > limit_mb) {
      errors <- c(errors, sprintf(
        "Excel-fil er for stor efter dekomprimering (%.1f MB > %d MB graense)",
        zip_check$total_mb, limit_mb
      ))
      return(list(valid = FALSE, errors = errors))
    }
  }
  # Hvis zip_check fejler (ej ZIP/xlsx) lader vi readxl give brugbar fejl

  safe_operation(
    "Validate Excel file structure",
    code = {
      # Check if file can be read
      sheets <- readxl::excel_sheets(file_path)

      if (length(sheets) == 0) {
        errors <- c(errors, "Excel fil indeholder ingen ark")
      }

      # biSPCharts gem-format: Data + Indstillinger. Valid\u00e9r begge ark her
      # s\u00e5 beskadigede save-filer fanges tidligt i stedet for at falde
      # igennem til fallback-stien i handle_excel_upload().
      if (all(c("Data", "Indstillinger") %in% sheets)) {
        safe_operation(
          "Validate biSPCharts Data sheet",
          code = {
            data <- readxl::read_excel(file_path, sheet = "Data", n_max = 1)
            if (ncol(data) == 0) {
              errors <- c(errors, "Data-ark er tomt")
            }
          },
          fallback = function(e) {
            errors <<- c(errors, paste("Kan ikke l\u00e6se Data-ark:", e$message))
          },
          error_type = "processing"
        )

        safe_operation(
          "Validate biSPCharts Indstillinger sheet",
          code = {
            settings <- readxl::read_excel(
              file_path,
              sheet = "Indstillinger",
              skip = INDSTILLINGER_HEADER_ROWS,
              col_names = c("key", "value")
            )
            if (ncol(settings) == 0 || nrow(settings) == 0) {
              errors <- c(errors, "Indstillinger-ark er tomt eller ugyldigt")
            }
          },
          fallback = function(e) {
            errors <<- c(errors, paste("Kan ikke l\u00e6se Indstillinger-ark:", e$message))
          },
          error_type = "processing"
        )
      } else {
        # Regular Excel file - validate first sheet
        safe_operation(
          "Validate regular Excel file",
          code = {
            data <- readxl::read_excel(file_path, n_max = 1)
            if (ncol(data) == 0) {
              errors <- c(errors, "Excel fil indeholder ingen kolonner")
            }
          },
          fallback = function(e) {
            errors <<- c(errors, paste("Kan ikke l\u00e6se Excel-fil:", e$message))
          },
          error_type = "processing"
        )
      }
    },
    fallback = function(e) {
      errors <<- c(errors, paste("Excel fil er beskadiget eller ugyldig:", e$message))
    },
    error_type = "processing"
  )

  return(list(
    valid = length(errors) == 0,
    errors = errors
  ))
}

## CSV file specific validation
validate_csv_file <- function(file_path) {
  errors <- character(0)

  safe_operation(
    "Validate CSV file structure",
    code = {
      # Brug shared delimiter-detektion (spejler parser-kaskaden i
      # fct_file_parse_pure.R) saa validator accepterer ALT som parser kan haandtere.
      detection <- detect_csv_delimiter(file_path, encoding = UTF8_ENCODING)

      if (!detection$parseable) {
        errors <- c(errors, paste0(
          "Filen kunne ikke l\u00e6ses som CSV. ",
          "Pr\u00f8v at eksportere filen fra Excel som 'CSV (semikolon-separeret)' ",
          "eller 'CSV (kommasepareret)'."
        ))
      } else {
        if (detection$nrow == 0) {
          errors <- c(errors, paste0(
            "Filen indeholder kun overskrifter men ingen data. ",
            "Kontroll\u00e9r at der er r\u00e6kker med data under overskriftsr\u00e6kken."
          ))
        }
      }
    },
    fallback = function(e) {
      if (grepl("invalid", tolower(e$message)) || grepl("encoding", tolower(e$message))) {
        errors <<- c(errors, paste0(
          "Filen har et tegnkodningsproblem. Pr\u00f8v at gemme ",
          "filen som UTF-8 i Excel: Gem som \u2192 ",
          "'CSV UTF-8 (kommasepareret)'."
        ))
      } else {
        errors <<- c(errors, paste("Kan ikke l\u00e6se CSV-filen:", e$message))
      }
    },
    error_type = "processing"
  )

  return(list(
    valid = length(errors) == 0,
    errors = errors
  ))
}

# ENHANCED ERROR RECOVERY ====================================================

## Enhanced error handling with recovery suggestions
handle_upload_error <- function(error, file_info, session_id = NULL) {
  error_message <- as.character(error$message)
  error_type <- "unknown"
  user_message <- paste0(
    "En uventet fejl opstod under filupload. ",
    "Kontakt Dataenheden: dataenheden.bispebjerg-frederiksberg-hospitaler@regionh.dk"
  )
  suggestions <- character(0)

  # Kategoris\u00e9r fejltyper og giv specifik vejledning

  if (grepl("encoding|locale|character|multibyte|utf", error_message, ignore.case = TRUE)) {
    error_type <- "encoding"
    user_message <- "Filens tegnkodning kunne ikke l\u00e6ses korrekt"
    suggestions <- c(
      "Gem filen som UTF-8 i Excel: Gem som \u2192 'CSV UTF-8 (kommasepareret)'",
      "Kontroll\u00e9r at danske tegn (\u00e6, \u00f8, \u00e5) vises korrekt i filen",
      "For Excel-filer: Gem som 'Excel-projektmappe (.xlsx)' i stedet for CSV"
    )
  } else if (grepl("permission|access|locked", error_message, ignore.case = TRUE)) {
    error_type <- "permission"
    user_message <- "Filen kunne ikke \u00e5bnes"
    suggestions <- c(
      "Luk filen i andre programmer (fx Excel) og pr\u00f8v igen",
      "Kontroll\u00e9r at filen ikke er skrivebeskyttet",
      "Pr\u00f8v at kopiere filen til en anden mappe og upload den derfra"
    )
  } else if (grepl("memory|size|allocation", error_message, ignore.case = TRUE)) {
    error_type <- "memory"
    user_message <- "Filen er for stor til at behandle"
    suggestions <- c(
      "Pr\u00f8v at uploade en mindre fil",
      "Fjern un\u00f8dvendige kolonner eller r\u00e6kker f\u00f8r upload",
      "Opdel store datas\u00e6t i mindre filer"
    )
  } else if (grepl("column|header|sheet", error_message, ignore.case = TRUE)) {
    error_type <- "structure"
    user_message <- "Filens struktur kunne ikke fortolkes"
    suggestions <- c(
      "Kontroll\u00e9r at filen har kolonneoverskrifter i f\u00f8rste r\u00e6kke",
      "Kontroll\u00e9r at data er organiseret i r\u00e6kker og kolonner",
      "For Excel-filer: S\u00f8rg for at data ligger i det f\u00f8rste ark eller i et ark kaldet 'Data'"
    )
  } else if (grepl("corrupt|invalid|damaged", error_message, ignore.case = TRUE)) {
    error_type <- "corruption"
    user_message <- "Filen ser ud til at v\u00e6re beskadiget"
    suggestions <- c(
      "Pr\u00f8v at gemme filen igen fra det oprindelige program",
      "Kontroll\u00e9r at filen kan \u00e5bnes normalt i Excel",
      "Pr\u00f8v at eksportere data til en ny fil"
    )
  }

  # Log detailed error information
  log_error("Enhanced error handling triggered",
    .context = "ERROR_HANDLING",
    details = list(
      error_type = error_type,
      error_message = error_message,
      filename = file_info$name,
      file_size = file_info$size,
      file_type = file_info$type,
      suggestions = suggestions
    )
  )

  # Gate tekniske fejldetaljer bag hide_error_details (default TRUE i produktion)
  hide_details <- tryCatch(
    isTRUE(golem::get_golem_options("hide_error_details", default = TRUE)),
    error = function(e) TRUE # nolint: swallowed_error_linter
  )

  # Create comprehensive user notification
  notification_html <- shiny::tags$div(
    shiny::tags$strong(user_message),
    shiny::tags$br(),
    if (!hide_details) shiny::tags$em(paste("Tekniske detaljer:", error_message)),
    if (length(suggestions) > 0) {
      shiny::tags$div(
        shiny::tags$br(),
        shiny::tags$strong("Forslag til l\u00f8sning:"),
        shiny::tags$ul(
          purrr::map(suggestions, ~ shiny::tags$li(.x))
        )
      )
    }
  )

  tryCatch(
    shiny::showNotification(
      notification_html,
      type = "error",
      duration = 15
    ),
    error = function(e) {
      # showNotification fejler uden aktiv Shiny-session (fx i unit tests)
      invisible(NULL)
    }
  )

  return(list(
    error_type = error_type,
    user_message = user_message,
    suggestions = suggestions
  ))
}

# DATA VALIDATION FOR AUTO-DETECTION ========================================

## Validate data suitability for auto-detection
validate_data_for_auto_detect <- function(data, session_id = NULL) {
  issues <- character(0)
  validation_results <- list()

  # Check data dimensions
  validation_results$rows <- nrow(data)
  validation_results$columns <- ncol(data)

  if (nrow(data) < 2) {
    issues <- c(issues, "For f\u00e5 datar\u00e6kker (minimum 2 kr\u00e6vet)")
  }

  if (ncol(data) < 2) {
    issues <- c(issues, "For f\u00e5 kolonner (minimum 2 kr\u00e6vet)")
  }

  # Check for reasonable column names
  col_names <- names(data)
  validation_results$column_names <- col_names

  # Count empty/missing column names
  empty_names <- sum(is.na(col_names) | col_names == "" | grepl("^\\.\\.\\.", col_names))
  validation_results$empty_column_names <- empty_names

  if (empty_names > 0) {
    issues <- c(issues, paste(empty_names, "kolonner har manglende eller ugyldige navne"))
  }

  # Check for data content - optimized med vectorized base R operations
  has_data_content <- vapply(data, function(col) {
    if (is.numeric(col)) {
      sum(!is.na(col)) > 0
    } else if (is.character(col)) {
      sum(nzchar(col, keepNA = FALSE)) > 0
    } else if (is.logical(col)) {
      sum(!is.na(col)) > 0
    } else {
      sum(!is.na(col)) > 0
    }
  }, logical(1))

  columns_with_data <- sum(has_data_content)
  validation_results$columns_with_data <- columns_with_data

  if (columns_with_data < 2) {
    issues <- c(issues, "Utilstr\u00e6kkelige kolonner med meningsfuld data")
  }

  # Check for potential date columns (for X-axis) - optimized med vectorized base R
  col_names_lower <- tolower(col_names)
  potential_date_columns <- grepl("dato|date|tid|time", col_names_lower) |
    grepl("^(x|uge|m\u00e5ned|\u00e5r|dag)", col_names_lower)
  validation_results$potential_date_columns <- sum(potential_date_columns)

  # Check for potential numeric columns (for Y-axis) - optimized med vectorized base R
  potential_numeric_columns <- vapply(data, function(col) {
    if (is.numeric(col)) {
      return(TRUE)
    }
    if (is.character(col)) {
      # Check if character data looks like it could be numeric
      non_empty <- col[nzchar(col, keepNA = FALSE)]
      if (length(non_empty) == 0) {
        return(FALSE)
      }
      # Try to parse some values as numbers (Danish format)
      sample_size <- min(10, length(non_empty))
      sample_values <- non_empty[1:sample_size]
      parsed <- suppressWarnings(parse_danish_number(sample_values))
      return(sum(!is.na(parsed)) > 0)
    }
    return(FALSE)
  }, logical(1))
  validation_results$potential_numeric_columns <- sum(potential_numeric_columns)

  if (sum(potential_numeric_columns) < 1) {
    issues <- c(issues, "Ingen egnede numeriske kolonner fundet til Y-akse")
  }

  # Overall suitability assessment
  suitable <- length(issues) == 0

  # Log validation results
  log_info("Data validation for auto-detection completed",
    .context = "FILE_UPLOAD_FLOW",
    details = list(
      suitable = suitable,
      validation_results = validation_results,
      issues = if (length(issues) > 0) issues else "none"
    )
  )

  return(list(
    suitable = suitable,
    issues = issues,
    validation_results = validation_results
  ))
}

# EDGE CASE HANDLING =========================================================

## Enhanced data cleaning and preprocessing
preprocess_uploaded_data <- function(data, file_info, session_id = NULL) {
  original_dims <- c(nrow(data), ncol(data))
  cleaning_log <- list()

  # Data quality analysis before preprocessing - optimized med vectorized base R
  na_counts <- vapply(data, function(col) sum(is.na(col)), integer(1))
  # Fix: Only check character columns for empty strings to avoid NA-warnings
  empty_counts <- vapply(data, function(col) {
    if (is.character(col)) {
      sum(trimws(col) == "", na.rm = TRUE)
    } else {
      0L
    }
  }, integer(1))

  # Handle completely empty rows using tidyverse approach
  if (nrow(data) > 0) {
    # Count empty rows before filtering
    empty_rows_count <- data |>
      dplyr::filter(dplyr::if_all(dplyr::everything(), ~ {
        is.na(.x) | (is.character(.x) & stringr::str_trim(.x) == "")
      })) |>
      nrow()

    if (empty_rows_count > 0) {
      # Filter out empty rows
      data <- data |>
        dplyr::filter(!dplyr::if_all(dplyr::everything(), ~ {
          is.na(.x) | (is.character(.x) & stringr::str_trim(.x) == "")
        }))
      cleaning_log$empty_rows_removed <- empty_rows_count
    }
  }

  # Clean column names
  if (ncol(data) > 0) {
    original_names <- names(data)
    cleaned_names <- make.names(original_names, unique = TRUE)

    # Replace problematic characters with readable alternatives
    cleaned_names <- gsub("\\.\\.+", "_", cleaned_names) # Multiple dots to underscore
    cleaned_names <- gsub("^X", "Column_", cleaned_names) # R's automatic X prefix
    cleaned_names <- gsub("\\.$", "", cleaned_names) # Trailing dots

    if (!identical(original_names, cleaned_names)) {
      names(data) <- cleaned_names
      cleaning_log$column_names_cleaned <- TRUE
    }
  }

  final_dims <- c(nrow(data), ncol(data))
  cleaning_log$dimension_change <- list(
    original = original_dims,
    final = final_dims
  )

  # Enhanced final analysis and logging


  # Data quality check after preprocessing
  if (nrow(data) > 0 && ncol(data) > 0) {
    # Check for columns with all NA values - optimized med vectorized base R
    all_na_cols <- vapply(data, function(col) all(is.na(col)), logical(1))

    # Check for potential numeric columns - optimized med vectorized base R
    potential_numeric <- vapply(data, function(col) {
      if (is.character(col)) {
        numeric_values <- suppressWarnings(as.numeric(col))
        sum(!is.na(numeric_values)) > 0
      } else {
        is.numeric(col)
      }
    }, logical(1))
  }

  # Log preprocessing results
  log_info("Data preprocessing completed",
    .context = "FILE_UPLOAD_FLOW",
    details = list(
      filename = file_info$name,
      cleaning_log = cleaning_log,
      original_dimensions = original_dims,
      final_dimensions = final_dims
    )
  )


  return(list(
    data = data,
    cleaning_log = cleaning_log
  ))
}
