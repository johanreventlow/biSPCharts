# app_ui.R
# Consolidated UI components for SPC app

# UI components now loaded globally in global.R for better performance

# UI HEADER KOMPONENTER =======================================================

## Hovedfunktion for UI header
# Opretter alle header komponenter inklusive scripts og styles
#' @export
create_ui_header <- function() {
  # Get hospital colors using the proper package function
  hospital_colors <- get_hospital_colors()

  shiny::tagList(
    # Aktivér shinyjs
    shinyjs::useShinyjs(),
    shiny::tags$head(
      # CSS files for plot debugging
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "plot-debug.css"),

      # JavaScript files
      shiny::tags$script(src = "local-storage.js"),
      shiny::tags$script(src = "ui-helpers.js"),
      shiny::tags$script(src = "shiny-handlers.js"),
      shiny::tags$script(src = "wizard-nav.js"),
      # Inline CSS styles
      shiny::tags$style(htmltools::HTML(paste0("

      /* Navigation and Tab Styling */
    .nav-link {
      padding: .5rem 1rem !important;
    }

    /* Tab styling - ikke-aktive tabs */
    .nav-tabs .nav-link:not(.active) {
      color: #009ce8 !important;
    }

    /* Tab styling - aktive tabs (behold standard) */
    .nav-tabs .nav-link.active {
      color: inherit;
    }


    /* --- Excel-lignende tema til excelR --- */
    .jexcel_container {
      /*font-family: Calibri, 'Segoe UI', Arial, sans-serif;
      font-size: 13px;*/
      width: none !important;
      height: auto !important;
      padding-bottom: 25px !important;
      position: none !important;
      border: none !important;
    }

    .jexcel thead td {
      background: #f3f3f3;
      border-bottom: 2px solid #bfbfbf;
      font-weight: 600;
      white-space: nowrap;
    }

    /* Excel-lignende styling */
    .jexcel tbody tr:nth-child(odd) {
      background-color: #f9f9f9;
    }

    .jexcel tbody tr:nth-child(even) {
      background-color: #ffffff;
    }

    .jexcel tbody tr:hover {
      background-color: #f0f8ff !important;
    }

    .jexcel td {
      border: 1px solid #d9d9d9;
      padding: 4px 8px;
    }

    /* Aktiv celle styling */
    .jexcel .highlight {
      background-color: #cce7ff !important;
      border: 2px solid #0066cc !important;
    }

    .jexcel_content {
      overflow-y: unset !important;
      max-height: none !important;
      margin-bottom: 25px !important;
    }

    .jexcel > thead > tr > td {
      position: unset !important;
    }

    /* Neutraliser bslib spacing omkring textarea wrapper */
    .bslib-grid:has(#indicator-description-wrapper) {
      margin-bottom: 0 !important;
      padding-bottom: 0 !important;
    }

    .bslib-mb-spacing:has(#indicator-description-wrapper) {
      margin-bottom: 0 !important;
    }



    /* Parent container skal være fleksibel */
    #indicator-description-wrapper {
      display: flex !important;
      flex-direction: column !important;
      flex: 1 1 auto !important;
      min-height: 0 !important;
      margin-bottom: 0 !important;
      padding-bottom: 0 !important;
    }

    /* Textarea skal fylde tilgængelig højde */
    #indicator_description {
      flex: 1 1 auto !important;
      min-height: 130px !important;
      height: 100% !important;
      resize: none !important;
      overflow: auto !important;
      margin-bottom: 0 !important;
    }

    /* Fjern margin på form-group omkring textarea */
    #indicator-description-wrapper .form-group,
    #indicator_div {
      margin-bottom: 0 !important;
      flex: 1 1 auto !important;
      display: flex !important;
      flex-direction: column !important;
    }

    /* Selectize dropup styling */
    .selectize-dropup .selectize-control .selectize-dropdown {
      position: absolute !important;
      top: auto !important;
      bottom: 100% !important;
      border-top: 1px solid #d0d7de !important;
      border-bottom: none !important;
      border-radius: 4px 4px 0 0 !important;
      box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.1) !important;
      margin-bottom: 2px !important;
    }

    .selectize-dropup {
      position: relative !important;
    }

    .selectize-dropup .selectize-control {
      position: relative !important;
    }

    .selectize-dropdown {
      max-height: 200px !important;
      overflow-y: auto !important;
      z-index: 1050 !important;
    }

    /* Dynamic hospital color styles that need R variables */
    .status-ready { background-color: ", hospital_colors$success, "; }
    .status-warning { background-color: ", hospital_colors$warning, "; }
    .status-error { background-color: ", hospital_colors$danger, "; }
    .status-processing { background-color: ", hospital_colors$primary, "; }

    /* Wizard nummererede trin */
    .navbar-nav .nav-link[data-step]::before {
      content: attr(data-step);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 24px;
      height: 24px;
      border-radius: 50%;
      border: 2px solid currentColor;
      font-size: 12px;
      font-weight: 700;
      margin-right: 6px;
      flex-shrink: 0;
    }

    /* Aktiv tab: filled cirkel med tab-farve som baggrund, hvidt tal */
    .navbar-nav .nav-link.active[data-step]::before {
      background-color: currentColor;
      border-color: currentColor;
      -webkit-text-fill-color: white;
    }

    /* Locked tab styling */
    .navbar-nav .nav-link.wizard-locked {
      opacity: 0.4 !important;
      cursor: not-allowed !important;
      pointer-events: auto !important;
    }

    .navbar-nav .nav-link.wizard-locked:hover {
      opacity: 0.4 !important;
    }

    /* Gennemfoert wizard-trin: groent checkmark i stedet for nummer */
    .navbar-nav .nav-link.wizard-completed[data-step]::before {
      content: '\\2713';
      background-color: #28a745;
      border-color: #28a745;
      -webkit-text-fill-color: white;
      color: white;
    }

    /* Loading overlay på SPC plot under genberegning */
    .spc-plot-container .recalculating {
      opacity: 0.35 !important;
      transition: opacity 0.15s ease-in-out;
    }
    .spc-plot-container::after {
      content: '';
      display: none;
    }
    .spc-plot-container:has(.recalculating)::after {
      content: 'Opdaterer...';
      display: flex;
      align-items: center;
      justify-content: center;
      position: absolute;
      inset: 0;
      font-size: 0.9rem;
      color: #666;
      font-weight: 500;
      pointer-events: none;
      z-index: 10;
    }

    /* Sync-badge: vises når plot IKKE genberegner */
    .spc-sync-badge {
      position: absolute;
      bottom: 6px;
      right: 8px;
      font-size: 0.72rem;
      color: #28a745;
      opacity: 0.7;
      pointer-events: none;
      z-index: 5;
      transition: opacity 0.2s;
    }
    .spc-plot-container:has(.recalculating) .spc-sync-badge {
      opacity: 0;
    }

        ")))
    )
  )
}
# R/ui/ui_main_content.R
# Main content area components

