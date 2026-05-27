# ==============================================================================
# CONFIG_BRANDING_GETTERS.R
# ==============================================================================
# FORMAaL: Safe access til hospital branding (navn, logo, theme, farver) uden
#         global environment pollution. Loader brand.yml og eksponerer via
#         getter-funktioner.
#
# ANVENDES AF:
#   - UI rendering (logo, bootstrap theme)
#   - Plot generation (hospital ggplot2 theme, farver, footer)
#   - App initialization (branding setup)
#
# RELATERET:
#   - inst/config/brand.yml - Brand configuration source file
#   - config_spc_config.R - SPC visualization colors
#   - See: docs/CONFIGURATION.md for complete guide
# ==============================================================================

# BFHtheme color mapping reference:
#   primary    = BFHtheme::bfh_cols("hospital_primary")   = #007dbb
#   secondary  = BFHtheme::bfh_cols("hospital_grey")      = #646c6f
#   info       = BFHtheme::bfh_cols("hospital_blue")      = #009ce8
#   dark       = BFHtheme::bfh_cols("hospital_dark_grey")  = #333333
#   navbar-bg  = BFHtheme::bfh_cols("hospital_primary")    = #007dbb

# Package environment for storing initialized branding
claudespc_branding <- new.env(parent = emptyenv())

#' Get Brand Configuration File Path
#'
#' @noRd
get_brand_config_path <- function() {
  # Try package installation first
  brand_path <- bisp_system_file("config", "brand.yml")

  if (brand_path == "" || !file.exists(brand_path)) {
    # Fallback for development (package not installed)
    fallback_paths <- c(
      "inst/config/brand.yml",
      "_brand.yml"
    )

    # TIDYVERSE: Use purrr::detect to find first matching path (80% code reduction)
    found_path <- purrr::detect(fallback_paths, file.exists)
    if (!is.null(found_path)) {
      return(normalizePath(found_path, mustWork = TRUE))
    }

    # If no brand file found, return NULL and use defaults
    warning("Brand configuration file not found. Using default branding.")
    return(NULL)
  }

  return(brand_path)
}

#' Load Brand Configuration
#'
#' @noRd
load_brand_config <- function() {
  brand_path <- get_brand_config_path()

  if (is.null(brand_path)) {
    # Default configuration if brand.yml not found
    return(list(
      meta = list(
        name = "SPC Hospital",
        description = "Statistical Process Control v\u00e6rkt\u00f8j"
      ),
      logo = list(
        image = "www/BISPCHARTS.png"
      ),
      color = list(
        palette = list(
          primary = "#007dbb",
          secondary = "#646c6f",
          accent = "#FF6B35",
          success = "#4f8325",
          warning = "#f9b928",
          danger = "#dc202b",
          info = "#009ce8",
          light = "#f8f8f8",
          dark = "#333333",
          hospitalblue = "#009ce8",
          darkgrey = "#333333",
          lightgrey = "#ccd3dd",
          mediumgrey = "#646c6f",
          regionhblue = "#002555",
          ui_grey_light = "#ebebeb",
          ui_grey_soft = "#b8b8b8",
          ui_grey_mid = "#8f8f8f",
          ui_grey_dark = "#666666"
        )
      )
    ))
  }

  tryCatch(
    {
      yaml::read_yaml(brand_path)
    },
    error = function(e) {
      warning(paste("Failed to read brand configuration:", e$message, ". Using defaults."))
      # Return default config on error
      load_brand_config() # Recursive call will return defaults
    }
  )
}

