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

  # Replace comma with dot for decimal separation
  x_normalized <- gsub(",", ".", x_cleaned)

  # Convert to numeric
  result <- suppressWarnings(as.numeric(x_normalized))

  return(result)
}

# parse_danish_target er defineret i utils_y_axis_scaling.R
