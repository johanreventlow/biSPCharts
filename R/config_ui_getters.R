# ==============================================================================
# CONFIG_UI_GETTERS.R
# ==============================================================================
# FORMÅL: Accessor functions for UI-related constants.
#
# Provides getter functions for all UI layout and styling parameters, allowing
# future responsive design configuration and theme customization without
# modifying calling code.
#
# PRECEDENCE: Future YAML → Environment Variable → Constant Default
#
# BRUGT AF: UI rendering, layout construction, responsive font scaling
# ==============================================================================

#' Get UI column width configuration
#'
#' Returns the column width configuration for a given layout type.
#' Currently reads from `UI_COLUMN_WIDTHS` constant; future versions can support
#' responsive design via YAML configuration.
#'
#' **Supported layout types:**
#' - `"quarter"`: Four equal columns (6, 6, 6, 6) — Bootstrap grid
#' - `"half"`: Two equal columns (6, 6) — 50/50 split
#' - `"thirds"`: Three equal columns (4, 4, 4) — 33/33/33 split
#' - `"sidebar"`: Sidebar layout (3, 9) — sidebar + main content
#'
#' @param layout_type Character string naming the layout type
#'
#' @return Numeric vector of column widths (Bootstrap grid units), or NULL if not found
#'
#' @examples
#' \dontrun{
#' cols <- get_ui_column_width("sidebar")
#' # Returns: c(3, 9) — sidebar (3 units) + main (9 units)
#'
#' # Use in Shiny UI
#' fluidRow(
#'   column(get_ui_column_width("sidebar")[1], sidebarPanel(...)),
#'   column(get_ui_column_width("sidebar")[2], mainPanel(...))
#' )
#' }
#'
#' @keywords internal
get_ui_column_width <- function(layout_type = "sidebar") {
  UI_COLUMN_WIDTHS[[layout_type]] %||% NULL
}

#' Get UI height for specified component
#'
#' Returns the CSS height value for a given UI component.
#' Currently reads from `UI_HEIGHTS` constant; future versions can support
#' responsive heights based on viewport dimensions.
#'
#' **Supported components:**
#' - `"logo"`: Logo height — default "40px"
#' - `"modal_content"`: Modal content height — default "300px"
#' - `"chart_container"`: Chart container height — default "calc(50vh - 60px)"
#' - `"table_max"`: Table max height — default "200px"
#' - `"sidebar_min"`: Sidebar minimum height — default "130px"
#'
#' @param component Character string naming the UI component
#'
#' @return CSS height string (e.g., "300px", "calc(50vh - 60px)"), or NULL if not found
#'
#' @examples
#' \dontrun{
#' chart_height <- get_ui_height("chart_container")
#' # Returns: "calc(50vh - 60px)"
#' }
#'
#' @keywords internal
get_ui_height <- function(component = "chart_container") {
  UI_HEIGHTS[[component]] %||% NULL
}

#' Get CSS style string for specified style type
#'
#' Returns reusable CSS style strings for consistent styling across components.
#' Currently reads from `UI_STYLES` constant; future versions can support
#' theme customization and dark mode variants.
#'
#' **Supported style types:**
#' - `"flex_column"`: Flexible column layout with auto sizing
#' - `"scroll_auto"`: Scrollable container with max height
#' - `"full_width"`: Full width CSS (width: 100%)
#' - `"right_align"`: Right-aligned text
#' - `"margin_right"`: Right margin spacing
#' - `"position_absolute_right"`: Absolute positioned element (top right)
#'
#' @param style_type Character string naming the style type
#'
#' @return CSS style string suitable for `tags$div(style = ...)`, or NULL if not found
#'
#' @examples
#' \dontrun{
#' # Use in Shiny UI
#' tags$div(
#'   style = get_ui_style("flex_column"),
#'   h3("Flexible content area")
#' )
#' }
#'
#' @keywords internal
get_ui_style <- function(style_type = "flex_column") {
  UI_STYLES[[style_type]] %||% NULL
}