#' Create Bootstrap Theme from Brand Configuration
#'
#' Bygger et custom bslib theme baseret paa brand.yml farver.
#' Bruger Flatly som base-preset og overskriver alle farver og
#' navbar-styling med hospitalets officielle BFHtheme-vaerdier.
#'
#' @noRd
create_brand_theme <- function(config = NULL) {
  if (is.null(config)) config <- load_brand_config()
  colors <- config$color$palette

  tryCatch(
    {
      bslib::bs_theme(
        version = 5,
        preset = "flatly",

        # Semantiske farver fra BFHtheme
        primary = colors$primary %||% "#007dbb",
        secondary = colors$secondary %||% "#646c6f",
        success = colors$success %||% "#4f8325",
        warning = colors$warning %||% "#f9b928",
        danger = colors$danger %||% "#dc202b",
        info = colors$info %||% "#009ce8",
        light = colors$light %||% "#f8f8f8",
        dark = colors$dark %||% "#333333",

        # Navbar: hospital primary blaa med hvid tekst
        "navbar-bg" = colors$primary %||% "#007dbb",
        "navbar-dark-color" = "rgba(255,255,255,0.85)",
        "navbar-dark-hover-color" = "white",
        "navbar-dark-active-color" = "white",
        "navbar-dark-brand-color" = "white",

        # Typografi: Mari med Arial-fallback
        # Skala matcher bispebjerghospital.dk Region H-pattern:
        # H1 48px/300, H2 30px/500, H3 16px/700, H4 14px/700, body 18px/400, lead 22.4px/400.
        "font-family-base" = "Mari, Arial, Helvetica, sans-serif",
        "font-size-base" = "1.125rem",
        "body-color" = "#333",
        "body-line-height" = 1.5,
        "headings-font-family" = "Mari, Arial, Helvetica, sans-serif",
        # Mari leveres som Light(300)/Book(400)/Bold(700)/Heavy(800) -- ingen 500-fil.
        # h2 = 700 = Mari-Bold (site bruger "maribold"-fil med CSS-weight 500, men
        # vi har kun Mari-Bold-filen, saa weight 700 sikrer korrekt font-valg).
        "headings-font-weight" = 700,
        "headings-color" = "#333",
        "headings-line-height" = 1.2,
        "h1-font-size" = "3rem",
        "h2-font-size" = "1.875rem",
        "h3-font-size" = "1rem",
        "h4-font-size" = "0.875rem",
        "lead-font-size" = "1.4rem",
        "lead-font-weight" = 400,
        # Links: Bispebjerg-blaa (#005F8F) i stedet for Bootstrap primary
        "link-color" = "#005F8F",
        "link-decoration" = "underline",
        "link-hover-color" = "#003e5d"
      ) |>
        # Heading-vaegt-afvigelser (h2 bruger headings-font-weight default 500).
        # h1 = light (300), h3+h4 = bold (700).
        bslib::bs_add_rules(paste0(
          "h1, .h1 { font-weight: 300; }",
          "h3, .h3, h4, .h4 { font-weight: 700; }"
        )) |>
        # Knapper: lysere sekundaer-knapper end koncern-graa
        bslib::bs_add_rules(paste0(
          ".btn-secondary {",
          "  --bs-btn-bg: ", colors$ui_grey_mid %||% "#8f8f8f", ";",
          "  --bs-btn-border-color: ", colors$ui_grey_mid %||% "#8f8f8f", ";",
          "  --bs-btn-hover-bg: ", colors$ui_grey_dark %||% "#666666", ";",
          "  --bs-btn-hover-border-color: ", colors$ui_grey_dark %||% "#666666", ";",
          "}",
          ".btn-outline-secondary {",
          "  --bs-btn-color: ", colors$ui_grey_mid %||% "#8f8f8f", ";",
          "  --bs-btn-border-color: ", colors$ui_grey_mid %||% "#8f8f8f", ";",
          "  --bs-btn-hover-color: #fff;",
          "  --bs-btn-hover-bg: ", colors$ui_grey_mid %||% "#8f8f8f", ";",
          "  --bs-btn-hover-border-color: ", colors$ui_grey_mid %||% "#8f8f8f", ";",
          "  --bs-btn-active-color: #fff;",
          "  --bs-btn-active-bg: ", colors$ui_grey_dark %||% "#666666", ";",
          "  --bs-btn-active-border-color: ", colors$ui_grey_dark %||% "#666666", ";",
          "}"
        ))
    },
    error = function(e) {
      warning(paste("Failed to create custom theme:", e$message, ". Using default theme."))
      bslib::bs_theme(
        version = 5,
        preset = "flatly"
      )
    }
  )
}

