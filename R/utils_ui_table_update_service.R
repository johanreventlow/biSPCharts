# utils_ui_table_update_service.R
# Tabel-relaterede UI-opdateringer (excelR + eventuel DT)

#' Formater data til excelR-visning
#'
#' Ren hjaelpefunktion der konverterer numeriske kolonner til dansk
#' format (komma-decimal) for visning i excelR-tabel.
#' Logiske kolonner (Skift/Frys) ekskluderes fra numerisk formatering.
#'
#' @param data Data frame der skal formateres
#' @return Data frame med numeriske kolonner konverteret til character
#'
#' @keywords internal
format_data_for_excelr <- function(data) {
  if (is.null(data) || nrow(data) == 0) {
    return(data)
  }
  # Find numeriske kolonner og ekskluder logiske (Skift/Frys)
  numeric_cols <- names(data)[vapply(data, is.numeric, logical(1))]
  numeric_cols <- setdiff(numeric_cols, c("Skift", "Frys"))
  for (col in numeric_cols) {
    data[[col]] <- ifelse(
      is.na(data[[col]]),
      NA_character_,
      format(data[[col]], decimal.mark = ",", big.mark = "")
    )
  }
  data
}

#' Create Table Update Service
#'
#' Tynd closure der centraliserer tabel-opdateringer for excelR og
#' fremtidige dataTable-widgets. Deler token-protection med
#' `safe_programmatic_ui_update()` (samme moenster som column/form services).
#'
#' Tabel-opdatering i denne app sker via state-aendring (set_current_data +
#' table_version bump) -- excelR's renderExcel re-renderer reaktivt.
#' Der er ingen proxy-baseret updateExcelR i packagets API.
#'
#' @param session Shiny session-objekt
#' @param app_state Centraliseret app state
#' @return Liste med tabel-update-funktioner
#'
#' @keywords internal
create_table_update_service <- function(session, app_state) {
  # Hjaelper: foroeg table_version for at tvinge excelR re-render
  .bump_table_version <- function() {
    current <- shiny::isolate(app_state$data$table_version) %||% 0L
    shiny::isolate({
      app_state$data$table_version <- current + 1L
    })
  }

  # Opdater excelR-tabel med nye data
  #
  # Opdatering sker via set_current_data() + table_version bump:
  # excelR's renderExcel() re-renderer reaktivt naar state aendres.
  # Wrappet i safe_programmatic_ui_update for token-protection
  # (forhindrer cirkulaere event-loops under programmatisk opdatering).
  #
  # @param table_id Tabelens output ID (bruges som log-kontekst; renderExcel
  #   reagerer paa app_state$data$current_data uanset ID)
  # @param data Data frame der skal vises i tabellen
  # @param options Liste med valgfrie indstillinger (reserveret, bruges ikke endnu)
  #
  update_excelr_data <- function(table_id, data, options = list()) {
    safe_programmatic_ui_update(session, app_state, function() {
      safe_operation(
        paste("Opdater excelR tabel:", table_id),
        code = {
          set_current_data(app_state, data)
          .bump_table_version()
          log_debug_kv(
            .context = "TABLE_UPDATE_SERVICE",
            table_id = table_id,
            rows = nrow(data) %||% 0L,
            cols = ncol(data) %||% 0L
          )
        },
        fallback = function(e) {
          log_error(
            paste("Fejl ved opdatering af excelR tabel:", table_id, "-", e$message),
            "TABLE_UPDATE_SERVICE"
          )
        },
        error_type = "processing"
      )
    })
  }

  # Opdater DT::datatable-widget (stub -- DT bruges ikke i denne app endnu)
  #
  # Denne funktion er reserveret til fremtidig brug hvis DT::datatable
  # introduceres som supplement til excelR. I nuvaerende implementation
  # er DT ikke aktivt -- kald logger en advarsel og returnerer usynligt NULL.
  #
  # @param table_id DT proxy ID
  # @param data Data frame der skal vises
  # @param options Liste med valgfrie DT-indstillinger
  #
  update_datatable <- function(table_id, data, options = list()) {
    log_debug_kv(
      .context = "TABLE_UPDATE_SERVICE",
      table_id = table_id,
      note = "DT::datatable bruges ikke i denne app - update_datatable er stub"
    )
    invisible(NULL)
  }

  # Ryd tabel-indhold og nulstil table_version
  #
  # Saetter current_data til NULL og bumper table_version saa
  # excelR's renderExcel() reagerer korrekt via req()-guard.
  #
  # @param table_id Tabelens output ID (bruges som log-kontekst)
  #
  clear_table <- function(table_id) {
    safe_programmatic_ui_update(session, app_state, function() {
      safe_operation(
        paste("Ryd tabel:", table_id),
        code = {
          set_current_data(app_state, NULL)
          .bump_table_version()
          log_debug_kv(
            .context = "TABLE_UPDATE_SERVICE",
            table_id = table_id,
            action = "cleared"
          )
        },
        fallback = function(e) {
          log_error(
            paste("Fejl ved rydning af tabel:", table_id, "-", e$message),
            "TABLE_UPDATE_SERVICE"
          )
        },
        error_type = "processing"
      )
    })
  }

  list(
    update_excelr_data = update_excelr_data,
    update_datatable = update_datatable,
    clear_table = clear_table
  )
}
