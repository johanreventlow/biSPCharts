# R/utils/danish_numbers.R
# Hjaelpefunktioner til haandtering af danske talformater (komma som decimalseparator)

# DANSK TAL KONVERTERING =====================================================

## Konverter dansk talstreng til numerisk vaerdi
# Haandterer baade komma og punktum som decimalseparator samt procent/promille symboler
parse_danish_number <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(numeric(0))
  }

  # Handle vectors using tidyverse approach
  if (length(x) > 1) {
    return(purrr::map_dbl(x, parse_danish_number))
  }

  # Convert to character if needed
  x <- as.character(x)

  # Return NA if empty or whitespace only
  if (is.na(x) || trimws(x) == "") {
    return(NA_real_)
  }

  # Remove whitespace
  x <- trimws(x)

  # Handle special cases
  if (x == "" || is.na(x)) {
    return(NA_real_)
  }

  # Remove common symbols that appear in Danish data
  # - Remove % and %% symbols (but keep the numeric value)
  # - Remove thousand separators (spaces or dots in specific patterns)
  x_cleaned <- x
  x_cleaned <- gsub("[%\u2030]", "", x_cleaned) # Remove percent and permille symbols
  x_cleaned <- gsub("\\s+", "", x_cleaned) # Remove spaces
  x_cleaned <- trimws(x_cleaned)

  # Cycle D M1 (Codex 2026-05-10): conditional thousand-separator strip.
  # Dansk format "1.234,56" har komma som decimal -> punktum er grouping.
  # Uden komma kan "1.234" v\u00e6re enten 1234 (dansk grouping) eller 1.234 (point-
  # decimal, fx engelsk-eksport). Strip kun grouping-dots HVIS komma er til
  # stede (entydigt dansk format-signal). Forhindrer silent corruption af
  # engelsk point-decimal "1.234" -> 1234.
  if (grepl(",", x_cleaned, fixed = TRUE)) {
    # Match . der staar mellem cifre med pr\u00e6cis 3-cifre-gruppe efter
    # (tusind-separator, ej decimal). K\u00f8rer over multiple grupperinger.
    x_cleaned <- gsub(
      "(?<=\\d)\\.(?=\\d{3}(\\D|$))",
      "",
      x_cleaned,
      perl = TRUE
    )
  }

  # Replace comma with dot for decimal separation
  x_normalized <- gsub(",", ".", x_cleaned)

  # Convert to numeric
  result <- suppressWarnings(as.numeric(x_normalized))

  return(result)
}

# parse_danish_target er defineret i utils_y_axis_scaling.R