#' Initialize Branding Configuration
#'
#' Called during package loading to set up branding configuration
#'
#' @noRd
initialize_branding <- function() {
  # Load brand configuration
  brand_config <- load_brand_config()

  # Store in package environment
  claudespc_branding$config <- brand_config
  claudespc_branding$theme <- create_brand_theme(brand_config)
  claudespc_branding$hospital_name <- brand_config$meta$name
  claudespc_branding$logo_path <- brand_config$logo$images$small %||% brand_config$logo$image

  # Build hospital colors
  claudespc_branding$colors <- list(
    primary = brand_config$color$palette$primary,
    secondary = brand_config$color$palette$secondary,
    accent = brand_config$color$palette$accent,
    success = brand_config$color$palette$success,
    warning = brand_config$color$palette$warning,
    danger = brand_config$color$palette$danger,
    info = brand_config$color$palette$info,
    light = brand_config$color$palette$light,
    dark = brand_config$color$palette$dark,
    hospitalblue = brand_config$color$palette$hospitalblue,
    darkgrey = brand_config$color$palette$darkgrey,
    lightgrey = brand_config$color$palette$lightgrey,
    mediumgrey = brand_config$color$palette$mediumgrey,
    regionhblue = brand_config$color$palette$regionhblue,
    ui_grey_light = brand_config$color$palette$ui_grey_light,
    ui_grey_soft = brand_config$color$palette$ui_grey_soft,
    ui_grey_mid = brand_config$color$palette$ui_grey_mid,
    ui_grey_dark = brand_config$color$palette$ui_grey_dark
  )

  invisible()
}

#' Get Hospital Name
#'
#' @return Character string with hospital name
#' @noRd
get_hospital_name <- function() {
  if (is.null(claudespc_branding$hospital_name)) {
    initialize_branding()
  }
  claudespc_branding$hospital_name %||% "SPC Hospital"
}

#' Get Hospital Logo Path
#'
#' @return Character string with logo path
#' @noRd
get_hospital_logo_path <- function() {
  if (is.null(claudespc_branding$logo_path)) {
    initialize_branding()
  }
  claudespc_branding$logo_path %||% "www/BISPCHARTS.png"
}

#' Get Bootstrap Theme
#'
#' @return bslib bootstrap theme object
#' @noRd
get_bootstrap_theme <- function() {
  if (is.null(claudespc_branding$theme)) {
    initialize_branding()
  }
  claudespc_branding$theme %||% bslib::bs_theme(version = 5, preset = "flatly")
}

#' Get Hospital Colors
#'
#' @return List of hospital colors
#' @noRd
get_hospital_colors <- function() {
  if (is.null(claudespc_branding$colors)) {
    initialize_branding()
  }
  claudespc_branding$colors %||% list(
    primary = "#007dbb",
    secondary = "#646c6f",
    accent = "#FF6B35"
  )
}

#' Create Hospital ggplot2 Theme
#'
#' @return ggplot2 theme function
#' @noRd
get_hospital_ggplot_theme <- function() {
  colors <- get_hospital_colors()

  function() {
    ggplot2::theme_minimal() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(color = colors$primary, size = 14, face = "bold"),
        plot.subtitle = ggplot2::element_text(color = colors$secondary, size = 12),
        axis.title = ggplot2::element_text(color = colors$dark, size = 11),
        axis.text = ggplot2::element_text(color = colors$dark, size = 10),
        legend.title = ggplot2::element_text(color = colors$dark, size = 11),
        legend.text = ggplot2::element_text(color = colors$dark, size = 10),
        panel.grid.major = ggplot2::element_line(color = colors$light),
        panel.grid.minor = ggplot2::element_line(color = colors$light),
        strip.text = ggplot2::element_text(color = colors$primary, face = "bold")
      )
  }
}

# Null-coalescing operator is defined in utils_logging.R
