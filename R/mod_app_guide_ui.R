# mod_app_guide_ui.R
# App-vejledning: Saadan bruger du biSPCharts (modal-format med carousel)

#' App Guide Module UI
#'
#' Returnerer carousel-content til app-guide modal-body. Modal-frame +
#' close-knap haandteres af show_app_guide_modal() (custom Bootstrap 5
#' markup). Ingen header, ingen footer, ingen lead-paragraph \u2014 modal er
#' ren lightbox-overlay.
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny tag (carousel)
#' @keywords internal
mod_app_guide_ui <- function(id) {
  ns <- shiny::NS(id)
  app_guide_intro_carousel(ns)
}

#' Vis app-guide som lightbox modal-overlay
#'
#' Custom Bootstrap 5 modal-markup uden header/footer (drop shiny::modalDialog
#' for fuld kontrol). Lukkes ved klik udenfor (data-bs-backdrop=true), Esc
#' (data-bs-keyboard=true), eller custom X-knap (data-bs-dismiss=modal).
#'
#' @param session Shiny session-objekt (typisk parent_session fra modul)
#' @return invisible(NULL). Side-effekt: viser modal.
#' @keywords internal
show_app_guide_modal <- function(session = shiny::getDefaultReactiveDomain()) {
  shiny::showModal(build_app_guide_modal_markup(), session = session)
}

#' Byg markup-struktur for app-guide modal
#'
#' Extracted som separat helper for at testen kan asserte paa REEL
#' production-output (ej recreation). Forhindrer drift mellem test og
#' implementation.
#'
#' @return Shiny tag (modal-div med carousel-content + Bootstrap init-script)
#' @keywords internal
build_app_guide_modal_markup <- function() {
  shiny::tags$div(
    id = "shiny-modal",
    class = "modal fade app-guide-modal",
    tabindex = "-1",
    # Accessibility: role + aria-modal saettes ej automatisk paa custom markup.
    # Shiny's modalDialog laver Bootstrap modal-init der ikke retroaktivt
    # tilfoejer disse — vi skal saette dem eksplicit her. aria-label erstatter
    # aria-labelledby da modal har INGEN synlig title.
    role = "dialog",
    `aria-modal` = "true",
    `aria-label` = "App-vejledning",
    # Bemærk: bade data-* og data-bs-* sættes for parity med shiny::modalDialog.
    # Shiny's Esc-handler i modal.ts laeser data-keyboard; Bootstrap 5 laeser data-bs-keyboard.
    `data-backdrop` = "true",
    `data-bs-backdrop` = "true",
    `data-keyboard` = "true",
    `data-bs-keyboard` = "true",
    shiny::tags$div(
      class = "modal-dialog app-guide-modal-dialog",
      shiny::tags$div(
        class = "modal-content app-guide-inner",
        shiny::tags$button(
          type = "button",
          class = "app-guide-close",
          `data-bs-dismiss` = "modal",
          `aria-label` = "Luk",
          shiny::HTML("&times;")
        ),
        mod_app_guide_ui("app_guide")
      )
    ),
    # KRITISK: shiny::showModal() injicerer markup men initialiserer IKKE Bootstrap-modal.
    # Mirror init-script fra shiny::modalDialog (verificeret via deparse(body())).
    # Uden dette vises modal aldrig (silent runtime failure).
    shiny::tags$script(shiny::HTML(
      "if (window.bootstrap && !window.bootstrap.Modal.VERSION.match(/^4\\./)) {
         var modal = new bootstrap.Modal(document.getElementById('shiny-modal'));
         modal.show();
      } else {
         $('#shiny-modal').modal().focus();
      }"
    ))
  )
}

# ---------------------------------------------------------------------------
# Intro-carousel helpers
# ---------------------------------------------------------------------------