#' @export
create_ui_main_content <- function() {
  shiny::div(
    style = "display: flex; flex-direction: column; height: calc(100vh - 80px);",
    # Layout: 6-6 grid (fylder det meste, men ikke helt til bunden)
    # Venstre: Datatabel (fuld hoejde)
    # Hoejre top: SPC Preview
    # Hoejre bund: Anhoej (3) + Indstillinger (3)
    bslib::layout_columns(
      col_widths = c(6, 6),
      height = "calc(100vh - 160px)",

      # Venstre kolonne: Datatabel (fuld hoejde)
      create_data_table_card(),

      # Hoejre kolonne: SPC preview + Anhoej/Indstillinger
      shiny::div(
        style = "display: flex; flex-direction: column; height: 100%; gap: 8px;",

        # Oeverste halvdel: SPC Preview
        shiny::div(
          style = "flex: 1 1 50%; min-height: 0;",
          create_plot_only_card()
        ),

        # Nederste halvdel: Indstillinger (3) + Anhoej-regler (3)
        shiny::div(
          style = "flex: 1 1 50%; min-height: 0;",
          bslib::layout_columns(
            col_widths = c(6, 6),
            height = "100%",
            create_chart_settings_card_compact(),
            create_status_value_boxes()
          )
        )
      )
    ),
    # Tilbage/Fortsæt knapper under cards
    shiny::div(
      style = "display: flex; justify-content: space-between;",
      shiny::actionButton(
        "back_to_upload",
        shiny::tagList(shiny::icon("arrow-left"), " Tilbage"),
        class = "btn-secondary",
        style = "width: 200px;",
        title = "Gå tilbage til upload"
      ),
      shiny::actionButton(
        "continue_to_export",
        shiny::tagList("Fortsæt ", shiny::icon("arrow-right")),
        class = "btn-primary",
        style = "width: 200px;",
        title = "Gå til eksport"
      )
    )
  )
}


