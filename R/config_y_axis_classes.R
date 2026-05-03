# config_y_axis_classes.R
#
# Y-akse interne klasser: kanonisk taxonomi for hvilke chart-typer en
# given UI-input-type maps til. Bruges af `determine_internal_class()` og
# `suggest_chart_type()` i utils_y_axis_model.R.
#
# Flyttet fra utils_y_axis_model.R i #461 for at følge konfig-konventionen
# (constants i config_*.R + getter). Tilgang via `get_internal_class()`
# bevarer mulighed for fremtidig validering / YAML-overstyring uden at
# bryde call-sites.

#' Y-axis internal classes (canonical taxonomy)
#'
#' Defines the closed set of internal y-axis classes that downstream
#' chart-type-suggestion logic switches on. Strings ej eksponeret som
#' enum — `get_internal_class()` returnerer string-navn så switch-statements
#' i `suggest_chart_type()` forbliver sammenlignelige med `==`.
#'
#' @keywords internal
INTERNAL_CLASSES <- list(
  MEASUREMENT = "MEASUREMENT",
  COUNT = "COUNT",
  PROPORTION = "PROPORTION",
  RATE_INTERNAL = "RATE_INTERNAL",
  TIME_BETWEEN = "TIME_BETWEEN",
  COUNT_BETWEEN = "COUNT_BETWEEN"
)

#' Get internal y-axis class by name
#'
#' Validerer at navnet eksisterer i `INTERNAL_CLASSES` taxonomien og
#' returnerer den kanoniske string. Bruges som getter for at fange
#' typos før de propagerer til `==`-comparisons der silently failer.
#'
#' @param name Character. Et af "MEASUREMENT", "COUNT", "PROPORTION",
#'   "RATE_INTERNAL", "TIME_BETWEEN", "COUNT_BETWEEN".
#'
#' @return Character scalar. Stopper med tydelig fejl hvis ukendt.
#' @keywords internal
get_internal_class <- function(name) {
  value <- INTERNAL_CLASSES[[name]]
  if (is.null(value)) {
    stop(sprintf(
      "Ukendt INTERNAL_CLASSES-navn: '%s'. Gyldige: %s",
      name, paste(names(INTERNAL_CLASSES), collapse = ", ")
    ))
  }
  value
}
