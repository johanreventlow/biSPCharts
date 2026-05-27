# mod_report_bug_ui.R
# "Rapporter fejl"-side: ikke-teknisk bug-rapporterings-guide
# med praefyldt mailto-knap mod Dataenhedens postkasse.

#' Report Bug Module UI
#'
#' Vejledning til brugere om hvordan de rapporterer fejl i biSPCharts.
#' Indeholder en knap der aabner brugerens mail-klient med en
#' praefyldt skabelon via et mailto-link.
#'
#' @param id Character. Namespace ID for modulet.
#' @return Shiny UI element.
#' @keywords internal
mod_report_bug_ui <- function(id) {
  ns <- shiny::NS(id)

  mailto_url <- build_bug_report_mailto()

  shiny::div(
    class = "container-fluid info-page",
    style = "max-width: 900px; margin: 0 auto; padding: 30px 20px;",
    help_back_link(ns),
    shiny::tags$h1("Rapport\u00e9r fejl"),
    shiny::tags$p(
      class = "lead",
      "Oplever du, at noget i biSPCharts ikke virker som forventet? ",
      "S\u00e5 hj\u00e6lper du os meget ved at sende en kort beskrivelse. ",
      "Du beh\u00f8ver ikke at v\u00e6re teknisk - bare fort\u00e6l, hvad du oplevede."
    ),

    # Section 1: Before you send
    shiny::tags$section(
      shiny::tags$h2("Inden du sender"),
      shiny::tags$p(
        "Det hj\u00e6lper os hurtigt at forst\u00e5 og rette fejlen, hvis du kan vedh\u00e6fte:"
      ),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("din datafil"),
          " - gem den via ",
          shiny::tags$em("Eksport\u00e9r"),
          "-fanen som Excel og vedh\u00e6ft .xlsx-filen"
        ),
        shiny::tags$li(
          shiny::tags$strong("grafen"),
          ", du s\u00e5, da fejlen opstod - gem den ogs\u00e5 via ",
          shiny::tags$em("Eksport\u00e9r"),
          "-fanen"
        ),
        shiny::tags$li(
          shiny::tags$strong("et sk\u00e6rmbillede"),
          " af det, du oplevede, hvis det er relevant ",
          "(Windows: Win+Shift+S, Mac: Cmd+Shift+4)"
        )
      ),
      shiny::div(
        class = "alert alert-info",
        shiny::tags$strong("Hvorfor? "),
        "Med dit datas\u00e6t og grafen kan vi gen-afspille situationen og ",
        "sikre, at fejlen er rettet, n\u00e5r vi melder tilbage."
      ),
      shiny::tags$hr()
    ),

    # Section 2: What is useful to describe
    shiny::tags$section(
      shiny::tags$h2("Hvad er nyttigt at beskrive?"),
      shiny::tags$p(
        "Skabelonen i mailen guider dig - men kort fortalt hj\u00e6lper det os, ",
        "hvis du fort\u00e6ller:"
      ),
      shiny::tags$ul(
        shiny::tags$li("Hvad skete der?"),
        shiny::tags$li("Hvad lavede du, da det skete?"),
        shiny::tags$li("Hvad havde du forventet?"),
        shiny::tags$li("Skete det \u00e9n gang, eller hver gang du pr\u00f8ver?")
      ),
      shiny::tags$p(
        class = "text-muted",
        "Du beh\u00f8ver ikke at udfylde alt - skriv bare det, du kan huske."
      ),
      shiny::tags$hr()
    ),

    # Section 3: Send
    shiny::tags$section(
      shiny::tags$h2("Send rapporten"),
      shiny::tags$p(
        "N\u00e5r du klikker p\u00e5 knappen herunder, \u00e5bnes din mail-klient med ",
        "en f\u00e6rdig skabelon til inspiration. Skriv eller udfyld det du kan, vedh\u00e6ft gerne din datafil, ",
        "samt evt. din graf og et sk\u00e6rmbillede, og tryk send."
      ),
      shiny::div(
        class = "text-center my-4",
        shiny::tags$a(
          href = mailto_url,
          class = "btn btn-primary btn-lg",
          style = "color: #ffffff;",
          shiny::icon("envelope"),
          " \u00c5bn mail"
        )
      ),
      shiny::div(
        class = "alert alert-light border",
        shiny::tags$strong("Virker knappen ikke? "),
        "S\u00e5 kan du i stedet sende en mail direkte til ",
        shiny::tags$a(
          href = paste0("mailto:", SUPPORT_EMAIL),
          SUPPORT_EMAIL
        ),
        " - skriv kort, hvad du oplevede, og vedh\u00e6ft gerne ",
        "datas\u00e6t, graf og sk\u00e6rmbillede."
      )
    )
  )
}