#' App-guide carousel: 7-trins gennemgang
#' @param ns Namespace function (fra shiny::NS(id))
#' @return shiny.tag
#' @noRd
app_guide_intro_carousel <- function(ns) {
  carousel_id <- ns("guide_carousel")
  slides <- app_guide_intro_slides()
  total <- length(slides)

  # DOM-r\u00e6kkef\u00f8lge matcher Bootstrap 5 canonical struktur:
  # indicators F\u00d8RST (positioneret absolut over carousel-inner),
  # derefter inner, derefter controls.
  shiny::tags$div(
    id = carousel_id,
    class = "carousel slide app-guide-carousel",
    `data-bs-interval` = "false",
    `data-bs-touch` = "true",
    shiny::tags$div(
      class = "carousel-indicators app-guide-indicators",
      lapply(seq_along(slides), function(idx) {
        shiny::tags$button(
          type = "button",
          `data-bs-target` = paste0("#", carousel_id),
          `data-bs-slide-to` = idx - 1L,
          class = if (idx == 1L) "active" else NULL,
          `aria-current` = if (idx == 1L) "true" else NULL,
          `aria-label` = paste("Vis trin", idx)
        )
      })
    ),
    shiny::tags$div(
      class = "carousel-inner",
      lapply(seq_along(slides), function(idx) {
        app_guide_intro_slide(
          slide = slides[[idx]],
          idx = idx,
          total = total,
          active = idx == 1L
        )
      })
    ),
    shiny::tags$button(
      class = "app-guide-control app-guide-control--prev",
      type = "button",
      `data-bs-target` = paste0("#", carousel_id),
      `data-bs-slide` = "prev",
      `aria-label` = "Forrige trin",
      shiny::HTML("&lsaquo;"),
      shiny::tags$span(class = "visually-hidden", "Forrige")
    ),
    shiny::tags$button(
      class = "app-guide-control app-guide-control--next",
      type = "button",
      `data-bs-target` = paste0("#", carousel_id),
      `data-bs-slide` = "next",
      `aria-label` = "N\u00e6ste trin",
      shiny::HTML("&rsaquo;"),
      shiny::tags$span(class = "visually-hidden", "N\u00e6ste")
    )
  )
}

#' Renderer ét carousel-slide i app-guide
#'
#' Slide-layout: venstre=media (50%), hoejre=content (50%). Media-siden
#' viser screenshot hvis slide$image_src er sat; ellers fallback decorativ
#' gradient med stort trin-nummer (matcher hospital-brand). Konsekvent
#' 460px hoejde uanset content for at undgaa layout-hop ved navigation.
#'
#' @param slide Named list med title, content, image_src, image_alt
#' @param idx Integer. Slide-nummer (1-baseret)
#' @param total Integer. Total antal slides
#' @param active Logical. TRUE for første slide
#' @return shiny.tag
#' @noRd
app_guide_intro_slide <- function(slide, idx, total, active = FALSE) {
  has_image <- !is.null(slide$image_src) && nzchar(slide$image_src)

  media_col <- if (has_image) {
    shiny::div(
      class = "app-guide-media app-guide-media--image",
      shiny::img(
        src = slide$image_src,
        alt = slide$image_alt %||% ""
      )
    )
  } else {
    shiny::div(
      class = "app-guide-media app-guide-media--decor",
      # aria-hidden: title vises ogsaa i h3 nedenfor (content-col),
      # decor-label er rent visuel — undgaa screen-reader-duplikering
      `aria-hidden` = "true",
      shiny::div(class = "app-guide-decor-num", as.character(idx)),
      shiny::div(class = "app-guide-decor-label", slide$title)
    )
  }

  content_col <- shiny::div(
    class = "app-guide-content",
    shiny::div(
      class = "app-guide-step",
      sprintf("Trin %d / %d", idx, total)
    ),
    shiny::tags$h3(slide$title, class = "app-guide-title"),
    shiny::div(class = "app-guide-body", slide$content)
  )

  shiny::tags$div(
    class = paste("carousel-item app-guide-slide", if (active) "active"),
    media_col,
    content_col
  )
}

