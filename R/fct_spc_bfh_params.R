# fct_spc_bfh_params.R
# BFHchart Parameter Transformation
#
# Mapper biSPCharts parametre til BFHcharts API-format.
# Haandterer:
# - Kolonne-navnemapping (sanitisering af danske karakterer for BFHcharts)
# - Skalering og normalisering (procent til decimal)
# - Freeze/part position-beregning
# - Notes/comment-integrering

ascii_column_name_for_bfh <- function(name) {
  name <- gsub("\u00e6", "ae", name, ignore.case = TRUE)
  name <- gsub("\u00f8", "oe", name, ignore.case = TRUE)
  name <- gsub("\u00e5", "aa", name, ignore.case = TRUE)
  name <- iconv(name, to = "ASCII//TRANSLIT")
  if (is.na(name)) name <- ""
  gsub("[^A-Za-z0-9_]", "_", name)
}

build_bfh_column_mapping <- function(data) {
  sanitized_col_names <- vapply(names(data), ascii_column_name_for_bfh, character(1), USE.NAMES = FALSE)
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

  setNames(sanitized_col_names, names(data))
}

extract_freeze_position <- function(data, freeze_var) {
  if (is.null(freeze_var) || !freeze_var %in% names(data)) {
    return(NULL)
  }

  freeze_col <- data[[freeze_var]]
  logical_vec <- suppressWarnings(as.logical(freeze_col))
  numeric_vec <- suppressWarnings(as.numeric(freeze_col))
  is_freeze <- (!is.na(logical_vec) & logical_vec) |
    (!is.na(numeric_vec) & numeric_vec == 1)

  freeze_positions <- which(is_freeze)
  if (length(freeze_positions) == 0) NULL else freeze_positions[1]
}

extract_part_positions <- function(data, part_var) {
  if (is.null(part_var) || !part_var %in% names(data)) {
    return(NULL)
  }

  part_col <- data[[part_var]]
  logical_vec <- suppressWarnings(as.logical(part_col))
  numeric_vec <- suppressWarnings(as.numeric(part_col))
  is_part_boundary <- (!is.na(logical_vec) & logical_vec) |
    (!is.na(numeric_vec) & numeric_vec == 1)

  part_positions <- which(is_part_boundary)
  if (length(part_positions) == 0) NULL else part_positions
}

resolve_notes_column <- function(notes_column, col_mapping) {
  if (is.null(notes_column)) {
    return(NULL)
  }

  if (notes_column %in% names(col_mapping)) {
    return(col_mapping[[notes_column]])
  }

  original_names <- names(col_mapping)
  match_idx <- which(tolower(original_names) == tolower(notes_column))
  if (length(match_idx) > 0) {
    return(col_mapping[[original_names[match_idx[1]]]])
  }

  log_warn(
    paste(
      "Notes column not found in data:",
      notes_column, "| Available columns:",
      paste(head(original_names, 5), collapse = ", ")
    ),
    .context = "BFH_SERVICE"
  )
  NULL
}

extract_notes_vector <- function(data, notes_column) {
  if (is.null(notes_column) || !notes_column %in% names(data)) {
    return(NULL)
  }

  notes_char <- as.character(data[[notes_column]])
  notes_char[is.na(notes_char)] <- ""
  if (any(nzchar(notes_char))) notes_char else NULL
}

build_bfh_params_core <- function(
  data,
  col_mapping,
  x_var,
  y_var,
  n_var,
  freeze_var,
  part_var,
  notes_column,
  target_value,
  centerline_value,
  chart_type,
  extra_params
) {
  original_names <- names(data)
  names(data) <- unname(col_mapping[names(data)])

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

  params <- list(
    data = data,
    x = rlang::sym(x_var_sanitized),
    y = rlang::sym(y_var_sanitized),
    chart_type = chart_type,
    .column_mapping = col_mapping,
    .original_names = original_names
  )
  if (!is.null(n_var_sanitized)) {
    params$n <- rlang::sym(n_var_sanitized)
  }

  freeze_var_sanitized <- if (!is.null(freeze_var)) col_mapping[freeze_var] else NULL
  part_var_sanitized <- if (!is.null(part_var)) col_mapping[part_var] else NULL
  freeze_position <- extract_freeze_position(data, freeze_var_sanitized)
  part_positions <- extract_part_positions(data, part_var_sanitized)

  if (!is.null(freeze_position)) {
    params$freeze <- freeze_position
    log_debug(paste("Freeze position set to:", freeze_position), .context = "BFH_SERVICE")
  }
  if (!is.null(part_positions)) {
    params$part <- part_positions
    log_debug(paste("Part boundaries:", paste(part_positions, collapse = ", ")), .context = "BFH_SERVICE")
  }

  if (!is.null(target_value)) {
    params$target_value <- normalize_scale_for_bfh(target_value, chart_type, "target")
  }
  if (!is.null(centerline_value)) {
    params$cl <- normalize_scale_for_bfh(centerline_value, chart_type, "centerline")
  }

  notes_column_sanitized <- resolve_notes_column(notes_column, col_mapping)
  notes <- extract_notes_vector(data, notes_column_sanitized)
  if (!is.null(notes)) {
    params$notes <- notes
  }

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
  params
}

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

  col_mapping <- build_bfh_column_mapping(data)
  extra_params <- list(...)

  safe_operation(
    operation_name = "BFHchart parameter mapping",
    code = {
      # 1. .original_row_id allerede injiceret foer safe_operation (se trin 0 ovenfor).
      # 1b. WORKAROUND: BFHcharts rejects Danish characters (æøå) i column
      # names — biSPCharts ASCII-translit'er navnene før kald + rev-mapper
      # output for at bevare brugerens originale navne i UI.
      # FOLLOW-UP: BFHcharts#327 — fjern workaround når upstream leverer
      # native Danish-character-support i column-name-validator.
      build_bfh_params_core(
        data = data,
        col_mapping = col_mapping,
        x_var = x_var,
        y_var = y_var,
        n_var = n_var,
        freeze_var = freeze_var,
        part_var = part_var,
        notes_column = notes_column,
        target_value = target_value,
        centerline_value = centerline_value,
        chart_type = chart_type,
        extra_params = extra_params
      )
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
