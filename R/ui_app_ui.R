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
      # JavaScript files
      shiny::tags$script(src = "local-storage.js"),
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

    /* Gennemfoert wizard-trin: checkmark med tema-farve */
    .navbar-nav .nav-link.wizard-completed[data-step]::before {
      content: '\\2713';
      background-color: #58B99E;
      border-color: #58B99E;
      -webkit-text-fill-color: white;
      color: white;
    }

    /* Loading overlay på SPC plot under genberegning */
    .spc-plot-container.input-pending .shiny-plot-output,
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

    /* Export preview loading spinner */
    .export-preview-container .recalculating {
      opacity: 0.3 !important;
      transition: opacity 0.15s ease-in-out;
    }
    .export-preview-container::after {
      content: '';
      display: none;
    }
    .export-preview-container:has(.recalculating)::after {
      content: 'Genererer preview...';
      display: flex;
      align-items: center;
      justify-content: center;
      position: absolute;
      inset: 0;
      font-size: 0.85rem;
      color: #666;
      font-weight: 500;
      pointer-events: none;
      z-index: 10;
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


# Fjernet død kode: create_chart_settings_card() (med tabs: Detaljer,
# Organisatorisk, Avanceret) og create_unit_selection().
# Erstattet af create_chart_settings_card_compact(). Se git historie.

# Plot-only card

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

# ui_sidebar.R
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

# Fjernet død kode: create_ui_sidebar(), create_welcome_page(),
# create_getting_started_card(), create_understanding_spc_card(),
# create_step_item(), create_info_section()
# Erstattet af wizard-baseret upload-flow. Se git historie.
