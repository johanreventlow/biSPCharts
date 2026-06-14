# Tests for config_sample_data.R (eksempeldatasaet i trin 1)
#
# Drift-guard: eksempeldatasaettenes chart_type SKAL pege paa den kuraterede
# brugervendte dropdown-maengde (Standardvalg + Udvidede kontrolkortvalg) - IKKE
# blot en hvilken som helst gyldig dropdown-value. De rene by-name-koder
# (i/p/u/c) lever kun i "Avanceret kontrolkortvalg" og maa derfor ikke bruges
# som sample-kobling; gjorde de det, ville knappens framing ikke matche den
# udvidede entry brugeren ser i dropdownen.

# Kurateret, brugervendt maengde = Standardvalg + Udvidede (ekskl. Avanceret).
curated_chart_values <- function() {
  groups <- build_grouped_chart_choices()
  unlist(
    groups[c("Standardvalg", "Udvidede kontrolkortvalg")],
    use.names = FALSE
  )
}

# Kobling --------------------------------------------------------------------

test_that("hvert sample chart_type er en kurateret (ikke-avanceret) dropdown-value", {
  curated <- curated_chart_values()
  for (ds in SAMPLE_DATASETS) {
    expect_true(
      ds$chart_type %in% curated,
      info = paste0(
        "Datasaet '", ds$id, "' har chart_type '", ds$chart_type,
        "' som ikke findes i Standardvalg/Udvidede kontrolkortvalg. ",
        "Brug en kurateret value (fx ip__dt/pp__dt/up__dt/c__dt), ikke en ",
        "ren by-name-kode fra Avanceret-gruppen."
      )
    )
  }
})

test_that("de gamle by-name-koder er IKKE laengere brugt som sample-kobling", {
  used <- vapply(SAMPLE_DATASETS, function(ds) ds$chart_type, character(1))
  expect_false(any(used %in% c("i", "p", "u", "c")))
})

test_that("hvert sample chart_type resolver til en understoettet qic-kode", {
  for (ds in SAMPLE_DATASETS) {
    resolved <- get_qic_chart_type(ds$chart_type)
    expect_true(
      resolved %in% SUPPORTED_CHART_TYPES_BFH,
      info = paste0("Datasaet '", ds$id, "' -> qic '", resolved, "'")
    )
  }
})

# Filer ----------------------------------------------------------------------

test_that("hver sample-CSV findes i inst/extdata", {
  for (ds in SAMPLE_DATASETS) {
    path <- bisp_system_file("extdata", ds$file)
    if (identical(path, "") || !file.exists(path)) {
      path <- file.path("inst", "extdata", ds$file)
    }
    expect_true(
      file.exists(path),
      info = paste0("Mangler CSV for '", ds$id, "': ", ds$file)
    )
  }
})

# Struktur -------------------------------------------------------------------

test_that("hvert datasaet har de paakraevede felter", {
  for (ds in SAMPLE_DATASETS) {
    expect_true(all(c("id", "label", "description", "file", "chart_type") %in% names(ds)))
    expect_true(nzchar(ds$label))
    expect_true(nzchar(ds$description))
  }
})

test_that("der findes praecis et run chart-datasaet", {
  run_types <- vapply(
    SAMPLE_DATASETS,
    function(ds) get_qic_chart_type(ds$chart_type),
    character(1)
  )
  expect_equal(sum(run_types == "run"), 1L)
})
