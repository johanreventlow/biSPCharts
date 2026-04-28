# Tests for interpret_anhoej_signal_da()
# Pure mapping fra Anhoej signal-flag til dansk klinisk-venlig tekst.

test_that("Stabil proces (ingen signaler) tolkes korrekt", {
  anhoej <- list(runs_signal = FALSE, crossings_signal = FALSE)
  expect_equal(
    interpret_anhoej_signal_da(anhoej),
    "Stabil proces (ingen særskilt årsag)"
  )
})

test_that("Kun runs_signal udløst tolkes som lang serie", {
  anhoej <- list(runs_signal = TRUE, crossings_signal = FALSE)
  expect_equal(
    interpret_anhoej_signal_da(anhoej),
    "Særskilt årsag: lang serie"
  )
})

test_that("Kun crossings_signal udløst tolkes som for få mediankryds", {
  anhoej <- list(runs_signal = FALSE, crossings_signal = TRUE)
  expect_equal(
    interpret_anhoej_signal_da(anhoej),
    "Særskilt årsag: for få mediankryds"
  )
})

test_that("Begge signaler udløst tolkes som kombineret signal", {
  anhoej <- list(runs_signal = TRUE, crossings_signal = TRUE)
  expect_equal(
    interpret_anhoej_signal_da(anhoej),
    "Særskilt årsag: lang serie + få kryds"
  )
})

test_that("interpret_anhoej_signal_da fejler ikke ved manglende felter", {
  # Defensive: hvis signal-felter mangler eller er NULL, tolkes som FALSE
  anhoej <- list()
  expect_equal(
    interpret_anhoej_signal_da(anhoej),
    "Stabil proces (ingen særskilt årsag)"
  )
})

test_that("interpret_anhoej_signal_da accepterer NA og tolker som FALSE", {
  anhoej <- list(runs_signal = NA, crossings_signal = NA)
  expect_equal(
    interpret_anhoej_signal_da(anhoej),
    "Stabil proces (ingen særskilt årsag)"
  )
})
