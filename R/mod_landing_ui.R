# mod_landing_ui.R
# Landing page / velkomstside

#' Landing Page Module UI
#'
#' Velkomstside der vises ved app-start.
#' Indeholder logo, velkomsttekst, feature-highlights og CTA-knap.
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny UI element
#' @export
mod_landing_ui <- function(id) {
  ns <- shiny::NS(id)

  shiny::div(
    style = paste0(
      "display: flex; flex-direction: column; align-items: center; ",
      "justify-content: center; min-height: calc(100vh - 100px); ",
      "text-align: center; padding: 10px 20px;"
    ),

    # Logo
    shiny::div(
      style = "margin-bottom: 15px;",
      shiny::img(
        src = get_hospital_logo_path(),
        height = "80px",
        onerror = "this.style.display='none'"
      )
    ),

    # Velkomsttekst
    shiny::tags$h1(
      "Velkommen til biSPCharts",
      style = "font-weight: 700; margin-bottom: 10px;"
    ),
    shiny::tags$p(
      style = "font-size: 1.15rem; color: #6c757d; max-width: 600px; margin-bottom: 25px;",
      "Statistisk proceskontrol til klinisk kvalitetsarbejde på Bispebjerg og Frederiksberg Hospital.",
      "Upload dine data, analys\u00e9r med seriediagrammer og kontroldiagrammer, ",
      "og eksport\u00e9r færdige diagrammer i regionalt layout."
    ),

    # Feature-highlights
    shiny::div(
      style = "display: flex; gap: 30px; margin-bottom: 30px; flex-wrap: wrap; justify-content: center;",
      landing_feature_card("upload", "Upload data",
        "Upload CSV/Excel eller inds\u00e6t direkte fra regneark"),
      landing_feature_card("chart-line", "Analys\u00e9r med SPC",
        "Seriediagrammer og kontroldiagrammer med automatisk signaldetektion"),
      landing_feature_card("file-export", "Eksport\u00e9r diagram",
        "Diagrammer i PDF, PNG eller MS PowerPoint-format")
    ),

    # CTA-knap
    shiny::actionButton(
      ns("start_wizard"),
      shiny::tagList("Kom i gang ", shiny::icon("arrow-right")),
      class = "btn-primary btn-lg",
      style = "padding: 12px 40px; font-size: 1.1rem;"
    )
  )
}

#' Feature-highlight kort til landing page
#' @param icon_name FontAwesome ikon
#' @param title Kort titel
#' @param description Beskrivelse
#' @return shiny.tag
#' @noRd
landing_feature_card <- function(icon_name, title, description) {
  shiny::div(
    style = "width: 200px; text-align: center;",
    shiny::div(
      style = "margin-bottom: 10px;",
      shiny::icon(icon_name, class = "fa-2x", style = "color: #95a5a6;")
    ),
    shiny::tags$h5(title, style = "font-weight: 600;"),
    shiny::tags$p(
      style = "font-size: 0.9rem; color: #6c757d;",
      description
    )
  )
}
