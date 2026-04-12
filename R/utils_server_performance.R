# Performance Helper Functions
# Supporting functions for performance optimizations

#' Ensure Standard Columns
#'
#' Ensure data has standard column naming and structure
#'
#' @param data Data frame to standardize
#' @return Standardized data frame
#' @keywords internal
ensure_standard_columns <- function(data) {
  if (is.null(data) || nrow(data) == 0) {
    return(data)
  }

  # Tilføj Skift som kolonne 1 hvis den mangler
  if (!"Skift" %in% names(data)) {
    data <- dplyr::bind_cols(
      tibble::tibble(Skift = rep(FALSE, nrow(data))),
      data
    )
  }

  # Tilføj Frys som kolonne 2 (efter Skift) hvis den mangler
  if (!"Frys" %in% names(data)) {
    skift_pos <- which(names(data) == "Skift")
    if (skift_pos < ncol(data)) {
      data <- dplyr::bind_cols(
        data[, 1:skift_pos, drop = FALSE],
        tibble::tibble(Frys = rep(FALSE, nrow(data))),
        data[, (skift_pos + 1):ncol(data), drop = FALSE]
      )
    } else {
      data <- dplyr::bind_cols(
        data,
        tibble::tibble(Frys = rep(FALSE, nrow(data)))
      )
    }
  }

  # Sikre gyldige kolonnenavne
  names(data) <- make.names(names(data), unique = TRUE)

  data
}
