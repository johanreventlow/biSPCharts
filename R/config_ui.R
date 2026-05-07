# ==============================================================================
# CONFIG_UI.R
# ==============================================================================
# FORMAaL: UI layout constants, CSS styles og responsive font scaling configuration.
#         Centraliserer alle UI-relaterede dimensioner og styling for konsistent
#         appearance paa tvaers af komponenter.
#
# ANVENDES AF:
#   - UI rendering (column widths, heights, styles)
#   - Plot generation (responsive font scaling)
#   - CSS styling (UI_STYLES genbrugelige patterns)
#   - Responsive design (FONT_SCALING_CONFIG)
#
# RELATERET:
#   - BFHcharts - Label sizing for plots
#   - Plot rendering functions - Font calculation
#   - See: docs/CONFIGURATION.md for complete guide
# ==============================================================================

# UI LAYOUT CONSTANTS ==========================================================

#' Standard kolonne bredder for UI
#'
#' Praedefinerede kolonne bredde kombinationer til bslib layout systemer.
#' @format Named list med numeriske vektorer for kolonne bredder
#' @keywords internal
UI_COLUMN_WIDTHS <- list(
  quarter = c(6, 6, 6, 6),
  half = c(6, 6),
  thirds = c(4, 4, 4),
  sidebar = c(3, 9)
)

#' Standard hoejder for UI komponenter
#'
#' CSS hoejde vaerdier til konsistent UI layout paa tvaers af komponenter.
#' @format Named list med CSS hoejde strings
#' @keywords internal
UI_HEIGHTS <- list(
  logo = "40px",
  modal_content = "300px",
  chart_container = "calc(50vh - 60px)",
  table_max = "200px",
  sidebar_min = "130px"
)

#' CSS styles constants
#'
#' Genbrugelige CSS style strings til konsistent styling.
#' @format Named list med CSS style strings
#' @keywords internal
UI_STYLES <- list(
  flex_column = "display: flex; flex-direction: column; flex: 1 1 auto; min-height: 0;",
  scroll_auto = "max-height: 300px; overflow-y: auto;",
  full_width = "width: 100%;",
  right_align = "text-align: right;",
  margin_right = "margin-right: 10px;",
  position_absolute_right = "position: absolute; right: 20px; top: 20px; font-weight: bold;"
)

#' Standard UI input widths
#' @keywords internal
UI_INPUT_WIDTHS <- list(
  full = "100%",
  half = "50%",
  quarter = "25%",
  three_quarter = "75%",
  auto = "auto"
)

#' Layout proportions for consistent UI
#' @keywords internal
UI_LAYOUT_PROPORTIONS <- list(
  half = 1 / 2,
  third = 1 / 3,
  quarter = 1 / 4,
  two_thirds = 2 / 3,
  three_quarters = 3 / 4
)

# FONT SCALING CONFIGURATION ===================================================

#' Responsive font scaling configuration
#'
#' Styrer hvordan base_size skaleres baseret paa viewport dimensioner.
#'
#' @details
#' base_size beregnes som: max(min_size, min(max_size, viewport_diagonal / divisor))
#' hvor viewport_diagonal = sqrt(width_px * height_px)
#'
#' GEOMETRIC MEAN APPROACH: Geometric mean (sqrt(width x height)) giver balanced
#' scaling baseret paa baade bredde og hoejde. Dette sikrer at fonts skalerer
#' intuitivt med den samlede plotstoerrelse, ikke kun en dimension.
#'
#' VIGTIG: Shiny's renderPlot() multiplicerer automatisk res med pixelratio,
#' saa vi skal IKKE dividere base_size med pixelratio. Dette sikrer konsistent
#' visuel stoerrelse paa tvaers af standard og Retina displays.
#'
#' - divisor: Lavere vaerdi = stoerre fonts (40 = ~40% stoerre end 56)
#' - min_size: Minimum font size uanset viewport
#' - max_size: Maximum font size selv paa store skaerme
#'
#' Eksempler ved divisor = 56:
#' - 700x500px viewport: diagonal = 836px -> base_size = 14.9pt
#' - 1000x800px viewport: diagonal = 894px -> base_size = 16.0pt
#' - 1400x900px viewport: diagonal = 1668px -> base_size = 29.8pt
#'
#' @format Named list med scaling parametre
#' @keywords internal
FONT_SCALING_CONFIG <- list(
  divisor = 42, # Viewport diagonal divisor (lower = larger fonts)
  min_size = 8, # Minimum base_size i points
  max_size = 64 # Maximum base_size i points
)

# VIEWPORT DEFAULTS ============================================================

#' Viewport default dimensioner for plot rendering
#'
#' Standard viewport stoerrelse og DPI settings til konsistent plot rendering.
#' Disse vaerdier bruges som fallback naar viewport dimensioner ikke er tilgaengelige.
#'
#' @details
#' - width/height: Default pixels for plot rendering
#' - dpi: Industry standard 96 DPI for web graphics
#'
#' M10: Centraliseret fra hardcoded magic numbers i mod_spc_chart_server.R
#'
#' @format Named list med viewport parametre
#' @keywords internal
VIEWPORT_DEFAULTS <- list(
  width = 800, # Default width i pixels
  height = 600, # Default height i pixels
  dpi = 96 # Standard DPI for web graphics
)

#' Kliniske enhedstype-labels til UI-selector
#'
#' Bruges i `current_unit()` til at mappe korte enhedskoder til
#' fulde danske navne. Tilfoej nye enhedstyper her.
#'
#' @keywords internal
UNIT_TYPE_LABELS <- list(
  "med"  = "Medicinsk Afdeling",
  "kir"  = "Kirurgisk Afdeling",
  "icu"  = "Intensiv Afdeling",
  "amb"  = "Ambulatorie",
  "akut" = "Akutmodtagelse",
  "paed" = "P\u00e6diatrisk Afdeling",
  "gyn"  = "Gyn\u00e6kologi/Obstetrik"
)
