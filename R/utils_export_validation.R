# ==============================================================================
# UTILS_EXPORT_VALIDATION.R
# ==============================================================================
# FORMAaL: Input validation og sanitization for export funktioner.
#         Sikrer XSS protection, character limits og dimension validation.
#
# FUNKTIONER:
#   - validate_export_inputs() - Komplet input validation
#   - sanitize_user_input() - XSS protection og character filtering
#   - validate_aspect_ratio() - Aspect ratio validation med warnings
#
# ANVENDES AF:
#   - Export module server (mod_export_server.R)
#   - PDF export logic
#   - PNG export logic
#
# SIKKERHED:
#   - XSS protection gennem HTML escaping
#   - Character filtering til cross-platform kompatibilitet
#   - Input validation forhindrer buffer overflow og injection
# ==============================================================================

#' Validate Export Inputs
#'
#' Validerer alle export inputs foer generering af PDF/PNG.
#' Tjekker character limits, dimension ranges og aspect ratios.
#'
#' @param format Export format ("pdf", "png")
#' @param title Chart titel (max 200 tegn)
#' @param department Afdeling/afsnit (max 100 tegn)
#' @param description Indikator beskrivelse (max 2000 tegn)
#' @param footnote Datakilde-attribution (max EXPORT_FOOTNOTE_MAX_LENGTH tegn).
#'   Sendes til BFHcharts Typst-template som `footer_content` (#485).
#' @param width Custom bredde i pixels (kun PNG)
#' @param height Custom hoejde i pixels (kun PNG)
#'
#' @return TRUE hvis alle validations passerer.
#'
#' @section Errors:
#' Kaster en fejl hvis validation fejler med beskrivende fejlbesked.
#'
#' @examples
#' \dontrun{
#' validate_export_inputs(
#'   format = "pdf",
#'   title = "Min SPC Graf",
#'   department = "Kardiologi"
#' )
#'
#' validate_export_inputs(
#'   format = "png",
#'   title = "Graf",
#'   width = 1200,
#'   height = 900
#' )
#' }
#'
#' @keywords internal
validate_export_inputs <- function(format,
                                   title = "",
                                   department = "",
                                   hospital = "",
                                   description = "",
                                   footnote = "",
                                   width = NULL,
                                   height = NULL) {
  errors <- character(0)

  # Convert NULL to empty string
  title <- title %||% ""
  department <- department %||% ""
  hospital <- hospital %||% ""
  description <- description %||% ""
  footnote <- footnote %||% ""

  # Character limit validation
  if (nchar(title) > EXPORT_TITLE_MAX_LENGTH) {
    errors <- c(errors, sprintf(
      "Titel m\u00e5 max v\u00e6re %d tegn (nuv\u00e6rende: %d)",
      EXPORT_TITLE_MAX_LENGTH,
      nchar(title)
    ))
  }

  if (nchar(description) > EXPORT_DESCRIPTION_MAX_LENGTH) {
    errors <- c(errors, sprintf(
      "Beskrivelse m\u00e5 max v\u00e6re %d tegn (nuv\u00e6rende: %d)",
      EXPORT_DESCRIPTION_MAX_LENGTH,
      nchar(description)
    ))
  }

  if (nchar(department) > EXPORT_DEPARTMENT_MAX_LENGTH) {
    errors <- c(errors, sprintf(
      "Afdeling m\u00e5 max v\u00e6re %d tegn (nuv\u00e6rende: %d)",
      EXPORT_DEPARTMENT_MAX_LENGTH,
      nchar(department)
    ))
  }

  if (nchar(hospital) > EXPORT_HOSPITAL_MAX_LENGTH) {
    errors <- c(errors, sprintf(
      "Hospitalsnavn m\u00e5 max v\u00e6re %d tegn (nuv\u00e6rende: %d)",
      EXPORT_HOSPITAL_MAX_LENGTH,
      nchar(hospital)
    ))
  }

  if (nchar(footnote) > EXPORT_FOOTNOTE_MAX_LENGTH) {
    errors <- c(errors, sprintf(
      "Fodnote m\u00e5 max v\u00e6re %d tegn (nuv\u00e6rende: %d)",
      EXPORT_FOOTNOTE_MAX_LENGTH,
      nchar(footnote)
    ))
  }

  # PNG-specific dimension validation
  if (tolower(format) == "png" && !is.null(width) && !is.null(height)) {
    # Width validation
    if (width < EXPORT_VALIDATION_RULES$min_width_px) {
      errors <- c(errors, sprintf(
        "Bredde skal v\u00e6re mellem %d og %d pixels (nuv\u00e6rende: %d)",
        EXPORT_VALIDATION_RULES$min_width_px,
        EXPORT_VALIDATION_RULES$max_width_px,
        width
      ))
    }

    if (width > EXPORT_VALIDATION_RULES$max_width_px) {
      errors <- c(errors, sprintf(
        "Bredde skal v\u00e6re mellem %d og %d pixels (nuv\u00e6rende: %d)",
        EXPORT_VALIDATION_RULES$min_width_px,
        EXPORT_VALIDATION_RULES$max_width_px,
        width
      ))
    }

    # Height validation
    if (height < EXPORT_VALIDATION_RULES$min_height_px) {
      errors <- c(errors, sprintf(
        "H\u00f8jde skal v\u00e6re mellem %d og %d pixels (nuv\u00e6rende: %d)",
        EXPORT_VALIDATION_RULES$min_height_px,
        EXPORT_VALIDATION_RULES$max_height_px,
        height
      ))
    }

    if (height > EXPORT_VALIDATION_RULES$max_height_px) {
      errors <- c(errors, sprintf(
        "H\u00f8jde skal v\u00e6re mellem %d og %d pixels (nuv\u00e6rende: %d)",
        EXPORT_VALIDATION_RULES$min_height_px,
        EXPORT_VALIDATION_RULES$max_height_px,
        height
      ))
    }

    # Aspect ratio validation
    if (width > 0 && height > 0) {
      aspect_ratio <- width / height

      if (aspect_ratio < EXPORT_ASPECT_RATIO_MIN ||
        aspect_ratio > EXPORT_ASPECT_RATIO_MAX) {
        errors <- c(errors, sprintf(
          "\u26a0\ufe0f Ekstrem aspekt-ratio (%.2f) kan resultere i forvr\u00e6nget graf (forventet: %.1f-%.1f)",
          aspect_ratio,
          EXPORT_ASPECT_RATIO_MIN,
          EXPORT_ASPECT_RATIO_MAX
        ))
      }
    }
  }

  # Throw error hvis validation fejlede
  if (length(errors) > 0) {
    stop(paste(errors, collapse = "\n"), call. = FALSE)
  }

  return(TRUE)
}

