# ==============================================================================
# utils_server_paste_data.R
# ==============================================================================
# PASTE DATA AND SAMPLE DATA OBSERVERS
#
# Extracted from: utils_server_event_listeners.R (Phase 2d refactoring)
# ==============================================================================

setup_paste_data_observers <- function(input, output, app_state, session, emit, ui_service = NULL) {
  # Observer: "Fortsaet" knap -- indlaes pasted data
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
    # Bevar chart_type fra eksempeldatasaet-valg (reset_form_fields saetter den til "run")
    current_chart_type <- input$chart_type

    # Nulstil alle indstillinger inden nyt datasaet processeres
    if (!is.null(ui_service)) {
      ui_service$reset_form_fields()
    }

    # Gendan chart_type hvis den var sat (fx fra eksempeldatasaet)
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

  # Observer: Toggle dropdown for eksempeldatasaet
  shiny::observeEvent(input$toggle_sample_dropdown, {
    shinyjs::toggle("sample_data_dropdown")
  })

  # Observer: Bruger vaelger eksempeldatasaet fra dropdown
  shiny::observeEvent(input$selected_sample, {
    sample_id <- input$selected_sample

    # Find datasaet-metadata fra config
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

    # Laes CSV-fil fra inst/extdata/
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
      # Saet chart type dropdown til det anbefalede chart type for datasaettet
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

  # Observer: "Indlaes xlsx/csv" knap -- trigger skjult fileInput
  shiny::observeEvent(input$trigger_file_upload, {
    # Klik paa det skjulte fileInput via JS
    shinyjs::click("direct_file_upload")
  })

  # Observer: Direkte fil-upload -- valider og behandl via eksisterende upload-logik
  shiny::observeEvent(input$direct_file_upload, {
    req(input$direct_file_upload)
    file_info <- input$direct_file_upload

    # Filvalidering (rate limiting, stoerrelse, MIME, korruption)
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
        excel_sheets <- list_excel_sheets(file_info$datapath)
        if (is.null(excel_sheets) || length(excel_sheets) == 0) {
          shiny::showNotification(
            "Excel-filen kunne ikke l\u00e6ses (ingen ark fundet)",
            type = "error", duration = 5
          )
          return()
        }
        if (is_bispchart_excel_format(excel_sheets)) {
          # biSPCharts gem-format: gendannelse direkte uden paste-felt
          handle_excel_upload(file_info$datapath, session, app_state, emit, ui_service)
        } else if (length(excel_sheets) == 1) {
          # Standard single-sheet: laes direkte
          data <- readxl::read_excel(
            file_info$datapath,
            sheet = excel_sheets[1],
            col_names = TRUE
          )
          shiny::updateTextAreaInput(
            session, "paste_data_input",
            value = excel_data_to_paste_text(data)
          )
          shiny::showNotification(
            paste0("\"", file_info$name, "\" indl\u00e6st \u2014 tryk Forts\u00e6t for at analysere"),
            type = "message", duration = 3
          )
        } else {
          # Standard multi-sheet: vis sheet-picker, vent paa eksplicit valg
          empty_flags <- detect_empty_sheets(file_info$datapath, excel_sheets)
          app_state$session$pending_excel_upload <- list(
            datapath = file_info$datapath,
            name = file_info$name,
            sheets = excel_sheets,
            empty_flags = empty_flags
          )
          shinyjs::show("excel_sheet_dropdown")
          shiny::showNotification(
            paste0(
              "\"", file_info$name, "\" indeholder ",
              length(excel_sheets),
              " faneblade \u2014 v\u00e6lg det \u00f8nskede ark fra menuen"
            ),
            type = "message", duration = 5
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
        shiny::showNotification("Kun xlsx, xls og csv filer underst\u00f8ttes", type = "error")
      }
    })
  })

  # Render: Excel sheet-picker dropdown items (vises ved multi-sheet upload)
  output$excel_sheet_dropdown_items <- shiny::renderUI({
    pending <- app_state$session$pending_excel_upload
    if (is.null(pending) || is.null(pending$sheets) || length(pending$sheets) == 0) {
      return(NULL)
    }
    build_excel_sheet_dropdown_items(pending$sheets, pending$empty_flags)
  })

  # Observer: Bruger vaelger ark fra sheet-picker dropdown
  shiny::observeEvent(input$selected_excel_sheet, {
    sheet_name <- input$selected_excel_sheet
    pending <- app_state$session$pending_excel_upload

    if (is.null(pending) || is.null(sheet_name) || !nzchar(sheet_name)) {
      shinyjs::hide("excel_sheet_dropdown")
      return()
    }
    if (!sheet_name %in% pending$sheets) {
      shiny::showNotification(
        paste0("Ukendt ark: ", sheet_name),
        type = "error", duration = 3
      )
      shinyjs::hide("excel_sheet_dropdown")
      return()
    }

    safe_operation("Indlaes valgt Excel-ark", {
      data <- readxl::read_excel(
        path = pending$datapath,
        sheet = sheet_name,
        col_names = TRUE
      )
      shiny::updateTextAreaInput(
        session, "paste_data_input",
        value = excel_data_to_paste_text(data)
      )
      shiny::showNotification(
        paste0(
          "Ark \"", sheet_name, "\" indl\u00e6st - tryk Forts\u00e6t for at analysere"
        ),
        type = "message", duration = 4
      )
      app_state$session$pending_excel_upload <- NULL
      shinyjs::hide("excel_sheet_dropdown")
    })
  })
}

# ---- Internal helpers --------------------------------------------------------

#' Konverter data.frame fra Excel til tab-separeret paste-text
#'
#' Bevarer type-information: numeriske formatteres med komma-decimal, datoer
#' i ISO 8601, NA -> tom streng. Headers indlejres som foerste linje.
#'
#' @param data data.frame fra `readxl::read_excel()`
#' @return Single character med "\\n"-separerede raekker
#' @noRd
excel_data_to_paste_text <- function(data) {
  if (is.null(data) || ncol(data) == 0) {
    return("")
  }
  header <- paste(names(data), collapse = "\t")
  if (nrow(data) == 0) {
    return(header)
  }
  rows <- vapply(seq_len(nrow(data)), function(i) {
    vals <- vapply(names(data), function(col) {
      v <- data[[col]][[i]]
      if (is.na(v)) {
        ""
      } else if (is.numeric(v)) {
        format(v, decimal.mark = ",", scientific = FALSE)
      } else if (inherits(v, c("Date", "POSIXct"))) {
        format(v, "%Y-%m-%d")
      } else {
        as.character(v)
      }
    }, character(1))
    paste(vals, collapse = "\t")
  }, character(1))
  paste(c(header, rows), collapse = "\n")
}

#' Byg sheet-picker dropdown items (HTML-buttons)
#'
#' En button per ark, med JSON-escaped onclick som saetter `selected_excel_sheet`
#' input. Tomme ark faar dempet styling via `excel-sheet-item--empty`-klassen.
#'
#' @param sheets Character vector af ark-navne
#' @param empty_flags Logical vector samme laengde - TRUE for tomme ark
#' @return `tagList()` af `<button>`-elementer
#' @noRd
build_excel_sheet_dropdown_items <- function(sheets, empty_flags = NULL) {
  if (is.null(sheets) || length(sheets) == 0) {
    return(NULL)
  }
  if (is.null(empty_flags) || length(empty_flags) != length(sheets)) {
    empty_flags <- rep(FALSE, length(sheets))
  }

  items <- lapply(seq_along(sheets), function(i) {
    sheet_name <- sheets[i]
    is_empty <- isTRUE(empty_flags[i])

    # JSON-escape sheet-navn for sikker JS-injection
    name_json <- jsonlite::toJSON(sheet_name, auto_unbox = TRUE)
    onclick <- sprintf(
      paste0(
        "Shiny.setInputValue('selected_excel_sheet', %s, {priority: 'event'});",
        " document.getElementById('excel_sheet_dropdown').style.display='none';"
      ),
      name_json
    )

    css_class <- if (is_empty) "excel-sheet-item excel-sheet-item--empty" else "excel-sheet-item"
    label <- if (is_empty) {
      paste0(sheet_name, " (tomt ark)")
    } else {
      sheet_name
    }

    shiny::tags$button(
      type = "button",
      class = css_class,
      onclick = onclick,
      htmltools::htmlEscape(label)
    )
  })

  shiny::tagList(
    shiny::tags$div(
      class = "excel-sheet-header",
      "V\u00e6lg faneblad"
    ),
    items
  )
}
