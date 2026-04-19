# utils_y_axis_formatting.R
# Y-Axis Formatting Utilities for SPC Plots
#
# FASE 4 Task 4.2: Y-axis formatting extraction (Week 11-12)
# Consolidates Y-axis formatting logic from fct_spc_plot_generation.R
# Priority 1: LOW RISK, HIGH VALUE refactoring
#
# Benefits:
# - Reduces generateSPCPlot() by ~60 lines
# - DRY principle: Consolidates duplicated time formatting (~30 lines)
# - Easier to unit test formatting logic independently
# - Potential reuse in other plotting functions

# Y-AXIS FORMATTING MAIN FUNCTION ============================================

#' Apply Y-Axis Formatting to SPC Plot
#'
#' Applies unit-specific Y-axis formatting to an SPC ggplot object.
#' This function consolidates all Y-axis formatting logic for different
#' unit types (percent, count, rate, time).
#'
#' @param plot ggplot object to which formatting will be applied
#' @param y_axis_unit Character string indicating unit type:
#'   - "percent": Percentage values (0-100%)
#'   - "count": Count values with intelligent K/M/mia. notation
#'   - "rate": Rate values with decimal formatting
#'   - "time": Time values (minutes/hours/days)
#' @param qic_data Data frame with qic data (used for time range calculation)
#'
#' @return Modified ggplot object with appropriate y-axis scale
#'
#' @details
#' This function replaces inline Y-axis formatting from generateSPCPlot()
#' (lines 1159-1285). It provides:
#' - Consistent expansion (mult = c(.25, .25)) across all unit types
#' - Danish number formatting (decimal.mark = ",", big.mark = ".")
#' - Intelligent scaling (K for thousands, M for millions, etc.)
#' - Context-aware time formatting (minutes/hours/days)
#'
#' @examples
#' \dontrun{
#' plot <- ggplot(qic_data, aes(x = x, y = y)) +
#'   geom_point()
#' plot <- apply_y_axis_formatting(plot, "percent", qic_data)
#' }
#'
#' @keywords internal
apply_y_axis_formatting <- function(plot, y_axis_unit = "count", qic_data = NULL) {
  # Validate inputs
  if (!inherits(plot, "ggplot")) {
    log_warn("apply_y_axis_formatting: plot is not a ggplot object", .context = "Y_AXIS_FORMAT")
    return(plot)
  }

  if (is.null(y_axis_unit) || !is.character(y_axis_unit)) {
    log_warn("apply_y_axis_formatting: invalid y_axis_unit, defaulting to 'count'", .context = "Y_AXIS_FORMAT")
    y_axis_unit <- "count"
  }

  # Apply unit-specific formatting
  if (y_axis_unit == "percent") {
    return(plot + format_y_axis_percent())
  } else if (y_axis_unit == "count") {
    return(plot + format_y_axis_count())
  } else if (y_axis_unit == "rate") {
    return(plot + format_y_axis_rate())
  } else if (is_time_unit(y_axis_unit)) {
    # Dækker legacy "time" og nye time_minutes/time_hours/time_days.
    # Kandidat-intervaller filtreres per input-enhed for "naturlig"
    # tick-afstand (fx time_days bruger kun >= 12t intervaller).
    return(plot + format_y_axis_time(qic_data, input_unit = y_axis_unit))
  }

  # Default: no special formatting (use ggplot2 defaults)
  return(plot)
}

# UNIT-SPECIFIC FORMATTING FUNCTIONS =========================================

#' Format Y-Axis for Percentage Data
#'
#' @return ggplot2 scale_y_continuous layer for percentage formatting
#' @keywords internal
format_y_axis_percent <- function() {
  # Percent formatting with % suffix
  # Data from qic is in decimal form (0.9 for 90%), scale = 100 converts to percentage
  # Danish formatting: decimal.mark = "," (85,5 %), big.mark = "." (not used for %)
  ggplot2::scale_y_continuous(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = scales::label_percent()
  )
}

#' Format Y-Axis for Count Data with Intelligent K/M Notation
#'
#' @return ggplot2 scale_y_continuous layer for count formatting
#' @keywords internal
format_y_axis_count <- function() {
  # Count formatting with intelligent K/M notation
  # K starts at 1.000+ for correct notation (K = 1.000, not 10.000)
  # Trade-off: loses thousand separator for 1.000-9.999 range
  # Only shows decimals if present (50K vs 50,5K)

  ggplot2::scale_y_continuous(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = function(x) {
      # DEFENSIVE INPUT VALIDATION: Handle waiver objects and non-numeric inputs
      # ggplot2 passes waiver() objects during scale training, which must be returned unchanged
      # This prevents purrr_error_indexed when processing non-numeric scale inputs
      if (inherits(x, "waiver")) {
        return(x)
      }

      # Coerce to numeric if not already (defensive against character/factor inputs)
      if (!is.numeric(x)) {
        x_coerced <- suppressWarnings(as.numeric(as.character(x)))
        if (all(is.na(x_coerced))) {
          # If coercion fails completely, return original input unchanged
          return(x)
        }
        x <- x_coerced
      }

      formatted <- character(length(x))

      for (idx in seq_along(x)) {
        value <- x[[idx]]

        if (is.na(value)) {
          formatted[[idx]] <- NA_character_
          next
        }

        abs_value <- abs(value)

        formatted[[idx]] <- if (abs_value >= 1e9) {
          format_scaled_number(value, 1e9, " mia.")
        } else if (abs_value >= 1e6) {
          format_scaled_number(value, 1e6, "M")
        } else if (abs_value >= 1e3) {
          format_scaled_number(value, 1e3, "K")
        } else {
          format_unscaled_number(value)
        }
      }

      formatted
    }
  )
}

