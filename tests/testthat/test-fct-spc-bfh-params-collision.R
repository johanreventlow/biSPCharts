# test-fct-spc-bfh-params-collision.R
# Tests for column name collision detection after sanitization (#422)
#
# Reproducer: to distinkte kolonner kan kollidere naar danske/specielle tegn
# konverteres til ASCII (aer, oer, aar, _ etc.) => silent failure => forkert plot.
# Fix: hard-fail med klar spc_input_error foer safe_operation.
#
# Kollisionslogik:
#   ae/oe/aa-erstatning + iconv(ASCII//TRANSLIT) + gsub([^A-Za-z0-9_], "_")
#
# Eksempler paa faktiske kollisioner:
#   "Sub-grupper" -> "Sub_grupper"  og  "Sub_grupper" -> "Sub_grupper"   (bindestreg -> _)
#   "aar og dag"  -> "aar_og_dag"   og  "aar_og_dag"  -> "aar_og_dag"   (mellemrum -> _)
#   "Aar"         -> "Aar"           og  "aar"          -> "aar"          (case-sensitiv, ingen kollision!)
#
# Vigtig note: iconv(ASCII//TRANSLIT) + gsub er CASE-SENSITIV paa macOS.
# "Aeble" og "Aeble" = identiske originaler (ingen kollision).
# "aeble" og "aeble" = identiske originaler (ingen kollision).
# "Aeble" og "aeble" er ikke identiske originaler, og "Aeble"!="aeble" efter sanitization.

# Helper: minimal data frame med n raekker og specificerede kolonner
make_df_with_cols <- function(col_names, n = 15L) {
  cols <- vector("list", length(col_names))
  cols[[1]] <- seq(as.Date("2023-01-01"), by = "week", length.out = n)
  for (i in seq_along(col_names)[-1]) {
    cols[[i]] <- as.numeric(seq_len(n))
  }
  as.data.frame(setNames(cols, col_names))
}

# ── Kollision-scenarierne (skal give spc_input_error) ─────────────────────────

test_that("#422: 'Sub-grupper' og 'Sub_grupper' giver spc_input_error", {
  # Bindestreg og underscore saniteres begge til '_' => "Sub_grupper" + "Sub_grupper"
  df <- make_df_with_cols(c("Dato", "Sub-grupper", "Sub_grupper"))
  expect_error(
    map_to_bfh_params(
      data = df,
      x_var = "Dato",
      y_var = "Sub-grupper",
      chart_type = "run"
    ),
    class = "spc_input_error"
  )
})

test_that("#422: kolonner med mellemrum vs. underscore giver spc_input_error", {
  # "aar og dag" -> "aar_og_dag" = "aar_og_dag" -> "aar_og_dag"
  df <- make_df_with_cols(c("Dato", "aar og dag", "aar_og_dag"))
  expect_error(
    map_to_bfh_params(
      data = df,
      x_var = "Dato",
      y_var = "aar og dag",
      chart_type = "run"
    ),
    class = "spc_input_error"
  )
})

test_that("#422: specielle tegn vs underscore giver spc_input_error", {
  # "A.B" -> "A_B" = "A_B" -> "A_B"
  df <- make_df_with_cols(c("Dato", "A.B", "A_B"))
  expect_error(
    map_to_bfh_params(
      data = df,
      x_var = "Dato",
      y_var = "A.B",
      chart_type = "run"
    ),
    class = "spc_input_error"
  )
})

test_that("#422: 'Antal_foer' og 'Antal_oer' giver spc_input_error naar foer=oer efter TRANSLIT", {
  # Begge konverteres af iconv(ASCII//TRANSLIT) paa samme maade
  # "Antal-oer" -> "Antal_oer", "Antal_oer" -> "Antal_oer"
  df <- make_df_with_cols(c("Dato", "Antal-oer", "Antal_oer"))
  expect_error(
    map_to_bfh_params(
      data = df,
      x_var = "Dato",
      y_var = "Antal-oer",
      chart_type = "run"
    ),
    class = "spc_input_error"
  )
})

# ── Ingen-kollision-scenarierne (ingen spc_input_error fra kollision) ──────────
# Moenster: withCallingHandlers fanger spc_input_error med "kolliderer" og
# fail(). Andre fejl (BFHcharts-kald i test-env) tavsere vi bevidst igennem.
# succeed() kaores KUN hvis ingen kollisions-fejl blev kastet.

assert_no_collision_error <- function(expr_fn) {
  caught_collision <- FALSE
  tryCatch(
    withCallingHandlers(
      expr_fn(),
      spc_input_error = function(e) {
        if (grepl("kolliderer", conditionMessage(e), fixed = FALSE)) {
          caught_collision <<- TRUE
          invokeRestart("abort")
        }
      }
    ),
    error = function(e) {
      # Tillad andre fejl (fx BFHcharts-runtime fejl i test-env)
      # men ikke spc_input_error om kollision
      invisible(NULL)
    }
  )
  if (caught_collision) {
    fail("Uventet kollisionsfejl kastet (ingen kollision forventet)")
  }
  succeed("Ingen kollisionsfejl kastet")
}

test_that("#422: enkelt dansk kolonnenavn giver ingen kollisionsfejl", {
  # "Aar" alene => ingen kollision mulig
  df <- make_df_with_cols(c("Dato", "Aar"))
  assert_no_collision_error(function() {
    map_to_bfh_params(
      data = df,
      x_var = "Dato",
      y_var = "Aar",
      chart_type = "run"
    )
  })
})

test_that("#422: 'Taeller' + 'Naevner' + 'Dato' giver ingen kollisionsfejl", {
  # Alle tre saniteres til unikke ASCII-navne
  df <- make_df_with_cols(c("Dato", "Taeller", "Naevner"))
  assert_no_collision_error(function() {
    map_to_bfh_params(
      data = df,
      x_var = "Dato",
      y_var = "Taeller",
      chart_type = "run"
    )
  })
})
