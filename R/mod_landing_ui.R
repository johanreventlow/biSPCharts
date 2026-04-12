# mod_landing_ui.R
# Landing page / velkomstside

#' Landing Page Module UI
#'
#' Velkomstside der renderes dynamisk baseret på localStorage-peek.
#' Når en gemt session er tilgængelig vises en restore-card; ellers
#' vises standard-landingen med "Kom i gang"-knap.
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny UI element
#' @export
mod_landing_ui <- function(id) {
  ns <- shiny::NS(id)

  shiny::div(
    style = paste0(
      "display: flex; flex-direction: column; align-items: center; ",
      "justify-content: flex-start; min-height: calc(100vh - 100px); ",
      "text-align: center; padding: 8vh 20px 20px 20px;"
    ),
    shiny::uiOutput(ns("landing_body"))
  )
}

# ---------------------------------------------------------------------------
# Intern helper: standard-landing (vis altid når ingen gemt session)
# ---------------------------------------------------------------------------
landing_default_ui <- function(ns) {
  shiny::tagList(
    # Logo
    shiny::div(
      style = "margin-bottom: 12px;",
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
      "Statistisk proceskontrol til klinisk kvalitetsarbejde p\u00e5 Bispebjerg og Frederiksberg Hospital.",
      "Upload dine data, analys\u00e9r med seriediagrammer og kontroldiagrammer, ",
      "og eksport\u00e9r f\u00e6rdige diagrammer i regionalt layout."
    ),

    # Feature-highlights
    shiny::div(
      style = "display: flex; gap: 24px; margin-bottom: 24px; flex-wrap: wrap; justify-content: center;",
      landing_feature_card(
        "upload", "Upload data",
        "Upload CSV/Excel eller inds\u00e6t direkte fra regneark"
      ),
      landing_feature_card(
        "chart-line", "Analys\u00e9r med SPC",
        "Seriediagrammer og kontroldiagrammer med automatisk signaldetektion"
      ),
      landing_feature_card(
        "file-export", "Eksport\u00e9r diagram",
        "Diagrammer i PDF, PNG eller MS PowerPoint-format"
      )
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

# ---------------------------------------------------------------------------
# Intern helper: restore-landing (vis når gemt session er tilgængelig)
# ---------------------------------------------------------------------------
landing_restore_ui <- function(ns, peek) {
  # Formater timestamp hvis tilgængeligt. R's jsonlite serialiserer Sys.time()
  # som ISO-streng ("2026-04-11 18:46:15"), ikke ms-epoch, så vi parser direkte.
  ts_label <- tryCatch(
    {
      raw <- peek$timestamp
      if (is.null(raw) || !nzchar(as.character(raw))) {
        "ukendt tidspunkt"
      } else if (is.numeric(raw)) {
        format(as.POSIXct(raw / 1000, origin = "1970-01-01"), "%d-%m-%Y kl. %H:%M")
      } else {
        format(as.POSIXct(raw), "%d-%m-%Y kl. %H:%M")
      }
    },
    error = function(e) "ukendt tidspunkt"
  )

  data_label <- if (!is.null(peek$nrows) && !is.null(peek$ncols)) {
    paste0(peek$nrows, " r\u00e6kker \u00d7 ", peek$ncols, " kolonner")
  } else {
    NULL
  }

  title_label <- if (nzchar(peek$indicator_title %||% "")) peek$indicator_title else NULL

  shiny::tagList(
    # Logo
    shiny::div(
      style = "margin-bottom: 12px;",
      shiny::img(
        src = get_hospital_logo_path(),
        height = "80px",
        onerror = "this.style.display='none'"
      )
    ),

    # Velkomsttekst
    shiny::tags$h1(
      "Velkommen tilbage",
      style = "font-weight: 700; margin-bottom: 10px;"
    ),
    shiny::tags$p(
      style = "font-size: 1.15rem; color: #6c757d; max-width: 600px; margin-bottom: 25px;",
      "Der er fundet en tidligere gemt session. Vil du forts\u00e6tte hvor du slap, ",
      "eller starte helt fra begyndelsen?"
    ),

    # Restore-kort med metadata og valg
    bslib::card(
      style = "max-width: 480px; margin: 0 auto 30px auto; text-align: left;",
      bslib::card_header(
        shiny::tagList(
          shiny::icon("clock"),
          " Tidligere session fundet"
        ),
        class = "bg-light"
      ),
      bslib::card_body(
        shiny::tags$dl(
          class = "row mb-0",
          style = "font-size: 0.95rem;",
          shiny::tags$dt(class = "col-sm-4", "Gemt"),
          shiny::tags$dd(class = "col-sm-8", ts_label),
          if (!is.null(data_label)) shiny::tags$dt(class = "col-sm-4", "Data"),
          if (!is.null(data_label)) shiny::tags$dd(class = "col-sm-8", data_label),
          if (!is.null(title_label)) shiny::tags$dt(class = "col-sm-4", "Indikator"),
          if (!is.null(title_label)) shiny::tags$dd(class = "col-sm-8", title_label)
        ),
        shiny::div(
          style = "display: flex; gap: 12px; margin-top: 20px; flex-wrap: wrap;",
          shiny::actionButton(
            ns("restore_saved_session"),
            shiny::tagList(shiny::icon("rotate-left"), " Gendan session"),
            class = "btn-primary btn-lg"
          ),
          shiny::actionButton(
            ns("discard_saved_session"),
            shiny::tagList(shiny::icon("plus"), " Start ny session"),
            class = "btn-outline-secondary btn-lg"
          )
        )
      )
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