#' Format Y-Axis for Rate Data
#'
#' @return ggplot2 scale_y_continuous layer for rate formatting
#' @keywords internal
format_y_axis_rate <- function() {
  # Rate formatting (only shows decimals if present)
  ggplot2::scale_y_continuous(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = function(x) {
      # DEFENSIVE INPUT VALIDATION: Handle waiver objects
      if (inherits(x, "waiver")) {
        return(x)
      }

      # Coerce to numeric if needed
      if (!is.numeric(x)) {
        x <- suppressWarnings(as.numeric(as.character(x)))
      }

      ifelse(x == round(x),
        format(round(x), decimal.mark = ","),
        format(x, decimal.mark = ",", nsmall = 1)
      )
    }
  )
}

#' Format Y-Axis for Time Data (Composite Format: "1t 30m", "2d 4t")
#'
#' Uses tids-naturlige tick-breaks (time_breaks) og komposit label-format
#' (format_time_composite). Input antages at vaere i minutter (kanonisk
#' intern enhed).
#'
#' @param qic_data Data frame with qic data containing y column (time values in minutes)
#' @param input_unit character eller NULL. En af 'time_minutes',
#'   'time_hours', 'time_days' (eller legacy 'time'). Bruges til at
#'   filtrere kandidat-intervaller i time_breaks(). NULL = alle kandidater.
#'
#' @return ggplot2 scale_y_continuous layer for time formatting
#' @keywords internal
format_y_axis_time <- function(qic_data, input_unit = NULL) {
  if (is.null(qic_data) || !"y" %in% names(qic_data)) {
    log_warn(
      "format_y_axis_time: missing qic_data or y column, using default formatting",
      .context = "Y_AXIS_FORMAT"
    )
    return(ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(.25, .25))))
  }

  y_values <- qic_data$y
  breaks <- time_breaks(y_values, input_unit = input_unit)

  ggplot2::scale_y_continuous(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    breaks = breaks,
    labels = function(x) {
      if (inherits(x, "waiver")) {
        return(x)
      }
      if (!is.numeric(x)) {
        x <- suppressWarnings(as.numeric(as.character(x)))
      }
      format_time_composite(x)
    }
  )
}

# HELPER FUNCTIONS ===========================================================

#' Format Scaled Number with Suffix (K, M, mia.)
#'
#' Helper function for count formatting with intelligent scaling.
#' Only shows decimals if the scaled value has decimal places.
#'
#' @param val Numeric value to format
#' @param scale Scale factor (1e3 for K, 1e6 for M, 1e9 for mia.)
#' @param suffix Suffix string ("K", "M", " mia.")
#'
#' @return Formatted string with Danish decimal notation
#' @keywords internal
format_scaled_number <- function(val, scale, suffix) {
  # Bemærk: formatC med format="f" giver round-half-up (2.75 → 2,8) som
  # matcher klinisk læsevaner. R's base round() bruger banker's rounding
  # (2.75 → 2.8 faktisk men 2.45 → 2.4). Se også #236 for samme mønster
  # i format_y_value().
  scaled <- val / scale
  if (scaled == round(scaled)) {
    paste0(round(scaled), suffix)
  } else {
    paste0(formatC(scaled, digits = 1, format = "f", decimal.mark = ","), suffix)
  }
}

#' Format Unscaled Number with Danish Notation
#'
#' Helper function for count formatting without scaling.
#' Uses Danish thousand separator (.) and decimal mark (,).
#'
#' @param val Numeric value to format
#'
#' @return Formatted string with Danish number notation
#' @keywords internal
format_unscaled_number <- function(val) {
  # Bemærk: formatC undgår scientific notation leak (format() returnerer
  # fx "1e+05" for 100000 med big.mark="."). formatC med format="d"/"f"
  # giver deterministisk dansk formatering. Eksplicit decimal.mark="," er
  # nødvendig selv for heltal for at undgå R's advarsel om big.mark ==
  # decimal.mark. Se også #236/#242.
  if (val == round(val)) {
    formatC(val, format = "d", big.mark = ".", decimal.mark = ",")
  } else {
    formatC(val, digits = 1, format = "f", big.mark = ".", decimal.mark = ",")
  }
}