create_chart_settings_card <- function() {
  bslib::navset_card_tab(
    title = shiny::span(shiny::icon("sliders-h"), " Indstillinger", ),
    full_screen = TRUE,
    height = "calc(50vh - 60px)",
    # Tab 1: Detaljer ----
    bslib::nav_panel(
      max_height = "100%",
      min_height = "100%",
      title = "Detaljer",
      icon = shiny::icon("pen-to-square"),
      # Chart type and target value side by side
      bslib::layout_column_wrap(
        width = 1 / 2,
        shiny::div(
          id = "indicator_div",
          # Indikator metadata
          shiny::textInput(
            "indicator_title",
            "Titel på indikator:",
            width = UI_INPUT_WIDTHS$full,
            value = "",
            placeholder = "F.eks. 'Infektioner pr. 1000 sengedage'"
          ),
          bslib::layout_column_wrap(
            width = UI_LAYOUT_PROPORTIONS$half,

            # Target value input
            shiny::textInput(
              "target_value",
              "Udviklingsmål:",
              value = "",
              placeholder = "fx >=90%, <25 eller >",
              width = UI_INPUT_WIDTHS$full
            ),

            # Centerline input
            shiny::textInput(
              "centerline_value",
              "Evt. baseline:",
              value = "",
              placeholder = "fx 68%, 0,7 el. 22",
              width = UI_INPUT_WIDTHS$full
            )
          ),

          # Beskrivelse
          shiny::div(
            id = "indicator-description-wrapper",
            style = "display: flex; flex-direction: column; flex: 1 1 auto; min-height: 0;",
            shiny::textAreaInput(
              "indicator_description",
              "Datadefinition:",
              value = "",
              placeholder = "Angiv kort, hvad indikatoren udtrykker, og hvordan data opgøres – fx beregning af tæller og nævner.",
              resize = "none",
              width = UI_INPUT_WIDTHS$full,
            )
          ),
        ),
        shiny::div(
          # Chart type selection
          shiny::selectizeInput(
            "chart_type",
            "Diagram type:",
            choices = CHART_TYPES_DA,
            selected = "run"
          ),


          # Y-axis UI type (simpel datamodel)
          shiny::selectizeInput(
            "y_axis_unit",
            "Y-akse enhed:",
            choices = Y_AXIS_UI_TYPES_DA,
            selected = "count"
          )
        )
      )
    ),

    # Tab 2: Organisatorisk enhed ----
    # (Kolonnematch-tab fjernet — felterne er nu inline over datatabellen)
    bslib::nav_panel(
      "Organisatorisk",
      icon = shiny::icon("building"),
      max_height = "100%",
      min_height = "100%",
      shiny::div(
        style = "padding: 10px 0;",
        # Organisatorisk enhed selection
        create_unit_selection()
      )
    ),

    # Tab 4: Additional settings (placeholder) ----
    # bslib::nav_panel(
    #   "Avanceret",
    #   icon = shiny::icon("cogs"),
    #   max_height = "100%",
    #   min_height = "100%",
    #
    #   shiny::div(
    #     style = "padding: 20px; text-align: center; color: #666;",
    #     shiny::icon("wrench", style = "font-size: 2rem; margin-bottom: 10px;"),
    #     shiny::br(),
    #     "Yderligere indstillinger kommer her",
    #     shiny::br(),
    #     shiny::tags$small("Denne tab er reserveret til fremtidige features")
    #   )
    # ) # bslib::nav_panel(Avanceret)
  ) # navset_card_tab
}


# New function for plot-only card

create_plot_only_card <- function() {
  bslib::card(
    full_screen = TRUE,
    fillable = TRUE,
    height = "100%",
    bslib::card_header(
      shiny::div(shiny::icon("chart-line"), " SPC Preview")
    ),
    bslib::card_body(
      fill = TRUE,
      shiny::div(
        style = "height: 100%",
        visualizationModuleUI("visualization")
      )
    )
  )
}

#' Kompakt indstillings-card til hoejre side
#' @export
create_chart_settings_card_compact <- function() {
  bslib::card(
    height = "100%",
    bslib::card_header(
      shiny::div(shiny::icon("sliders-h"), " Indstillinger")
    ),
    bslib::card_body(
      shiny::selectizeInput(
        "chart_type",
        "Diagram type:",
        choices = CHART_TYPES_DA,
        selected = "run",
        width = "100%"
      ),
      shiny::selectizeInput(
        "y_axis_unit",
        "Y-akse enhed:",
        choices = Y_AXIS_UI_TYPES_DA,
        selected = "count",
        width = "100%"
      ),
      shiny::textInput(
        "target_value",
        "Udviklingsmål:",
        value = "",
        placeholder = "fx >=90%, <25 eller >",
        width = "100%"
      ),
      shiny::textInput(
        "centerline_value",
        "Evt. baseline:",
        value = "",
        placeholder = "fx 68%, 0,7 el. 22",
        width = "100%"
      )
    )
  )
}

create_data_table_card <- function() {
  bslib::card(
    full_screen = TRUE,
    height = "100%",
    bslib::card_header(
      shiny::div(
        style = paste0(
          "display: flex; justify-content: space-between; ",
          "align-items: center; flex-wrap: wrap; ",
          "gap: 4px; width: 100%;"
        ),
        shiny::div(shiny::icon("table"), " Data"),
        shiny::div(
          class = "btn-group-sm",
          shiny::actionButton(
            "auto_detect_columns",
            label = "Auto-detekt\u00e9r kolonner",
            icon = shiny::icon("magic"),
            title = "Auto-detekt\u00e9r kolonner",
            class = "btn-primary btn-sm"
          ),
          shiny::actionButton(
            "edit_column_names",
            label = "Omd\u00f8b",
            icon = shiny::icon("edit"),
            title = "Redig\u00e9r kolonnenavne",
            class = "btn-secondary btn-sm"
          ),
          shiny::actionButton(
            "add_column",
            label = "Kolonne",
            icon = shiny::icon("plus"),
            title = "Tilf\u00f8j kolonne",
            class = "btn-secondary btn-sm"
          ),
          shiny::actionButton(
            "add_row",
            label = "R\u00e6kke",
            icon = shiny::icon("plus-square"),
            title = "Tilf\u00f8j r\u00e6kke",
            class = "btn-secondary btn-sm"
          )
        )
      )
    ),
    bslib::card_body(
      fill = TRUE,
      # Inline kolonnemapping over datatabellen
      create_inline_column_mapping(),
      excelR::excelOutput("main_data_table", height = "auto")
    )
  )
}

