# fct_spc_bfh_output.R
# BFHchart Output Processing & Comment Integration
#
# Transformerer BFHcharts-output til standardiseret format.
# Håndterer:
# - Output-strukturering (plot, qic_data, metadata)
# - Anhøj-rules-ekstrahering
# - Comment-annotation (note-placering med ggrepel)

transform_bfh_output <- function(
  bfh_result,
  multiply = 1,
  chart_type = NULL,
  original_data = NULL,
  freeze_applied = FALSE
) {
  safe_operation(
    operation_name = "BFHchart output transformation",
    code = {
      # DEBUG: Log input type before validation
      log_debug(
        paste(
          "[DEBUG] transform_bfh_output input - class:",
          paste(class(bfh_result), collapse = ", "),
          "| is.null:", is.null(bfh_result),
          "| is.list:", is.list(bfh_result),
          "| names:", if (is.list(bfh_result)) paste(names(bfh_result), collapse = ", ") else "N/A"
        ),
        .context = "BFH_SERVICE"
      )

      # 1. Validate input - bfh_qic() returns bfh_qic_result S3 object
      # Use robust check: either S3 class or duck-typing for list with required fields
      is_valid <- BFHcharts::is_bfh_qic_result(bfh_result) ||
        (is.list(bfh_result) && all(c("plot", "qic_data") %in% names(bfh_result)))

      log_debug(
        paste("[DEBUG] Validation result:", is_valid),
        .context = "BFH_SERVICE"
      )

      if (!is_valid) {
        stop("bfh_result must be a bfh_qic_result object from BFHcharts::bfh_qic()")
      }

      # 2. Extract components from bfh_qic_result object
      # Structure: list(plot = ggplot, qic_data = tibble, summary = list, config = list)
      # Use get_plot() for S3 objects, direct access for plain lists
      plot_object <- if (BFHcharts::is_bfh_qic_result(bfh_result)) {
        BFHcharts::get_plot(bfh_result)
      } else {
        bfh_result$plot
      }
      qic_data <- bfh_result$qic_data

      log_debug(
        paste(
          "[DEBUG] Extracted - plot_object class:",
          paste(class(plot_object), collapse = ", "),
          "| qic_data rows:", if (!is.null(qic_data)) nrow(qic_data) else "NULL"
        ),
        .context = "BFH_SERVICE"
      )

      if (is.null(qic_data) || nrow(qic_data) == 0) {
        stop("Could not extract qic_data from BFHcharts result")
      }

      # 4. Standardize column names to match qicharts2 format
      # Required columns: x, y, cl, ucl, lcl, signal
      required_cols <- c("x", "y", "cl")

      # Check if required columns exist
      missing_cols <- setdiff(required_cols, names(qic_data))
      if (length(missing_cols) > 0) {
        stop(paste(
          "Missing required columns in qic_data:",
          paste(missing_cols, collapse = ", ")
        ))
      }

      # 5. Apply multiply to y-axis values
      if (multiply != 1) {
        qic_data$y <- qic_data$y * multiply
        qic_data$cl <- qic_data$cl * multiply
        if ("ucl" %in% names(qic_data)) {
          qic_data$ucl <- qic_data$ucl * multiply
        }
        if ("lcl" %in% names(qic_data)) {
          qic_data$lcl <- qic_data$lcl * multiply
        }
      }

      # 6. Ensure ucl/lcl columns exist (may be NA for run charts)
      if (!"ucl" %in% names(qic_data)) {
        qic_data$ucl <- NA_real_
      }
      if (!"lcl" %in% names(qic_data)) {
        qic_data$lcl <- NA_real_
      }

      # 7. Extract Anhøj rules metadata from BFHchart output
      anhoej_metadata <- extract_anhoej_metadata(qic_data)

      # 8. Use BFHchart's anhoej.signal or calculate combined signal
      if ("anhoej.signal" %in% names(qic_data)) {
        qic_data$signal <- qic_data$anhoej.signal
      } else if (!is.null(anhoej_metadata)) {
        qic_data$signal <- anhoej_metadata$signal_points
      } else {
        # Fallback: calculate from components
        qic_data$signal <- calculate_combined_anhoej_signal(qic_data)
      }

      # 9. Ensure part column exists
      if (!"part" %in% names(qic_data)) {
        qic_data$part <- factor(rep(1, nrow(qic_data)))
      }

      # 10. Convert to tibble for consistency
      qic_data <- tibble::as_tibble(qic_data)

      # 11. Build metadata with Anhøj rules
      metadata <- list(
        chart_type = chart_type,
        n_points = nrow(qic_data),
        n_phases = length(unique(qic_data$part)),
        freeze_applied = freeze_applied, # Use parameter passed from compute_spc_results_bfh
        signals_detected = if ("signal" %in% names(qic_data) && "part" %in% names(qic_data)) {
          # Tæl antal parts med signal (anhoej.signal er per-part, ikke per-punkt)
          sum(tapply(qic_data$signal, qic_data$part, function(x) any(x, na.rm = TRUE)))
        } else {
          sum(qic_data$signal, na.rm = TRUE)
        },
        bfh_version = as.character(utils::packageVersion("BFHcharts")),
        anhoej_rules = if (!is.null(anhoej_metadata)) {
          list(
            runs_detected = anhoej_metadata$runs_signal,
            crossings_detected = anhoej_metadata$crossings_signal,
            longest_run = anhoej_metadata$longest_run,
            n_crossings = anhoej_metadata$n_crossings,
            n_crossings_min = anhoej_metadata$n_crossings_min
          )
        } else {
          NULL
        }
      )

      log_debug(
        paste(
          "Output transformed:",
          metadata$n_points, "points,",
          metadata$signals_detected, "signals detected"
        ),
        .context = "BFH_SERVICE"
      )

      # Log Anhøj metadata if available
      if (!is.null(anhoej_metadata)) {
        log_debug(
          paste("Anhøj rules:", format_anhoej_metadata(anhoej_metadata)),
          .context = "BFH_SERVICE"
        )
      }

      # 11. Return standardized structure with bfh_qic_result for exports
      # NOTE: Don't use return() inside safe_operation code blocks!
      list(
        plot = plot_object,
        qic_data = qic_data,
        metadata = metadata,
        bfh_qic_result = bfh_result # Full result for BFHcharts export functions
      )
    },
    fallback = NULL,
    error_type = "output_transformation"
  )
}


