# mod_export_ui.R
# UI components for export module
# Provides user interface for exporting SPC charts in multiple formats

# Dependencies ----------------------------------------------------------------
# Helper functions loaded globally in global.R for better performance

# Helpers -------------------------------------------------------------------

#' Opret en eksportformat-knap med ikon
#' @param ns Namespace-funktion fra modulet
#' @param suffix Format-suffix ("pdf", "png", "pptx")
#' @param icon_name FontAwesome ikon-navn
#' @param label_text Tekst vist under ikonet
#' @return shiny.tag
#' @noRd
export_format_button <- function(ns, suffix, icon_name, label_text) {
  shiny::div(
    style = "flex: 1; max-width: 120px;",
    shiny::actionButton(
      ns(paste0("export_fmt_", suffix)),
      label = shiny::div(
        shiny::icon(icon_name, class = "fa-2x"),
        shiny::tags$br(),
        shiny::tags$span(label_text, style = "font-size: 0.85rem; font-weight: 600;")
      ),
      class = paste(
        "btn btn-outline-secondary export-format-btn w-100",
        "d-flex flex-column align-items-center justify-content-center"
      ),
      style = "aspect-ratio: 1; padding: 12px;",
      title = paste0("Eksport\u00e9r som ", label_text)
    )
  )
}

# EXPORT MODULE UI ============================================================

