# Performance Helper Functions
# Supporting functions for performance optimizations

#' Appears Date
#'
#' Check if a character vector appears to contain date data
#'
#' @param x Character vector to check
#' @return Logical indicating if data appears to be dates
#'
appears_date <- function(x) {
  if (!is.character(x)) {
    return(FALSE)
  }

  # Sample a few values for efficiency
  sample_size <- min(10, length(x))
  sample_data <- x[!is.na(x)][1:sample_size]

  if (length(sample_data) == 0) {
    return(FALSE)
  }

  # Common date patterns
  date_patterns <- c(
    "\\d{4}-\\d{2}-\\d{2}", # YYYY-MM-DD
    "\\d{2}-\\d{2}-\\d{4}", # DD-MM-YYYY
    "\\d{2}/\\d{2}/\\d{4}", # DD/MM/YYYY
    "\\d{4}/\\d{2}/\\d{2}" # YYYY/MM/DD
  )

  # Check pattern matches
  pattern_matches <- 0
  for (pattern in date_patterns) {
    if (any(grepl(pattern, sample_data))) {
      pattern_matches <- pattern_matches + 1
    }
  }

  # TEST FIX: Try actual date parsing with tryCatch to handle errors
  parse_success_rate <- 0
  tryCatch(
    {
      suppressWarnings({
        parsed_dates <- as.Date(sample_data)
        parse_success_rate <- sum(!is.na(parsed_dates)) / length(sample_data)
      })
    },
    error = function(e) {
      # If parsing fails completely, treat as non-date
      parse_success_rate <<- 0
    }
  )

  return(pattern_matches > 0 || parse_success_rate > 0.5)
}

#' Parse Danish Number Vectorized
#'
#' Efficiently parse Danish number format with vectorized operations
#'
#' @param x Character vector with Danish number format
#' @return Numeric vector
#'
parse_danish_number_vectorized <- function(x) {
  if (!is.character(x)) {
    return(as.numeric(x))
  }

  # Vectorized cleaning and conversion
  # Replace Danish decimal comma with period
  cleaned <- gsub(",", ".", x)
  # Remove thousands separators (space or period when not decimal)
  cleaned <- gsub("\\s+", "", cleaned)
  # Convert to numeric
  suppressWarnings(as.numeric(cleaned))
}

#' Parse Danish Date Vectorized
#'
#' Efficiently parse Danish date format with vectorized operations
#'
#' @param x Character vector with Danish date format
#' @return Date vector
#'
parse_danish_date_vectorized <- function(x) {
  if (!is.character(x)) {
    return(as.Date(x))
  }

  # Try multiple date formats common in Danish data
  date_formats <- c(
    "%d-%m-%Y", # DD-MM-YYYY
    "%d/%m/%Y", # DD/MM/YYYY
    "%Y-%m-%d", # YYYY-MM-DD
    "%Y/%m/%d", # YYYY/MM/DD
    "%d.%m.%Y" # DD.MM.YYYY
  )

  result <- rep(as.Date(NA), length(x))

  for (format in date_formats) {
    if (all(!is.na(result))) break # All dates parsed successfully

    missing_indices <- is.na(result)
    if (any(missing_indices)) {
      suppressWarnings({
        parsed <- as.Date(x[missing_indices], format = format)
        success_indices <- !is.na(parsed)
        result[missing_indices][success_indices] <- parsed[success_indices]
      })
    }
  }

  return(result)
}

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

#' Add Comments Optimized
#'
#' Add comments to plot with optimization - matches extract_comment_data approach
#'
#' @param plot ggplot object
#' @param data Original data frame
#' @param kommentar_column Column name for comments
#' @param qic_data QIC processed data with transformed coordinates
#'
add_comments_optimized <- function(plot, data, kommentar_column, qic_data) {
  if (is.null(kommentar_column) || !kommentar_column %in% names(data) || is.null(qic_data)) {
    return(plot)
  }

  # Use same approach as extract_comment_data for consistency
  comments_raw <- data[[kommentar_column]]

  # Create comment data frame aligned with qic_data
  comment_data <- data.frame(
    x = qic_data$x,
    y = qic_data$y,
    comment = comments_raw[1:nrow(qic_data)], # Ensure same length as qic_data
    stringsAsFactors = FALSE
  )

  # Filter to only non-empty comments
  comment_data <- comment_data[
    !is.na(comment_data$comment) &
      trimws(comment_data$comment) != "",
  ]

  if (nrow(comment_data) == 0) {
    return(plot)
  }

  # Truncate very long comments
  if (nrow(comment_data) > 0) {
    comment_data$comment <- dplyr::if_else(
      nchar(comment_data$comment) > 40,
      stringr::str_c(substr(comment_data$comment, 1, 37), "..."),
      comment_data$comment
    )
  }

  # Get hospital colors for consistent styling
  hospital_colors <- get_hospital_colors()

  # Add comments with ggrepel for better positioning
  if (requireNamespace("ggrepel", quietly = TRUE)) {
    plot <- plot + ggrepel::geom_text_repel(
      data = comment_data,
      ggplot2::aes(x = x, y = y, label = comment),
      size = 3,
      color = hospital_colors$darkgrey,
      bg.color = "white",
      bg.r = 0.1,
      box.padding = 0.5,
      point.padding = 0.5,
      segment.color = hospital_colors$mediumgrey,
      segment.size = 0.3,
      nudge_x = .15,
      nudge_y = .5,
      segment.curvature = -1e-20,
      arrow = grid::arrow(length = grid::unit(0.015, "npc")),
      max.overlaps = Inf,
      inherit.aes = FALSE
    )
  } else {
    # Fallback without ggrepel - use same styling as main function
    plot <- plot + ggplot2::geom_text(
      data = comment_data,
      ggplot2::aes(x = x, y = y, label = comment),
      size = 3,
      color = hospital_colors$darkgrey,
      vjust = -0.5
    )
  }

  return(plot)
}
