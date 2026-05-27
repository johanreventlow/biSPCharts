# mod_help_ui.R
# Hjaelpeside: Laer om SPC

#' Help Module UI
#'
#' Introduktion til SPC-begreber og praktisk brug i biSPCharts.
#' Indholdet er statisk og kraever ingen server-logik.
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny UI element
#' @keywords internal
mod_help_ui <- function(id) {
  ns <- shiny::NS(id)

  help_image <- function(src, alt, caption) {
    shiny::tags$div(
      class = "text-center my-3",
      shiny::tags$img(
        src = src,
        alt = alt,
        class = "img-fluid rounded shadow-sm",
        style = "max-width: 700px;"
      ),
      shiny::tags$p(class = "text-muted small mt-1", caption)
    )
  }

  shiny::div(
    class = "container-fluid info-page",
    style = "max-width: 900px; margin: 0 auto; padding: 30px 20px;",

    # Tilbagelink til forrige side
    help_back_link(ns),
    shiny::tags$h1("L\u00e6r om SPC"),
    shiny::tags$p(
      class = "lead",
      "SPC hj\u00e6lper dig med at se, om en proces varierer tilf\u00e6ldigt \u2014 alts\u00e5 naturligt \u2014 ",
      "eller om der er tegn p\u00e5 en reel \u00e6ndring."
    ),
    shiny::tags$p(
      "Denne side forklarer de vigtigste begreber, du m\u00f8der i biSPCharts: ",
      "variation, seriediagrammer, Anh\u00f8j-regler, kontrolgr\u00e6nser og valg af charttype. ",
      "Hvis du leder efter den konkrete klik-for-klik arbejdsgang, ",
      "s\u00e5 brug linket \u201eS\u00e5dan bruger du appen\u201c p\u00e5 velkomstsiden."
    ),

    # Ankerlinks
    shiny::div(
      class = "card mb-4",
      shiny::div(
        class = "card-body",
        shiny::tags$h5("Indhold", class = "card-title"),
        shiny::tags$ol(
          style = "margin-bottom: 0;",
          shiny::tags$li(shiny::tags$a(href = "#spc-hvad", "Hvad er SPC?")),
          shiny::tags$li(shiny::tags$a(href = "#spc-data", "SPC starter med data over tid")),
          shiny::tags$li(shiny::tags$a(href = "#spc-variation", "To typer variation")),
          shiny::tags$li(shiny::tags$a(href = "#spc-laes", "S\u00e5dan l\u00e6ser du et seriediagram")),
          shiny::tags$li(shiny::tags$a(href = "#spc-anhoej", "Anh\u00f8j-reglerne")),
          shiny::tags$li(shiny::tags$a(href = "#spc-kontrol", "Kontroldiagrammer og kontrolgr\u00e6nser")),
          shiny::tags$li(shiny::tags$a(href = "#spc-chartvalg", "Hvilken charttype skal jeg v\u00e6lge?")),
          shiny::tags$li(shiny::tags$a(href = "#spc-appvalg", "M\u00e5l, baseline, skift og frys")),
          shiny::tags$li(shiny::tags$a(href = "#spc-fortolkning", "Fra signal til handling")),
          shiny::tags$li(shiny::tags$a(href = "#spc-raad", "Typiske faldgruber")),
          shiny::tags$li(shiny::tags$a(href = "#spc-litteratur", "Videre l\u00e6sning"))
        )
      )
    ),

    # Section 1: What is SPC?
    shiny::tags$section(
      id = "spc-hvad",
      shiny::tags$h2("Hvad er SPC?"),
      shiny::tags$p(
        "SPC st\u00e5r for ",
        shiny::tags$em("Statistical Process Control."),
        " Det er en metode til at forst\u00e5 variation i processer over tid."
      ),
      shiny::tags$p(
        "I klinisk kvalitetsarbejde er pointen enkel: Data varierer altid. ",
        "SPC hj\u00e6lper dig med at skelne mellem almindelige udsving og signaler, ",
        "der kan betyde, at processen faktisk har \u00e6ndret sig."
      ),
      shiny::div(
        class = "alert alert-info",
        shiny::tags$strong("Kort sagt: "),
        "SPC svarer ikke bare p\u00e5 om et tal er h\u00f8jt eller lavt. ",
        "SPC hj\u00e6lper dig med at vurdere, om udviklingen over tid ser stabil, ",
        "forbedret eller ustabil ud."
      ),
      help_image(
        "www/help/01-run-chart-stabil.png",
        "Seriediagram der viser en stabil proces",
        "En stabil proces: Punkterne varierer omkring midterlinjen uden tydeligt signal."
      ),
      shiny::tags$hr()
    ),

    # Section 2: Data over time
    shiny::tags$section(
      id = "spc-data",
      shiny::tags$h2("SPC starter med data over tid"),
      shiny::tags$p(
        "SPC virker bedst, n\u00e5r du f\u00f8lger den samme indikator p\u00e5 samme m\u00e5de over tid. ",
        "R\u00e6kkef\u00f8lgen er afg\u00f8rende. Et gennemsnit eller en f\u00f8r/efter-sammenligning ",
        "kan skjule, om processen var stabil, gradvist forbedret eller pr\u00e6get af enkelte udsving."
      ),
      shiny::tags$h4("Gode data til SPC har typisk"),
      shiny::tags$ul(
        shiny::tags$li("en tydelig tids- eller r\u00e6kkef\u00f8lgekolonne, fx m\u00e5ned, uge eller dato"),
        shiny::tags$li("en ensartet definition af hvad der t\u00e6lles eller m\u00e5les"),
        shiny::tags$li("nok datapunkter til at vurdere m\u00f8nstre over tid"),
        shiny::tags$li("en relevant n\u00e6vner, hvis du arbejder med andele eller rater"),
        shiny::tags$li("noter om kendte proces\u00e6ndringer, ferieperioder, databrud eller kampagner")
      ),
      shiny::div(
        class = "alert alert-warning",
        shiny::tags$strong("Pas p\u00e5 databrud: "),
        "Hvis definitionen, datakilden eller opg\u00f8relsesmetoden \u00e6ndrer sig, ",
        "kan diagrammet vise et signal, der skyldes m\u00e5den data er opgjort p\u00e5 ",
        "\u2014 ikke en reel proces\u00e6ndring."
      ),
      shiny::tags$hr()
    ),

    # Section 3: Variation
    shiny::tags$section(
      id = "spc-variation",
      shiny::tags$h2("To typer variation"),
      shiny::tags$p(
        "Den vigtigste skelnen i SPC er mellem tilf\u00e6ldig variation og ikke-tilf\u00e6ldig variation."
      ),
      shiny::div(
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
                "Ogs\u00e5 kaldet ",
                shiny::tags$em("common cause variation"),
                ". Det er den naturlige st\u00f8j, der findes i alle processer. ",
                "Processen er forudsigelig inden for sit normale niveau."
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
              shiny::tags$h5("Ikke-tilf\u00e6ldig (eller s\u00e6rlig) variation", class = "card-title text-danger"),
              shiny::tags$p(
                class = "card-text",
                "Ogs\u00e5 kaldet ",
                shiny::tags$em("special cause variation"),
                ". Det er tegn p\u00e5, at noget us\u00e6dvanligt kan v\u00e6re sket. ",
                "Processen b\u00f8r unders\u00f8ges, f\u00f8r man konkluderer."
              )
            )
          )
        )
      ),
      shiny::div(
        class = "alert alert-warning",
        shiny::tags$strong("Undg\u00e5 tampering: "),
        "Hvis du reagerer p\u00e5 tilf\u00e6ldige udsving, som om de var reelle \u00e6ndringer, ",
        "kan du g\u00f8re processen mere ustabil. SPC hj\u00e6lper med at undg\u00e5 den fejl."
      ),
      shiny::tags$p(
        "En stabil proces er ikke n\u00f8dvendigvis en god proces. Den er bare forudsigelig. ",
        "Hvis niveauet er utilfredsstillende, kr\u00e6ver forbedring typisk en \u00e6ndring af selve systemet."
      ),
      help_image(
        "www/help/02-niveauskift.png",
        "Proces med tydeligt niveauskift",
        "Proces med et tydeligt niveauskift."
      ),
      shiny::tags$hr()
    ),

    # Section 4: Read run chart
    shiny::tags$section(
      id = "spc-laes",
      shiny::tags$h2("S\u00e5dan l\u00e6ser du et seriediagram"),
      shiny::tags$p(
        "Et seriediagram er det bedste sted at starte. Det viser dine datapunkter i r\u00e6kkef\u00f8lge ",
        "og l\u00e6gger en midterlinje ind, s\u00e5 du kan se m\u00f8nstre over tid."
      ),
      shiny::tags$dl(
        class = "row",
        shiny::tags$dt(class = "col-sm-3", "Punkter"),
        shiny::tags$dd(class = "col-sm-9", "Hver observation i dataserien."),
        shiny::tags$dt(class = "col-sm-3", "Linje"),
        shiny::tags$dd(class = "col-sm-9", "Forbinder punkterne, s\u00e5 udviklingen over tid bliver synlig."),
        shiny::tags$dt(class = "col-sm-3", "Midterlinje"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Viser processens nuv\u00e6rende niveau og kaldes derfor \u201eNuv. niveau\u201c p\u00e5 grafen. ",
          "I seriediagrammer er midterlinjen typisk medianen. I kontroldiagrammer er den typisk ",
          "et gennemsnit eller en beregnet middelv\u00e6rdi."
        ),
        shiny::tags$dt(class = "col-sm-3", "Serie"),
        shiny::tags$dd(class = "col-sm-9", "Flere punkter efter hinanden p\u00e5 samme side af midterlinjen."),
        shiny::tags$dt(class = "col-sm-3", "Kryds"),
        shiny::tags$dd(class = "col-sm-9", "N\u00e5r linjen krydser midterlinjen.")
      ),
      help_image(
        "www/help/03-seriediagram-annoteret.png",
        "Seriediagram med annotationer der viser midterlinje, serie og kryds",
        "Et seriediagram med midterlinje, markeret serie og kryds."
      ),
      shiny::tags$hr()
    ),

    # Section 5: Anhoej
    shiny::tags$section(
      id = "spc-anhoej",
      shiny::tags$h2("Anh\u00f8j-reglerne"),
      shiny::tags$p(
        "Anh\u00f8j-reglerne er to statistiske tests, der bruges til at finde tegn p\u00e5 ",
        "ikke-tilf\u00e6ldig variation i seriediagrammer."
      ),
      shiny::div(
        class = "card mb-3",
        shiny::div(
          class = "card-body",
          shiny::tags$h5("Regel 1: Seriel\u00e6ngde", class = "card-title"),
          shiny::tags$p(
            class = "card-text",
            "Hvis den l\u00e6ngste serie af punkter p\u00e5 samme side af midterlinjen er l\u00e6ngere end forventet, ",
            "er der tegn p\u00e5 et niveauskift i processen."
          )
        )
      ),
      shiny::div(
        class = "card mb-3",
        shiny::div(
          class = "card-body",
          shiny::tags$h5("Regel 2: Antal kryds", class = "card-title"),
          shiny::tags$p(
            class = "card-text",
            "Hvis linjen krydser midterlinjen f\u00e6rre gange end forventet, kan det tyde p\u00e5 clustering, ",
            "stratificering eller en trend i data."
          )
        )
      ),
      shiny::div(
        class = "alert alert-info",
        shiny::tags$strong("I biSPCharts: "),
        "Signalboksene viser blandt andet seriel\u00e6ngde og antal kryds. ",
        "Farvemarkering betyder, at appen har fundet et signal, som b\u00f8r vurderes fagligt."
      ),
      shiny::tags$p(
        "Reglerne kr\u00e6ver ikke, at data er normalfordelte. De bliver dog mere meningsfulde, ",
        "n\u00e5r der er nok datapunkter. Ved meget korte serier skal resultaterne tolkes forsigtigt."
      ),
      help_image(
        "www/help/04-anhoej-signal.png",
        "Diagram med Anh\u00f8j-signal detekteret og value boxes",
        "Et diagram med signal. Boksene hj\u00e6lper med at vise, hvilken regel der er udslagsgivende."
      ),
      shiny::tags$hr()
    ),

    # Section 6: Control charts
    shiny::tags$section(
      id = "spc-kontrol",
      shiny::tags$h2("Kontroldiagrammer og kontrolgr\u00e6nser"),
      shiny::tags$p(
        "Kontroldiagrammer tilf\u00f8jer kontrolgr\u00e6nser omkring midterlinjen. ",
        "Gr\u00e6nserne beregnes ud fra processens variation og viser, hvor langt man normalt kan forvente, ",
        "at data varierer, hvis processen er stabil."
      ),
      shiny::tags$p(
        "Punkter uden for kontrolgr\u00e6nserne er st\u00e6rke signaler om ikke-tilf\u00e6ldig variation. ",
        "De skal ikke bare ignoreres som st\u00f8j, men de skal heller ikke tolkes uden lokal viden."
      ),
      shiny::div(
        class = "alert alert-light border",
        shiny::tags$strong("Kontrolgr\u00e6nser er ikke m\u00e5lgr\u00e6nser. "),
        "Et udviklingsm\u00e5l viser, hvor I gerne vil hen. Kontrolgr\u00e6nser viser, ",
        "hvad processen naturligt producerer lige nu."
      ),
      help_image(
        "www/help/05-p-chart.png",
        "P-kort med kontrolgr\u00e6nser",
        "Et P-kort med kontrolgr\u00e6nser. Punkter uden for gr\u00e6nserne er markeret."
      ),
      shiny::tags$hr()
    ),

    # Section 7: Chart chooser
    shiny::tags$section(
      id = "spc-chartvalg",
      shiny::tags$h2("Hvilken charttype skal jeg v\u00e6lge?"),
      shiny::tags$p(
        "Start med seriediagram, hvis du er i tvivl. V\u00e6lg derefter en kontrolcharttype, ",
        "hvis du ved hvilken type data du arbejder med."
      ),
      shiny::tags$table(
        class = "table table-striped",
        shiny::tags$thead(
          shiny::tags$tr(
            shiny::tags$th("Type"),
            shiny::tags$th("Bruges til"),
            shiny::tags$th("N\u00e6vner?"),
            shiny::tags$th("Eksempel")
          )
        ),
        shiny::tags$tbody(
          shiny::tags$tr(
            shiny::tags$td("Seriediagram (Run)"),
            shiny::tags$td("F\u00f8rste overblik over udvikling over tid"),
            shiny::tags$td("Valgfrit"),
            shiny::tags$td("Ventetid eller andel per m\u00e5ned")
          ),
          shiny::tags$tr(
            shiny::tags$td("I-kort"),
            shiny::tags$td("Individuelle m\u00e5linger med kontrolgr\u00e6nser"),
            shiny::tags$td("Nej"),
            shiny::tags$td("Liggetid, svartid, score")
          ),
          shiny::tags$tr(
            shiny::tags$td("P-kort"),
            shiny::tags$td("Andele og procenter"),
            shiny::tags$td("Ja"),
            shiny::tags$td("Andel patienter med komplikation")
          ),
          shiny::tags$tr(
            shiny::tags$td("U-kort"),
            shiny::tags$td("Rater, hvor observationsm\u00e6ngden varierer"),
            shiny::tags$td("Ja"),
            shiny::tags$td("Infektioner per 1.000 sengedage")
          ),
          shiny::tags$tr(
            shiny::tags$td("C-kort"),
            shiny::tags$td("T\u00e6llinger, n\u00e5r observationsmuligheden er nogenlunde konstant"),
            shiny::tags$td("Nej"),
            shiny::tags$td("Antal fald per m\u00e5ned p\u00e5 samme enhed")
          )
        )
      ),
      shiny::div(
        class = "alert alert-light border",
        shiny::tags$strong("N\u00e6vner i seriediagram: "),
        "Et seriediagram kan godt bruges med n\u00e6vner, fx hvis du vil vise en andel over tid. ",
        "N\u00e6vneren er bare ikke p\u00e5kr\u00e6vet for at lave et seriediagram."
      ),
      shiny::tags$hr()
    ),

    # Section 8: App choices
    shiny::tags$section(
      id = "spc-appvalg",
      shiny::tags$h2("M\u00e5l, baseline, skift og frys"),
      shiny::tags$p(
        "Nogle af appens valg lyder ens, men de betyder forskellige ting."
      ),
      shiny::tags$dl(
        class = "row",
        shiny::tags$dt(class = "col-sm-3", "Udviklingsm\u00e5l"),
        shiny::tags$dd(
          class = "col-sm-9",
          "En visuel m\u00e5llinje. Den viser ambitionen, men \u00e6ndrer ikke beregningerne."
        ),
        shiny::tags$dt(class = "col-sm-3", "Evt. baseline"),
        shiny::tags$dd(
          class = "col-sm-9",
          "En fast midterlinje, hvis du vil sammenligne mod en kendt v\u00e6rdi."
        ),
        shiny::tags$dt(class = "col-sm-3", "Skift"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Markerer kendte proces\u00e6ndringer eller faser i diagrammet."
        ),
        shiny::tags$dt(class = "col-sm-3", "Frys"),
        shiny::tags$dd(
          class = "col-sm-9",
          "L\u00e5ser kontrolgr\u00e6nser ud fra en baseline-periode, s\u00e5 senere data sammenlignes med det niveau."
        )
      ),
      shiny::div(
        class = "alert alert-info",
        shiny::tags$strong("Praktisk tommelfingerregel: "),
        "Brug udviklingsm\u00e5l til ambitionen, skift til kendte \u00e6ndringer i processen, ",
        "og frys n\u00e5r I bevidst vil fastholde en baseline som sammenligningsgrundlag."
      ),
      shiny::tags$hr()
    ),

    # Section 9: Interpretation
    shiny::tags$section(
      id = "spc-fortolkning",
      shiny::tags$h2("Fra signal til handling"),
      shiny::tags$p(
        "Et SPC-signal er starten p\u00e5 en faglig vurdering \u2014 ikke slutningen. ",
        "Appen kan vise, at et m\u00f8nster er us\u00e6dvanligt, men den kan ikke alene forklare hvorfor."
      ),
      shiny::tags$h4("Gode sp\u00f8rgsm\u00e5l n\u00e5r der er signal"),
      shiny::tags$ul(
        shiny::tags$li("Skete der en kendt proces\u00e6ndring omkring tidspunktet?"),
        shiny::tags$li("Er datadefinitionen eller datakilden \u00e6ndret?"),
        shiny::tags$li("Er signalet klinisk meningsfuldt eller kun statistisk synligt?"),
        shiny::tags$li("Er forbedringen stabil over tid, eller hviler den p\u00e5 f\u00e5 punkter?"),
        shiny::tags$li("Hvad ved medarbejdere og ledere om perioden, som diagrammet ikke viser?")
      ),
      shiny::tags$p(
        "N\u00e5r du eksporterer en rapport, b\u00f8r analysen derfor kombinere signalstatus, ",
        "datadefinition og lokal viden om processen."
      ),
      shiny::tags$hr()
    ),

    # Section 10: Pitfalls
    shiny::tags$section(
      id = "spc-raad",
      shiny::tags$h2("Typiske faldgruber"),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("For f\u00e5 datapunkter: "),
          "Meget korte serier kan give usikre signalvurderinger. ",
          "Brug derfor mindst 12 datapunkter i en serie \u2014 og helst 20 eller flere \u2014 ",
          "f\u00f8r signalvurderingen till\u00e6gges stor v\u00e6gt."
        ),
        shiny::tags$li(
          shiny::tags$strong("Forkert n\u00e6vner: "),
          "P- og U-kort afh\u00e6nger af en meningsfuld n\u00e6vner."
        ),
        shiny::tags$li(
          shiny::tags$strong("Data uden tidsorden: "),
          "SPC handler om proces over tid. R\u00e6kkef\u00f8lgen m\u00e5 ikke v\u00e6re tilf\u00e6ldig."
        ),
        shiny::tags$li(
          shiny::tags$strong("For hurtige konklusioner: "),
          "Et enkelt h\u00f8jt eller lavt punkt er ikke automatisk en forbedring eller forv\u00e6rring."
        ),
        shiny::tags$li(
          shiny::tags$strong("Skift markeret efter resultatet: "),
          "Skift b\u00f8r afspejle kendte proces\u00e6ndringer, ikke bruges til at forklare et signal bagefter."
        )
      ),
      shiny::tags$hr()
    ),

    # Section 11: Further reading
    shiny::tags$section(
      id = "spc-litteratur",
      shiny::tags$h2("Videre l\u00e6sning"),
      shiny::tags$p(
        "Hvis du vil dykke dybere ned i SPC, er disse kilder gode at starte med:"
      ),
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
        )
      )
    )
  )
}
