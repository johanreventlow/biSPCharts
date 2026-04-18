# Sikrer at branding constants er tilgængelige for legacy kode

library(testthat)

project_root <- here::here()
local_lib <- file.path(project_root, ".Rlibs")
if (dir.exists(local_lib)) {
  .libPaths(c(local_lib, .libPaths()))
}

# NOTE: R/branding_globals.R blev fjernet i brandings-refactor — konstanter
# sættes nu dynamisk via get_hospital_colors()/get_hospital_name() fra
# R/config_branding_getters.R (kaldes i .onLoad i R/zzz.R).

test_that("HOSPITAL_COLORS er tilgængelig via branding-accessor", {
  # get_hospital_colors() er den nye public API. Det legacy-globale
  # HOSPITAL_COLORS sættes stadig ved package-load i zzz.R, men ligger
  # i pakke-intern env (claudespc_env) — ikke globalenv().
  colors <- get_hospital_colors()
  expect_true(is.list(colors))
  expect_true(all(c("primary", "success", "warning", "danger") %in% names(colors)))
})
