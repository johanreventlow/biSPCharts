#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @import bslib
#' @keywords internal
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    # CSS: Skjul wizard-trin og hjaelp i navbar fra start.
    # Klassen 'wizard-nav-active' paa <body> viser dem (tilfoejes af JS ved "Kom i gang").
    # Dette undgaar FOUC (flash of unstyled content) i langsomme browsere.
    shiny::tags$style(htmltools::HTML("
      .navbar .nav-link[data-value='upload'],
      .navbar .nav-link[data-value='analyser'],
      .navbar .nav-link[data-value='eksporter'],
      .navbar .nav-link[data-value='app_guide'],
      .navbar .nav-link[data-value='hjaelp'],
      .navbar .nav-item:has(.nav-link[data-value='upload']),
      .navbar .nav-item:has(.nav-link[data-value='analyser']),
      .navbar .nav-item:has(.nav-link[data-value='eksporter']),
      .navbar .nav-item:has(.nav-link[data-value='app_guide']),
      .navbar .nav-item:has(.nav-link[data-value='hjaelp']),
      .navbar .nav-item:has(#session_save_status) {
        display: none !important;
      }
      body.wizard-nav-active .navbar .nav-item:has(.nav-link[data-value='upload']),
      body.wizard-nav-active .navbar .nav-item:has(.nav-link[data-value='analyser']),
      body.wizard-nav-active .navbar .nav-item:has(.nav-link[data-value='eksporter']),
      body.wizard-nav-active .navbar .nav-item:has(.nav-link[data-value='app_guide']),
      body.wizard-nav-active .navbar .nav-item:has(.nav-link[data-value='hjaelp']),
      body.wizard-nav-active .navbar .nav-item:has(#session_save_status) {
        display: flex !important;
        align-items: center;
      }
      body.wizard-nav-active .navbar .nav-link[data-value='upload'],
      body.wizard-nav-active .navbar .nav-link[data-value='analyser'],
      body.wizard-nav-active .navbar .nav-link[data-value='eksporter'],
      body.wizard-nav-active .navbar .nav-link[data-value='app_guide'],
      body.wizard-nav-active .navbar .nav-link[data-value='hjaelp'] {
        display: block !important;
      }
      /* Flash-mitigation: undgaa tom landing mens peek-resultatet afklares */
      #landing-landing_body:empty { min-height: 60vh; }
      /* Graa linkfarve paa hjaelpesider (matcher download-template-link) */
      .tab-pane a { color: #666666; }
      .tab-pane a:hover { color: #333333; }
    ")),
    # Your application UI logic
    bslib::page_navbar(
      id = "main_navbar",
      selected = "start",
      window_title = "biSPCharts",
      title = shiny::tagList(
        shiny::tags$a(
          id = "logo_home_link",
          href = "#",
          style = "cursor: pointer; text-decoration: none;",
          shiny::img(
            src = get_hospital_logo_path(),
            height = "40px",
            style = "margin-right: 15px;",
            onerror = "this.style.display='none'"
          )
        )
      ),
      theme = get_bootstrap_theme(),
      navbar_options = bslib::navbar_options(theme = "dark", underline = FALSE),

      # Header-komponenter
      header = create_ui_header(),

      # Startside (landing page)
      bslib::nav_panel(
        title = NULL,
        value = "start",
        mod_landing_ui("landing")
      ),

      # Navigation tabs (wizard trin)
      # data-step attributter tilfoejes via JS (wizard-nav.js) da bslib
      # genererer nav-links dynamisk. value param bruges til identifikation.

      # Trin 1: Upload
      bslib::nav_panel(
        title = "Upload",
        icon = shiny::icon("upload"),
        value = "upload",
        create_ui_upload_page()
      ),

      # Trin 2: Analyser
      bslib::nav_panel(
        title = "Analys\u00e9r",
        icon = shiny::icon("chart-line"),
        value = "analyser",
        create_ui_main_content()
      ),

      # Trin 3: Eksporter
      bslib::nav_panel(
        title = "Eksport\u00e9r",
        icon = shiny::icon("file-export"),
        value = "eksporter",
        mod_export_ui("export")
      ),

      # Visuelt skel mellem wizard-trin og hjaelp
      bslib::nav_spacer(),

      # Auto-save status i navbar (synlig fra alle wizard-trin)
      bslib::nav_item(
        shiny::uiOutput("session_save_status", inline = TRUE)
      ),

      # App-vejledning (adskilt fra wizard-flow)
      bslib::nav_panel(
        title = "S\u00e5dan bruger du appen",
        icon = shiny::icon("circle-question"),
        value = "app_guide",
        mod_app_guide_ui("app_guide")
      ),

      # Hjaelp (adskilt fra wizard-flow)
      bslib::nav_panel(
        title = "L\u00e6r om SPC",
        icon = shiny::icon("book-open"),
        value = "hjaelp",
        mod_help_ui("help")
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @import golem
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  golem::add_resource_path(
    "www", app_sys("app/www")
  )

  shiny::tagList(
    shiny::tags$head(
      golem::favicon(),
      golem::bundle_resources(
        path = app_sys("app/www"),
        app_title = "biSPCharts"
      ),
      # Accessibility: aria-live paa Shinys notification-panel
      shiny::tags$script(htmltools::HTML(
        "$(function(){
          var p = document.getElementById('shiny-notification-panel');
          if (!p) {
            p = document.createElement('div');
            p.id = 'shiny-notification-panel';
            document.body.appendChild(p);
          }
          p.setAttribute('aria-live', 'polite');
          p.setAttribute('role', 'status');
        });"
      ))
    )
  )
}

#' Access files in the current app
#'
#' NOTE: If you manually change your package name in the DESCRIPTION,
#' don't forget to change it here too, and in the config file.
#' For a safer name change mechanism, use the `golem::set_golem_name()` function.
#'
#' @param ... character. Path to the file, relative to the app's root directory.
#'
#' @noRd
app_sys <- function(...) {
  # Try package installation first
  result <- system.file(..., package = "biSPCharts")

  # If package not found, try development paths
  if (result == "") {
    # Development mode fallback
    path_components <- c(...)
    dev_path <- file.path("inst", path_components)
    if (file.exists(dev_path) || dir.exists(dev_path)) {
      # Return absolute path only for config files to avoid loops
      if (any(grepl("config", path_components))) {
        return(normalizePath(dev_path))
      } else {
        return(dev_path)
      }
    }

    # Try without inst/ prefix
    direct_path <- do.call(file.path, as.list(path_components))
    if (file.exists(direct_path) || dir.exists(direct_path)) {
      # Return absolute path only for config files to avoid loops
      if (any(grepl("config", path_components))) {
        return(normalizePath(direct_path))
      } else {
        return(direct_path)
      }
    }

    # Return empty string to maintain golem compatibility
    return("")
  }

  return(result)
}

#' Read App Config
#'
#' @param value Name of the value to read
#' @param config Config file to read from. Default is "default"
#' @param use_parent Should the config file inherit from parent?
#'
#' @noRd
get_golem_config <- function(
  value,
  config = Sys.getenv(
    "GOLEM_CONFIG_ACTIVE",
    "default"
  ),
  use_parent = TRUE
) {
  # Avoid app_sys during package loading to prevent freeze
  config_file <- "inst/golem-config.yml"
  if (!file.exists(config_file)) {
    config_file <- app_sys("golem-config.yml")
  }

  config::get(
    value = value,
    config = config,
    file = config_file,
    use_parent = use_parent
  )
}
