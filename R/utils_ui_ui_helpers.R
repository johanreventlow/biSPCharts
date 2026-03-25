# utils_ui_helpers.R
# Genanvendelige UI helper funktioner

# INPUT SANITIZATION UTILITIES ================================

#' Robust input sanitization for character(0) and NA handling
#'
#' Centralized input sanitization function that handles character(0),
#' NA values, empty strings, and vectors. Used throughout the app
#' for consistent dropdown and input validation.
#'
#' @param input_value Input value to sanitize (can be any type)
#'
#' @return Sanitized value or NULL if invalid/empty
#'
#' @details
#' Handles the following cases:
#' - NULL values → NULL
#' - character(0) → NULL
#' - Vectors with all NA → NULL
#' - Vectors longer than 1 → first element only
#' - Single NA values → NULL
#' - Empty or whitespace-only strings → NULL
#' - Valid values → unchanged
#'
#' @examples
#' sanitize_selection(NULL) # → NULL
#' sanitize_selection(character(0)) # → NULL
#' sanitize_selection(c(NA, NA)) # → NULL
#' sanitize_selection(c("a", "b")) # → "a"
#' sanitize_selection("") # → NULL
#' sanitize_selection("  ") # → NULL
#' sanitize_selection("valid") # → "valid"
#'
#' @family input_validation
#' @keywords internal
sanitize_selection <- function(input_value) {
  if (is.null(input_value) || length(input_value) == 0 || identical(input_value, character(0))) {
    return(NULL)
  }
  # Handle vectors with all NA values
  if (all(is.na(input_value))) {
    return(NULL)
  }
  # Handle vectors - use first element only
  if (length(input_value) > 1) {
    input_value <- input_value[1]
  }
  # Handle single NA value
  if (is.na(input_value)) {
    return(NULL)
  }
  # Handle empty strings and whitespace-only strings
  if (is.character(input_value) && (input_value == "" || trimws(input_value) == "")) {
    return(NULL)
  }
  return(input_value)
}