#' Sanitize User Input for XSS Protection
#'
#' Renser bruger input for potentielle XSS angreb og fjerner ugyldige karakterer.
#' Understoetter danske karakterer (aeoeaaAeOeAa) og basis tegnsaetning.
#'
#' @param input_value Input string til sanitization
#' @param max_length Maximum tilladt laengde (NULL for ingen graense)
#' @param allowed_chars Regex pattern for tilladte karakterer
#' @param html_escape Escape HTML special characters (default TRUE)
#'
#' @return Sanitized string
#'
#' @details
#' Sanitization proces:
#' 1. Konverter NULL til tom string
#' 2. Konverter til character hvis noedvendigt
#' 3. HTML escape hvis aktiveret
#' 4. Fjern ugyldige karakterer via regex
#' 5. Trim whitespace
#' 6. Truncate til max_length hvis specificeret
#'
#' @examples
#' \dontrun{
#' sanitize_user_input("<script>alert('XSS')</script>")
#' # "&lt;script&gt;alert('XSS')&lt;/script&gt;"
#'
#' sanitize_user_input("Koebenhavn Sygehus @#$")
#' # "Koebenhavn Sygehus "
#' }
#'
#' @keywords internal
sanitize_user_input <- function(input_value,
                                max_length = NULL,
                                allowed_chars = "A-Za-z0-9_\u00e6\u00f8\u00e5\u00c6\u00d8\u00c5 .,-:!?*_",
                                html_escape = TRUE) {
  # Handle empty inputs before string operations that expect length one.
  if (is.null(input_value) || length(input_value) == 0 || all(is.na(input_value))) {
    return("")
  }

  # Convert to character if necessary
  if (!is.character(input_value)) {
    input_value <- as.character(input_value)
  }

  # HTML escape for XSS protection
  if (html_escape) {
    input_value <- gsub("<", "&lt;", input_value, fixed = TRUE)
    input_value <- gsub(">", "&gt;", input_value, fixed = TRUE)
    input_value <- gsub("&", "&amp;", input_value, fixed = TRUE)
    input_value <- gsub("\"", "&quot;", input_value, fixed = TRUE)
    input_value <- gsub("'", "&#39;", input_value, fixed = TRUE)

    # Remove JavaScript protocols
    input_value <- gsub("javascript:", "", input_value, ignore.case = TRUE)
    input_value <- gsub("vbscript:", "", input_value, ignore.case = TRUE)
  }

  # Split by newlines to preserve them during sanitization
  # Process each line separately, then rejoin
  lines <- strsplit(input_value, "\n", fixed = TRUE)[[1]]

  # Remove characters not in allowed set from each line (newlines already separated)
  pattern <- sprintf("[^%s]", allowed_chars)
  lines <- gsub(pattern, "", lines)

  # Trim leading/trailing whitespace per line
  lines <- trimws(lines)

  # Remove empty lines but preserve the structure with newlines
  input_value <- paste(lines, collapse = "\n")

  # Truncate to max length if specified
  if (!is.null(max_length) && nchar(input_value) > max_length) {
    input_value <- substr(input_value, 1, max_length)
  }

  return(input_value)
}