#' Inline kolonnemapping — 6 dropdowns i \u00e9n r\u00e6kke over datatabellen
#' @noRd
create_inline_column_mapping <- function() {
  # Compact selectize med forkortet label
  compact_select <- function(id, label, tooltip_text = NULL) {
    el <- shiny::div(
      style = "flex: 1 1 0; min-width: 100px;",
      shiny::selectizeInput(
        id, label,
        choices = NULL, selected = NULL,
        width = "100%",
        options = list(placeholder = "V\u00e6lg...")
      )
    )
    if (!is.null(tooltip_text)) {
      el <- el |> bslib::tooltip(tooltip_text)
    }
    el
  }

  shiny::div(
    style = paste0(
      "display: flex; gap: 6px; padding: 4px 0 8px 0; ",
      "border-bottom: 1px solid #dee2e6; margin-bottom: 8px;"
    ),
    compact_select(
      "x_column", "X-akse",
      "Kolonne med tidspunkter eller observationsnumre (fx Dato, Uge, M\u00e5ned)"
    ),
    compact_select(
      "y_column", "Y-akse",
      "Kolonne med den v\u00e6rdi der skal f\u00f8lges (fx antal, ventetid, score)"
    ),
    compact_select(
      "n_column", "N\u00e6vner (n)",
      paste0(
        "V\u00e6lg en n\u00e6vner-kolonne hvis du arbejder med ",
        "andele eller rater (fx infektioner pr. 100 patienter). ",
        "Ellers kan du springe dette felt over."
      )
    ),
    compact_select(
      "skift_column", "Skift",
      "Valgfri: Kolonne der markerer hvor processen opdeles i faser"
    ),
    compact_select(
      "frys_column", "Frys",
      "Valgfri: Kolonne der markerer en baseline-periode for kontrolgr\u00e6nserne"
    ),
    compact_select(
      "kommentar_column", "Kommentar",
      "Valgfri: Kolonne med kommentarer eller noter"
    )
  )
}


# New function for status value boxes
create_status_value_boxes <- function() {
  visualizationStatusUI("visualization")
}

create_unit_selection <- function() {
  shiny::div(
    style = "margin-bottom: 15px;",
    shiny::tags$label("Afdeling eller afsnit", style = "font-weight: 500;"),
    shiny::div(
      style = "margin-top: 5px;",
      shiny::radioButtons(
        "unit_type",
        NULL,
        choices = list("Vælg fra liste" = "select", "Indtast selv" = "custom"),
        selected = "select",
        inline = TRUE
      )
    ),

    # Dropdown for standard enheder
    shiny::conditionalPanel(condition = "input.unit_type == 'select'", shiny::selectizeInput(
      "unit_select",
      NULL,
      choices = list(
        "Vælg enhed..." = "",
        "Medicinsk Afdeling" = "med",
        "Kirurgisk Afdeling" = "kir",
        "Intensiv Afdeling" = "icu",
        "Ambulatorie" = "amb",
        "Akutmodtagelse" = "akut",
        "Pædiatrisk Afdeling" = "paed",
        "Gynækologi/Obstetrik" = "gyn"
      )
    )),

    # Custom input
    shiny::conditionalPanel(
      condition = "input.unit_type == 'custom'",
      shiny::textInput("unit_custom", NULL, placeholder = "Indtast enhedsnavn...")
    )
  )
}

create_export_card <- function() {
  shiny::conditionalPanel(condition = "output.plot_ready == 'true'", bslib::card(
    bslib::card_header(shiny::div(shiny::icon("download"), " Eksport", )),
    bslib::card_body(
      # KOMPLET EXPORT - Excel version
      shiny::div(
        shiny::downloadButton(
          "download_complete_excel",
          "📋 Komplet Export (Excel)",
          icon = shiny::icon("file-excel"),
          title = "Download hele sessionen som Excel fil med data og konfiguration",
          class = "btn-success w-100 mb-2"
        ),

        # Hjælpe-tekst for komplet export
        shiny::div(
          style = "font-size: 0.75rem; color: #666; text-align: center; margin-bottom: 8px; font-style: italic;",
          "Data + metadata i 2 Excel sheets - klar til brug og re-import"
        )
      ),
      shiny::hr(style = "margin: 15px 0;"),
      shiny::div(style = "text-align: center; font-size: 0.85rem; color: #666; margin-bottom: 10px;", shiny::strong("Graf eksporter:")),
      shiny::downloadButton(
        "download_png",
        "Download PNG",
        icon = shiny::icon("image"),
        class = "btn-outline-primary w-100 mb-2"
      ),
      shiny::downloadButton(
        "download_pdf",
        "Download PDF Rapport",
        icon = shiny::icon("file-pdf"),
        class = "btn-outline-primary w-100"
      )
    )
  ))
}
# ui_sidebar.R
# UI sidebar komponenter

