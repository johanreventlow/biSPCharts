# mod_help_ui.R
# Hjælpeside: SPC-teori og app-vejledning

#' Help Module UI
#'
#' Hjælpeside med SPC-grundbegreber og app-vejledning.
#' Indholdet er statisk og kræver ingen server-logik.
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny UI element
#' @export
mod_help_ui <- function(id) {
  ns <- shiny::NS(id)

  shiny::div(
    class = "container-fluid",
    style = "max-width: 900px; margin: 0 auto; padding: 30px 20px;",

    # Ankerlinks (indholdsfortegnelse)
    shiny::div(
      class = "card mb-4",
      shiny::div(
        class = "card-body",
        shiny::tags$h5("Indhold", class = "card-title"),
        shiny::tags$ol(
          style = "margin-bottom: 0;",
          shiny::tags$li(shiny::tags$a(href = "#spc-hvad", "Hvad er SPC?")),
          shiny::tags$li(shiny::tags$a(href = "#spc-variation", "To typer variation")),
          shiny::tags$li(shiny::tags$a(href = "#spc-laes", "S\u00e5dan l\u00e6ser du et seriediagram")),
          shiny::tags$li(shiny::tags$a(href = "#spc-anhoej", "Anh\u00f8j-reglerne")),
          shiny::tags$li(shiny::tags$a(href = "#spc-kontrol", "Kontroldiagrammer")),
          shiny::tags$li(shiny::tags$a(href = "#app-vejledning", "S\u00e5dan bruger du appen")),
          shiny::tags$li(shiny::tags$a(href = "#spc-raad", "Gode r\u00e5d")),
          shiny::tags$li(shiny::tags$a(href = "#spc-litteratur", "Videre l\u00e6sning"))
        )
      )
    ),

    # Sektion 1: Hvad er SPC?
    shiny::tags$section(
      id = "spc-hvad",
      shiny::tags$h2("Hvad er SPC?"),
      shiny::tags$p(
        "SPC (Statistical Process Control) er en metode til at forst\u00e5 ",
        shiny::tags$strong("variation"), " i processer over tid. ",
        "Metoden blev udviklet af Walter Shewhart i 1920'erne og er i dag ",
        "central i klinisk kvalitetsarbejde verden over."
      ),
      shiny::tags$p(
        "Kernebudskabet i SPC er enkelt: ",
        shiny::tags$em("Al data varierer. Sp\u00f8rgsm\u00e5let er om variationen er tilf\u00e6ldig eller meningsfuld."),
        " Et seriediagram g\u00f8r det muligt at skelne mellem de to."
      ),
      shiny::tags$div(
        class = "text-center my-3",
        shiny::tags$img(
          src = "www/help/01-run-chart-stabil.png",
          alt = "Seriediagram der viser en stabil proces",
          class = "img-fluid rounded shadow-sm",
          style = "max-width: 700px;"
        ),
        shiny::tags$p(
          class = "text-muted small mt-1",
          "Et seriediagram med en stabil proces. Punkterne varierer tilf\u00e6ldigt omkring medianen."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 2: To typer variation
    shiny::tags$section(
      id = "spc-variation",
      shiny::tags$h2("To typer variation"),
      shiny::tags$p(
        "Den vigtigste skelnen i SPC er mellem to typer variation:"
      ),
      shiny::tags$div(
        class = "row mb-3",
        shiny::tags$div(
          class = "col-md-6",
          shiny::tags$div(
            class = "card h-100",
            shiny::tags$div(
              class = "card-body",
              shiny::tags$h5("Tilf\u00e6ldig variation", class = "card-title text-success"),
              shiny::tags$p(
                class = "card-text",
                "Ogs\u00e5 kaldet ", shiny::tags$em("common cause variation"), ". ",
                "Naturlig st\u00f8j der er til stede i alle processer. ",
                "Processen er forudsigelig inden for sine gr\u00e6nser. ",
                "Kan kun reduceres ved at \u00e6ndre selve systemet."
              )
            )
          )
        ),
        shiny::tags$div(
          class = "col-md-6",
          shiny::tags$div(
            class = "card h-100",
            shiny::tags$div(
              class = "card-body",
              shiny::tags$h5("S\u00e6rlig variation", class = "card-title text-danger"),
              shiny::tags$p(
                class = "card-text",
                "Ogs\u00e5 kaldet ", shiny::tags$em("special cause variation"), ". ",
                "Ikke-tilf\u00e6ldige signaler fra us\u00e6dvanlige h\u00e6ndelser. ",
                "Processen er uforudsigelig. ",
                "Kan unders\u00f8ges og handles direkte."
              )
            )
          )
        )
      ),
      shiny::tags$div(
        class = "alert alert-warning",
        shiny::tags$strong("Pas p\u00e5 tampering: "),
        "At reagere p\u00e5 tilf\u00e6ldig variation som om den var meningsfuld ",
        "g\u00f8r processen ", shiny::tags$em("v\u00e6rre"), ", ikke bedre. ",
        "Det er som at dreje p\u00e5 termostaten hver gang temperaturen svinger lidt."
      ),
      shiny::tags$div(
        class = "text-center my-3",
        shiny::tags$img(
          src = "www/help/02-variation-sammenligning.png",
          alt = "Sammenligning af stabil proces og proces med niveauskift",
          class = "img-fluid rounded shadow-sm",
          style = "max-width: 700px;"
        ),
        shiny::tags$p(
          class = "text-muted small mt-1",
          "Venstre: Stabil proces (kun tilf\u00e6ldig variation). H\u00f8jre: Proces med niveauskift (s\u00e6rlig variation detekteret)."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 3: Sådan læser du et seriediagram
    shiny::tags$section(
      id = "spc-laes",
      shiny::tags$h2("S\u00e5dan l\u00e6ser du et seriediagram"),
      shiny::tags$p("Et seriediagram har tre centrale elementer:"),
      shiny::tags$dl(
        class = "row",
        shiny::tags$dt(class = "col-sm-3", "Centrallinje (median)"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Den vandrette linje i midten. Halvdelen af punkterne ligger over, halvdelen under."
        ),
        shiny::tags$dt(class = "col-sm-3", "Serie (run)"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Konsekutive punkter p\u00e5 samme side af medianen. En us\u00e6dvanligt lang serie tyder p\u00e5 et skift i processen."
        ),
        shiny::tags$dt(class = "col-sm-3", "Krydsning"),
        shiny::tags$dd(
          class = "col-sm-9",
          "N\u00e5r linjen krydser medianen. For f\u00e5 krydsninger tyder p\u00e5 clustering eller stratificering."
        )
      ),
      shiny::tags$div(
        class = "text-center my-3",
        shiny::tags$img(
          src = "www/help/03-diagram-annoteret.png",
          alt = "Seriediagram med annotationer der viser centrallinje, serie og krydsning",
          class = "img-fluid rounded shadow-sm",
          style = "max-width: 700px;"
        ),
        shiny::tags$p(
          class = "text-muted small mt-1",
          "Et seriediagram med centrallinje (median), en markeret serie, og krydsningspunkter."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 4: Anhøj-reglerne
    shiny::tags$section(
      id = "spc-anhoej",
      shiny::tags$h2("Anh\u00f8j-reglerne"),
      shiny::tags$p(
        "Anh\u00f8j-reglerne er to statistiske tests der detekterer ikke-tilf\u00e6ldig variation. ",
        "De er udviklet af Jacob Anh\u00f8j og valideret i peer-reviewed forskning."
      ),
      shiny::tags$div(
        class = "card mb-3",
        shiny::tags$div(
          class = "card-body",
          shiny::tags$h5("Regel 1: Seriel\u00e6ngde", class = "card-title"),
          shiny::tags$p(
            class = "card-text",
            "Hvis den l\u00e6ngste serie (konsekutive punkter p\u00e5 samme side af medianen) ",
            "overstiger en gr\u00e6nse baseret p\u00e5 antal datapunkter, er der tegn p\u00e5 et ",
            shiny::tags$strong("niveauskift"), " i processen."
          )
        )
      ),
      shiny::tags$div(
        class = "card mb-3",
        shiny::tags$div(
          class = "card-body",
          shiny::tags$h5("Regel 2: Antal krydsninger", class = "card-title"),
          shiny::tags$p(
            class = "card-text",
            "Hvis der er f\u00e6rre krydsninger af medianen end forventet, er der tegn p\u00e5 ",
            shiny::tags$strong("clustering eller stratificering"), " i data."
          )
        )
      ),
      shiny::tags$p(
        "Reglerne tilpasser sig automatisk til datas\u00e6ttets st\u00f8rrelse og kr\u00e6ver ",
        "ingen antagelser om dataens fordeling \u2014 i mods\u00e6tning til traditionelle kontroldiagram-regler."
      ),
      shiny::tags$div(
        class = "text-center my-3",
        shiny::tags$img(
          src = "www/help/04-anhoej-signal.png",
          alt = "Diagram med Anh\u00f8j-signal detekteret og value boxes",
          class = "img-fluid rounded shadow-sm",
          style = "max-width: 700px;"
        ),
        shiny::tags$p(
          class = "text-muted small mt-1",
          "Et diagram med detekteret signal. V\u00e6rdiboksene i bunden viser seriel\u00e6ngde og krydsninger."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 5: Kontroldiagrammer
    shiny::tags$section(
      id = "spc-kontrol",
      shiny::tags$h2("Kontroldiagrammer"),
      shiny::tags$p(
        "Kontroldiagrammer tilf\u00f8jer ", shiny::tags$strong("kontrolgr\u00e6nser"),
        " (3-sigma gr\u00e6nser) baseret p\u00e5 dataens naturlige variation. ",
        "Punkter uden for kontrolgr\u00e6nserne er st\u00e6rke signaler om s\u00e6rlig variation."
      ),
      shiny::tags$p(
        shiny::tags$strong("Start altid med et seriediagram."),
        " Brug kontroldiagram n\u00e5r du har brug for at opdage punkter der ligger ",
        "ekstremt langt fra gennemsnittet."
      ),
      shiny::tags$h4("Charttyper i appen"),
      shiny::tags$table(
        class = "table table-striped",
        shiny::tags$thead(
          shiny::tags$tr(
            shiny::tags$th("Type"),
            shiny::tags$th("Bruges til"),
            shiny::tags$th("Eksempel")
          )
        ),
        shiny::tags$tbody(
          shiny::tags$tr(
            shiny::tags$td("Seriediagram (Run)"),
            shiny::tags$td("Simpleste type, bruger medianen"),
            shiny::tags$td("Ethvert m\u00e5l over tid")
          ),
          shiny::tags$tr(
            shiny::tags$td("I-kort"),
            shiny::tags$td("Individuelle m\u00e5linger"),
            shiny::tags$td("Ventetid, temperatur")
          ),
          shiny::tags$tr(
            shiny::tags$td("P-kort"),
            shiny::tags$td("Andele/procenter (kr\u00e6ver n\u00e6vner)"),
            shiny::tags$td("Andel patienter med komplikation")
          ),
          shiny::tags$tr(
            shiny::tags$td("C-kort"),
            shiny::tags$td("T\u00e6llinger"),
            shiny::tags$td("Antal fald per m\u00e5ned")
          ),
          shiny::tags$tr(
            shiny::tags$td("U-kort"),
            shiny::tags$td("Rater (kr\u00e6ver n\u00e6vner)"),
            shiny::tags$td("Infektioner per 1000 plejedage")
          )
        )
      ),
      shiny::tags$div(
        class = "text-center my-3",
        shiny::tags$img(
          src = "www/help/05-p-chart.png",
          alt = "P-kort med kontrolgr\u00e6nser",
          class = "img-fluid rounded shadow-sm",
          style = "max-width: 700px;"
        ),
        shiny::tags$p(
          class = "text-muted small mt-1",
          "Et P-kort med kontrolgr\u00e6nser (de stiplede linjer). Punkter uden for gr\u00e6nserne er markeret."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 6: Sådan bruger du appen
    shiny::tags$section(
      id = "app-vejledning",
      shiny::tags$h2("S\u00e5dan bruger du appen"),
      shiny::tags$h4("Trin 1: Upload"),
      shiny::tags$p(
        "Upload en CSV- eller Excel-fil, eller inds\u00e6t data direkte fra Excel. ",
        "Appen registrerer automatisk dine kolonner."
      ),
      shiny::tags$div(
        class = "text-center my-3",
        shiny::tags$img(
          src = "www/help/06a-trin1-upload.png",
          alt = "Upload-siden med data valgt",
          class = "img-fluid rounded shadow-sm",
          style = "max-width: 700px;"
        )
      ),
      shiny::tags$h4("Trin 2: Analys\u00e9r"),
      shiny::tags$p(
        "V\u00e6lg x-akse (typisk dato), y-akse (din indikator), og eventuelt en n\u00e6vner ",
        "(for andele/rater). V\u00e6lg charttype. Tilf\u00f8j valgfrit: target, ",
        "skift-markering (ved kendte proces\u00e6ndringer), frysning af baseline."
      ),
      shiny::tags$div(
        class = "text-center my-3",
        shiny::tags$img(
          src = "www/help/06b-trin2-analyser.png",
          alt = "Analyse-siden med diagram",
          class = "img-fluid rounded shadow-sm",
          style = "max-width: 700px;"
        )
      ),
      shiny::tags$h4("Trin 3: Eksport\u00e9r"),
      shiny::tags$p(
        "Se en preview af din PDF-rapport med automatisk genereret analysetekst. ",
        "Rediger analysen efter behov, eller brug AI til at forfine den. ",
        "Download som PDF eller PNG."
      ),
      shiny::tags$div(
        class = "text-center my-3",
        shiny::tags$img(
          src = "www/help/06c-trin3-eksporter.png",
          alt = "Eksport-siden med PDF preview",
          class = "img-fluid rounded shadow-sm",
          style = "max-width: 700px;"
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 7: Gode råd
    shiny::tags$section(
      id = "spc-raad",
      shiny::tags$h2("Gode r\u00e5d"),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("Start altid med et seriediagram"),
          " \u2014 det er det simpleste og mest robuste"
        ),
        shiny::tags$li(
          shiny::tags$strong("Brug mindst 12\u201315 datapunkter"),
          " for at Anh\u00f8j-reglerne kan detektere signaler p\u00e5lideligt"
        ),
        shiny::tags$li(
          shiny::tags$strong("Marker skift kun ved kendte proces\u00e6ndringer"),
          " \u2014 ikke ved tilf\u00e6ldig variation"
        ),
        shiny::tags$li(
          shiny::tags$strong("Lad data tale:"),
          " undg\u00e5 at overfortolke enkelte punkter eller korte perioder"
        ),
        shiny::tags$li(
          shiny::tags$strong("Vis data som tidsserier,"),
          " ikke som s\u00f8jlediagrammer eller tabeller \u2014 r\u00e6kkef\u00f8lgen er vigtig"
        ),
        shiny::tags$li(
          shiny::tags$strong("En stabil proces er ikke n\u00f8dvendigvis en god proces"),
          " \u2014 den er bare forudsigelig"
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 8: Videre læsning
    shiny::tags$section(
      id = "spc-litteratur",
      shiny::tags$h2("Videre l\u00e6sning"),
      shiny::tags$ul(
        shiny::tags$li(
          "Anh\u00f8j J. ",
          shiny::tags$em("Statistical Process Control for Healthcare."),
          " ",
          shiny::tags$a(
            href = "https://anhoej.github.io/spc4hc/",
            "Online bog", target = "_blank"
          )
        ),
        shiny::tags$li(
          "Anh\u00f8j J. ",
          shiny::tags$em("qicharts2: Quality Improvement Charts."),
          " ",
          shiny::tags$a(
            href = "https://anhoej.github.io/qicharts2/articles/qicharts2.html",
            "Vignette", target = "_blank"
          )
        ),
        shiny::tags$li(
          "Anh\u00f8j J, Olesen AV. Run charts revisited. ",
          shiny::tags$em("BMJ Quality & Safety"),
          " 2015. ",
          shiny::tags$a(
            href = "https://qualitysafety.bmj.com/content/26/1/81",
            "Artikel", target = "_blank"
          )
        ),
        shiny::tags$li(
          "Anh\u00f8j J. ",
          shiny::tags$em("SPC-manifestet: Otte principper for brug af data i kvalitetsudvikling."),
          " ",
          shiny::tags$a(
            href = "https://www.anhoej.net/jacob_fag_spc-manifest.html",
            "L\u00e6s manifestet", target = "_blank"
          )
        ),
        shiny::tags$li(
          "Anh\u00f8j J. ",
          shiny::tags$em("Det begyndte med \u00f8l \u2014 en kort historie om forbedringsmodellen."),
          " ",
          shiny::tags$a(
            href = "https://www.anhoej.net/jacob_fag_det_begyndte_med_oel.html",
            "L\u00e6s artikel", target = "_blank"
          )
        )
      )
    )
  )
}
