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
    class = "container-fluid",
    style = "max-width: 900px; margin: 0 auto; padding: 30px 20px;",
    help_back_link(ns),
    shiny::tags$h1("Rapportér fejl"),
    shiny::tags$p(
      class = "lead",
      "Oplever du, at noget i biSPCharts ikke virker som forventet? ",
      "Så hjælper du os meget ved at sende en kort beskrivelse. ",
      "Du behøver ikke at være teknisk - bare fortæl, hvad du oplevede."
    ),

    # Section 1: Before you send
    shiny::tags$section(
      shiny::tags$h2("Inden du sender"),
      shiny::tags$p(
        "Det hjælper os hurtigt at forstå og rette fejlen, hvis du kan vedhæfte:"
      ),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("din datafil"),
          " - gem den via ",
          shiny::tags$em("Eksportér"),
          "-fanen som Excel og vedhæft .xlsx-filen"
        ),
        shiny::tags$li(
          shiny::tags$strong("grafen"),
          ", du så, da fejlen opstod - gem den også via ",
          shiny::tags$em("Eksportér"),
          "-fanen"
        ),
        shiny::tags$li(
          shiny::tags$strong("et skærmbillede"),
          " af det, du oplevede, hvis det er relevant ",
          "(Windows: Win+Shift+S, Mac: Cmd+Shift+4)"
        )
      ),
      shiny::div(
        class = "alert alert-info",
        shiny::tags$strong("Hvorfor? "),
        "Med dit datasæt og grafen kan vi gen-afspille situationen og ",
        "sikre, at fejlen er rettet, når vi melder tilbage."
      ),
      shiny::tags$hr()
    ),

    # Section 2: What is useful to describe
    shiny::tags$section(
      shiny::tags$h2("Hvad er nyttigt at beskrive?"),
      shiny::tags$p(
        "Skabelonen i mailen guider dig - men kort fortalt hjælper det os, ",
        "hvis du fortæller:"
      ),
      shiny::tags$ul(
        shiny::tags$li("Hvad skete der?"),
        shiny::tags$li("Hvad lavede du, da det skete?"),
        shiny::tags$li("Hvad havde du forventet?"),
        shiny::tags$li("Skete det én gang, eller hver gang du prøver?")
      ),
      shiny::tags$p(
        class = "text-muted",
        "Du behøver ikke at udfylde alt - skriv bare det, du kan huske."
      ),
      shiny::tags$hr()
    ),

    # Section 3: Send
    shiny::tags$section(
      shiny::tags$h2("Send rapporten"),
      shiny::tags$p(
        "Når du klikker på knappen herunder, åbnes din mail-klient med ",
        "en færdig skabelon til inspiration. Skriv eller udfyld det du kan, vedhæft gerne din datafil, ",
        "samt evt. din graf og et skærmbillede, og tryk send."
      ),
      shiny::div(
        class = "text-center my-4",
        shiny::tags$a(
          href = mailto_url,
          class = "btn btn-primary btn-lg",
          style = "color: #ffffff;",
          shiny::icon("envelope"),
          " Åbn mail"
        )
      ),
      shiny::div(
        class = "alert alert-light border",
        shiny::tags$strong("Virker knappen ikke? "),
        "Så kan du i stedet sende en mail direkte til ",
        shiny::tags$a(
          href = paste0("mailto:", SUPPORT_EMAIL),
          SUPPORT_EMAIL
        ),
        " - skriv kort, hvad du oplevede, og vedhæft gerne ",
        "datasæt, graf og skærmbillede."
      )
    )
  )
}
