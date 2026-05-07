# utils_ui_app_layout.R
# UI-helper-komponenter for SPC app layout (header, upload-side, main content)

# UI components now loaded globally in global.R for better performance

# UI HEADER KOMPONENTER =======================================================

## Hovedfunktion for UI header
# Opretter alle header komponenter inklusive scripts og styles
#' Create UI header
#' @return tagList with header components
#' @keywords internal
create_ui_header <- function() {
  # Get hospital colors using the proper package function
  hospital_colors <- get_hospital_colors()

  # Byg betinget @font-face CSS til Mari-font.
  # Mari-fonts leveres af BFHchartsAssets companion-pakken (privat) via
  # resource-prefix 'bfh_assets' registreret i golem_add_external_resources().
  # Fallback: ingen @font-face injiceres -- browser bruger naesteoverladte
  # system-font fra CSS font-family-stack (Arial, Helvetica, sans-serif).
  mari_fontface_css <- if (requireNamespace("BFHchartsAssets", quietly = TRUE)) {
    # Brug Mari-Book.otf / Mari-Bold.otf (internal family = "Mari", weight=4/7).
    # Tidligere brugte vi MariOffice-Book.ttf / MariOffice-Bold.ttf der internt
    # hedder "Mari Office" (med mellemrum) -- mismatch mod CSS-deklarationen
    # `font-family: 'Mari'` resulterede i forkert weight-rendering i browser.
    # Mari-*.otf filerne er authoritative-navngivne (BFHchartsAssets v0.1.0).
    "
      /* Mari hospital font via BFHchartsAssets companion-pakke (@font-face) */
      @font-face {
        font-family: 'Mari';
        src: url('bfh_assets/Mari-Book.otf') format('opentype');
        font-weight: normal;
        font-style: normal;
      }
      @font-face {
        font-family: 'Mari';
        src: url('bfh_assets/Mari-Bold.otf') format('opentype');
        font-weight: bold;
        font-style: normal;
      }
    "
  } else {
    # BFHchartsAssets ikke tilgaengelig -- browser falder tilbage til
    # Arial/Helvetica/sans-serif fra CSS-stakken i config_branding_getters.R.
    ""
  }

  shiny::tagList(
    # Aktiver shinyjs
    shinyjs::useShinyjs(),
    shiny::tags$head(
      # JavaScript files loades automatisk via golem::bundle_resources() i
      # golem_add_external_resources() (app_ui.R). Manuelle <script src=...>
      # tags her 404'ede fordi stien skulle vaere "www/..." og ikke root.
      # Fjernet i Issue #193 -- bundle_resources haandterer alle .js/.css i
      # inst/app/www/ automatisk.

      # Inline CSS styles
      shiny::tags$style(htmltools::HTML(paste0(mari_fontface_css, "

      /* Navigation and Tab Styling */
    .nav-link {
      padding: .5rem 1rem !important;
    }

    /* Tab styling - ikke-aktive tabs */
    .nav-tabs .nav-link:not(.active) {
      color: ", hospital_colors$info, " !important;
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
      background-color: #d8eef9 !important;
    }

    .jexcel td {
      border: 1px solid #d9d9d9;
      padding: 4px 8px;
    }

    /* Aktiv celle styling */
    .jexcel .highlight {
      background-color: #99d8f6 !important;
      border: 2px solid ", hospital_colors$primary, " !important;
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



    /* Parent container skal vaere fleksibel */
    #indicator-description-wrapper {
      display: flex !important;
      flex-direction: column !important;
      flex: 1 1 auto !important;
      min-height: 0 !important;
      margin-bottom: 0 !important;
      padding-bottom: 0 !important;
    }

    /* Textarea skal fylde tilgaengelig hoejde */
    #indicator_description {
      flex: 1 1 auto !important;
      min-height: 130px !important;
      height: 100% !important;
      resize: none !important;
      overflow: auto !important;
      margin-bottom: 0 !important;
    }

    /* Fjern margin paa form-group omkring textarea */
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

    /* Aktiv tab: hvid cirkel med header-farvet tal */
    .navbar-nav .nav-link.active[data-step]::before {
      background-color: white;
      border-color: white;
      -webkit-text-fill-color: var(--bs-primary);
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
      background-color: transparent;
      border-color: white;
      -webkit-text-fill-color: white;
      color: white;
    }

    /* Loading overlay paa SPC plot under genberegning */
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
    ),
    # Tooltips paa Skift/Frys tabel-headere (excelR renderer dynamisk)
    # Keys SKAL matche kolonnenavne fra ensure_standard_columns()
    shiny::tags$script(htmltools::HTML("
      (function() {
        var tooltips = {
          'Skift': 'Opdeler diagrammet i faser ved kendte proces\\u00e6ndringer',
          'Frys': 'L\\u00e5ser kontrolgr\\u00e6nser baseret p\\u00e5 en baseline-periode'
        };
        var pending = null;
        function addTableHeaderTooltips() {
          var headers = document.querySelectorAll('.jexcel thead td');
          headers.forEach(function(td) {
            var text = td.textContent.trim();
            if (tooltips[text] && !td.title) {
              td.title = tooltips[text];
              td.style.cursor = 'help';
            }
          });
        }
        var observer = new MutationObserver(function() {
          if (!pending) {
            pending = requestAnimationFrame(function() {
              addTableHeaderTooltips();
              pending = null;
            });
          }
        });
        observer.observe(document.body, {childList: true, subtree: true});
      })();
    ")),
    # Cookie-indstillinger link (synlig i bunden af siden)
    # Skjules paa trin 2 (analyser) og 3 (eksporter) for at undgaa kollision
    # med hoejre-justerede actionknapper ("Fortsaet" / "Eksporter").
    shiny::conditionalPanel(
      condition = "input.main_navbar !== 'analyser' && input.main_navbar !== 'eksporter'",
      shiny::tags$div(
        style = "position: fixed; bottom: 4px; right: 12px; z-index: 999;",
        shiny::tags$a(
          href = "javascript:void(0)",
          onclick = "if(window.spcShowCookieSettings) window.spcShowCookieSettings();",
          class = "spc-cookie-settings-link",
          "Cookie-indstillinger"
        )
      )
    )
  )
}
# R/ui/ui_main_content.R
# Main content area components

#' Create UI main content area
#' @return tagList with main content components
#' @keywords internal
create_ui_main_content <- function() {
  shiny::div(
    style = "display: flex; flex-direction: column; height: calc(100vh - 80px);",

    # Sammenklapbar hjaelp (minimal footprint naar sammenklappet)
    shiny::div(
      style = "flex-shrink: 0;",
      shiny::tags$button(
        class = "btn btn-sm btn-link text-muted p-0",
        style = "text-decoration: none; font-size: 0.75rem; line-height: 1.2;",
        onclick = "$('#analyser_help_content').slideToggle(200); $(this).find('.chevron-icon').toggleClass('fa-chevron-down fa-chevron-up');",
        shiny::icon("chevron-down", class = "chevron-icon", style = "font-size: 0.65em; margin-right: 3px;"),
        "Hj\u00e6lp til dette trin"
      ),
      shiny::div(
        id = "analyser_help_content",
        style = "display: none;",
        shiny::div(
          class = "alert alert-light border mt-1 mb-1",
          style = "font-size: 0.82rem; padding: 8px 12px;",
          shiny::tags$p(
            class = "mb-2",
            shiny::tags$strong("Datatabel (venstre side)"),
            shiny::tags$br(),
            "Du kan redigere data direkte i tabellen ved at klikke p\u00e5 en celle. ",
            "Brug ", shiny::tags$em("+ R\u00e6kke"), " for at tilf\u00f8je nye datapunkter, og ",
            shiny::tags$em("+ Kolonne"), " for at tilf\u00f8je kolonner ",
            "(fx Skift eller Frys, som altid skal v\u00e6re til stede). ",
            "Brug ", shiny::tags$em("Omd\u00f8b"), " for at give kolonner mere beskrivende navne."
          ),
          shiny::tags$p(
            class = "mb-2",
            shiny::tags$strong("Kolonnetildelinger (\u00f8verst)"),
            shiny::tags$br(),
            "Klik ", shiny::tags$em("Auto-detekt\u00e9r kolonner"),
            " for at lade appen g\u00e6tte hvilke kolonner der er X-akse, Y-akse osv. ",
            "Du kan altid \u00e6ndre tildelingerne manuelt via dropdown-menuerne. ",
            "X-akse (typisk dato) og Y-akse (den v\u00e6rdi der f\u00f8lges) er p\u00e5kr\u00e6vede. ",
            "V\u00e6lg en N\u00e6vner hvis du arbejder med andele eller rater."
          ),
          shiny::tags$p(
            class = "mb-2",
            shiny::tags$strong("Indstillinger og diagramtype (h\u00f8jre side)"),
            shiny::tags$br(),
            "V\u00e6lg diagramtype under ", shiny::tags$em("Indstillinger"),
            ". Start med ", shiny::tags$em("Seriediagram (Run)"),
            " hvis du er i tvivl \u2014 det er den simpleste og mest robuste type."
          ),
          shiny::tags$p(
            class = "mb-0",
            shiny::tags$strong("V\u00e6rdibokse (nederst til h\u00f8jre)"),
            shiny::tags$br(),
            "De tre bokse viser resultater fra Anh\u00f8j-reglerne: ",
            shiny::tags$em("Seriel\u00e6ngde"),
            " (l\u00e6ngste serie p\u00e5 samme side af centrallinjen), ",
            shiny::tags$em("Antal kryds"),
            " (krydsninger af centrallinjen) og ",
            shiny::tags$em("Kontrolgr\u00e6nser"),
            ". Boksene skifter farve n\u00e5r der er et signal."
          )
        )
      )
    ),

    # Layout: 6-6 grid (fylder det meste, men ikke helt til bunden)
    # Venstre: Datatabel (fuld hoejde)
    # Hoejre top: SPC Preview
    # Hoejre bund: Anhoej (3) + Indstillinger (3)
    bslib::layout_columns(
      col_widths = c(6, 6),
      height = "calc(100vh - 175px)",

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
    # Tilbage/Gem/Fortsaet knapper under cards
    shiny::div(
      style = "display: flex; justify-content: space-between; align-items: center;",
      shiny::actionButton(
        "back_to_upload",
        shiny::tagList(shiny::icon("arrow-left"), " Tilbage"),
        class = "btn-secondary",
        style = "width: 200px;",
        title = "G\u00e5 tilbage til upload"
      ),
      shinyjs::disabled(
        shiny::downloadButton(
          "download_spc_file",
          "Gem kopi af data og indstillinger",
          class = "btn-outline-secondary",
          style = "width: auto; min-width: 200px;",
          title = "Gem kopi af data og indstillinger til Excel-fil"
        )
      ),
      shiny::actionButton(
        "continue_to_export",
        shiny::tagList("Forts\u00e6t ", shiny::icon("arrow-right")),
        class = "btn-primary",
        style = "width: 200px;",
        title = "G\u00e5 til eksport"
      )
    )
  )
}


# Fjernet doed kode: create_chart_settings_card() (med tabs: Detaljer,
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
#' @keywords internal
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
        shiny::tagList(
          "Udviklingsm\u00e5l:",
          shiny::icon("circle-info", style = "font-size: 0.8em; opacity: 0.6; margin-left: 4px;") |>
            bslib::tooltip("En vandret linje der viser jeres m\u00e5ls\u00e6tning. P\u00e5virker ikke beregninger eller signaldetektion.")
        ),
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

#' Inline kolonnemapping -- 6 dropdowns i én række over datatabellen
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
      el <- el |> bslib::tooltip(tooltip_text, placement = "top", options = list(fallbackPlacements = list("top", "bottom")))
    }
    el
  }

  shiny::div(
    class = "column-mapping-row",
    style = paste0(
      "display: flex; gap: 6px; padding: 4px 0 8px 0; ",
      "border-bottom: 1px solid #dee2e6; margin-bottom: 8px;"
    ),
    # Begraens selectize input-felt til en linje, men lad dropdown vise fulde navne
    shiny::tags$style(shiny::HTML(paste0(
      ".column-mapping-row .selectize-input { height: 36px; overflow: hidden; }",
      ".column-mapping-row .selectize-input > .item { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }",
      ".column-mapping-row .selectize-dropdown .option { white-space: normal; overflow: visible; }"
    ))),
    compact_select(
      "x_column", "X-akse",
      paste0(
        "Kolonne med tidspunkter eller observationsnumre (fx Dato, Uge, M\u00e5ned). ",
        "Underst\u00f8ttede datoformater: 15-03-2024, 15/03/2024, 15.03.2024, 2024-03-15 ",
        "eller \"15 mar 2024\". Andre tekster bruges som observationsnumre."
      )
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
      "Opdeler diagrammet i faser ved kendte proces\u00e6ndringer. Kolonne med TRUE/1 markerer nye faser (tilf\u00f8jes automatisk hvis den mangler)."
    ),
    compact_select(
      "frys_column", "Frys",
      "L\u00e5ser kontrolgr\u00e6nser baseret p\u00e5 en baseline-periode. Kolonne med TRUE/1 markerer baseline-punkter (tilf\u00f8jes automatisk hvis den mangler)."
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
#' Wizard trin 1: Fire kvadratiske knapper (venstre) + paste-felt (hoejre).
#' Ingen cards -- rent, fladt layout.
#' @keywords internal
create_ui_upload_page <- function() {
  hospital_colors <- get_hospital_colors()
  # Hjaelpefunktion: kvadratisk knap med ikon og tekst
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
    shiny::tags$style(htmltools::HTML(paste0("
      /* Alle upload-source knapper: normal tilstand -- lys graa */
      .btn-outline-secondary.upload-source-btn {
        transition: all 0.15s ease;
        border-color: ", hospital_colors$ui_grey_mid, " !important;
        color: ", hospital_colors$ui_grey_mid, " !important;
      }
      .btn-outline-secondary.upload-source-btn .fa-2x,
      .btn-outline-secondary.upload-source-btn span {
        color: ", hospital_colors$ui_grey_mid, " !important;
      }

      /* Hover ikke-valgt: moerkere border+tekst+ikoner */
      .btn-outline-secondary.upload-source-btn:hover {
        background-color: #fff !important;
        border-color: ", hospital_colors$ui_grey_dark, " !important;
        color: ", hospital_colors$ui_grey_dark, " !important;
      }
      .btn-outline-secondary.upload-source-btn:hover .fa-2x,
      .btn-outline-secondary.upload-source-btn:hover span {
        color: ", hospital_colors$ui_grey_dark, " !important;
      }

      /* Hover valgt knap: moerkere baggrund, hvid tekst */
      .btn-outline-secondary.upload-source-btn.upload-btn-active:hover {
        background-color: ", hospital_colors$ui_grey_dark, " !important;
        border-color: ", hospital_colors$ui_grey_dark, " !important;
        color: #fff !important;
      }
      .btn-outline-secondary.upload-source-btn.upload-btn-active:hover .fa-2x,
      .btn-outline-secondary.upload-source-btn.upload-btn-active:hover span {
        color: #fff !important;
      }

      /* Valgt knap: medium graa baggrund */
      .upload-source-btn.upload-btn-active {
        background-color: ", hospital_colors$ui_grey_mid, " !important;
        border-color: ", hospital_colors$ui_grey_mid, " !important;
        color: #fff !important;
      }
      .upload-source-btn.upload-btn-active .fa-2x,
      .upload-source-btn.upload-btn-active span {
        color: #fff !important;
      }

      /* Sample data dropdown */
      .sample-data-dropdown {
        position: absolute;
        bottom: 100%;
        left: 0;
        z-index: 1000;
        min-width: 320px;
        max-height: 400px;
        overflow-y: auto;
        background: #fff;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        box-shadow: 0 2px 8px rgba(0,0,0,.12);
        padding: 4px 0;
        margin-bottom: 4px;
        display: none;
      }
      .sample-data-item {
        display: block;
        padding: 8px 16px;
        cursor: pointer;
        text-decoration: none;
        color: ", hospital_colors$dark, ";
        font-size: 0.82rem;
        border: none;
        background: none;
        width: 100%;
        text-align: left;
        line-height: 1.4;
      }
      .sample-data-item:hover {
        background-color: ", hospital_colors$light, ";
        text-decoration: none;
        color: ", hospital_colors$dark, ";
      }
      .sample-data-item .sample-label {
        font-weight: 600;
        display: block;
      }
      .sample-data-item .sample-desc {
        font-size: 0.75rem;
        color: ", hospital_colors$ui_grey_dark, ";
        display: block;
      }

      /* Excel sheet picker dropdown (multi-sheet upload) */
      .excel-sheet-dropdown {
        position: absolute;
        bottom: 100%;
        left: 0;
        z-index: 1000;
        min-width: 320px;
        max-height: 400px;
        overflow-y: auto;
        background: #fff;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        box-shadow: 0 2px 8px rgba(0,0,0,.12);
        padding: 4px 0;
        margin-bottom: 4px;
        display: none;
      }
      .excel-sheet-item {
        display: block;
        padding: 8px 16px;
        cursor: pointer;
        text-decoration: none;
        color: ", hospital_colors$dark, ";
        font-size: 0.82rem;
        border: none;
        background: none;
        width: 100%;
        text-align: left;
        line-height: 1.4;
      }
      .excel-sheet-item:hover {
        background-color: ", hospital_colors$light, ";
        text-decoration: none;
        color: ", hospital_colors$dark, ";
      }
      .excel-sheet-item--empty {
        color: ", hospital_colors$ui_grey_dark, ";
        font-style: italic;
      }
      .excel-sheet-item--empty:hover {
        color: ", hospital_colors$ui_grey_dark, ";
      }
      .excel-sheet-header {
        padding: 6px 16px;
        font-size: 0.75rem;
        color: ", hospital_colors$ui_grey_dark, ";
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        border-bottom: 1px solid #f0f0f0;
        margin-bottom: 4px;
      }

      /* Download skabelon link */
      .download-template-link {
        font-size: 0.8rem;
        color: ", hospital_colors$ui_grey_dark, ";
        text-decoration: none;
        display: inline-flex;
        align-items: center;
        gap: 4px;
        margin-top: 8px;
      }
      .download-template-link:hover {
        color: ", hospital_colors$dark, ";
        text-decoration: underline;
      }
    "))),
    # Luk dropdown ved klik udenfor
    shiny::tags$script(htmltools::HTML("
      document.addEventListener('click', function(e) {
        var dropdown = document.getElementById('sample_data_dropdown');
        var toggleBtn = document.getElementById('toggle_sample_dropdown');
        if (dropdown && toggleBtn &&
            !dropdown.contains(e.target) &&
            !toggleBtn.contains(e.target)) {
          dropdown.style.display = 'none';
        }

        var sheetDropdown = document.getElementById('excel_sheet_dropdown');
        var uploadBtn = document.getElementById('trigger_file_upload');
        if (sheetDropdown && uploadBtn &&
            !sheetDropdown.contains(e.target) &&
            !uploadBtn.contains(e.target)) {
          sheetDropdown.style.display = 'none';
        }
      });
    ")),
    shiny::div(
      class = "container-fluid d-flex align-items-center justify-content-center",
      style = "max-width: 1200px; margin: 0 auto; min-height: calc(100vh - 120px);",
      shiny::div(
        style = "width: 100%;",

        # Flexbox-row: knapper (fast bredde) + paste-felt (fylder resten)
        shiny::div(
          style = "display: flex; gap: 20px; align-items: stretch; width: 100%;",

          # Knap 1: Kopier & Indsaet data (default valgt via JS)
          shiny::div(
            style = "flex: 0 0 120px;",
            square_button(
              "show_paste_area", "Kopi\u00e9r &\nInds\u00e6t data", "clipboard",
              "Inds\u00e6t data fra Excel eller CSV"
            )
          ),

          # Knap 2: Indlaes XLS/CSV (med sheet-picker dropdown for multi-sheet Excel)
          shiny::div(
            style = "flex: 0 0 120px; position: relative;",
            # Skjult fileInput
            shiny::div(
              style = "display: none;",
              shiny::fileInput(
                "direct_file_upload",
                label = NULL,
                accept = c(".csv", ".xlsx", ".xls"),
                buttonLabel = "V\u00e6lg fil"
              )
            ),
            square_button(
              "trigger_file_upload", "Indl\u00e6s\nXLS/CSV", "table",
              "V\u00e6lg Excel/CSV eller en tidligere gemt biSPCharts-fil"
            ),
            # Sheet-picker dropdown (vises kun ved multi-sheet Excel-upload)
            shiny::div(
              id = "excel_sheet_dropdown",
              class = "excel-sheet-dropdown",
              shiny::uiOutput("excel_sheet_dropdown_items")
            )
          ),

          # Knap 3: Proev med eksempeldata (med dropdown)
          shiny::div(
            style = "flex: 0 0 120px; position: relative;",
            square_button(
              "toggle_sample_dropdown", "Pr\u00f8v med\neksempeldata", "flask",
              "V\u00e6lg et SPC-eksempeldatas\u00e6t"
            ),
            # Dropdown-menu med eksempeldatasaet
            shiny::div(
              id = "sample_data_dropdown",
              class = "sample-data-dropdown",
              lapply(SAMPLE_DATASETS, function(ds) {
                shiny::tags$button(
                  class = "sample-data-item",
                  onclick = sprintf(
                    "Shiny.setInputValue('selected_sample', '%s', {priority: 'event'}); document.getElementById('sample_data_dropdown').style.display='none';",
                    ds$id
                  ),
                  shiny::tags$span(class = "sample-label", ds$label),
                  shiny::tags$span(class = "sample-desc", ds$description)
                )
              })
            )
          ),

          # Knap 4: Blank session
          shiny::div(
            style = "flex: 0 0 120px;",
            square_button(
              "clear_saved", "Blank\nsession", "file-circle-plus",
              "Start med tomt datas\u00e6t"
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
              placeholder = "Inds\u00e6t data fra Excel eller CSV her..."
            ),
            shiny::div(
              style = "display: flex; justify-content: flex-end;",
              shiny::actionButton(
                "load_paste_data",
                shiny::tagList("Forts\u00e6t ", shiny::icon("arrow-right")),
                class = "btn-primary",
                style = "width: 200px;",
                title = "Indl\u00e6s data og g\u00e5 til analyse"
              )
            )
          )
        ), # Luk flex-row div

        # Download tom skabelon-link under knapperne
        shiny::div(
          style = "margin-top: 12px; padding-left: 4px;",
          shiny::downloadLink(
            "download_template",
            label = shiny::tagList(
              " ... eller download en tom Excel-skabelon til dine egne data ",
              shiny::icon("download")
            ),
            class = "download-template-link"
          )
        )
      ) # Luk wrapper div
    )
  )
}

# Fjernet doed kode: create_ui_sidebar(), create_welcome_page(),
# create_getting_started_card(), create_understanding_spc_card(),
# create_step_item(), create_info_section()
# Erstattet af wizard-baseret upload-flow. Se git historie.