#' Slide-data til app-guide carousel (7 trin: upload -> gem)
#' @return list med 7 slide-definitioner. Hver slide har: title (chr),
#'   content (Shiny tag/tagList), image_src (chr eller NULL), image_alt (chr)
#' @noRd
app_guide_intro_slides <- function() {
  list(
    # Trin 1: Upload data
    list(
      title = "Upload data",
      image_src = "www/help/06a-trin1-upload.png",
      image_alt = "Sk\u00e6rmbillede af upload-trinnet",
      content = shiny::tagList(
        shiny::tags$p(
          "Start med at v\u00e6lge, hvordan du vil indl\u00e6se data:"
        ),
        shiny::tags$dl(
          shiny::tags$dt("Kopi\u00e9r & Inds\u00e6t data"),
          shiny::tags$dd(
            "Ligger dine data i Excel? Mark\u00e9r tabellen inkl. ",
            "kolonneoverskrifter, kopi\u00e9r og inds\u00e6t i feltet, klik ",
            shiny::tags$strong("Forts\u00e6t.")
          ),
          shiny::tags$dt("Indl\u00e6s XLS/CSV"),
          shiny::tags$dd(
            "Excel- eller CSV-fil. Du kan ogs\u00e5 indl\u00e6se en tidligere ",
            "gemt biSPCharts-fil."
          ),
          shiny::tags$dt("Pr\u00f8v med eksempeldata"),
          shiny::tags$dd(
            "Brug eksempeldata, hvis du vil l\u00e6re appen at kende eller teste."
          ),
          shiny::tags$dt("Blank session"),
          shiny::tags$dd("Hvis du vil starte helt forfra.")
        ),
        shiny::div(
          class = "alert alert-info mt-3 mb-0",
          shiny::tags$strong("Dataformat: "),
          "En almindelig tabel med \u00e9n r\u00e6kke per observation. ",
          "Mindst en kolonne til tid/kategori og en kolonne med v\u00e6rdien."
        )
      )
    ),

    # Trin 2: Tildel kolonner
    list(
      title = "Tildel kolonner",
      image_src = NULL,
      image_alt = NULL,
      content = shiny::tagList(
        shiny::tags$p(
          "N\u00e5r data er indl\u00e6st, viser appen tabellen og et forel\u00f8bigt ",
          "diagram. Klik ", shiny::tags$strong("Tildel kolonner"),
          " og kontroll\u00e9r, at appen har forst\u00e5et data korrekt."
        ),
        shiny::tags$table(
          class = "table table-sm table-striped",
          shiny::tags$thead(
            shiny::tags$tr(
              shiny::tags$th("Felt"),
              shiny::tags$th("Betydning")
            )
          ),
          shiny::tags$tbody(
            shiny::tags$tr(
              shiny::tags$td(shiny::tags$strong("Tid/kategori (X)")),
              shiny::tags$td("Dato, m\u00e5ned, uge eller observationsnummer")
            ),
            shiny::tags$tr(
              shiny::tags$td(shiny::tags$strong("T\u00e6ller (Y)")),
              shiny::tags$td("V\u00e6rdien du vil f\u00f8lge over tid")
            ),
            shiny::tags$tr(
              shiny::tags$td(shiny::tags$strong("N\u00e6vner")),
              shiny::tags$td("Andele/rater (patienter, forl\u00f8b, sengedage)")
            ),
            shiny::tags$tr(
              shiny::tags$td(shiny::tags$strong("Skift")),
              shiny::tags$td("Markerer kendte proces\u00e6ndringer")
            ),
            shiny::tags$tr(
              shiny::tags$td(shiny::tags$strong("Frys")),
              shiny::tags$td("L\u00e5ser kontrolgr\u00e6nser ud fra baseline")
            ),
            shiny::tags$tr(
              shiny::tags$td(shiny::tags$strong("Kommentar")),
              shiny::tags$td("Noter der kan vises p\u00e5 diagrammet")
            )
          )
        ),
        shiny::div(
          class = "alert alert-warning mb-0",
          shiny::tags$strong("Vigtigt: "),
          "Kontroll\u00e9r altid kolonnemappingen. Forkert X-akse, t\u00e6ller ",
          "eller n\u00e6vner = forkert diagram."
        )
      )
    ),

    # Trin 3: Juster diagrammet
    list(
      title = "Just\u00e9r diagrammet",
      image_src = "www/help/06b-trin2-analyser.png",
      image_alt = "Sk\u00e6rmbillede af analyse-trinnet",
      content = shiny::tagList(
        shiny::tags$p(
          "Under ", shiny::tags$strong("Indstillinger"),
          " v\u00e6lger du diagramtype og visning. Start med ",
          shiny::tags$strong("Seriediagram (Run)"),
          ", hvis du er i tvivl."
        ),
        shiny::tags$dl(
          shiny::tags$dt("Y-akse enhed"),
          shiny::tags$dd("Tal, procent, rate eller tid."),
          shiny::tags$dt("Udviklingsm\u00e5l"),
          shiny::tags$dd(
            "M\u00e5llinje, fx ", shiny::tags$code(">=90%"), ", ",
            shiny::tags$code("<25"), " eller ", shiny::tags$code("0,8"),
            ". \u00c6ndrer ikke SPC-beregninger."
          ),
          shiny::tags$dt("Evt. baseline"),
          shiny::tags$dd(
            "Fast midterlinje. Hvis du vil l\u00e5se kontrolgr\u00e6nser ud ",
            "fra baseline-periode i data, brug ",
            shiny::tags$strong("Frys-kolonnen.")
          )
        ),
        shiny::div(
          class = "alert alert-light border mb-0",
          shiny::tags$strong("Midterlinje (\u201eNuv. niveau\u201c): "),
          "Niveauet processen ligger omkring nu. Ikke det samme som ",
          shiny::tags$strong("Udviklingsm\u00e5l"),
          " (hvor I gerne vil hen)."
        )
      )
    ),

    # Trin 4: Laes diagrammet
    list(
      title = "L\u00e6s diagrammet",
      image_src = NULL,
      image_alt = NULL,
      content = shiny::tagList(
        shiny::tags$p(
          "Diagrammet opdateres automatisk, n\u00e5r du \u00e6ndrer data eller ",
          "indstillinger."
        ),
        shiny::tags$p(
          "Under diagrammet vises n\u00f8gletal for signaler: ",
          shiny::tags$strong("seriel\u00e6ngde"), ", ",
          shiny::tags$strong("antal kryds"),
          " og ",
          shiny::tags$strong("punkter uden for kontrolgr\u00e6nser"),
          ". Farverne hj\u00e6lper dig med at se, om appen har fundet tegn ",
          "p\u00e5 s\u00e6rlig variation."
        ),
        shiny::div(
          class = "alert alert-info mb-0",
          shiny::tags$strong("Husk: "),
          "Et signal er ikke en forklaring i sig selv. Det er et tegn p\u00e5, ",
          "at processen b\u00f8r vurderes fagligt."
        )
      )
    ),

    # Trin 5: Rediger data
    list(
      title = "Redig\u00e9r data ved behov",
      image_src = NULL,
      image_alt = NULL,
      content = shiny::tagList(
        shiny::tags$p(
          "Du kan rette data direkte i tabellen uden at uploade filen igen."
        ),
        shiny::tags$ul(
          shiny::tags$li("Tilf\u00f8j r\u00e6kker"),
          shiny::tags$li("Tilf\u00f8j kolonner"),
          shiny::tags$li("Omd\u00f8b kolonner"),
          shiny::tags$li("Ret kolonnemapping")
        ),
        shiny::tags$p(
          class = "mb-0",
          "N\u00e5r data \u00e6ndres, opdateres diagrammet automatisk."
        )
      )
    ),

    # Trin 6: Eksporter
    list(
      title = "Eksport\u00e9r",
      image_src = "www/help/06c-trin3-eksporter.png",
      image_alt = "Sk\u00e6rmbillede af eksport-trinnet",
      content = shiny::tagList(
        shiny::tags$p(
          "Klik ", shiny::tags$strong("Forts\u00e6t"), " for at g\u00e5 til eksport."
        ),
        shiny::tags$dl(
          shiny::tags$dt("PDF"),
          shiny::tags$dd(
            "Rapportering, kvalitetsm\u00f8der, arkivering og deling som ",
            "f\u00e6rdig rapport."
          ),
          shiny::tags$dt("PNG"),
          shiny::tags$dd(
            "Pr\u00e6sentation, mail eller dokument."
          )
        ),
        shiny::tags$p("Udfyld is\u00e6r:"),
        shiny::tags$ul(
          class = "mb-0",
          shiny::tags$li(
            shiny::tags$strong("Indikatortitel: "),
            "kort titel eller konklusion"
          ),
          shiny::tags$li(
            shiny::tags$strong("Afdeling/afsnit: "),
            "hvor data h\u00f8rer til"
          ),
          shiny::tags$li(
            shiny::tags$strong("Datadefinition: "),
            "hvad m\u00e5les, hvem indg\u00e5r, hvilken periode, hvad er udeladt"
          ),
          shiny::tags$li(
            shiny::tags$strong("Analyse: "),
            "din faglige fortolkning"
          ),
          shiny::tags$li(
            shiny::tags$strong("Datakilde/fodnote: "),
            "hvor data kommer fra"
          )
        )
      )
    ),

    # Trin 7: Gem arbejdet
    list(
      title = "Gem arbejdet",
      image_src = NULL,
      image_alt = NULL,
      content = shiny::tagList(
        shiny::tags$p(
          "Appen gemmer automatisk din session i browseren, s\u00e5 du kan ",
          "forts\u00e6tte senere fra samme computer."
        ),
        shiny::tags$p(
          class = "mb-0",
          "Hvis arbejdet skal deles, dokumenteres eller bruges p\u00e5 en ",
          "anden computer, b\u00f8r du ogs\u00e5 downloade en kopi af data og ",
          "indstillinger via knappen ",
          shiny::tags$strong("Download kopi af data og indstillinger"),
          " p\u00e5 analyse-trinnet."
        )
      )
    )
  )
}
