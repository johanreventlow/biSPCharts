# utils_end_to_end_debug.R
# Enhanced debug utilities for comprehensive end-to-end testing

# END-TO-END DEBUG INFRASTRUCTURE ==========================================

## Enhanced session tracking with user interaction logging
debug_user_interaction <- function(action, details = NULL, session_id = NULL) {
  timestamp <- format(Sys.time(), "%H:%M:%S.%f")

  log_debug_block("USER_INTERACTION", paste("User interaction:", action))
  if (!is.null(details) && is.list(details)) {
    log_debug_kv(.list_data = details, .context = "USER_INTERACTION")
  }
  log_debug_block("USER_INTERACTION", "User interaction completed", type = "stop")

  # Also log to structured debug system
  debug_log(paste("User interaction:", action), "USER_INTERACTION",
    level = "INFO",
    context = details, session_id = session_id
  )
}

## State change detailed tracker
debug_state_change <- function(component, state_path, old_value, new_value, trigger = NULL, session_id = NULL) {
  timestamp <- format(Sys.time(), "%H:%M:%S.%f")

  log_debug_block("STATE_CHANGE", paste("State change in", component, "at", state_path))
  log_debug_block("STATE_CHANGE", "State change completed", type = "stop")

  # Structured logging
  debug_log(paste("State change in", component, "at", state_path), "STATE_CHANGE",
    level = "TRACE",
    context = list(
      component = component,
      state_path = state_path,
      old_type = class(old_value)[1],
      new_type = class(new_value)[1],
      trigger = trigger
    ),
    session_id = session_id
  )
}