#' Get UI input width for specified width type
#'
#' Returns CSS width value for form inputs and controls.
#' Currently reads from `UI_INPUT_WIDTHS` constant; future versions can support
#' responsive input sizing.
#'
#' **Supported width types:**
#' - `"full"`: Full width — default "100%"
#' - `"half"`: Half width — default "50%"
#' - `"quarter"`: Quarter width — default "25%"
#' - `"three_quarter"`: Three-quarter width — default "75%"
#' - `"auto"`: Automatic width — default "auto"
#'
#' @param width_type Character string naming the width type
#'
#' @return CSS width string (e.g., "100%", "50px"), or NULL if not found
#'
#' @examples
#' \dontrun{
#' textInput("title", "Chart Title", style = paste0("width: ", get_ui_input_width("three_quarter")))
#' }
#'
#' @keywords internal
get_ui_input_width <- function(width_type = "full") {
  UI_INPUT_WIDTHS[[width_type]] %||% NULL
}

#' Get layout proportion for UI calculations
#'
#' Returns numeric proportions for flexible layout calculations.
#' Useful for computing dynamic widths and spacing.
#'
#' **Supported proportions:**
#' - `"half"`: 1/2 — 0.5
#' - `"third"`: 1/3 — 0.333...
#' - `"quarter"`: 1/4 — 0.25
#' - `"two_thirds"`: 2/3 — 0.667...
#' - `"three_quarters"`: 3/4 — 0.75
#'
#' @param proportion_type Character string naming the proportion type
#'
#' @return Numeric proportion value, or NULL if not found
#'
#' @examples
#' \dontrun{
#' sidebar_width <- 400
#' # Calculate complementary width for main content
#' main_width <- sidebar_width / (1 - get_ui_layout_proportion("quarter"))
#' }
#'
#' @keywords internal
get_ui_layout_proportion <- function(proportion_type = "half") {
  UI_LAYOUT_PROPORTIONS[[proportion_type]] %||% NULL
}

#' Get font scaling configuration
#'
#' Returns responsive font scaling parameters for adaptive text sizing.
#' These values control how base font size is calculated based on viewport dimensions.
#'
#' **Configuration parameters:**
#' - `"divisor"`: Viewport diagonal divisor (lower = larger fonts) — default 42
#' - `"min_size"`: Minimum font size in points — default 8
#' - `"max_size"`: Maximum font size in points — default 64
#'
#' **Font scaling formula:**
#' `base_size = max(min_size, min(max_size, diagonal / divisor))`
#' where `diagonal = sqrt(width_px * height_px)`
#'
#' @param parameter Character string naming the scaling parameter
#'
#' @return Numeric configuration value, or NULL if not found
#'
#' @examples
#' \dontrun{
#' # Calculate responsive base font size
#' divisor <- get_ui_font_scaling("divisor")
#' viewport_diagonal <- sqrt(800 * 600)
#' base_size <- max(
#'   get_ui_font_scaling("min_size"),
#'   min(
#'     get_ui_font_scaling("max_size"),
#'     viewport_diagonal / divisor
#'   )
#' )
#' }
#'
#' @keywords internal
get_ui_font_scaling <- function(parameter = "divisor") {
  FONT_SCALING_CONFIG[[parameter]] %||% NULL
}

#' Get viewport default configuration
#'
#' Returns default viewport dimensions and DPI settings for plot rendering.
#' Used as fallback when actual viewport dimensions are not available.
#'
#' **Configuration parameters:**
#' - `"width"`: Default plot width in pixels — default 800
#' - `"height"`: Default plot height in pixels — default 600
#' - `"dpi"`: Display DPI for web graphics — default 96
#'
#' @param parameter Character string naming the viewport parameter
#'
#' @return Numeric configuration value, or NULL if not found
#'
#' @examples
#' \dontrun{
#' # Use as fallback viewport dimensions
#' plot_width <- session$clientData$output_plot_width %||% get_ui_viewport_default("width")
#' plot_height <- session$clientData$output_plot_height %||% get_ui_viewport_default("height")
#' }
#'
#' @keywords internal
get_ui_viewport_default <- function(parameter = "width") {
  VIEWPORT_DEFAULTS[[parameter]] %||% NULL
}
