# server_observer_manager.R
# Administrerer server-observers og sikrer oprydning

#' Opret observer manager
#'
#' Giver et sæt hjælpefunktioner til at registrere, fjerne og rydde op i
#' Shiny observers, så vi undgår memory leaks og hængende observers mellem
#' sessioner/tests.
#'
#' @return Liste med funktionerne `add()`, `remove()`, `cleanup_all()` og `count()`
#' @keywords internal
observer_manager <- function() {
  observers <- list()

  list(
    add = function(observer, name = NULL) {
      id <- if (is.null(name)) length(observers) + 1 else name
      # Destruér eksisterende observer ved navne-overwrite (#487) for at
      # undgaa orphan-observers i Shiny's reactive graph. Cleanup_all() rydder
      # kun det der er i `observers`-listen — overskrevne entries forsvinder
      # ellers aldrig.
      existing <- observers[[id]]
      if (!is.null(existing) && !is.null(existing$destroy)) {
        tryCatch(
          existing$destroy(),
          error = function(e) {
            log_warn(
              message = paste("Observer destroy fejlede ved overwrite for", id, ":", e$message),
              .context = "OBSERVER_MGMT"
            )
          }
        )
      }
      observers[[id]] <<- observer
      id
    },
    remove = function(id) {
      if (id %in% names(observers)) {
        if (!is.null(observers[[id]]$destroy)) {
          observers[[id]]$destroy()
        }
        observers[[id]] <<- NULL
      }
      invisible()
    },
    cleanup_all = function() {
      for (id in names(observers)) {
        if (!is.null(observers[[id]]$destroy)) {
          tryCatch(
            observers[[id]]$destroy(),
            error = function(e) {
              log_error(
                message = paste("Observer cleanup fejl for", id, ":", e$message),
                component = "[OBSERVER_MGMT]"
              )
            }
          )
        }
      }
      observers <<- list()
      invisible()
    },
    count = function() {
      length(observers)
    }
  )
}
