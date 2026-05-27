# mod_about_ui.R
# "Om os"-side: information om udvikling, ophav og inspiration.

#' About Module UI
#'
#' Statisk informationsside om biSPCharts: hvem producerer appen,
#' hvad det statistiske fundament bygger paa, formaal og kontakt.
#'
#' @param id Character. Namespace ID for modulet.
#' @return Shiny UI element.
#' @keywords internal
mod_about_ui <- function(id) {
  ns <- shiny::NS(id)

  shiny::div(
    class = "container-fluid info-page",
    style = "max-width: 900px; margin: 0 auto; padding: 30px 20px;",
    help_back_link(ns),
    shiny::tags$h1("Om biSPCharts"),
    shiny::tags$p(
      class = "lead",
      "biSPCharts er udviklet til at g\u00f8re Statistical Process Control (SPC) ",
      "tilg\u00e6ngeligt for klinikere og kvalitetsmedarbejdere \u2014 uden krav om ",
      "erfaring med databearbejdning eller s\u00e6rlig statistisk viden."
    ),

    # Section 1: Hvem staar bag?
    shiny::tags$section(
      shiny::tags$h2("Hvem st\u00e5r bag?"),
      shiny::tags$p(
        "biSPCharts er produceret af ",
        shiny::tags$strong("Dataenheden"), " i ",
        shiny::tags$strong("Afdeling for Kvalitet og Uddannelse"), " p\u00e5 ",
        shiny::tags$strong("Bispebjerg og Frederiksberg Hospital"), "."
      ),
      shiny::tags$p(
        "Vi arbejder med kliniske data, kvalitetsudvikling og analyse i hverdagen ",
        "\u2014 og har bygget appen ud fra de behov, vi selv og vores kolleger ",
        "m\u00f8der, n\u00e5r data skal oms\u00e6ttes til indsigt og handling."
      ),
      shiny::tags$hr()
    ),

    # Section 2: Inspiration og fundament
    shiny::tags$section(
      shiny::tags$h2("Inspiration og fundament"),
      shiny::tags$p(
        "Det statistiske fundament i biSPCharts bygger p\u00e5 ",
        shiny::tags$strong("Jacob Anh\u00f8js"),
        " mange\u00e5rige arbejde med SPC i sundhedsv\u00e6senet. Anh\u00f8j-reglerne, ",
        "som appen bruger til at finde signaler i data, kommer fra hans R-pakke ",
        shiny::tags$code("qicharts2"),
        ", som biSPCharts tr\u00e6kker direkte p\u00e5."
      ),
      shiny::tags$p(
        "Vi anbefaler Jacob Anh\u00f8js bog ",
        shiny::tags$em("Statistical Process Control for Healthcare"),
        " og ", shiny::tags$em("SPC-manifestet"),
        " som videre l\u00e6sning \u2014 begge findes p\u00e5 siden ",
        shiny::actionLink(ns("goto_help"), "L\u00e6r om SPC"),
        "."
      ),
      shiny::tags$hr()
    ),

    # Section 3: Formaalet
    shiny::tags$section(
      shiny::tags$h2("Form\u00e5let"),
      shiny::tags$p(
        "M\u00e5let med biSPCharts er at s\u00e6nke t\u00e6rsklen for at bruge SPC i ",
        "klinisk kvalitetsarbejde. Vi tror p\u00e5, at flere gode beslutninger ",
        "tr\u00e6ffes, n\u00e5r data pr\u00e6senteres p\u00e5 en m\u00e5de, der adskiller ",
        "tilf\u00e6ldig variation fra reelle \u00e6ndringer."
      ),
      shiny::tags$p(
        "Appen udvikles l\u00f8bende p\u00e5 baggrund af brugernes feedback. Har du ",
        "forslag eller oplever fejl, s\u00e5 brug ",
        shiny::actionLink(ns("goto_report_bug"), "Rapport\u00e9r fejl"),
        "."
      ),
      shiny::tags$hr()
    ),

    # Section 4: Kontakt og support
    shiny::tags$section(
      shiny::tags$h2("Kontakt og support"),
      shiny::tags$p(
        "Sp\u00f8rgsm\u00e5l eller forslag: skriv til Dataenheden via ",
        shiny::tags$a(
          href = paste0("mailto:", SUPPORT_EMAIL),
          SUPPORT_EMAIL
        ),
        "."
      ),
      shiny::div(
        class = "alert alert-info",
        shiny::tags$strong("Bem\u00e6rk: "),
        "biSPCharts udvikles og vedligeholdes som et internt v\u00e6rkt\u00f8j. ",
        "Der ydes ikke egentlig support, men vi l\u00e6ser alle henvendelser ",
        "og indarbejder feedback efter bedste evne."
      )
    )
  )
}
