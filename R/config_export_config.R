# ==============================================================================
# CONFIG_EXPORT_CONFIG.R
# ==============================================================================
# FORMAaL: Export-specifikke konstanter for PDF og PNG eksport.
#         Centraliserer alle export defaults, size presets, DPI options og
#         metadata limitations.
#
# ANVENDES AF:
#   - Export module UI (mod_export_ui.R) - Size preset selections
#   - Export module server (mod_export_server.R) - Export generation logic
#   - Validation logic - Metadata length checks
#   - Filename generation - Prefix and separator constants
#
# RELATERET:
#   - mod_export_ui.R - Export module UI
#   - mod_export_server.R - Export module server
#   - See: docs/CONFIGURATION.md for complete guide
# ==============================================================================

# EXPORT SIZE PRESETS ==========================================================

#' Export size presets for different output formats
#'
#' Praedefinerede stoerrelser til eksport af SPC plots.
#' Hver preset inkluderer bredde, hoejde, DPI og display label.
#'
#' @format Named list med size preset objekter
#' @details
#' Presets inkluderer:
#' - small: 800x600px ved 96 DPI (lille web/email format)
#' - medium: 1200x900px ved 96 DPI (standard praesentation)
#' - large: 1920x1440px ved 96 DPI (hoej oploesning)
#'
#' @keywords internal
EXPORT_SIZE_PRESETS <- list(
  small = list(
    width = 800,
    height = 600,
    dpi = 96,
    unit = "px",
    label = "Lille (800 \u00d7 600 px)"
  ),
  medium = list(
    width = 1200,
    height = 900,
    dpi = 96,
    unit = "px",
    label = "Medium (1200 \u00d7 900 px)"
  ),
  large = list(
    width = 1920,
    height = 1440,
    dpi = 96,
    unit = "px",
    label = "Stor (1920 \u00d7 1440 px)"
  )
)

#' Convert Size Preset to Dimensions
#'
#' Konverterer en size preset navn til konkrete dimensioner og DPI vaerdier.
#' Bruges til at mappe UI dropdown vaerdier til faktiske export parametre.
#'
#' @param preset_name Character preset name ("small", "medium", "large")
#'
#' @return Named list med width, height, dpi, unit, label
#'   - width: Numeric width (pixels eller inches afhaengig af unit)
#'   - height: Numeric height (pixels eller inches afhaengig af unit)
#'   - dpi: Numeric DPI resolution
#'   - unit: Character unit type ("px" eller "in")
#'   - label: Character display label for UI
#'
#' @details
#' Available presets (fra EXPORT_SIZE_PRESETS):
#' - small: 800x600px @ 96 DPI (lille web/email format)
#' - medium: 1200x900px @ 96 DPI (standard praesentation)
#' - large: 1920x1440px @ 96 DPI (hoej oploesning)
#'
#' Default fallback: medium preset hvis preset_name ikke findes
#'
#' @examples
#' \dontrun{
#' # Get small preset
#' preset <- get_size_from_preset("small")
#' # Returns: list(width = 800, height = 600, dpi = 96, unit = "px", label = "Lille")
#'
#' # Unknown preset falls back to medium
#' preset <- get_size_from_preset("unknown")
#' # Returns: medium preset (1200x900px @ 96 DPI)
#' }
#'
#' @keywords internal
get_size_from_preset <- function(preset_name) {
  # Get presets from config
  presets <- EXPORT_SIZE_PRESETS

  # Handle NULL input
  if (is.null(preset_name)) {
    log_debug(
      "NULL preset_name provided, defaulting to medium",
      .context = "EXPORT_PNG"
    )
    return(presets$medium)
  }

  # Convert to character and lowercase for case-insensitive matching
  preset_key <- tolower(as.character(preset_name))

  # Check if preset exists
  if (preset_key %in% names(presets)) {
    log_debug(
      paste("Size preset found:", preset_key),
      .context = "EXPORT_PNG"
    )
    return(presets[[preset_key]])
  } else {
    # Default to medium if unknown preset
    log_warn(
      paste("Unknown size preset:", preset_name, "- defaulting to medium"),
      .context = "EXPORT_PNG"
    )
    return(presets$medium)
  }
}

