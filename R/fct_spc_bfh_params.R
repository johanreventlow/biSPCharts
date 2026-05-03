# fct_spc_bfh_params.R
# BFHchart Parameter Transformation
#
# Mapper biSPCharts parametre til BFHcharts API-format.
# Haandterer:
# - Kolonne-navnemapping (sanitisering af danske karakterer for BFHcharts)
# - Skalering og normalisering (procent til decimal)
# - Freeze/part position-beregning
# - Notes/comment-integrering

#' Map biSPCharts Parameters to BFHchart API
#'
#' Transforms biSPCharts-style parameters to BFHchart API conventions. Handles
#' parameter name mapping, scale normalization (percentage to decimal), and
#' data structure preparation. Isolates biSPCharts from BFHchart API changes.
#'
#' @details
#' **Transformation Responsibilities:**
#' - Column name mapping (x_var, y_var, n_var -> BFHchart parameters)
#' - Chart type validation and translation
#' - Scale normalization (e.g., target 75 -> 0.75 for percentage charts)
#' - Freeze/part position adjustment for NA-removed rows
#' - Row ID injection (`.original_row_id`) for comment mapping stability
#' - NSE (non-standard evaluation) handling if required by BFHchart
#'
#' **Parameter Mappings (Expected):**
#' - biSPCharts `part_var` -> BFHchart `part` parameter
#' - biSPCharts `cl_var` -> BFHchart centerline override
#' - biSPCharts `freeze_var` -> BFHchart `freeze` parameter
#' - Scale: biSPCharts percentages (0-100) -> BFHchart decimals (0-1) if needed
#'
#' @param data data.frame. Cleaned input data (post-validation).
#' @param x_var character. X-axis column name.
#' @param y_var character. Y-axis column name.
#' @param chart_type character. qicharts2-style chart code (lowercase).
#' @param n_var character. Denominator column name (optional).
#' @param cl_var character. Centerline override column (optional).
#' @param freeze_var character. Freeze indicator column (optional).
#' @param part_var character. Phase grouping column (optional).
#' @param notes_column character. Name of notes/comment column in data. Will be
#'   mapped to BFHcharts `notes` parameter as character vector. Default NULL.
#' @param target_value numeric. Target value in biSPCharts scale (optional).
#' @param centerline_value numeric. Custom centerline in biSPCharts scale (optional).
#' @param ... Additional parameters to pass through to BFHchart.
#'
#' @return list. Named list of BFHchart-compatible parameters ready for
#'   `do.call(BFHcharts::bfh_qic, bfh_params)`. Structure:
#'   \describe{
#'     \item{data}{data.frame with `.original_row_id` column}
#'     \item{x}{Bare column name (NSE) for BFHchart}
#'     \item{y}{Bare column name (NSE) for BFHchart}
#'     \item{n}{Bare column name (NSE) or NULL}
#'     \item{chart_type}{Chart type string (BFHchart format)}
#'     \item{freeze}{Integer position or NULL}
#'     \item{part}{Integer vector or NULL (part boundaries)}
#'     \item{target}{Numeric or NULL (normalized scale)}
#'     \item{multiply}{Numeric multiplier}
#'     \item{...}{Additional passthrough parameters}
#'   }
#'   Returns NULL on validation failure (with error logging).
#' @examples
#' \dontrun{
#' # Basic parameter mapping
#' bfh_params <- map_to_bfh_params(
#'   data = clean_data,
#'   x_var = "month",
#'   y_var = "infections",
#'   chart_type = "run"
#' )
#'
#' # P-chart with scale normalization
#' bfh_params <- map_to_bfh_params(
#'   data = clean_data,
#'   x_var = "date",
#'   y_var = "complications",
#'   n_var = "procedures",
#'   chart_type = "p",
#'   target_value = 75 # Will be normalized to 0.75
#' )
#'
#' # Multi-phase with freeze
#' bfh_params <- map_to_bfh_params(
#'   data = clean_data,
#'   x_var = "week",
#'   y_var = "defects",
#'   chart_type = "i",
#'   freeze_var = "baseline",
#'   part_var = "phase"
#' )
#' }
#'
#' @seealso
#' \code{\link{compute_spc_results_bfh}} for facade interface
#' \code{\link{call_bfh_chart}} for BFHchart invocation
#' @keywords internal
#' @noRd
map_to_bfh_params <- function(
  data,
  x_var,
  y_var,
  chart_type,
  n_var = NULL,
  cl_var = NULL,
  freeze_var = NULL,
  part_var = NULL,
  notes_column = NULL,
  target_value = NULL,
  centerline_value = NULL,
  ...
) {
  # 0. Inject .original_row_id FOER kollisionscheck og sanitization.
  # .original_row_id er ren ASCII (ingen danske tegn, ingen specialtegn) og
  # kan ikke foraarsage kollision. Injection her sikrer at sanitized_col_names
  # og names(data) har samme laengde inde i safe_operation (#422).
  if (!".original_row_id" %in% names(data)) {
    data$.original_row_id <- seq_len(nrow(data))
  }

  # Hjaelpefunktion: konverter kolonnenavn til ASCII-sikkert navn (BFHcharts-krav).
  # Defineret paa funktions-niveau (foer safe_operation) saa kollisionscheck kan
  # kaste spc_input_error direkte uden at blive fanget af safe_operation (#422).
  sanitize_column_name <- function(name) {
    # Replace Danish characters with ASCII equivalents
    name <- gsub("\u00e6", "ae", name, ignore.case = TRUE)
    name <- gsub("\u00f8", "oe", name, ignore.case = TRUE)
    name <- gsub("\u00e5", "aa", name, ignore.case = TRUE)
    # Remove any remaining non-ASCII characters
    name <- iconv(name, to = "ASCII//TRANSLIT")
    # Remove spaces and special chars (keep only alphanumeric and underscore)
    name <- gsub("[^A-Za-z0-9_]", "_", name)
    return(name)
  }

  # Kollisionscheck: to distinkte kolonner maa ikke kollidere efter sanitization.
  # Placeret FOER safe_operation saa spc_input_error propagerer til kalder (#422).
  # Silent failure her giver forkert plot uden fejlbesked til brugeren.
  sanitized_col_names <- sapply(names(data), sanitize_column_name, USE.NAMES = FALSE)
  if (anyDuplicated(sanitized_col_names)) {
    duplicated_pairs <- names(data)[sanitized_col_names %in% sanitized_col_names[duplicated(sanitized_col_names)]]
    spc_abort(
      paste0(
        "Kolonnenavne kolliderer efter sanitization: ",
        paste(duplicated_pairs, collapse = ", "),
        ". Omdoeb kolonnerne i kilde-data."
      ),
      class = "spc_input_error"
    )
  }

  safe_operation(
    operation_name = "BFHchart parameter mapping",
    code = {
      # 1. .original_row_id allerede injiceret foer safe_operation (se trin 0 ovenfor).
      # DEBUG: Check x column type BEFORE sanitization
      log_debug(
        paste(
          "BEFORE sanitization - x column type:",
          "x(", x_var, ")=", class(data[[x_var]])[1]
        ),
        .context = "BFH_SERVICE"
      )

      # 1b. CRITICAL FIX: BFHcharts rejects Danish characters (aeoeaa) in column names
      # Temporarily sanitize column names to ASCII-safe versions
      # Strategy: Create mapping of original -> sanitized names, rename data, use sanitized in params
      # sanitized_col_names beregnet foer safe_operation (kollisionscheck) -- genbrug her.

      # Create column name mapping (original -> sanitized)
      col_mapping <- setNames(sanitized_col_names, names(data))

      # Store original names for later reversal
      original_names <- names(data)

      # DEBUG: Check col_mapping structure before renaming
      log_debug(
        paste(
          "col_mapping check:",
          "class =", class(col_mapping),
          "| length =", length(col_mapping),
          "| example:", if (length(col_mapping) > 0) paste(names(col_mapping)[1], "\u2192", col_mapping[1]) else "empty"
        ),
        .context = "BFH_SERVICE"
      )

      # Rename data columns to sanitized names
      # CRITICAL: Use unname() to get just the values, not named character vector
      names(data) <- unname(col_mapping[names(data)])

      # Map biSPCharts variable names to sanitized versions
      x_var_sanitized <- col_mapping[x_var]
      y_var_sanitized <- col_mapping[y_var]
      n_var_sanitized <- if (!is.null(n_var)) col_mapping[n_var] else NULL

      log_debug(
        paste(
          "Column name sanitization:",
          if (x_var != x_var_sanitized) paste(x_var, "\u2192", x_var_sanitized) else "none",
          if (y_var != y_var_sanitized) paste(y_var, "\u2192", y_var_sanitized) else "none"
        ),
        .context = "BFH_SERVICE"
      )

      # DEBUG: Verify data types after column renaming
      log_debug(
        paste(
          "After column renaming - Data types:",
          "x(", x_var_sanitized, ")=", class(data[[x_var_sanitized]])[1],
          ", y(", y_var_sanitized, ")=", class(data[[y_var_sanitized]])[1],
          if (!is.null(n_var_sanitized)) paste0(", n(", n_var_sanitized, ")=", class(data[[n_var_sanitized]])[1]) else "",
          " | First 3 y values:", paste(head(data[[y_var_sanitized]], 3), collapse = ", ")
        ),
        .context = "BFH_SERVICE"
      )

      # 2. Build base parameters (using NSE - bare column names with SANITIZED names)
      params <- list(
        data = data,
        x = rlang::sym(x_var_sanitized),
        y = rlang::sym(y_var_sanitized),
        chart_type = chart_type,
        .column_mapping = col_mapping, # Store mapping for potential reversal
        .original_names = original_names
      )

      # 3. Add denominator if provided
      if (!is.null(n_var_sanitized)) {
        params$n <- rlang::sym(n_var_sanitized)
      }

      # 4. Add freeze parameter if provided
      # NOTE: freeze_var and part_var still reference ORIGINAL names, need to look up in sanitized data
      freeze_var_sanitized <- if (!is.null(freeze_var)) col_mapping[freeze_var] else NULL
      part_var_sanitized <- if (!is.null(part_var)) col_mapping[part_var] else NULL

      if (!is.null(freeze_var_sanitized) && freeze_var_sanitized %in% names(data)) {
        # Find first TRUE value in freeze column (using SANITIZED name)
        freeze_col <- data[[freeze_var_sanitized]]
        # Convert to logical vector, handling both TRUE/FALSE and 0/1 values
        logical_vec <- suppressWarnings(as.logical(freeze_col))
        numeric_vec <- suppressWarnings(as.numeric(freeze_col))
        # Combine: TRUE if either logical TRUE or numeric 1
        is_freeze <- (!is.na(logical_vec) & logical_vec == TRUE) |
          (!is.na(numeric_vec) & numeric_vec == 1)
        freeze_positions <- which(is_freeze)
        if (length(freeze_positions) > 0) {
          params$freeze <- freeze_positions[1]
          log_debug(
            paste("Freeze position set to:", freeze_positions[1]),
            .context = "BFH_SERVICE"
          )
        }
      }

      # 5. Add part parameter if provided
      if (!is.null(part_var_sanitized) && part_var_sanitized %in% names(data)) {
        # BUG FIX: Each TRUE in Skift column marks a part boundary directly
        # Previous implementation used diff() which found BOTH TRUE->FALSE and FALSE->TRUE changes,
        # resulting in double boundaries (e.g., marking row 13 gave boundaries at 12 AND 13)
        part_col <- data[[part_var_sanitized]]

        # Convert to logical vector, handling both TRUE/FALSE and 0/1 values
        logical_vec <- suppressWarnings(as.logical(part_col))
        numeric_vec <- suppressWarnings(as.numeric(part_col))

        # Combine: TRUE if either logical TRUE or numeric 1
        is_part_boundary <- (!is.na(logical_vec) & logical_vec == TRUE) |
          (!is.na(numeric_vec) & numeric_vec == 1)

        part_positions <- which(is_part_boundary)
        if (length(part_positions) > 0) {
          params$part <- part_positions
          log_debug(
            paste("Part boundaries:", paste(part_positions, collapse = ", ")),
            .context = "BFH_SERVICE"
          )
        }
      }

      # 6. Add target value if provided (normalized if needed)
      if (!is.null(target_value)) {
        params$target_value <- normalize_scale_for_bfh(
          value = target_value,
          chart_type = chart_type,
          param_name = "target"
        )
      }

      # 7. Add centerline value if provided (normalized if needed)
      # BFHcharts parameter name: cl (not centerline_value)
      if (!is.null(centerline_value)) {
        params$cl <- normalize_scale_for_bfh(
          value = centerline_value,
          chart_type = chart_type,
          param_name = "centerline"
        )
      }

      # 7b. Add notes column if provided (map kommentarer -> notes)
      # BFHcharts expects a character vector for the notes parameter
      # IMPORTANT: notes_column refers to ORIGINAL column name (before sanitization)

      # ROBUST COLUMN NAME MATCHING: Case-insensitive with fallback
      notes_column_sanitized <- NULL
      if (!is.null(notes_column)) {
        # Try exact match first
        if (notes_column %in% names(col_mapping)) {
          notes_column_sanitized <- col_mapping[notes_column]
        } else {
          # Fallback: Case-insensitive match
          original_names <- names(col_mapping)
          match_idx <- which(tolower(original_names) == tolower(notes_column))
          if (length(match_idx) > 0) {
            notes_column_sanitized <- col_mapping[original_names[match_idx[1]]]
            log_debug(
              paste(
                "[NOTES_TRACE] Case-insensitive match:",
                notes_column, "\u2192", original_names[match_idx[1]]
              ),
              .context = "BFH_SERVICE"
            )
          } else {
            log_warn(
              paste(
                "[NOTES_TRACE] Column not found in data:",
                notes_column, "| Available columns:",
                paste(head(original_names, 5), collapse = ", ")
              ),
              .context = "BFH_SERVICE"
            )
          }
        }
      }

      # DEBUG: Log column name mapping for notes
      log_debug(
        paste(
          "[NOTES_TRACE] Original notes_column:", notes_column,
          "| Sanitized:", notes_column_sanitized,
          "| Exists in data:", !is.null(notes_column_sanitized) && notes_column_sanitized %in% names(data)
        ),
        .context = "BFH_SERVICE"
      )

      if (!is.null(notes_column_sanitized) && notes_column_sanitized %in% names(data)) {
        # Extract notes data and ensure it's character type
        notes_data <- data[[notes_column_sanitized]]

        # Convert to character vector (handles factor, numeric, etc.)
        notes_char <- as.character(notes_data)

        # Replace NA with empty strings (BFHcharts may not handle NA)
        notes_char[is.na(notes_char)] <- ""

        # Kun send notes hvis der faktisk er ikke-tomme noter
        # Tomme notes-vektorer kan foraarsage langsom label placement i BFHcharts
        if (any(nzchar(notes_char))) {
          params$notes <- notes_char
        }

        log_debug(
          paste(
            "[NOTES_TRACE] Notes vector created.",
            "Non-empty notes:", sum(nzchar(notes_char)),
            "| Total length:", length(notes_char),
            "| First value:", if (length(notes_char) > 0) substring(notes_char[1], 1, 20) else "NONE"
          ),
          .context = "BFH_SERVICE"
        )
      }

      # 8. Pass through additional parameters
      extra_params <- list(...)
      if (length(extra_params) > 0) {
        if ("chart_title" %in% names(extra_params)) {
          extra_params$chart_title <- resolve_bfh_chart_title(extra_params$chart_title)
        }
        params <- c(params, extra_params)
      }

      log_debug(
        paste(
          "BFHchart parameters mapped:",
          "chart_type =", chart_type,
          ", has_denominator =", !is.null(n_var),
          ", has_freeze =", !is.null(params$freeze),
          ", has_part =", !is.null(params$part)
        ),
        .context = "BFH_SERVICE"
      )

      # NOTE: Don't use return() inside safe_operation code blocks!
      params
    },
    fallback = NULL,
    error_type = "parameter_mapping"
  )
}

normalize_scale_for_bfh <- function(value, chart_type, param_name = "value") {
  safe_operation(
    operation_name = "Scale normalization",
    code = {
      # Chart types that use percentage scale (0-100) in biSPCharts
      # but may expect decimal scale (0-1) in BFHchart.
      # U/U'-charts er rate-charts (hændelser pr. nævnerenhed), ikke proportioner --
      # deres target-/centerlinje-værdier må IKKE divideres med 100.
      percentage_charts <- c("p", "pp")

      # NOTE: Don't use return() inside safe_operation code blocks (#446)
      # \u2014 return() exits the wrapper, not normalize_scale_for_bfh, og
      # safe_operation falder gennem til fallback. Brug result-variable.
      if (chart_type %in% percentage_charts && value > 1) {
        result <- value / 100
        log_debug(
          paste(
            "Normalized", param_name, "for", chart_type, "chart:",
            value, "\u2192", result
          ),
          .context = "BFH_SERVICE"
        )
      } else {
        result <- value
      }
      result
    },
    fallback = value,
    error_type = "scale_normalization"
  )
}
