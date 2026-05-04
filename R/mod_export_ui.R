# mod_export_ui.R
# UI components for export module
# Provides user interface for exporting SPC charts in multiple formats

# Dependencies ----------------------------------------------------------------
# Helper functions loaded globally in global.R for better performance

# Helpers -------------------------------------------------------------------

#' Opret en eksportformat-knap med ikon
#' @param ns Namespace-funktion fra modulet
#' @param suffix Format-suffix ("pdf", "png")
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
#' Understoetter PDF og PNG formater med live preview.
#'
#' Layout:
#' - Venstre panel (40%): Format selector, metadata input fields
#' - Hoejre panel (60%): Live preview af chart
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny UI element
#' @family export_modules
#' @keywords internal
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
            # Hidden input -- vaerdi styres udelukkende af JS via Shiny.setInputValue()
            shiny::tags$input(
              type = "hidden",
              id = ns("export_format"),
              name = ns("export_format"),
              value = "pdf"
            ),
            shiny::div(
              style = "display: flex; gap: 12px; justify-content: center;",
              export_format_button(ns, "pdf", "file-pdf", "PDF"),
              export_format_button(ns, "png", "file-image", "PNG")
            ),
            {
              colors <- get_hospital_colors()
              shiny::tags$style(htmltools::HTML(paste0("
              .export-format-btn {
                transition: all 0.15s ease;
              }
              .export-format-btn:hover {
                background-color: #fff !important;
                border-color: ", colors$ui_grey_dark, " !important;
                color: ", colors$ui_grey_dark, " !important;
              }
              .export-format-btn.upload-btn-active {
                background-color: ", colors$ui_grey_mid, " !important;
                border-color: ", colors$ui_grey_mid, " !important;
                color: #fff !important;
              }
            ")))
            }
          ),
          shiny::hr(),

          # Sammenklapbar hjaelp (minimal footprint naar sammenklappet)
          shiny::div(
            shiny::tags$button(
              class = "btn btn-sm btn-link text-muted p-0",
              style = "text-decoration: none; font-size: 0.75rem; line-height: 1.2;",
              onclick = "$('#eksporter_help_content').slideToggle(200); $(this).find('.chevron-icon').toggleClass('fa-chevron-down fa-chevron-up');",
              shiny::icon("chevron-down", class = "chevron-icon", style = "font-size: 0.65em; margin-right: 3px;"),
              "Hj\u00e6lp til dette trin"
            ),
            shiny::div(
              id = "eksporter_help_content",
              style = "display: none;",
              shiny::div(
                class = "alert alert-light border mt-1 mb-1",
                style = "font-size: 0.82rem; padding: 8px 12px;",
                shiny::tags$p(class = "mb-1", shiny::tags$strong("1."), " V\u00e6lg format (PDF for rapporter, PNG for pr\u00e6sentationer)."),
                shiny::tags$p(class = "mb-1", shiny::tags$strong("2."), " Skriv en kort titel der opsummerer hvad diagrammet viser."),
                shiny::tags$p(class = "mb-1", shiny::tags$strong("3."), " Udfyld datadefinition og analyse af processen."),
                shiny::tags$p(class = "mb-0", shiny::tags$strong("Tip:"), " Brug AI-funktionen til at generere et udkast til analyseteksten, og redig\u00e9r derefter.")
              )
            )
          ),

          # Metadata fields (alle formater) ----
          shiny::conditionalPanel(
            condition = sprintf("input['%s'] != 'png'", ns("export_format")),
            shiny::div(
              style = "margin-bottom: 15px;",
              shiny::textInput(
                ns("export_hospital"),
                "Hospital eller virksomhed:",
                value = get_hospital_name(),
                placeholder = "F.eks. 'Bispebjerg og Frederiksberg Hospital'",
                width = "100%"
              )
            )
          ),
          shiny::div(
            style = "margin-bottom: 15px;",
            shiny::textInput(
              ns("export_department"),
              "Afdeling eller afsnit:",
              value = "",
              placeholder = "F.eks. 'Medicinsk Afdeling'",
              width = "100%"
            )
          ),
          shiny::div(
            style = "margin-bottom: 15px;",
            shiny::textAreaInput(
              ns("export_title"),
              "Indikatortitel:",
              value = "",
              placeholder = "Skriv en kort titel, eller tilf\u00f8j en konklusion,\n**der tydeligt opsummerer, hvad grafen fort\u00e6ller**",
              width = "100%",
              rows = 2,
              resize = "vertical"
            ),
            shiny::tags$small(
              class = "text-muted",
              sprintf("Maksimalt %d karakterer", EXPORT_TITLE_MAX_LENGTH)
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
                shiny::tagList(
                  "Datadefinition:",
                  shiny::icon("circle-info", style = "font-size: 0.8em; opacity: 0.6; margin-left: 4px;") |>
                    bslib::tooltip("Beskriv hvad indikatoren m\u00e5ler og hvordan data er opgjort. Fx: \u201cAndel patienter m\u00f8dt til ambulant aftale (m\u00f8dt/tilkaldt), opgjort m\u00e5nedligt.\u201d")
                ),
                value = "",
                placeholder = "Beskriv hvad indikatoren m\u00e5ler og hvordan data opg\u00f8res",
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
                shiny::tagList(
                  "Analyse af processen:",
                  shiny::icon("circle-info", style = "font-size: 0.8em; opacity: 0.6; margin-left: 4px;") |>
                    bslib::tooltip("Beskriv hvad diagrammet viser \u2014 er processen stabil? Er der signaler? Hvad kan forklare eventuelle udsving?")
                ),
                value = "",
                placeholder = "Beskriv hvad SPC-analysen viser, eller lad feltet auto-udfylde baseret p\u00e5 data",
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
            # AI Suggestion Button -- midlertidigt skjult, genaktiveres senere
            # Funktionaliteten er intakt i mod_export_server.R og fct_ai_improvement_suggestions.R
            shiny::div(
              style = "display: none;",
              shiny::actionButton(
                ns("ai_generate_suggestion"),
                label = "Gener\u00e9r forslag med AI",
                icon = shiny::icon("wand-magic-sparkles"),
                class = "btn-primary btn-sm",
                style = "margin-top: 5px;"
              ),
              shiny::uiOutput(ns("ai_loading_feedback")),
              shiny::tags$p(
                class = "text-muted",
                style = "font-size: 0.85rem; margin-top: 8px; margin-bottom: 0;",
                shiny::icon("info-circle"),
                " AI kan hj\u00e6lpe med at formulere en mere detaljeret analyse af processen. Teksten kan redigeres efter behov."
              )
            )
          ),

          ## PNG-specific fields ----
          shiny::conditionalPanel(
            condition = sprintf("input['%s'] == 'png'", ns("export_format")),
            shiny::div(
              style = "margin-bottom: 10px;",
              shiny::selectizeInput(
                ns("png_preset"),
                "Format:",
                choices = c(
                  "HD 16:9 (1920 \u00d7 1080)" = "1920x1080",
                  "HD 16:9 (1280 \u00d7 720)" = "1280x720",
                  "4:3 (1600 \u00d7 1200)" = "1600x1200",
                  "4:3 (1024 \u00d7 768)" = "1024x768",
                  "Kvadrat (1080 \u00d7 1080)" = "1080x1080",
                  "A4 liggende (1754 \u00d7 1240)" = "1754x1240",
                  "Brugerdefineret" = "custom"
                ),
                selected = "1920x1080",
                width = "100%"
              ),
              shiny::tags$style(shiny::HTML(paste0(
                "#", ns("png_preset"),
                "+ div>.selectize-dropdown{bottom: 100% !important; top:auto!important;}"
              )))
            ),
            shiny::div(
              style = "margin-bottom: 15px;",
              shiny::tags$label("St\u00f8rrelse (px):", class = "control-label"),
              shiny::div(
                style = "display: flex; align-items: center; gap: 8px;",
                shiny::numericInput(
                  ns("png_width"),
                  label = NULL,
                  value = 1920,
                  min = 400,
                  max = 4000,
                  step = 10,
                  width = "120px"
                ),
                shiny::tags$span(
                  style = paste0("font-size: 1.1rem; color: ", get_hospital_colors()$ui_grey_dark, "; padding-bottom: 15px;"),
                  "\u00d7"
                ),
                shiny::numericInput(
                  ns("png_height"),
                  label = NULL,
                  value = 1080,
                  min = 300,
                  max = 4000,
                  step = 10,
                  width = "120px"
                ),
                shiny::tags$span(
                  style = paste0("color: ", get_hospital_colors()$ui_grey_mid, "; font-size: 0.85rem; padding-bottom: 15px;"),
                  "px"
                )
              )
            ),
          ),

          ## Datakilde / fodnote: nederste felt; sendes til BFHcharts footer_content (#485)
          shiny::div(
            style = "margin-bottom: 15px;",
            shiny::textInput(
              ns("export_footnote"),
              "Datakilde ell. fodnote:",
              value = "",
              placeholder = "Eksempel: Datakilde: KvalDB udtr\u00e6k 2026-04-29",
              width = "100%"
            ),
            # HTML5 maxlength (klient-side hard cap; server validerer ogsaa)
            shiny::tags$script(sprintf(
              "$('#%s').attr('maxlength', %d);",
              ns("export_footnote"),
              EXPORT_FOOTNOTE_MAX_LENGTH
            ))
          ),
        )
      ),

      # HOeJRE PANEL: Live preview ----
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
          style = "background-color: var(--bs-light, #f8f8f8)!important;",
          # Conditional panels for preview availability
          # Show warning when no plot available
          shiny::conditionalPanel(
            condition = "output.plot_available == false",
            ns = ns,
            shiny::div(
              class = "alert alert-warning",
              style = "margin: 20px; padding: 20px;",
              shiny::icon("exclamation-triangle"),
              " Ingen graf er genereret endnu. G\u00e5 til hovedsiden for at oprette en SPC-graf f\u00f8rst."
            )
          ),
          # Show PDF preview when PDF format selected
          shiny::conditionalPanel(
            condition = "output.plot_available == true && output.is_pdf_format == true",
            ns = ns,
            shiny::div(
              style = "height: 100%; display: flex; align-items: center; justify-content: center; background-color: var(--bs-light, #f8f8f8); padding: 10px;",
              shiny::div(
                class = "export-preview-container",
                style = paste0(
                  "border: 1px solid #ccd3dd; border-radius: 4px; ",
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
          # Show ggplot preview when PNG format selected
          shiny::conditionalPanel(
            condition = "output.plot_available == true && output.is_pdf_format == false",
            ns = ns,
            shiny::div(
              style = "height: 100%; display: flex; align-items: center; justify-content: center; overflow: hidden; background-color: var(--bs-light, #f8f8f8); padding: 20px;",
              shiny::div(
                class = "export-preview-container",
                style = paste0(
                  "border: 1px solid #ccd3dd; border-radius: 4px; ",
                  "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                  "background-color: white; position: relative; ",
                  "max-width: 100%; max-height: calc(100vh - 300px);"
                ),
                shiny::plotOutput(
                  ns("export_preview"),
                  width = "100%",
                  height = "auto"
                )
              ),
              # Skaler preview-billedet til at passe inden for rammen
              shiny::tags$style(shiny::HTML(paste0(
                "#", ns("export_preview"), " img { ",
                "max-width: 100%; max-height: calc(100vh - 340px); ",
                "width: auto; height: auto; ",
                "object-fit: contain; display: block; }"
              )))
            )
          )
        )
      )
    ),
    # Tilbage/Gem/Eksporter knapper under cards
    shiny::div(
      style = "display: flex; justify-content: space-between; align-items: center;",
      shiny::actionButton(
        ns("back_to_analysis"),
        shiny::tagList(shiny::icon("arrow-left"), " Tilbage"),
        class = "btn-secondary",
        style = "width: 200px;",
        title = "G\u00e5 tilbage til analyse"
      ),
      shinyjs::disabled(
        shiny::downloadButton(
          "download_spc_file_step3",
          "Gem kopi af data og indstillinger",
          class = "btn-outline-secondary",
          style = "width: auto; min-width: 200px;",
          title = "Gem kopi af data og indstillinger til Excel-fil"
        )
      ),
      shiny::downloadButton(
        ns("download_export"),
        "Eksport\u00e9r",
        icon = shiny::icon("file-export"),
        class = "btn-primary",
        style = "width: 200px; text-align: center; color: white !important;"
      )
    )
  )
}