# Dependencies ----------------------------------------------------------------

# UI SIDEBAR KOMPONENTER ======================================================

## Hovedfunktion for UI sidebar
# Opretter komplet sidebar med data upload og konfiguration
#' @export
create_ui_sidebar <- function() {
  bslib::sidebar(
    width = "200px",
    position = "left",
    open = "always",
    # collapsible = FALSE,

    # Action buttons section
    shiny::div(
      style = "margin-bottom: 20px;",
      # Start ny session knap
      shiny::actionButton(
        "clear_saved",
        "Start ny session",
        icon = shiny::icon("refresh"),
        class = "btn-primary w-100 mb-2",
        title = "Start med tom standardtabel"
      ),

      # Upload fil knap - åbner modal
      shiny::actionButton(
        "show_upload_modal",
        "Upload datafil",
        icon = shiny::icon("upload"),
        class = "btn-secondary w-100",
        title = "Upload Excel eller CSV fil"
      )
    ),
    shiny::hr(),

    # Vertical accordion with settings panels
    # bslib::accordion(
    #   id = "sidebar_accordion",
    #   open = "detaljer",
    #   multiple = FALSE,
    #
    #   # Panel 1: Detaljer
    #   # BEMÆRK: Detaljer-felter flyttet til SPC Preview card sidebar
    #   bslib::accordion_panel(
    #     title = shiny::tagList(shiny::icon("pen-to-square"), " Detaljer"),
    #     value = "detaljer",
    #
    #     # MIDLERTIDIG SKJULT: Indikator metadata (flyttes til anden side senere)
    #     # shiny::textInput(
    #     #   "indicator_title",
    #     #   "Titel på indikator:",
    #     #   width = "100%",
    #     #   value = "",
    #     #   placeholder = "F.eks. 'Infektioner pr. 1000 sengedage'"
    #     # ),
    #
    #     # FLYTTET: Detaljer-felter nu i SPC Preview card sidebar (se create_plot_only_card)
    #     # - target_value (Udviklingsmål)
    #     # - centerline_value (Evt. baseline)
    #     # - chart_type (Diagram type)
    #     # - y_axis_unit (Y-akse enhed)
    #
    #     # MIDLERTIDIG SKJULT: Beskrivelse (flyttes til anden side senere)
    #     # shiny::textAreaInput(
    #     #   "indicator_description",
    #     #   "Datadefinition:",
    #     #   value = "",
    #     #   placeholder = "Angiv kort, hvad indikatoren udtrykker",
    #     #   resize = "vertical",
    #     #   width = "100%",
    #     #   rows = 4
    #     # )
    #
    #     # Placeholder - panel er nu tom, alle felter flyttet til SPC Preview card sidebar
    #     shiny::p(
    #       style = "color: #999; font-style: italic; text-align: center; padding: 20px;",
    #       "Detaljer-felter vises nu i SPC Preview card sidebar"
    #     )
    #   ),
    #
    #   # Panel 2: Kolonnematch
    #   # BEMÆRK: Kolonnematch-felter flyttet til Data card sidebar
    #   bslib::accordion_panel(
    #     title = shiny::tagList(shiny::icon("columns"), " Kolonnematch"),
    #     value = "kolonnematch",
    #
    #     # FLYTTET: Kolonnematch-felter nu i Data card sidebar (se create_data_table_card)
    #     # - x_column (X-akse)
    #     # - y_column (Y-akse)
    #     # - n_column (Nævner)
    #     # - skift_column (Opdel proces)
    #     # - frys_column (Fastfrys niveau)
    #     # - kommentar_column (Kommentar)
    #     # - auto_detect_columns button
    #
    #     # Placeholder - panel er nu tom, alle felter flyttet til Data card sidebar
    #     shiny::p(
    #       style = "color: #999; font-style: italic; text-align: center; padding: 20px;",
    #       "Kolonnematch-felter vises nu i Data card sidebar"
    #     )
    #   ),
    #
    #   # Panel 3: Organisatorisk
    #   # MIDLERTIDIG SKJULT: Organisatorisk panel flyttes til anden side senere
    #   # bslib::accordion_panel(
    #   #   title = shiny::tagList(shiny::icon("building"), " Organisatorisk"),
    #   #   value = "organisatorisk",
    #   #   create_unit_selection()
    #   # )
    # )
  )
}

# UI UPLOAD PAGE KOMPONENTER ===================================================