# EXPORT DPI OPTIONS ===========================================================

#' DPI (Dots Per Inch) options for export
#'
#' Standard DPI vaerdier til forskellige export kvaliteter.
#'
#' @format Integer vector med tilgaengelige DPI vaerdier
#' @details
#' - 72 DPI: Web graphics (low quality)
#' - 96 DPI: Standard screen resolution
#' - 150 DPI: Medium print quality
#' - 300 DPI: High print quality (publicering)
#'
#' @keywords internal
EXPORT_DPI_OPTIONS <- c(72, 96, 150, 300)

# EXPORT ASPECT RATIO CONSTRAINTS ==============================================

#' Minimum aspect ratio for custom export dimensions
#'
#' Forhindrer alt for smalle plots (width/height < 0.5).
#'
#' @keywords internal
EXPORT_ASPECT_RATIO_MIN <- 0.5

#' Maximum aspect ratio for custom export dimensions
#'
#' Forhindrer alt for brede plots (width/height > 2.0).
#'
#' @keywords internal
EXPORT_ASPECT_RATIO_MAX <- 2.0

# METADATA CHARACTER LIMITS ====================================================

#' Maximum character length for export title
#'
#' Begraenser titel laengde til 200 karakterer for at undgaa layout problemer.
#'
#' @keywords internal
EXPORT_TITLE_MAX_LENGTH <- 200

#' Maximum character length for export description
#'
#' Begraenser beskrivelse laengde til 2000 karakterer for PDF metadata.
#'
#' @keywords internal
EXPORT_DESCRIPTION_MAX_LENGTH <- 2000

#' Maximum character length for department name
#'
#' Begraenser afdeling/afsnit navn til 250 karakterer.
#'
#' @keywords internal
EXPORT_DEPARTMENT_MAX_LENGTH <- 250

#' Maximum character length for hospital name
#'
#' Begraenser hospitalsnavn til 250 karakterer.
#'
#' @keywords internal
EXPORT_HOSPITAL_MAX_LENGTH <- 250

# FILENAME GENERATION CONSTANTS ================================================

#' Default prefix for exported filenames
#'
#' Alle eksporterede filer starter med denne prefix.
#'
#' @keywords internal
EXPORT_FILENAME_PREFIX <- "SPC"

#' Separator character for filename components
#'
#' Bruges til at separere prefix, titel og timestamp i filnavne.
#'
#' @keywords internal
EXPORT_FILENAME_SEPARATOR <- "_"

# EXPORT FORMAT CONFIGURATION ==================================================

#' Export format options
#'
#' Tilgaengelige eksport formater med display labels.
#'
#' @format Named character vector med format labels
#' @keywords internal
EXPORT_FORMAT_OPTIONS <- c(
  "PDF" = "pdf",
  "PNG" = "png"
)

# EXPORT VALIDATION CONFIGURATION ==============================================

#' Export validation rules
#'
#' Regler til validering af export inputs foer generering.
#'
#' @format Named list med validation parameters
#' @keywords internal
EXPORT_VALIDATION_RULES <- list(
  # Minimum custom width i pixels
  min_width_px = 400,

  # Maximum custom width i pixels
  max_width_px = 4000,

  # Minimum custom height i pixels
  min_height_px = 300,

  # Maximum custom height i pixels
  max_height_px = 3000,

  # Minimum DPI
  min_dpi = 72,

  # Maximum DPI
  max_dpi = 600,

  # Required fields for PDF export
  pdf_required_fields = c("title"),

  # Optional fields for PDF export
  pdf_optional_fields = c("department", "indicator_description", "improvement_potential")
)
