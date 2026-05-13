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

    # Intro-carousel (3 trin: upload, analys\u00e9r, eksport\u00e9r)
    landing_intro_carousel(ns),

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

#' Intro-carousel: 3-trins overblik på landing page
#' @param ns Namespace function (fra shiny::NS(id))
#' @return shiny.tag
#' @noRd
landing_intro_carousel <- function(ns) {
  carousel_id <- ns("intro_carousel")
  slides <- landing_intro_slides()

  shiny::div(
    class = "landing-intro-carousel",
    shiny::tags$div(
      id = carousel_id,
      class = "carousel slide landing-intro-carousel-widget",
      `data-bs-interval` = "false",
      `data-bs-touch` = "true",
      shiny::tags$div(
        class = "carousel-indicators landing-intro-indicators",
        lapply(seq_along(slides), function(idx) {
          shiny::tags$button(
            type = "button",
            `data-bs-target` = paste0("#", carousel_id),
            `data-bs-slide-to` = idx - 1L,
            class = if (idx == 1L) "active" else NULL,
            `aria-current` = if (idx == 1L) "true" else NULL,
            `aria-label` = paste("Vis introtrin", idx)
          )
        })
      ),
      shiny::tags$div(
        class = "carousel-inner",
        lapply(seq_along(slides), function(idx) {
          landing_intro_slide(
            slide = slides[[idx]],
            active = idx == 1L
          )
        })
      ),
      shiny::tags$button(
        class = "carousel-control-prev landing-intro-control",
        type = "button",
        `data-bs-target` = paste0("#", carousel_id),
        `data-bs-slide` = "prev",
        `aria-label` = "Forrige introtrin",
        shiny::tags$span(class = "carousel-control-prev-icon", `aria-hidden` = "true"),
        shiny::tags$span(class = "visually-hidden", "Forrige")
      ),
      shiny::tags$button(
        class = "carousel-control-next landing-intro-control",
        type = "button",
        `data-bs-target` = paste0("#", carousel_id),
        `data-bs-slide` = "next",
        `aria-label` = "N\u00e6ste introtrin",
        shiny::tags$span(class = "carousel-control-next-icon", `aria-hidden` = "true"),
        shiny::tags$span(class = "visually-hidden", "N\u00e6ste")
      )
    )
  )
}

#' Renderer ét carousel-slide
#' @param slide Named list med step, title, body, points, image_src, image_alt
#' @param active Logical. TRUE for første slide
#' @return shiny.tag
#' @noRd
landing_intro_slide <- function(slide, active = FALSE) {
  shiny::tags$div(
    class = paste("carousel-item landing-intro-slide", if (active) "active"),
    shiny::div(
      class = "landing-intro-frame",
      shiny::div(
        class = "row g-4 align-items-center",
        shiny::div(
          class = "col-lg-7",
          shiny::div(
            class = "landing-intro-media",
            shiny::img(
              src = slide$image_src,
              alt = slide$image_alt,
              class = "img-fluid"
            )
          )
        ),
        shiny::div(
          class = "col-lg-5",
          shiny::div(
            class = "landing-intro-copy",
            shiny::tags$div(class = "landing-intro-step", slide$step),
            shiny::tags$h3(slide$title, class = "landing-intro-title"),
            shiny::tags$p(class = "landing-intro-body", slide$body),
            shiny::tags$ul(
              class = "landing-intro-points",
              lapply(slide$points, function(point) shiny::tags$li(point))
            )
          )
        )
      )
    )
  )
}

#' Slide-data til intro-carousel (3 trin: upload, analysér, eksportér)
#' @return list med 3 slide-definitioner
#' @noRd
landing_intro_slides <- function() {
  list(
    list(
      step = "Trin 1",
      title = "Upload data hurtigt og fleksibelt",
      body = paste(
        "Start med at inds\u00e6tte data direkte fra Excel,",
        "upload en fil eller brug eksempeldata for at l\u00e6re appen at kende."
      ),
      points = c(
        "CSV, Excel og copy-paste underst\u00f8ttes",
        "Automatisk kolonnedetektion reducerer manuelt arbejde",
        "Egnet til b\u00e5de hurtige test og rigtige kliniske datas\u00e6t"
      ),
      image_src = "www/help/06a-trin1-upload.png",
      image_alt = "Sk\u00e6rmbillede af upload-trinnet i biSPCharts"
    ),
    list(
      step = "Trin 2",
      title = "Analys\u00e9r med SPC og f\u00e5 overblik",
      body = paste(
        "V\u00e6lg diagramtype, map kolonner og just\u00e9r indstillinger,",
        "mens diagrammet opdateres og signaler fremh\u00e6ves."
      ),
      points = c(
        "Run charts og kontroldiagrammer i samme workflow",
        "Automatisk signaldetektion hj\u00e6lper med at finde variation",
        "Tilpas labels, akser og ops\u00e6tning uden at forlade analysen"
      ),
      image_src = "www/help/06b-trin2-analyser.png",
      image_alt = "Sk\u00e6rmbillede af analyse-trinnet i biSPCharts"
    ),
    list(
      step = "Trin 3",
      title = "Eksport\u00e9r diagrammer i regionalt layout",
      body = paste(
        "Afslut med en eksport, der er klar til deling i kvalitetsarbejdet,",
        "med titel, analyse og grafik i et konsistent format."
      ),
      points = c(
        "Eksport til PDF og PNG",
        "Velegnet til m\u00f8der, rapporter og dokumentation",
        "Bevarer appens branding og ops\u00e6tning i output"
      ),
      image_src = "www/help/06c-trin3-eksporter.png",
      image_alt = "Sk\u00e6rmbillede af eksport-trinnet i biSPCharts"
    )
  )
}