#' Validate Aspect Ratio
#'
#' Validerer aspect ratio (bredde/hoejde) for export dimensioner.
#' Advarer eller fejler ved ekstreme ratios udenfor acceptable graenser.
#'
#' @param width Bredde i pixels eller inches
#' @param height Hoejde i pixels eller inches
#' @param warn_only Emit warning i stedet for error (default TRUE)
#'
#' @return TRUE hvis aspect ratio er acceptable eller warn_only = TRUE.
#'
#' @section Errors:
#' Advarer hvis aspect ratio er ekstrem og `warn_only = TRUE`; kaster fejl hvis
#' aspect ratio er ekstrem og `warn_only = FALSE`.
#'
#' @details
#' Acceptable aspect ratios: 0.5 - 2.0
#' \itemize{
#'   \item Under 0.5: For smalt (hoejt og snaevert)
#'   \item Over 2.0: For bredt (lavt og bredt)
#' }
#'
#' @examples
#' \dontrun{
#' validate_aspect_ratio(1200, 900) # OK (1.33)
#' validate_aspect_ratio(400, 1000) # Warning (0.4 - too narrow)
#' validate_aspect_ratio(2000, 800, warn_only = FALSE) # Error (2.5 - too wide)
#' }
#'
#' @keywords internal
validate_aspect_ratio <- function(width, height, warn_only = TRUE) {
  # Handle invalid inputs
  if (is.null(width) || is.null(height) ||
    !is.numeric(width) || !is.numeric(height)) {
    stop("Width and height must be numeric values", call. = FALSE)
  }

  if (height <= 0) {
    stop("Height must be greater than zero", call. = FALSE)
  }

  if (width <= 0) {
    stop("Width must be greater than zero", call. = FALSE)
  }

  # Calculate aspect ratio
  aspect_ratio <- width / height

  # Check if within acceptable range
  if (aspect_ratio < EXPORT_ASPECT_RATIO_MIN ||
    aspect_ratio > EXPORT_ASPECT_RATIO_MAX) {
    message <- sprintf(
      "Aspect ratio %.2f is extreme (expected: %.1f-%.1f)",
      aspect_ratio,
      EXPORT_ASPECT_RATIO_MIN,
      EXPORT_ASPECT_RATIO_MAX
    )

    if (warn_only) {
      warning(message, call. = FALSE)
      return(TRUE)
    } else {
      stop(message, call. = FALSE)
    }
  }

  return(TRUE)
}

