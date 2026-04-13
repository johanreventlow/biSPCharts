# ==============================================================================
# utils_server_paste_data.R
# ==============================================================================
# PASTE DATA AND SAMPLE DATA OBSERVERS
#
# Extracted from: utils_server_event_listeners.R (Phase 2d refactoring)
# ==============================================================================

setup_paste_data_observers <- function(input, output, app_state, session, emit, ui_service = NULL) {
  # Observer: "Fortsæt" knap — indlæs pasted data
  shiny::observeEvent(input$load_paste_data, {
    shinyjs::disable("load_paste_data")
    shinyjs::html(
      "load_paste_data",
      as.character(shiny::tagList(
        shiny::icon("spinner", class = "fa-spin"),
        " Indl\u00e6ser..."
      ))
    )
    on.exit({
      shinyjs::enable("load_paste_data")
      shinyjs::html(
        "load_paste_data",
        as.character(shiny::tagList(
          "Forts\u00e6t ", shiny::icon("arrow-right")
        ))
      )
    })
    # Bevar chart_type fra eksempeldatasæt-valg (reset_form_fields sætter den til "run")
    current_chart_type <- input$chart_type

    # Nulstil alle indstillinger inden nyt datasæt processeres
    if (!is.null(ui_service)) {
      ui_service$reset_form_fields()
    }

    # Gendan chart_type hvis den var sat (fx fra eksempeldatasæt)
    if (!is.null(current_chart_type) && nzchar(current_chart_type) && current_chart_type != CHART_TYPES_EN$run) {
      shiny::updateSelectizeInput(session, "chart_type", selected = current_chart_type)
    }

    safe_operation(
      "Paste data parsing",
      code = {
        handle_paste_data(
          text_data = input$paste_data_input,
          app_state = app_state,
          session_id = sanitize_session_token(session$token),
          emit = emit
        )
      },
      fallback = {
        shiny::showNotification(
          paste0(
            "Data kunne ikke l\u00e6ses. S\u00f8rg for at data har kolonneoverskrifter ",
            "adskilt med semikolon eller tabulator."
          ),
          type = "error", duration = 6
        )
      },
      session = session,
      error_type = "processing",
      emit = emit,
      app_state = app_state
    )
  })

  # Observer: Toggle dropdown for eksempeldatasæt
  shiny::observeEvent(input$toggle_sample_dropdown, {
    shinyjs::toggle("sample_data_dropdown")
  })

  # Observer: Bruger vælger eksempeldatasæt fra dropdown
  shiny::observeEvent(input$selected_sample, {
    sample_id <- input$selected_sample

    # Find datasæt-metadata fra config
    dataset <- NULL
    for (ds in SAMPLE_DATASETS) {
      if (ds$id == sample_id) {
        dataset <- ds
        break
      }
    }

    if (is.null(dataset)) {
      shiny::showNotification(
        "Ukendt eksempeldatas\u00e6t",
        type = "error", duration = 3
      )
      return()
    }

    # Læs CSV-fil fra inst/extdata/
    sample_path <- system.file("extdata", dataset$file, package = "biSPCharts")
    if (sample_path == "" || !file.exists(sample_path)) {
      sample_path <- file.path("inst", "extdata", dataset$file)
    }

    if (file.exists(sample_path)) {
      sample_text <- readLines(sample_path, warn = FALSE, encoding = "UTF-8")
      shiny::updateTextAreaInput(
        session, "paste_data_input",
        value = paste(sample_text, collapse = "\n")
      )
      # Sæt chart type dropdown til det anbefalede chart type for datasættet
      shiny::updateSelectizeInput(
        session, "chart_type",
        selected = dataset$chart_type
      )
      shiny::showNotification(
        paste0(dataset$label, " indsat \u2014 tryk Forts\u00e6t for at analysere"),
        type = "message", duration = 4
      )
    } else {
      shiny::showNotification(
        paste0("Kunne ikke finde fil: ", dataset$file),
        type = "error", duration = 3
      )
    }
  })

  # Download handler: Tom Excel-skabelon
  output$download_template <- shiny::downloadHandler(
    filename = function() {
      "SPC_skabelon.xlsx"
    },
    content = function(file) {
      # Opret tom skabelon med alle relevante kolonner
      template_data <- data.frame(
        Dato = as.Date(character(0)),
        "T\u00e6ller" = numeric(0),
        "N\u00e6vner" = numeric(0),
        Kommentar = character(0),
        Skift = logical(0),
        Frys = logical(0),
        check.names = FALSE
      )
      openxlsx::write.xlsx(template_data, file)
    }
  )

  # Observer: "Indlæs xlsx/csv" knap — trigger skjult fileInput
  shiny::observeEvent(input$trigger_file_upload, {
    # Klik på det skjulte fileInput via JS
    shinyjs::click("direct_file_upload")
  })

  # Observer: Direkte fil-upload — validér og behandl via eksisterende upload-logik
  shiny::observeEvent(input$direct_file_upload, {
    req(input$direct_file_upload)
    file_info <- input$direct_file_upload

    # Filvalidering (rate limiting, størrelse, MIME, korruption)
    validation_result <- validate_uploaded_file(
      file_info, sanitize_session_token(session$token)
    )
    if (!validation_result$valid) {
      shiny::showNotification(
        paste("Filvalidering fejlede:", paste(validation_result$errors, collapse = "; ")),
        type = "error", duration = 5
      )
      return()
    }

    safe_operation("Behandl uploadet fil", {
      ext <- tolower(tools::file_ext(file_info$name))

      if (ext %in% c("xlsx", "xls")) {
        excel_sheets <- readxl::excel_sheets(file_info$datapath)
        if ("Data" %in% excel_sheets && "Indstillinger" %in% excel_sheets) {
          # biSPCharts gem-format: gendannelse direkte uden paste-felt
          handle_excel_upload(file_info$datapath, session, app_state, emit, ui_service)
        } else {
          # Standard Excel: kolonne-aware formatering med komma-decimal
          # Bevarer type-information (i modsætning til apply som koercerer til matrix)
          data <- readxl::read_excel(file_info$datapath, col_names = TRUE)
          header <- paste(names(data), collapse = "\t")
          rows <- vapply(seq_len(nrow(data)), function(i) {
            vals <- vapply(names(data), function(col) {
              v <- data[[col]][[i]]
              if (is.na(v))                               ""
              else if (is.numeric(v))                      format(v, decimal.mark = ",", scientific = FALSE)
              else if (inherits(v, c("Date", "POSIXct"))) format(v, "%Y-%m-%d")
              else                                        as.character(v)
            }, character(1))
            paste(vals, collapse = "\t")
          }, character(1))
          text_content <- paste(c(header, rows), collapse = "\n")
          shiny::updateTextAreaInput(session, "paste_data_input", value = text_content)
          shiny::showNotification(
            paste0("\"", file_info$name, "\" indl\u00e6st \u2014 tryk Forts\u00e6t for at analysere"),
            type = "message", duration = 3
          )
        }
      } else if (ext %in% c("csv", "txt")) {
        # CSV: encoding-aware preview i paste-felt (#166)
        text_content <- read_csv_detect_encoding(file_info$datapath)
        shiny::updateTextAreaInput(
          session, "paste_data_input",
          value = paste(text_content, collapse = "\n")
        )
        shiny::showNotification(
          paste0("\"", file_info$name, "\" indl\u00e6st \u2014 tryk Forts\u00e6t for at analysere"),
          type = "message", duration = 3
        )
      } else {
        shiny::showNotification("Kun xlsx, xls og csv filer understøttes", type = "error")
      }
    })
  })
}
