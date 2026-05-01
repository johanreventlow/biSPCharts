# ==============================================================================
# CONFIG_SPC_CONFIG.R
# ==============================================================================
# FORMAaL: SPC-specifikke konstanter for data validation, column detection og
#         visualization settings. Centraliserer alle Statistical Process Control
#         defaults og thresholds.
#
# ANVENDES AF:
#   - Data validation logic (MIN_SPC_ROWS, MAX_MISSING_PERCENT)
#   - Auto-detection algorithms (SPC_COLUMN_NAMES, MIN_NUMERIC_PERCENT)
#   - Plot rendering (SPC_COLORS, SPC_LINE_TYPES, SPC_ALPHA_VALUES)
#   - Y-axis formatting (Y_AXIS_UNITS_DA)
#
# RELATERET:
#   - config_chart_types.R - Chart type definitions
#   - utils_auto_detect.R - Column detection logic
#   - fct_spc_plot_generation.R - Visualization
#   - See: docs/CONFIGURATION.md for complete guide
# ==============================================================================

# DATA VALIDATION CONSTANTS ====================================================

#' Minimum antal raekker for SPC analyse
#' @keywords internal
MIN_SPC_ROWS <- 10

#' Anbefalet minimum antal punkter for SPC
#' @keywords internal
RECOMMENDED_SPC_POINTS <- 20

#' Maximum missing values procent foer advarsel
#' @keywords internal
MAX_MISSING_PERCENT <- 20

#' Minimum procent numeriske vaerdier for kolonne detection
#' @keywords internal
MIN_NUMERIC_PERCENT <- 0.8

# SPC DATAPUNKT-GRAENSER (#417) ================================================
# Centraliserede graenser for datapunkt-validering.
# Erstatter tidligere spredte magic numbers (3, 8, 10, 12) i kodebasen.

#' SPC datapunkt-taerskler
#'
#' Samlet liste med alle datapunkt-graenser brugt paa tvaers af SPC-pipelinen.
#'   hard_min       = matematisk minimum for SPC-beregning
#'   warning_short  = under dette niveau er Anhoej-rules upalidelige
#'   recommended    = konventionel SPC best-practice (mindst 15 punkter)
#'
#' @keywords internal
SPC_DATA_THRESHOLDS <- list(
  hard_min      = 3L, # Matematisk minimum: bevar eksisterende checks
  warning_short = 12L, # Anhoej-rules upalidelige under dette antal
  recommended   = 15L # Konventionel SPC best-practice
)

#' Hent SPC hard minimum datapunkter
#' @return Integer. Matematisk minimum for SPC-analyse.
#' @keywords internal
get_spc_hard_min <- function() SPC_DATA_THRESHOLDS$hard_min

#' Hent SPC advarselsgransens for kort serie
#' @return Integer. Antal datapunkter under hvilke Anhoej-rules er upalidelige.
#' @keywords internal
get_spc_warning_threshold <- function() SPC_DATA_THRESHOLDS$warning_short

#' Hent SPC anbefalet minimum datapunkter
#' @return Integer. Anbefalet minimum for palidelig SPC-analyse.
#' @keywords internal
get_spc_recommended_threshold <- function() SPC_DATA_THRESHOLDS$recommended

# SPC CONFIGURATION CONSTANTS ==================================================

#' Standard kolonne navne for SPC analyse
#' @keywords internal
SPC_COLUMN_NAMES <- list(
  x = c("Dato", "Date", "Tid", "Time", "Periode", "Period"),
  y = c("T\u00e6ller", "Count", "V\u00e6rdi", "Value", "Antal", "Number"),
  n = c("N\u00e6vner", "Denominator", "Total", "Sum"),
  cl = c("Centerlinje", "CL", "Center", "M\u00e5lv\u00e6rdi", "Target"),
  freeze = "Frys",
  shift = "Skift",
  comment = "Kommentar"
)

#' Y-aksen enheder for forskellige chart typer
#' Named list mapping Danish display names to English runtime codes.
#' Used by get_unit_label() to convert runtime values back to Danish labels.
#' @keywords internal
Y_AXIS_UNITS_DA <- list(
  "Antal" = "count",
  "Procent (%)" = "percent",
  "Promille (\u2030)" = "permille",
  "Rate pr. 1000" = "rate_1000",
  "Rate pr. 100.000" = "rate_100000",
  "Rate" = "rate",
  "Tid" = "time",
  "Dage" = "days",
  "Timer" = "hours",
  "Gram" = "grams",
  "Kilogram" = "kg",
  "Kroner" = "dkk"
)

#' UI-typer for Y-akse (simpel valg)
#'
#' Tids-enheder er eksplicit adskilt fra Fase 2 af
#' docs/superpowers/specs/2026-04-17-time-yaxis-design.md. Legacy "time"
#' er fjernet fra UI men accepteres stadig af is_time_unit() for
#' bagudkompatibilitet og migration.
#'
#' @keywords internal
Y_AXIS_UI_TYPES_DA <- list(
  "Tal" = "count",
  "Procent (%)" = "percent",
  "Rate" = "rate",
  "Tid (minutter)" = "time_minutes",
  "Tid (timer)" = "time_hours",
  "Tid (dage)" = "time_days"
)

# SPC VISUALIZATION CONSTANTS ===================================================

#' Farve palette for SPC charts
#' @keywords internal
SPC_COLORS <- list(
  # Target linjer
  target_line = "#2E8B57", # SeaGreen for maalvaerdi linjer
  control_line = "#FF6B6B", # Coral for kontrolgraenser

  # Data punkter
  normal_point = "#4A90E2", # Blaa for normale datapunkter
  special_cause = "#FF4444", # Roed for special cause punkter

  # Chart baggrund
  chart_bg = "#FFFFFF", # Hvid baggrund
  grid_line = "#E8E8E8", # Lys graa for grid

  # UI elementer
  success = "#28A745", # Groen for success states
  warning = "#FFC107", # Gul for warnings
  error = "#DC3545", # Roed for errors
  info = "#17A2B8" # Blaa for info
)

#' Alpha vaerdier for gennemsigtighed
#' @keywords internal
SPC_ALPHA_VALUES <- list(
  target_line = 0.8,
  control_line = 0.7,
  data_point = 0.9,
  background = 0.1,
  highlight = 1.0
)

#' Linje typer for SPC charts
#' @keywords internal
SPC_LINE_TYPES <- list(
  solid = "solid",
  dashed = "dashed",
  dotted = "dotted",
  dot_dash = "dotdash"
)

#' Standard linje bredder
#' @keywords internal
SPC_LINE_WIDTHS <- list(
  thin = 0.8,
  normal = 1.0,
  thick = 1.2,
  extra_thick = 1.5
)

# SPC COMMENT PROCESSING CONSTANTS =============================================

#' Kommentar behandling konfiguration
#' M3: Centraliseret magic numbers for kommentar laengdebegraensninger
#' @keywords internal
SPC_COMMENT_CONFIG <- list(
  # Maximum laengde foer sanitization trunkering
  max_length = 100,

  # Display laengde foer afkortning med "..."
  display_length = 40,

  # Afkortning prefix laengde
  truncate_length = 37
)
