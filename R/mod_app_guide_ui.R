# mod_app_guide_ui.R
# App-vejledning: S\u00e5dan bruger du biSPCharts

#' App Guide Module UI
#'
#' Detaljeret trin-for-trin vejledning i brug af biSPCharts-appen.
#' Indholdet er statisk og kr\u00e6ver ingen server-logik.
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny UI element
#' @export
mod_app_guide_ui <- function(id) {
  ns <- shiny::NS(id)

  shiny::div(
    class = "container-fluid",
    style = "max-width: 900px; margin: 0 auto; padding: 30px 20px;",

    # Sidehoved
    shiny::tags$h1("S\u00e5dan bruger du appen"),
    shiny::tags$p(
      class = "lead",
      "En trin-for-trin vejledning i at uploade data, analysere med SPC og eksportere resultater."
    ),

    # Indholdsfortegnelse
    shiny::div(
      class = "card mb-4",
      shiny::div(
        class = "card-body",
        shiny::tags$h5("Indhold", class = "card-title"),
        shiny::tags$ol(
          style = "margin-bottom: 0;",
          shiny::tags$li(shiny::tags$a(href = "#guide-overblik", "Overblik")),
          shiny::tags$li(shiny::tags$a(href = "#guide-trin1", "Trin 1: Upload data")),
          shiny::tags$li(shiny::tags$a(href = "#guide-trin2", "Trin 2: Analys\u00e9r")),
          shiny::tags$li(shiny::tags$a(href = "#guide-trin3", "Trin 3: Eksport\u00e9r")),
          shiny::tags$li(shiny::tags$a(href = "#guide-tips", "Tips og genveje"))
        )
      )
    ),

    # Sektion 1: Overblik
    shiny::tags$section(
      id = "guide-overblik",
      shiny::tags$h2("Overblik"),
      shiny::tags$p(
        "Appen er bygget op om tre trin:"
      ),
      shiny::div(
        class = "row mb-3",
        shiny::tags$div(
          class = "col-md-4",
          shiny::tags$div(
            class = "card h-100 text-center",
            shiny::tags$div(
              class = "card-body",
              shiny::tags$h1(class = "display-4", "\u2460"),
              shiny::tags$h5("Upload", class = "card-title"),
              shiny::tags$p(
                class = "card-text",
                "Inds\u00e6t eller importer dine data. Appen registrerer automatisk kolonner."
              )
            )
          )
        ),
        shiny::tags$div(
          class = "col-md-4",
          shiny::tags$div(
            class = "card h-100 text-center",
            shiny::tags$div(
              class = "card-body",
              shiny::tags$h1(class = "display-4", "\u2461"),
              shiny::tags$h5("Analys\u00e9r", class = "card-title"),
              shiny::tags$p(
                class = "card-text",
                "Map kolonner, v\u00e6lg charttype og tilpas indstillinger. Diagrammet opdateres i realtid."
              )
            )
          )
        ),
        shiny::tags$div(
          class = "col-md-4",
          shiny::tags$div(
            class = "card h-100 text-center",
            shiny::tags$div(
              class = "card-body",
              shiny::tags$h1(class = "display-4", "\u2462"),
              shiny::tags$h5("Eksport\u00e9r", class = "card-title"),
              shiny::tags$p(
                class = "card-text",
                "Download som PDF-rapport eller PNG-billede med titel, datadefinition og analyse."
              )
            )
          )
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 2: Trin 1 – Upload data
    shiny::tags$section(
      id = "guide-trin1",
      shiny::tags$h2("Trin 1: Upload data"),
      shiny::tags$p(
        "Du kan indl\u00e6se data p\u00e5 fire m\u00e5der:"
      ),

      # Fire inputmetoder
      shiny::tags$h4("Inputmetoder"),
      shiny::tags$table(
        class = "table table-striped mb-4",
        shiny::tags$thead(
          shiny::tags$tr(
            shiny::tags$th("Metode"),
            shiny::tags$th("Hvorn\u00e5r"),
            shiny::tags$th("S\u00e5dan g\u00f8r du")
          )
        ),
        shiny::tags$tbody(
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Kopi\u00e9r/inds\u00e6t")),
            shiny::tags$td("Hurtig test, data fra Excel"),
            shiny::tags$td(
              "Marker celler i Excel, kopi\u00e9r (Ctrl+C), klik i tekstfeltet og inds\u00e6t (Ctrl+V)"
            )
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("XLS/CSV-fil")),
            shiny::tags$td("St\u00f8rre dataset, gentagen brug"),
            shiny::tags$td(
              "Klik \u201eUpload fil\u201c og v\u00e6lg en .xlsx, .xls eller .csv-fil fra din computer"
            )
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Eksempeldata")),
            shiny::tags$td("L\u00e6re appen at kende"),
            shiny::tags$td(
              "Klik \u201eIndl\u00e6s eksempeldata\u201c for at se appen med rigtige SPC-data"
            )
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Tom session")),
            shiny::tags$td("Starte forfra"),
            shiny::tags$td(
              "Klik \u201eNulstil\u201c for at rydde alle data og begynde p\u00e5 ny"
            )
          )
        )
      ),

      # Dataformat
      shiny::tags$h4("Dataformat"),
      shiny::tags$p(
        "Dine data skal v\u00e6re i ", shiny::tags$strong("tabelformat"),
        " med \u00e9n r\u00e6kke per observation:"
      ),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("F\u00f8rste r\u00e6kke:"),
          " Kolonnenavne (overskrifter)"
        ),
        shiny::tags$li(
          shiny::tags$strong("X-akse kolonne:"),
          " Dato eller sekventielt tal (fx m\u00e5ned, uge, l\u00f8benummer)"
        ),
        shiny::tags$li(
          shiny::tags$strong("Y-akse kolonne:"),
          " Din indikator (talv\u00e6rdi per r\u00e6kke)"
        ),
        shiny::tags$li(
          shiny::tags$strong("N\u00e6vner (valgfrit):"),
          " Kun n\u00f8dvendig ved P- og U-kort (n\u00e6ller/begivenhedsrum)"
        )
      ),
      shiny::div(
        class = "alert alert-info",
        shiny::tags$strong("Tip: "),
        "Datoer kan v\u00e6re i de fleste formater \u2014 appen parser automatisk ISO-datoer (2024-01), ",
        "danske m\u00e5nedsnavne (jan 2024) og Excel-datoer."
      ),
      shiny::tags$hr()
    ),

    # Sektion 3: Trin 2 – Analysér
    shiny::tags$section(
      id = "guide-trin2",
      shiny::tags$h2("Trin 2: Analys\u00e9r"),
      shiny::tags$p(
        "N\u00e5r data er indl\u00e6st, viser appen automatisk et seriediagram. ",
        "Du kan nu justere kolonnemap, charttype og indstillinger."
      ),

      # Kolonnemap
      shiny::tags$h4("Kolonnemapping"),
      shiny::tags$p(
        "Under ", shiny::tags$strong("Kolonnemap"),
        " fort\u00e6ller du appen, hvilke kolonner der indeholder hvad:"
      ),
      shiny::tags$table(
        class = "table table-striped mb-4",
        shiny::tags$thead(
          shiny::tags$tr(
            shiny::tags$th("Felt"),
            shiny::tags$th("Hvad det er"),
            shiny::tags$th("N\u00f8dvendigt?")
          )
        ),
        shiny::tags$tbody(
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("X-akse")),
            shiny::tags$td("Tidsakse eller sekvensnummer"),
            shiny::tags$td(
              shiny::tags$span(class = "badge bg-danger", "P\u00e5kr\u00e6vet")
            )
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Y-akse")),
            shiny::tags$td("Din m\u00e5lte indikator"),
            shiny::tags$td(
              shiny::tags$span(class = "badge bg-danger", "P\u00e5kr\u00e6vet")
            )
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("N\u00e6vner")),
            shiny::tags$td("Begivenhedsrum (f.eks. antal patienter)"),
            shiny::tags$td(
              shiny::tags$span(class = "badge bg-warning text-dark", "Kun P/U-kort")
            )
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Skift")),
            shiny::tags$td("Kolonne med 1 ved kendte process\u00e6ndringer"),
            shiny::tags$td(
              shiny::tags$span(class = "badge bg-secondary", "Valgfrit")
            )
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Frys")),
            shiny::tags$td("Kolonne der markerer, hvorn\u00e5r baseline fryses"),
            shiny::tags$td(
              shiny::tags$span(class = "badge bg-secondary", "Valgfrit")
            )
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Kommentar")),
            shiny::tags$td("Kolonne med noter der vises som annotationer p\u00e5 diagrammet"),
            shiny::tags$td(
              shiny::tags$span(class = "badge bg-secondary", "Valgfrit")
            )
          )
        )
      ),

      # Charttyper
      shiny::tags$h4("Charttyper"),
      shiny::tags$table(
        class = "table table-striped mb-4",
        shiny::tags$thead(
          shiny::tags$tr(
            shiny::tags$th("Charttype"),
            shiny::tags$th("Bruges til"),
            shiny::tags$th("Kr\u00e6ver n\u00e6vner?")
          )
        ),
        shiny::tags$tbody(
          shiny::tags$tr(
            shiny::tags$td("Seriediagram (Run)"),
            shiny::tags$td("Alle m\u00e5l \u2014 det simpleste udgangspunkt"),
            shiny::tags$td("Nej")
          ),
          shiny::tags$tr(
            shiny::tags$td("I-kort"),
            shiny::tags$td("Individuelle m\u00e5linger med kontrolgr\u00e6nser"),
            shiny::tags$td("Nej")
          ),
          shiny::tags$tr(
            shiny::tags$td("P-kort"),
            shiny::tags$td("Andele og procenter"),
            shiny::tags$td("Ja")
          ),
          shiny::tags$tr(
            shiny::tags$td("C-kort"),
            shiny::tags$td("T\u00e6llinger (antal h\u00e6ndelser)"),
            shiny::tags$td("Nej")
          ),
          shiny::tags$tr(
            shiny::tags$td("U-kort"),
            shiny::tags$td("Rater (h\u00e6ndelser per enhed)"),
            shiny::tags$td("Ja")
          )
        )
      ),

      # Indstillinger
      shiny::tags$h4("Indstillinger"),
      shiny::tags$dl(
        class = "row",
        shiny::tags$dt(class = "col-sm-3", "Y-akse enhed"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Tekst der vises p\u00e5 Y-aksen og i PDF-rapporten (f.eks. \u201edage\u201c, \u201epct.\u201c, \u201eantal\u201c)"
        ),
        shiny::tags$dt(class = "col-sm-3", "Udviklingsm\u00e5l"),
        shiny::tags$dd(
          class = "col-sm-9",
          "V\u00e6lges som en vandret stiplet linje p\u00e5 diagrammet. Angiv et tal svarende til m\u00e5l-v\u00e6rdien p\u00e5 Y-aksen."
        ),
        shiny::tags$dt(class = "col-sm-3", "Baseline"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Angiv f\u00f8rste og sidste observation der bruges til beregning af centrallinje og kontrolgr\u00e6nser. ",
          "Som standard bruges alle data."
        )
      ),

      # Value boxes
      shiny::tags$h4("Afl\u00e6s value boxes"),
      shiny::tags$p(
        "Under diagrammet vises fire value boxes med Anh\u00f8j-information:"
      ),
      shiny::tags$dl(
        class = "row",
        shiny::tags$dt(class = "col-sm-3", "Observationer"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Antal datapunkter der indg\u00e5r i analysen (ekskl. manglende v\u00e6rdier)"
        ),
        shiny::tags$dt(class = "col-sm-3", "Seriel\u00e6ngde"),
        shiny::tags$dd(
          class = "col-sm-9",
          "L\u00e6ngden af den l\u00e6ngste serie konsekutive punkter p\u00e5 samme side af medianen. ",
          "Orange/r\u00f8d farve indikerer signal."
        ),
        shiny::tags$dt(class = "col-sm-3", "Krydsninger"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Antal gange dataserien krydser medianen. For f\u00e5 krydsninger indikerer clustering. ",
          "Orange/r\u00f8d farve indikerer signal."
        ),
        shiny::tags$dt(class = "col-sm-3", "Signal"),
        shiny::tags$dd(
          class = "col-sm-9",
          "\u201eJa\u201c hvis Anh\u00f8j-reglerne detekterer ikke-tilf\u00e6ldig variation. ",
          "\u201eNej\u201c hvis processen ser stabil ud."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 4: Trin 3 – Eksportér
    shiny::tags$section(
      id = "guide-trin3",
      shiny::tags$h2("Trin 3: Eksport\u00e9r"),
      shiny::tags$p(
        "P\u00e5 eksportsiden kan du udfylde metadata og downloade dit diagram."
      ),

      # PDF vs PNG
      shiny::tags$h4("PDF vs. PNG"),
      shiny::tags$div(
        class = "row mb-3",
        shiny::tags$div(
          class = "col-md-6",
          shiny::tags$div(
            class = "card h-100",
            shiny::tags$div(
              class = "card-body",
              shiny::tags$h5("PDF-rapport", class = "card-title"),
              shiny::tags$p(
                class = "card-text",
                "Inkluderer titel, datadefinition, analysetekst og diagrammet. ",
                "Egner sig til rapportering og arkivering."
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
              shiny::tags$h5("PNG-billede", class = "card-title"),
              shiny::tags$p(
                class = "card-text",
                "Kun selve diagrammet som billede. ",
                "Egner sig til inds\u00e6ttelse i pr\u00e6sentationer, Word-dokumenter og e-mails."
              )
            )
          )
        )
      ),

      # Metadatafelter
      shiny::tags$h4("Metadatafelter"),
      shiny::tags$dl(
        class = "row",
        shiny::tags$dt(class = "col-sm-3", "Titel"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Diagrammets overskrift \u2014 vises \u00f8verst i b\u00e5de PDF og PNG"
        ),
        shiny::tags$dt(class = "col-sm-3", "Datadefinition"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Beskrivelse af hvad der m\u00e5les og hvordan: hvem taller, hvad er inkluderet, ",
          "hvilken periode og eventuelle undtagelser"
        ),
        shiny::tags$dt(class = "col-sm-3", "Analyse"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Fritekstfelt til din fortolkning af diagrammet. Appen genererer automatisk et udkast ",
          "baseret p\u00e5 signalstatus og charttype."
        )
      ),

      # AI-feature
      shiny::tags$h4("AI-forbedringsforslag"),
      shiny::tags$p(
        "Klik p\u00e5 ", shiny::tags$strong("\u201eF\u00e5 AI-forslag\u201c"),
        " for at f\u00e5 et SPC-relevant forbedringsforslag baseret p\u00e5 dit diagram. ",
        "Forslaget tager h\u00f8jde for charttype, signalstatus, datadefinition og udviklingsm\u00e5l."
      ),
      shiny::div(
        class = "alert alert-info",
        shiny::tags$strong("Bem\u00e6rk: "),
        "AI-forslaget er vejledende. Genneml\u00e6s og tilpas altid teksten, ",
        "s\u00e5 den afspejler din lokale kontekst og viden om processen."
      ),
      shiny::tags$hr()
    ),

    # Sektion 5: Tips og genveje
    shiny::tags$section(
      id = "guide-tips",
      shiny::tags$h2("Tips og genveje"),
      shiny::tags$dl(
        class = "row",
        shiny::tags$dt(class = "col-sm-4", "Gem en kopi"),
        shiny::tags$dd(
          class = "col-sm-8",
          "Appen gemmer automatisk din session i browseren. N\u00e6ste gang du \u00e5bner appen, ",
          "tilbyder den at gendanne dine data og indstillinger."
        ),
        shiny::tags$dt(class = "col-sm-4", "Rediger data"),
        shiny::tags$dd(
          class = "col-sm-8",
          "Klik p\u00e5 tabellen under diagrammet for at \u00e6ndre enkeltv\u00e6rdier direkte ",
          "uden at uploade filen igen."
        ),
        shiny::tags$dt(class = "col-sm-4", "Tilf\u00f8j kolonner"),
        shiny::tags$dd(
          class = "col-sm-8",
          "Brug tabeleditoren til at tilf\u00f8je en ny kolonne (f.eks. Skift eller Kommentar), ",
          "hvis din kildefil ikke indeholder den."
        ),
        shiny::tags$dt(class = "col-sm-4", "Omd\u00f8b kolonner"),
        shiny::tags$dd(
          class = "col-sm-8",
          "Klik p\u00e5 et kolonnenavn i tabeleditoren for at omd\u00f8be det. ",
          "Kolonnemap opdateres automatisk."
        ),
        shiny::tags$dt(class = "col-sm-4", "Eksempeldata"),
        shiny::tags$dd(
          class = "col-sm-8",
          "Brug \u201eIndl\u00e6s eksempeldata\u201c til at udforske alle charttyper og indstillinger ",
          "inden du bruger dine egne data."
        )
      )
    )
  )
}
