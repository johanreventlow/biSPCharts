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
#' @keywords internal
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
  muted_color <- get_hospital_colors()$ui_grey_mid
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
      style = paste0("font-size: 1.15rem; color: ", muted_color, "; max-width: 600px; margin-bottom: 25px;"),
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
        "Diagrammer i PDF eller PNG-format"
      )
    ),

    # CTA-knap
    shiny::actionButton(
      ns("start_wizard"),
      shiny::tagList("Kom i gang ", shiny::icon("arrow-right")),
      class = "btn-primary btn-lg",
      style = "padding: 12px 40px; font-size: 1.1rem;"
    ),

    # Discoveryability links
    shiny::div(
      style = paste0(
        "margin-top: 48px; font-size: 0.9rem; color: ", muted_color, ";"
      ),
      "Ny her? ",
      shiny::tags$a(
        href = "#",
        onclick = sprintf(
          "Shiny.setInputValue('%s', Math.random()); return false;",
          ns("goto_app_guide")
        ),
        style = paste0(
          "text-decoration: underline; color: ",
          get_hospital_colors()$ui_grey_dark, ";"
        ),
        "S\u00e5dan bruger du appen"
      ),
      " \u00b7 ",
      shiny::tags$a(
        href = "#",
        onclick = sprintf(
          "Shiny.setInputValue('%s', Math.random()); return false;",
          ns("goto_spc")
        ),
        style = paste0(
          "text-decoration: underline; color: ",
          get_hospital_colors()$ui_grey_dark, ";"
        ),
        "L\u00e6r om SPC"
      )
    )
  )
}

# ---------------------------------------------------------------------------
# Intern helper: restore-landing (vis når gemt session er tilgængelig)
# ---------------------------------------------------------------------------
landing_restore_ui <- function(ns, peek) {
  muted_color <- get_hospital_colors()$ui_grey_mid
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
      style = paste0("font-size: 1.15rem; color: ", muted_color, "; max-width: 600px; margin-bottom: 25px;"),
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
  muted_color <- get_hospital_colors()$ui_grey_mid
  shiny::div(
    style = "width: 200px; text-align: center;",
    shiny::div(
      style = "margin-bottom: 10px;",
      shiny::icon(icon_name, class = "fa-2x", style = paste0("color: ", muted_color, ";"))
    ),
    shiny::tags$h5(title, style = "font-weight: 600;"),
    shiny::tags$p(
      style = paste0("font-size: 0.9rem; color: ", muted_color, ";"),
      description
    )
  )
}
