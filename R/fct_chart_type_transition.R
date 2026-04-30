# fct_chart_type_transition.R
# Pure domænelogik for chart-type state-transitioner — ingen Shiny-afhængigheder.
# Returnerer modificeret kopi af state-snapshot.
#
# Kan unit-testes uden aktiv Shiny-session eller reactive context.

#' Synkroniser chart-type til state (pure)
#'
#' Beregner nyt state-snapshot ud fra ny chart-type.
#' Ingen Shiny-imports, ingen reactive context, ingen side-effekter.
#'
#' Returnerer KOPI af `state`-listet med opdaterede felter.
#' Kalder aldrig `reactive()`, `isolate()`, `req()` eller andre Shiny-APIs.
#'
#' @param state Liste (eller environment) med mindst:
#'   - `columns$mappings$chart_type`: nuværende chart-type kode
#' @param new_type Ny chart-type (qicharts2-kode, fx "run", "i", "p", "u", "c")
#' @return Liste med opdaterede felter:
#'   - `chart_type`: normaliseret qicharts2-kode
#'   - `requires_denominator`: logical — om nævnerkolonne er relevant
#'   - `y_axis_ui_type`: foreslået Y-akse UI-type ("count", "percent", "rate", "time_days")
#' @keywords internal
#' @noRd
sync_chart_type_to_state <- function(state, new_type) {
  # Input-normalisering: konverter dansk label eller kode til qicharts2-kode
  qic_type <- get_qic_chart_type(new_type %||% "run")

  # Afgør om nævnerkolonne er relevant for denne chart-type
  requires_denom <- chart_type_requires_denominator(qic_type)

  # Afgør foreslået Y-akse UI-type for denne chart-type
  # Brug new_type (original) fremfor qic_type for at håndtere "t", "pp", "up"
  # der ikke er i CHART_TYPES_EN (get_qic_chart_type fallbacker til "run")
  y_ui_type <- chart_type_to_ui_type(new_type %||% "run")

  list(
    chart_type = qic_type,
    requires_denominator = requires_denom,
    y_axis_ui_type = y_ui_type
  )
}