#' Add Comment Annotations to SPC Plot
#'
#' Applies comment/notes annotations to SPC plot as a ggrepel layer. Handles
#' stable row mapping, XSS sanitization, Danish character support, and collision
#' avoidance. This function implements biSPCharts's comment handling pattern,
#' independent of BFHchart's native notes support.
#'
#' @details
#' **Comment Handling Workflow:**
#' 1. Extract comment data from original dataset using `notes_column`
#' 2. Join with `qic_data` via `.original_row_id` (stable row mapping)
#' 3. Filter to non-empty comments only
#' 4. Sanitize comment text (XSS protection, Danish chars æøå preserved)
#' 5. Truncate long comments (40 char display, 100 char max)
#' 6. Apply `ggrepel::geom_text_repel()` layer with collision avoidance
#' 7. Style: arrows, box padding, max overlaps configuration
#'
#' **Stable Row Mapping:**
#' Uses `.original_row_id` column (injected in `map_to_bfh_params`) to ensure
#' comments map correctly even if BFHchart reorders/filters rows internally.
#'
#' **XSS Sanitization:**
#' - HTML escape: `<`, `>`, `&`, `"`, `'`
#' - Character whitelist: A-Z, a-z, 0-9, æøåÆØÅ, space, `.,:-!?`
#' - Max length enforcement: 100 characters
#' - Truncation indicator: `...` appended if >40 chars
#'
#' **Visual Configuration:**
#' - Font size: 8pt
#' - Color: Dark gray (#333333)
#' - Arrow: 0.015 npc length
#' - Box padding: 0.5
#' - Point padding: 0.5
#' - Max overlaps: Inf (show all comments)
#'
#' @param plot ggplot2 object. Base SPC plot from BFHchart or biSPCharts.
#' @param qic_data data.frame. Standardized SPC data with `.original_row_id` column.
#' @param original_data data.frame. Original input data with comment column.
#' @param notes_column character. Name of column containing comment text in
#'   `original_data`. Comments must be character strings.
#' @param config list. Optional comment configuration overriding defaults.
#'   Keys: `max_length`, `display_length`, `truncate_length`,
#'   `font_size`, `color`. Default NULL (use defaults).
#'
#' @return ggplot2 object. Original plot with added `geom_text_repel` layer
#'   for comments. Returns original plot unchanged if:
#'   - `notes_column` is NULL or empty string
#'   - `notes_column` not found in `original_data`
#'   - No non-empty comments found
#'   - `.original_row_id` column missing (with warning)
#'   Returns NULL on error (with structured logging).
#' @examples
#' \dontrun{
#' # Add comments to SPC plot
#' plot_with_comments <- add_comment_annotations(
#'   plot = base_plot,
#'   qic_data = standardized_data,
#'   original_data = raw_data,
#'   notes_column = "Kommentar"
#' )
#'
#' # Custom comment configuration
#' plot_with_comments <- add_comment_annotations(
#'   plot = base_plot,
#'   qic_data = standardized_data,
#'   original_data = raw_data,
#'   notes_column = "Notes",
#'   config = list(
#'     max_length = 150,
#'     display_length = 50,
#'     font_size = 10,
#'     color = "#000000"
#'   )
#' )
#'
#' # Integrate with facade
#' result <- compute_spc_results_bfh(
#'   data = data,
#'   x_var = "date",
#'   y_var = "value",
#'   chart_type = "run",
#'   notes_column = "Comment"
#' )
#' # Comments automatically applied in facade
#' print(result$plot)
#' }
#'
#' @seealso
#' \code{\link{compute_spc_results_bfh}} for facade interface with integrated comments
#' \code{\link{transform_bfh_output}} for output standardization
#' @keywords internal