# ESCAPE TYPST METADATA =======================================================

#' Escape user-input for Typst-template
#'
#' Escapes Typst-markup characters for at undgaa at user-input fortolkes som
#' Typst-markup ved indsaettelse i template. Defense-in-depth -- BFHcharts
#' forventes ogsaa at escape, men app-laget tilfoejer ekstra beskyttelse
#' mod markup-injection.
#'
#' Escaped tegn (jf. Typst-syntaks):
#' \itemize{
#'   \item Backslash (\\) -- escape-prefiks selv
#'   \item Hash (#) -- function-call/raw-block
#'   \item Dollar ($) -- math-mode
#'   \item Backtick (\code{`}) -- raw-text
#'   \item Asterisk (*) -- bold (#486)
#'   \item Underscore (_) -- emphasis/italic (#486)
#'   \item Square brackets (\code{[}, \code{]}) -- content-block (#486)
#'   \item Angle brackets (\code{<}, \code{>}) -- label/syntax (#486)
#'   \item At-sign (@) -- reference (#486)
#'   \item Line-leading =, -, +, / -- heading/list-markers (#486)
#' }
#'
#' @param value Character or NULL/non-character (returneres uaendret).
#'   Vectors behandles per element.
#' @return Escaped character, eller value uaendret hvis NULL/non-character.
#' @keywords internal
escape_typst_metadata <- function(value) {
  if (is.null(value) || !is.character(value)) {
    return(value)
  }
  if (length(value) != 1L) {
    return(vapply(value, escape_typst_metadata, character(1L)))
  }

  # Backslash foerst -- undgaar dobbelt-escape af efterfoelgende erstatninger.
  # Alle erstatninger bruger regex-mode (uden fixed=TRUE) saa replacement-strengen
  # fortolkes korrekt: \\\\ (4 tegn i kode) = \\ (2 tegn) = et \ i output.
  value <- gsub("\\\\", "\\\\\\\\", value)
  value <- gsub("#", "\\\\#", value)
  value <- gsub("\\$", "\\\\$", value)
  value <- gsub("`", "\\\\`", value)

  # #486: Markup-tegn der inden for tekst kan inducere format-aendring.
  value <- gsub("\\*", "\\\\*", value)
  value <- gsub("_", "\\\\_", value)
  value <- gsub("\\[", "\\\\[", value)
  value <- gsub("\\]", "\\\\]", value)
  value <- gsub("<", "\\\\<", value)
  value <- gsub(">", "\\\\>", value)
  value <- gsub("@", "\\\\@", value)

  # #486: Line-leading markup (heading/list). Brug multi-line-mode (?m) saa
  # ^ matcher start-af-linje, ej kun start-af-streng.
  value <- gsub("(?m)^=", "\\\\=", value, perl = TRUE)
  value <- gsub("(?m)^-", "\\\\-", value, perl = TRUE)
  value <- gsub("(?m)^\\+", "\\\\+", value, perl = TRUE)
  value <- gsub("(?m)^/", "\\\\/", value, perl = TRUE)

  value
}

# HELPER: NULL coalescing operator ============================================

# %||% operatoren er defineret i golem_utils.R (fjernet duplikat, se #102)