#' Upload-side med kvadratiske handlingsknapper og paste-felt
#'
#' Wizard trin 1: Fire kvadratiske knapper (venstre) + paste-felt (højre).
#' Ingen cards — rent, fladt layout.
#' @export
create_ui_upload_page <- function() {
  # Hjælpefunktion: kvadratisk knap med ikon og tekst
  # Alle knapper har samme base-styling. CSS class "upload-btn-active" styrer valgt-tilstand.
  square_button <- function(id, label, icon_name, title_text) {
    shiny::actionButton(
      id,
      label = shiny::div(
        shiny::icon(icon_name, class = "fa-2x"),
        shiny::tags$br(),
        shiny::tags$span(label, style = "font-size: 0.85rem; font-weight: 600;")
      ),
      class = "btn btn-outline-secondary upload-source-btn w-100 d-flex flex-column align-items-center justify-content-center",
      style = "aspect-ratio: 1; padding: 12px; min-height: 110px;",
      title = title_text
    )
  }

  shiny::tagList(
    # CSS for upload-knap active/hover tilstande
    shiny::tags$style(htmltools::HTML("
      /* Alle upload-source knapper: normal tilstand */
      .upload-source-btn {
        transition: all 0.15s ease;
      }

      /* Hover ikke-valgt: hvid baggrund, mørkere tekst */
      .upload-source-btn:hover {
        background-color: #fff !important;
        border-color: #828c8d !important;
        color: #828c8d !important;
      }

      /* Hover valgt knap: mørkere baggrund, hvid tekst */
      .upload-source-btn.upload-btn-active:hover {
        background-color: #828c8d !important;
        border-color: #828c8d !important;
        color: #fff !important;
      }

      /* Valgt knap: præcis Flatly btn-outline-secondary:hover (permanent) */
      .upload-source-btn.upload-btn-active {
        background-color: #95a5a6 !important;
        border-color: #95a5a6 !important;
        color: #fff !important;
      }
      .upload-source-btn.upload-btn-active .fa-2x,
      .upload-source-btn.upload-btn-active span {
        color: #fff !important;
      }
    ")),
    shiny::div(
      class = "container-fluid d-flex align-items-center justify-content-center",
      style = "max-width: 1200px; margin: 0 auto; min-height: calc(100vh - 120px);",

      # Flexbox-row: knapper (fast bredde) + paste-felt (fylder resten)
      shiny::div(
        style = "display: flex; gap: 20px; align-items: stretch; width: 100%;",

        # Knap 1: Kopiér & Indsæt data (default valgt via JS)
        shiny::div(
          style = "flex: 0 0 120px;",
          square_button(
            "show_paste_area", "Kopiér &\nIndsæt data", "clipboard",
            "Indsæt data fra Excel eller CSV"
          )
        ),

        # Knap 2: Indlæs XLS/CSV
        shiny::div(
          style = "flex: 0 0 120px;",
          # Skjult fileInput
          shiny::div(
            style = "display: none;",
            shiny::fileInput(
              "direct_file_upload",
              label = NULL,
              accept = c(".csv", ".xlsx", ".xls"),
              buttonLabel = "Vælg fil"
            )
          ),
          square_button(
            "trigger_file_upload", "Indlæs\nXLS/CSV", "table",
            "Vælg Excel eller CSV fil"
          )
        ),

        # Knap 3: Prøv med eksempeldata
        shiny::div(
          style = "flex: 0 0 120px;",
          square_button(
            "load_sample_data", "Prøv med\neksempeldata", "flask",
            "Indlæs et SPC-eksempeldatasæt"
          )
        ),

        # Knap 4: Blank session
        shiny::div(
          style = "flex: 0 0 120px;",
          square_button(
            "clear_saved", "Blank\nsession", "file-circle-plus",
            "Start med tomt datasæt"
          )
        ),

        # Paste-felt (fylder resten af pladsen)
        shiny::div(
          style = "flex: 1 1 auto; display: flex; flex-direction: column; margin-left: 20px;",
          shiny::textAreaInput(
            "paste_data_input",
            label = NULL,
            value = "",
            rows = 6,
            width = "100%",
            placeholder = "Indsæt data fra Excel eller CSV her..."
          ),
          shiny::div(
            style = "display: flex; justify-content: flex-end;",
            shiny::actionButton(
              "load_paste_data",
              shiny::tagList("Fortsæt ", shiny::icon("arrow-right")),
              class = "btn-primary",
              style = "width: 200px;",
              title = "Indlæs data og gå til analyse"
            )
          )
        )
      )
    )
  )
}

# ui_welcome_page.R
# UI komponenter for velkomstside

# Dependencies ----------------------------------------------------------------

# UI VELKOMSTSIDE KOMPONENTER =================================================

## Hovedfunktion for velkomstside
# Opretter komplet velkomstside med hero sektion og handlingsknapper
#' @keywords internal
create_welcome_page <- function() {
  # Get hospital colors using the proper package function
  hospital_colors <- get_hospital_colors()

  shiny::div(
    class = "welcome-page",
    style = "min-height: 100vh; background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);",

    # Hero Sektion
    shiny::div(
      class = "hero-section py-5",
      shiny::div(
        class = "container-fluid",
        shiny::div(
          class = "row align-items-center mb-5",
          shiny::div(
            class = "col-12 text-center",
            shiny::h1(
              class = "display-4 fw-bold",
              style = paste0("color: ", hospital_colors$primary, "; margin-bottom: 1rem;"),
              "Velkommen til BFH SPC-værktøj"
            ),
            shiny::p(
              class = "lead text-muted",
              style = "font-size: 1.25rem; max-width: 800px; margin: 0 auto;",
              "Transformér dine data til indsigter med Statistical Process Control. ",
              "Identificer mønstre, spot trends og træf bedre beslutninger baseret på dine healthcare data."
            )
          )
        )
      )
    ),

    # Main Content - Two Column Layout
    shiny::div(
      class = "container-fluid px-4",
      shiny::div(
        class = "row g-4 mb-5",

        # LEFT COLUMN - Getting Started Guide
        shiny::div(
          class = "col-lg-6",
          create_getting_started_card()
        ),

        # RIGHT COLUMN - Understanding SPC
        shiny::div(
          class = "col-lg-6",
          create_understanding_spc_card()
        )
      )
    ),

    # Call to Action Section
    shiny::div(
      class = "cta-section py-5",
      style = paste0("background-color: ", hospital_colors$primary, "; color: white;"),
      shiny::div(
        class = "container text-center",
        shiny::div(
          class = "row",
          shiny::div(
            class = "col-lg-8 mx-auto",
            shiny::h2(class = "mb-4", "Klar til at komme i gang?"),
            shiny::p(class = "mb-4 fs-5", "Start din første SPC-analyse på under 5 minutter."),
            shiny::div(
              class = "d-grid gap-2 d-md-flex justify-content-md-center",
              shiny::actionButton(
                "start_new_session",
                "🚀 Start ny analyse",
                class = "btn btn-light btn-lg me-md-2",
                style = "font-weight: 600; padding: 12px 30px;"
              ),
              shiny::actionButton(
                "upload_data_welcome",
                "Upload data",
                class = "btn btn-outline-light btn-lg",
                style = "font-weight: 600; padding: 12px 30px;"
              )
            )
          )
        )
      )
    )
  )
}

# Left Column - Getting Started Guide
create_getting_started_card <- function() {
  # Get hospital colors using the proper package function
  hospital_colors <- get_hospital_colors()
  bslib::card(
    class = "h-100 shadow-sm",
    style = "border: none; border-radius: 15px;",
    bslib::card_header(
      class = "bg-white border-0 pb-0",
      style = "border-radius: 15px 15px 0 0;",
      shiny::div(
        class = "d-flex align-items-center",
        shiny::div(
          class = "me-3",
          style = paste0("background: ", hospital_colors$primary, "; width: 50px; height: 50px; border-radius: 12px; display: flex; align-items: center; justify-content: center;"),
          shiny::icon("rocket", style = "color: white; font-size: 1.5rem;")
        ),
        shiny::div(
          shiny::h3(class = "card-title mb-1", "Kom i gang på 3 trin"),
          shiny::p(class = "text-muted mb-0", "Din vej fra data til indsigt")
        )
      )
    ),
    bslib::card_body(
      class = "px-4 py-4",

      # Step 1
      create_step_item(
        number = "1",
        icon = "upload",
        title = "Upload dine data",
        description = "Excel (.xlsx/.xls) eller CSV-fil med kolonneoverskrifter. Vi understøtter danske tal og datoformater.",
        example = "Eksempel: Dato, Tæller, Nævner, Kommentar"
      ),

      # Step 2
      create_step_item(
        number = "2",
        icon = "sliders-h",
        title = "Konfigurer din analyse",
        description = "Automatisk kolonnedetektering eller manuel opsætning. Vælg chart type baseret på dine data.",
        example = "Run chart, P-chart, U-chart, X̄-chart"
      ),

      # Step 3
      create_step_item(
        number = "3",
        icon = "chart-line",
        title = "Få dine insights",
        description = "Interaktiv SPC-graf med centerlinjer, kontrolgrænser og specialle mønstre (Anhøj regler).",
        example = "Eksporter som Excel, PDF eller PNG"
      ),

      # Quick Start Button
      shiny::div(
        class = "mt-4 pt-3 border-top",
        shiny::div(
          class = "d-grid",
          shiny::actionButton(
            "quick_start_demo",
            "👆 Prøv med eksempel-data",
            class = "btn btn-outline-primary btn-lg",
            style = "border-radius: 10px; font-weight: 500;"
          )
        ),
        shiny::p(
          class = "text-center text-muted mt-2 mb-0",
          style = "font-size: 0.9rem;",
          "Eller upload dine egne data direkte"
        )
      )
    )
  )
}

# Right Column - Understanding SPC
create_understanding_spc_card <- function() {
  # Get hospital colors using the proper package function
  hospital_colors <- get_hospital_colors()
  bslib::card(
    class = "h-100 shadow-sm",
    style = "border: none; border-radius: 15px;",
    bslib::card_header(
      class = "bg-white border-0 pb-0",
      style = "border-radius: 15px 15px 0 0;",
      shiny::div(
        class = "d-flex align-items-center",
        shiny::div(
          class = "me-3",
          style = paste0("background: ", hospital_colors$secondary, "; width: 50px; height: 50px; border-radius: 12px; display: flex; align-items: center; justify-content: center;"),
          shiny::icon("lightbulb", style = "color: white; font-size: 1.5rem;")
        ),
        shiny::div(
          shiny::h3(class = "card-title mb-1", "Forstå SPC"),
          shiny::p(class = "text-muted mb-0", "Værktøjet der transformerer data til handling")
        )
      )
    ),
    bslib::card_body(
      class = "px-4 py-4",

      # What is SPC?
      create_info_section(
        icon = "question-circle",
        title = "Hvad er Statistical Process Control?",
        content = "SPC hjælper dig med at skelne mellem normal variation og særlige årsager i dine processer. I sundhedsvæsenet betyder det bedre patientpleje gennem data-drevet beslutningstagning."
      ),

      # Why SPC in Healthcare?
      create_info_section(
        icon = "heartbeat",
        title = "Hvorfor SPC i sundhedsvæsenet?",
        content = htmltools::HTML("
          <ul class='list-unstyled'>
            <li><strong>🎯 Spot trends tidligt:</strong> Identificer problemer før de bliver kritiske</li>
            <li><strong>Forstå variation:</strong> Normal udsving vs. særlige årsager</li>
            <li><strong>💡 Træf bedre beslutninger:</strong> Baseret på statistisk evidens</li>
            <li><strong>🚀 Forbedre kontinuerligt:</strong> Måle effekt af ændringer</li>
          </ul>
        ")
      ),

      # Healthcare Examples
      create_info_section(
        icon = "hospital",
        title = "Konkrete eksempler fra BFH",
        content = htmltools::HTML("
          <div class='row g-2'>
            <div class='col-6'>
              <div class='example-item p-2 rounded' style='background: #f8f9fa;'>
                <small class='fw-bold text-primary'>Infektionsrater</small><br>
                <small class='text-muted'>Monitor og reducer HAI</small>
              </div>
            </div>
            <div class='col-6'>
              <div class='example-item p-2 rounded' style='background: #f8f9fa;'>
                <small class='fw-bold text-primary'>Ventetider</small><br>
                <small class='text-muted'>Optimér patientflow</small>
              </div>
            </div>
            <div class='col-6'>
              <div class='example-item p-2 rounded mt-2' style='background: #f8f9fa;'>
                <small class='fw-bold text-primary'>Medicinfejl</small><br>
                <small class='text-muted'>Forbedre patientsikkerhed</small>
              </div>
            </div>
            <div class='col-6'>
              <div class='example-item p-2 rounded mt-2' style='background: #f8f9fa;'>
                <small class='fw-bold text-primary'>Genindlæggelser</small><br>
                <small class='text-muted'>Kvalitetsindikatorer</small>
              </div>
            </div>
          </div>
        ")
      )
    )
  )
}

# Helper function for step items
create_step_item <- function(number, icon, title, description, example = NULL) {
  # Get hospital colors using the proper package function
  hospital_colors <- get_hospital_colors()
  shiny::div(
    class = "step-item d-flex mb-4",
    # Step Number Circle
    shiny::div(
      class = "step-number me-3 flex-shrink-0",
      style = paste0("width: 40px; height: 40px; background: ", hospital_colors$primary, "; color: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 1.1rem;"),
      number
    ),
    # Step Content
    shiny::div(
      class = "step-content flex-grow-1",
      shiny::div(
        class = "d-flex align-items-center mb-2",
        shiny::icon(icon, class = "text-primary me-2"),
        shiny::h5(class = "mb-0 fw-semibold", title)
      ),
      shiny::p(class = "text-muted mb-1", description),
      if (!is.null(example)) {
        shiny::p(
          class = "small text-primary mb-0",
          style = "font-style: italic;",
          example
        )
      }
    )
  )
}

# Helper function for info sections
create_info_section <- function(icon, title, content) {
  shiny::div(
    class = "info-section mb-4",
    shiny::div(
      class = "d-flex align-items-start mb-2",
      shiny::div(
        class = "me-2 flex-shrink-0",
        shiny::icon(icon, class = "text-secondary", style = "font-size: 1.2rem; margin-top: 2px;")
      ),
      shiny::div(
        class = "flex-grow-1",
        shiny::h5(class = "fw-semibold mb-2", title),
        shiny::div(class = "text-muted", content)
      )
    )
  )
}