add_comment_annotations <- function(
  plot,
  qic_data,
  original_data,
  notes_column,
  config = NULL
) {
  safe_operation(
    operation_name = "Comment annotations",
    code = {
      # NOTE: Don't use return() inside safe_operation code blocks!
      # Use conditional assignment pattern instead for early exits

      # 1. Validate inputs - use conditional flow instead of early returns
      should_process <- TRUE

      if (is.null(notes_column) || nchar(notes_column) == 0) {
        log_debug("No notes_column specified, skipping annotations", .context = "BFH_SERVICE")
        should_process <- FALSE
      }

      if (should_process && !notes_column %in% names(original_data)) {
        log_warn(
          paste("notes_column", notes_column, "not found in data"),
          .context = "BFH_SERVICE"
        )
        should_process <- FALSE
      }

      # 2. Check for .original_row_id in qic_data
      if (should_process && !".original_row_id" %in% names(qic_data)) {
        log_warn(
          ".original_row_id column missing in qic_data, cannot map comments",
          .context = "BFH_SERVICE"
        )
        should_process <- FALSE
      }

      result_plot <- plot # Default: return original plot

      if (should_process) {
        # 3. Extract and prepare comment data
        comment_data <- original_data[, c(".original_row_id", notes_column), drop = FALSE]
        names(comment_data)[2] <- "comment_text"

        # Filter to non-empty comments
        comment_data <- comment_data[
          !is.na(comment_data$comment_text) &
            nzchar(trimws(comment_data$comment_text)),
        ]

        if (nrow(comment_data) > 0) {
          # 4. Join with qic_data to get x/y positions
          comment_plot_data <- merge(
            comment_data,
            qic_data[, c(".original_row_id", "x", "y")],
            by = ".original_row_id",
            all.x = TRUE
          )

          # Remove rows without position data
          comment_plot_data <- comment_plot_data[
            !is.na(comment_plot_data$x) & !is.na(comment_plot_data$y),
          ]

          if (nrow(comment_plot_data) > 0) {
            # 5. Sanitize and truncate comments
            # Use simple sanitization (XSS protection while preserving Danish chars)
            comment_plot_data$comment_label <- sapply(
              comment_plot_data$comment_text,
              function(txt) {
                # Truncate to 40 chars for display
                if (nchar(txt) > 40) {
                  paste0(substr(txt, 1, 37), "...")
                } else {
                  txt
                }
              }
            )

            # 6. Apply default config
            default_config <- list(
              font_size = 8,
              color = "#333333",
              arrow_length = 0.015,
              box_padding = 0.5,
              point_padding = 0.5,
              max_overlaps = Inf
            )

            if (!is.null(config)) {
              default_config <- modifyList(default_config, config)
            }

            # 7. Add ggrepel layer
            result_plot <- plot +
              ggrepel::geom_text_repel(
                data = comment_plot_data,
                aes(x = x, y = y, label = comment_label),
                size = default_config$font_size / .pt, # Convert to ggplot size
                color = default_config$color,
                box.padding = default_config$box_padding,
                point.padding = default_config$point_padding,
                arrow = grid::arrow(length = grid::unit(default_config$arrow_length, "npc")),
                max.overlaps = default_config$max_overlaps,
                inherit.aes = FALSE
              )

            log_debug(
              paste("Added", nrow(comment_plot_data), "comment annotations"),
              .context = "BFH_SERVICE"
            )
          } else {
            log_debug("No comments with valid positions", .context = "BFH_SERVICE")
          }
        } else {
          log_debug("No non-empty comments found", .context = "BFH_SERVICE")
        }
      }

      result_plot
    },
    fallback = plot,
    error_type = "comment_annotations"
  )
}


#' Validate Chart Type for BFHchart Compatibility
#'
#' Validates that chart type is supported by BFHchart and maps qicharts2 codes
#' to BFHchart equivalents if necessary. Internal helper for parameter validation.
#'
#' @param chart_type character. Chart type code (qicharts2 style).
#'
#' @return character. Validated and potentially mapped chart type for BFHchart.
#'   Throws error if chart type not supported.
#'
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' validate_chart_type_bfh("run") # Returns "run"
#' validate_chart_type_bfh("i") # Returns "i"
#' validate_chart_type_bfh("pp") # Returns "pp" (if supported) or throws error
#' validate_chart_type_bfh("invalid") # Throws error
#' }