#' Export Module UI
#'
#' Brugerinterface til eksport af SPC charts.
#' Understøtter PDF, PNG og PowerPoint formater med live preview.
#'
#' Layout:
#' - Venstre panel (40%): Format selector, metadata input fields
#' - Højre panel (60%): Live preview af chart
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny UI element
#' @family export_modules
#' @export
mod_export_ui <- function(id) {
  ns <- shiny::NS(id)

  # Hovedlayout: To-kolonne layout + navigationsknapper
  shiny::tagList(
  bslib::layout_columns(
    col_widths = c(4, 8), # 40% / 60% split
    height = "auto",
    min_height = "calc(100vh - 200px)",

    # VENSTRE PANEL: Format selector og metadata ----
    bslib::card(
      full_screen = FALSE,
      height = "100%",
      bslib::card_header(
        shiny::div(
          shiny::icon("file-export"),
          " Eksport Indstillinger"
        )
      ),
      bslib::card_body(
        # Format selector (ikonknapper) ----
        shiny::div(
          style = "margin-bottom: 20px;",
          shiny::tags$label(
            "Eksport Format:",
            class = "control-label",
            style = "font-weight: 500; margin-bottom: 10px; display: block;"
          ),
          # Hidden input — værdi styres udelukkende af JS via Shiny.setInputValue()
          shiny::tags$input(
            type = "hidden",
            id = ns("export_format"),
            name = ns("export_format"),
            value = "pdf"
          ),
          shiny::div(
            style = "display: flex; gap: 12px; justify-content: center;",
            export_format_button(ns, "pdf", "file-pdf", "PDF"),
            export_format_button(ns, "png", "file-image", "PNG"),
            export_format_button(ns, "pptx", "file-powerpoint", "PowerPoint")
          ),
          shiny::tags$style(htmltools::HTML("
            .export-format-btn {
              transition: all 0.15s ease;
            }
            .export-format-btn:hover {
              background-color: #fff !important;
              border-color: #828c8d !important;
              color: #828c8d !important;
            }
            .export-format-btn.upload-btn-active {
              background-color: #95a5a6 !important;
              border-color: #95a5a6 !important;
              color: #fff !important;
            }
          "))
        ),
        shiny::hr(),

        # Metadata fields (alle formater) ----
        shiny::div(
          style = "margin-bottom: 15px;",
          shiny::textAreaInput(
            ns("export_title"),
            "Titel:",
            value = "",
            # placeholder = "Skriv en kort og sigende titel,\n**eller konkludér, hvad grafen viser**",
            placeholder = "Skriv en kort titel, eller tilføj en konklusion,\n**der tydeligt opsummerer, hvad grafen fortæller**",
            width = "100%",
            rows = 2,
            resize = "vertical"
          ),
          shiny::tags$small(
            class = "text-muted",
            sprintf("Maksimalt %d karakterer", EXPORT_TITLE_MAX_LENGTH)
          )
        ),
        shiny::div(
          style = "margin-bottom: 15px;",
          shiny::textInput(
            ns("export_department"),
            "Afdeling/Afsnit:",
            value = "",
            placeholder = "F.eks. 'Medicinsk Afdeling'",
            width = "100%"
          ),
          shiny::tags$small(
            class = "text-muted",
            sprintf("Maksimalt %d karakterer", EXPORT_DEPARTMENT_MAX_LENGTH)
          )
        ),

        # Conditional panels for format-specific fields ----

        ## PDF-specific fields ----
        shiny::conditionalPanel(
          condition = sprintf("input['%s'] == 'pdf'", ns("export_format")),
          shiny::div(
            style = "margin-bottom: 15px;",
            shiny::textAreaInput(
              ns("pdf_description"),
              "Datadefinition:",
              value = "",
              placeholder = "Beskriv hvad indikatoren måler og hvordan data opgøres",
              width = "100%",
              rows = 4,
              resize = "vertical"
            ),
            shiny::tags$small(
              class = "text-muted",
              sprintf("Maksimalt %d karakterer", EXPORT_DESCRIPTION_MAX_LENGTH)
            )
          ),
          shiny::div(
            style = "margin-bottom: 15px;",
            shiny::textAreaInput(
              ns("pdf_improvement"),
              "Analyse af processen:",
              value = "",
              placeholder = "Beskriv hvad SPC-analysen viser, eller lad feltet auto-udfylde baseret på data",
              width = "100%",
              rows = 4,
              resize = "vertical"
            ),
            shiny::tags$small(
              class = "text-muted",
              sprintf("Maksimalt %d karakterer", EXPORT_DESCRIPTION_MAX_LENGTH)
            ),
            shiny::div(
              id = ns("analysis_auto_indicator"),
              class = "text-muted",
              style = "font-size: 0.8rem; font-style: italic; margin-top: 4px;",
              shiny::icon("magic"),
              " Auto-genereret analyse \u2014 rediger for at tilpasse"
            ),
          ),
          # AI Suggestion Button
          shiny::div(
            style = "margin-bottom: 15px;",
            shiny::actionButton(
              ns("ai_generate_suggestion"),
              label = "Generér forslag med AI",
              icon = shiny::icon("wand-magic-sparkles"),
              class = "btn-primary btn-sm",
              style = "margin-top: 5px;"
            ),
            # Loading feedback (dynamic)
            shiny::uiOutput(ns("ai_loading_feedback")),
            # Help text
            shiny::tags$p(
              class = "text-muted",
              style = "font-size: 0.85rem; margin-top: 8px; margin-bottom: 0;",
              shiny::icon("info-circle"),
              " AI kan hjælpe med at formulere en mere detaljeret analyse af processen. Teksten kan redigeres efter behov."
            )
          )
        ),

        ## PNG-specific fields ----
        shiny::conditionalPanel(
          condition = sprintf("input['%s'] == 'png'", ns("export_format")),
          shiny::div(
            style = "margin-bottom: 15px;",
            shiny::selectInput(
              ns("png_size_preset"),
              "Størrelse:",
              choices = c(
                EXPORT_SIZE_PRESETS$small$label,
                EXPORT_SIZE_PRESETS$medium$label,
                EXPORT_SIZE_PRESETS$large$label
              ),
              selected = EXPORT_SIZE_PRESETS$medium$label,
              width = "100%"
            )
          ),
          shiny::div(
            style = "margin-bottom: 15px;",
            shiny::selectInput(
              ns("png_dpi"),
              "DPI (Opløsning):",
              choices = EXPORT_DPI_OPTIONS,
              selected = 96,
              width = "100%"
            ),
            shiny::tags$small(
              class = "text-muted",
              "96 DPI: Skærm | 150 DPI: Medium print | 300 DPI: Høj kvalitet"
            )
          )
        ),

        ## PowerPoint-specific fields ----
        shiny::conditionalPanel(
          condition = sprintf("input['%s'] == 'pptx'", ns("export_format")),
          shiny::div(
            style = "margin-bottom: 15px;",
            shiny::tags$p(
              class = "text-muted",
              style = "font-size: 0.9rem; margin-bottom: 10px;",
              shiny::icon("info-circle"),
              " Chart eksporteres med optimal størrelse til PowerPoint slides."
            ),
            shiny::tags$p(
              class = "text-muted",
              style = "font-size: 0.85rem;",
              sprintf(
                "Standard: %g × %g %s ved %d DPI",
                EXPORT_POWERPOINT_CONFIG$width,
                EXPORT_POWERPOINT_CONFIG$height,
                EXPORT_POWERPOINT_CONFIG$unit,
                EXPORT_SIZE_PRESETS$powerpoint$dpi
              )
            )
          )
        )
      )
    ),

    # HØJRE PANEL: Live preview ----
    bslib::card(
      full_screen = TRUE,
      height = "100%",
      fillable = TRUE,
      bslib::card_header(
        shiny::div(
          shiny::icon("eye"),
          " Preview"
        )
      ),
      bslib::card_body(
        fill = TRUE,
        style = "background-color: #f8f8f8!important;",
        # Conditional panels for preview availability
        # Show warning when no plot available
        shiny::conditionalPanel(
          condition = "output.plot_available == false",
          ns = ns,
          shiny::div(
            class = "alert alert-warning",
            style = "margin: 20px; padding: 20px;",
            shiny::icon("exclamation-triangle"),
            " Ingen graf er genereret endnu. Gå til hovedsiden for at oprette en SPC-graf først."
          )
        ),
        # Show PDF preview when PDF format selected
        shiny::conditionalPanel(
          condition = "output.plot_available == true && output.is_pdf_format == true",
          ns = ns,
          shiny::div(
            style = "height: 100%; display: flex; align-items: center; justify-content: center; background-color: #f8f8f8; padding: 10px;",
            shiny::div(
              class = "export-preview-container",
              style = paste0(
                "border: 1px solid #d2d2d2; border-radius: 4px; ",
                "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                "background-color: white; ",
                "max-width: 100%; max-height: 100%; ",
                "position: relative;"
              ),
              shiny::imageOutput(
                ns("pdf_preview"),
                width = "100%",
                height = "100%"
              ),
              # CSS: fit preview image within container without scrolling
              shiny::tags$style(shiny::HTML(paste0(
                "#", ns("pdf_preview"), " img { ",
                "max-width: 100%; max-height: calc(100vh - 350px); ",
                "width: auto; height: auto; ",
                "object-fit: contain; display: block; }"
              )))
            )
          )
        ),
        # Show ggplot preview when PNG/PPTX format selected
        shiny::conditionalPanel(
          condition = "output.plot_available == true && output.is_pdf_format == false",
          ns = ns,
          shiny::div(
            style = "height: 100%; display: flex; align-items: center; justify-content: center; overflow: auto; background-color: #f8f8f8; padding: 20px;",
            shiny::div(
              class = "export-preview-container",
              style = paste0(
                "border: 1px solid #d2d2d2; border-radius: 4px; ",
                "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                "background-color: white; position: relative;"
              ),
              shiny::plotOutput(
                ns("export_preview"),
                width = "800px",
                height = "450px"
              )
            )
          )
        )
      )
    )
  ),
  # Tilbage/Eksportér knapper under cards
  shiny::div(
    style = "display: flex; justify-content: space-between;",
    shiny::actionButton(
      ns("back_to_analysis"),
      shiny::tagList(shiny::icon("arrow-left"), " Tilbage"),
      class = "btn-secondary",
      style = "width: 200px;",
      title = "Gå tilbage til analyse"
    ),
    shiny::downloadButton(
      ns("download_export"),
      "Eksportér",
      icon = shiny::icon("file-export"),
      class = "btn-primary",
      style = "width: 200px; text-align: center;"
    )
  )
  )
}
