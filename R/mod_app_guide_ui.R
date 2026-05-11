# mod_app_guide_ui.R
# App-vejledning: Saadan bruger du biSPCharts

#' App Guide Module UI
#'
#' Praktisk trin-for-trin vejledning i brug af biSPCharts-appen.
#' Indholdet er statisk og kraever ingen server-logik.
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny UI element
#' @keywords internal
mod_app_guide_ui <- function(id) {
  ns <- shiny::NS(id)

  screenshot_placeholder <- function(title, description, suggestion) {
    shiny::div(
      class = "alert alert-light border my-3",
      style = paste(
        "border-style: dashed !important;",
        "background-color: #fafafa;",
        "color: #555;"
      ),
      shiny::tags$strong(title),
      shiny::tags$p(class = "mb-1 mt-2", description),
      shiny::tags$small(
        class = "text-muted",
        shiny::tags$strong("Screenshot-forslag: "),
        suggestion
      )
    )
  }

  shiny::div(
    class = "container-fluid",
    style = "max-width: 900px; margin: 0 auto; padding: 30px 20px;",

    # Tilbagelink til forrige side
    help_back_link(ns),

    # Sidehoved
    shiny::tags$h1("S\u00e5dan bruger du appen"),
    shiny::tags$p(
      class = "lead",
      "biSPCharts hj\u00e6lper dig fra data til f\u00e6rdigt SPC-diagram i tre trin: upload, analyse og eksport."
    ),
    shiny::tags$p(
      "Denne side handler om selve arbejdsgangen i appen. Hvis du vil forst\u00e5 ",
      "SPC, variation, Anh\u00f8j-regler og kontrolgr\u00e6nser, s\u00e5 brug siden \u201eL\u00e6r om SPC\u201c."
    ),

    # Indholdsfortegnelse
    shiny::div(
      class = "card mb-4",
      shiny::div(
        class = "card-body",
        shiny::tags$h5("Indhold", class = "card-title"),
        shiny::tags$ol(
          style = "margin-bottom: 0;",
          shiny::tags$li(shiny::tags$a(href = "#guide-upload", "1. Upload data")),
          shiny::tags$li(shiny::tags$a(href = "#guide-kolonner", "2. Tildel kolonner")),
          shiny::tags$li(shiny::tags$a(href = "#guide-diagram", "3. Just\u00e9r diagrammet")),
          shiny::tags$li(shiny::tags$a(href = "#guide-laes", "4. L\u00e6s diagrammet")),
          shiny::tags$li(shiny::tags$a(href = "#guide-rediger", "5. Redig\u00e9r data ved behov")),
          shiny::tags$li(shiny::tags$a(href = "#guide-eksport", "6. Eksport\u00e9r")),
          shiny::tags$li(shiny::tags$a(href = "#guide-gem", "7. Gem arbejdet")),
          shiny::tags$li(shiny::tags$a(href = "#guide-screenshots", "Forslag til screenshots"))
        )
      )
    ),

    # Sektion 1: Upload data
    shiny::tags$section(
      id = "guide-upload",
      shiny::tags$h2("1. Upload data"),
      shiny::tags$p(
        "Start med at v\u00e6lge, hvordan du vil indl\u00e6se data:"
      ),
      shiny::tags$dl(
        class = "row",
        shiny::tags$dt(class = "col-sm-4", "Kopi\u00e9r & Inds\u00e6t data"),
        shiny::tags$dd(
          class = "col-sm-8",
          "Brug denne, hvis dine data ligger i Excel. Mark\u00e9r tabellen inkl. ",
          "kolonneoverskrifter, kopi\u00e9r den, inds\u00e6t den i feltet og klik ",
          shiny::tags$strong("Forts\u00e6t.")
        ),
        shiny::tags$dt(class = "col-sm-4", "Indl\u00e6s XLS/CSV"),
        shiny::tags$dd(
          class = "col-sm-8",
          "Brug denne, hvis du har en Excel- eller CSV-fil. Du kan ogs\u00e5 ",
          "indl\u00e6se en tidligere gemt biSPCharts-fil."
        ),
        shiny::tags$dt(class = "col-sm-4", "Pr\u00f8v med eksempeldata"),
        shiny::tags$dd(
          class = "col-sm-8",
          "Brug eksempeldata, hvis du vil l\u00e6re appen at kende eller teste ",
          "forskellige diagramtyper."
        ),
        shiny::tags$dt(class = "col-sm-4", "Blank session"),
        shiny::tags$dd(
          class = "col-sm-8",
          "Brug denne, hvis du vil starte helt forfra."
        )
      ),
      shiny::div(
        class = "alert alert-info",
        shiny::tags$strong("Dataformat: "),
        "Dine data skal v\u00e6re en almindelig tabel med \u00e9n r\u00e6kke per ",
        "observation. Du skal som minimum have en kolonne til tid/kategori ",
        "og en kolonne med den v\u00e6rdi, du vil f\u00f8lge."
      ),
      screenshot_placeholder(
        "Illustration kommer: Upload-trinnet",
        "Her kan et screenshot vise de fire uploadvalg og paste-feltet.",
        paste(
          "Vis hele upload-siden med knapperne Kopi\u00e9r & Inds\u00e6t data,",
          "Indl\u00e6s XLS/CSV, Pr\u00f8v med eksempeldata og Blank session."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 2: Tildel kolonner
    shiny::tags$section(
      id = "guide-kolonner",
      shiny::tags$h2("2. Tildel kolonner"),
      shiny::tags$p(
        "N\u00e5r data er indl\u00e6st, viser appen tabellen og et forel\u00f8bigt ",
        "diagram. Klik ",
        shiny::tags$strong("Tildel kolonner"),
        " og kontroll\u00e9r, at appen har forst\u00e5et data korrekt."
      ),
      shiny::tags$table(
        class = "table table-striped mb-4",
        shiny::tags$thead(
          shiny::tags$tr(
            shiny::tags$th("Felt"),
            shiny::tags$th("Betydning")
          )
        ),
        shiny::tags$tbody(
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Tid/kategori (X-akse)")),
            shiny::tags$td("Dato, m\u00e5ned, uge eller observationsnummer.")
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("T\u00e6ller (Y-akse)")),
            shiny::tags$td("Den v\u00e6rdi du vil f\u00f8lge over tid.")
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("N\u00e6vner")),
            shiny::tags$td("Bruges ved andele og rater, fx patienter, forl\u00f8b eller sengedage.")
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Skift")),
            shiny::tags$td("Markerer kendte proces\u00e6ndringer eller nye faser.")
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Frys")),
            shiny::tags$td("Markerer hvor kontrolgr\u00e6nser skal l\u00e5ses ud fra en baseline-periode.")
          ),
          shiny::tags$tr(
            shiny::tags$td(shiny::tags$strong("Kommentar")),
            shiny::tags$td("Noter der kan vises p\u00e5 diagrammet.")
          )
        )
      ),
      shiny::div(
        class = "alert alert-warning",
        shiny::tags$strong("Vigtigt: "),
        "Kontroll\u00e9r altid kolonnemappingen. Hvis X-akse, t\u00e6ller eller ",
        "n\u00e6vner er forkert valgt, bliver diagrammet ogs\u00e5 forkert."
      ),
      screenshot_placeholder(
        "Illustration kommer: Tildel kolonner",
        paste(
          "Her kan et screenshot vise dialogen hvor kolonner tildeles til X-akse,",
          "t\u00e6ller, n\u00e6vner, skift, frys og kommentar."
        ),
        paste(
          "Vis kolonnemapping-dialogen med et realistisk datas\u00e6t,",
          "gerne hvor auto-detekteringen allerede har foresl\u00e5et felter."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 3: Juster diagrammet
    shiny::tags$section(
      id = "guide-diagram",
      shiny::tags$h2("3. Just\u00e9r diagrammet"),
      shiny::tags$p(
        "Under ",
        shiny::tags$strong("Indstillinger"),
        " v\u00e6lger du diagramtype og visning. Start med ",
        shiny::tags$strong("Seriediagram (Run),"),
        " hvis du er i tvivl. Det er ofte det bedste f\u00f8rste overblik."
      ),
      shiny::tags$p(
        "Brug \u201eL\u00e6r om SPC\u201c, hvis du er usikker p\u00e5 forskellen mellem I-, P-, U- og C-kort."
      ),
      shiny::tags$dl(
        class = "row",
        shiny::tags$dt(class = "col-sm-4", "Y-akse enhed"),
        shiny::tags$dd(
          class = "col-sm-8",
          "V\u00e6lg hvordan v\u00e6rdierne skal vises, fx tal, procent, rate eller tid."
        ),
        shiny::tags$dt(class = "col-sm-4", "Udviklingsm\u00e5l"),
        shiny::tags$dd(
          class = "col-sm-8",
          "En m\u00e5llinje i diagrammet, fx ",
          shiny::tags$code(">=90%"),
          ", ",
          shiny::tags$code("<25"),
          " eller ",
          shiny::tags$code("0,8"),
          ". M\u00e5let hj\u00e6lper l\u00e6seren, men \u00e6ndrer ikke SPC-beregningerne."
        ),
        shiny::tags$dt(class = "col-sm-4", "Evt. baseline"),
        shiny::tags$dd(
          class = "col-sm-8",
          "En fast midterlinje, hvis du vil sammenligne mod en kendt v\u00e6rdi. ",
          "Hvis du vil l\u00e5se kontrolgr\u00e6nser ud fra en baseline-periode i data, ",
          "skal du bruge ",
          shiny::tags$strong("Frys-kolonnen.")
        )
      ),
      shiny::div(
        class = "alert alert-light border",
        shiny::tags$strong("Midterlinje / Nuv. niveau: "),
        "Grafens midterlinje kaldes ",
        shiny::tags$strong("\u201eNuv. niveau\u201c."),
        " Den viser det niveau, processen aktuelt ligger omkring. ",
        "I seriediagrammer er midterlinjen typisk medianen. I kontroldiagrammer ",
        "er den typisk et gennemsnit eller en beregnet middelv\u00e6rdi. ",
        "Midterlinjen er ikke det samme som udviklingsm\u00e5let: M\u00e5let viser, ",
        "hvor I gerne vil hen; midterlinjen viser, hvor processen ser ud til at v\u00e6re nu."
      ),
      screenshot_placeholder(
        "Illustration kommer: Analyse-trinnet",
        "Her kan et screenshot vise datatabel, SPC-preview, indstillingspanel og signalbokse samlet.",
        paste(
          "Vis analyse-siden efter data er indl\u00e6st, med Tildel kolonner-knappen,",
          "diagramtype, Y-akse enhed, udviklingsm\u00e5l og baseline synlige."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 4: Laes diagrammet
    shiny::tags$section(
      id = "guide-laes",
      shiny::tags$h2("4. L\u00e6s diagrammet"),
      shiny::tags$p(
        "Diagrammet opdateres automatisk, n\u00e5r du \u00e6ndrer data eller ",
        "indstillinger."
      ),
      shiny::tags$p(
        "Under diagrammet vises n\u00f8gletal for signaler i data, fx seriel\u00e6ngde, ",
        "antal kryds og punkter uden for kontrolgr\u00e6nser. Farverne hj\u00e6lper dig ",
        "med at se, om appen har fundet tegn p\u00e5 ",
        "s\u00e6rlig variation."
      ),
      shiny::div(
        class = "alert alert-info",
        shiny::tags$strong("Husk: "),
        "Et signal er ikke en forklaring i sig selv. Det er et tegn p\u00e5, ",
        "at processen b\u00f8r vurderes fagligt."
      ),
      screenshot_placeholder(
        "Illustration kommer: Signalbokse",
        "Her kan et screenshot zoome ind p\u00e5 boksene under diagrammet.",
        paste(
          "Vis de tre bokse Seriel\u00e6ngde, Antal kryds og Uden for kontrolgr\u00e6nser,",
          "gerne i en situation hvor mindst \u00e9n boks markerer signal."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 5: Rediger data
    shiny::tags$section(
      id = "guide-rediger",
      shiny::tags$h2("5. Redig\u00e9r data ved behov"),
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
        "N\u00e5r data \u00e6ndres, opdateres diagrammet automatisk."
      ),
      screenshot_placeholder(
        "Illustration kommer: Tabeleditoren",
        "Her kan et screenshot vise knapperne over datatabellen og en celle der redigeres.",
        "Vis Omd\u00f8b, Kolonne og R\u00e6kke-knapperne samt en markeret celle i tabellen."
      ),
      shiny::tags$hr()
    ),

    # Sektion 6: Eksporter
    shiny::tags$section(
      id = "guide-eksport",
      shiny::tags$h2("6. Eksport\u00e9r"),
      shiny::tags$p(
        "Klik ",
        shiny::tags$strong("Forts\u00e6t"),
        " for at g\u00e5 til eksport."
      ),
      shiny::tags$dl(
        class = "row",
        shiny::tags$dt(class = "col-sm-3", "PDF"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Brug PDF til rapportering, kvalitetsm\u00f8der, arkivering og deling ",
          "som f\u00e6rdig rapport."
        ),
        shiny::tags$dt(class = "col-sm-3", "PNG"),
        shiny::tags$dd(
          class = "col-sm-9",
          "Brug PNG n\u00e5r du kun skal bruge diagrammet i en pr\u00e6sentation, ",
          "mail eller et dokument."
        )
      ),
      shiny::tags$p("Udfyld is\u00e6r:"),
      shiny::tags$ul(
        shiny::tags$li(shiny::tags$strong("Indikatortitel: "), "en kort titel eller konklusion."),
        shiny::tags$li(shiny::tags$strong("Afdeling eller afsnit: "), "hvor data h\u00f8rer til."),
        shiny::tags$li(
          shiny::tags$strong("Datadefinition: "),
          "hvad m\u00e5les, hvem indg\u00e5r, hvilken periode d\u00e6kker data, og hvad er eventuelt udeladt?"
        ),
        shiny::tags$li(
          shiny::tags$strong("Analyse af processen: "),
          "din faglige fortolkning af diagrammet."
        ),
        shiny::tags$li(shiny::tags$strong("Datakilde/fodnote: "), "hvor data kommer fra.")
      ),
      shiny::tags$p(
        "Klik ",
        shiny::tags$strong("Eksport\u00e9r"),
        " for at downloade filen."
      ),
      screenshot_placeholder(
        "Illustration kommer: Eksport-trinnet",
        "Her kan et screenshot vise formatvalg, metadatafelter og preview.",
        paste(
          "Vis eksport-siden med PDF valgt, udfyldt indikatortitel,",
          "datadefinition, analysefelt og preview til h\u00f8jre."
        )
      ),
      shiny::tags$hr()
    ),

    # Sektion 7: Gem arbejdet
    shiny::tags$section(
      id = "guide-gem",
      shiny::tags$h2("7. Gem arbejdet"),
      shiny::tags$p(
        "Appen gemmer automatisk din session i browseren, s\u00e5 du kan ",
        "forts\u00e6tte senere fra samme computer."
      ),
      shiny::tags$p(
        "Hvis arbejdet skal deles, dokumenteres eller bruges p\u00e5 en anden ",
        "computer, b\u00f8r du ogs\u00e5 downloade en kopi af data og indstillinger."
      ),
      shiny::tags$hr()
    ),

    # Sektion 8: Screenshot backlog
    shiny::tags$section(
      id = "guide-screenshots",
      shiny::tags$h2("Forslag til screenshots"),
      shiny::tags$p(
        "N\u00e5r de rigtige screenshots er klar, kan pladsholderne ovenfor ",
        "erstattes med billeder i samme stil som p\u00e5 siden \u201eL\u00e6r om SPC\u201c."
      ),
      shiny::tags$ul(
        shiny::tags$li("Upload-siden med de fire startvalg og paste-feltet."),
        shiny::tags$li("Kolonnemapping-dialogen med realistiske kolonnevalg."),
        shiny::tags$li("Analyse-siden med datatabel, diagram, indstillinger og signalbokse."),
        shiny::tags$li("Et n\u00e6rbillede af signalboksene, gerne med et aktivt signal."),
        shiny::tags$li("Tabeleditoren med Omd\u00f8b, Kolonne og R\u00e6kke synlige."),
        shiny::tags$li("Eksport-siden med PDF-preview og udfyldte metadatafelter.")
      )
    )
  )
}
