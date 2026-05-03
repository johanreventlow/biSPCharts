# Regression-test for #450: text-x-axis charts skal kun have ÉN
# ScaleContinuousPosition på plot, ej duplikeret layer fra tidligere
# double-application i execute_bfh_request.

test_that("execute_bfh_request: text-x-axis plot har max 2 x-scales efter #450 (vs 3 pre-fix)", {
  skip_if_not_installed("BFHcharts")

  # Datasæt med text-x-kolonne (måneds-navne) der tvinger
  # prepare_spc_data() til at konvertere til numerisk sekvens og
  # tilføje .x_labels_<x_var>-kolonne.
  test_data <- data.frame(
    maaned = c(
      "Jan", "Feb", "Mar", "Apr", "Maj", "Jun",
      "Jul", "Aug", "Sep", "Okt", "Nov", "Dec"
    ),
    indikator = c(10, 12, 15, 13, 14, 16, 18, 17, 19, 20, 21, 22)
  )

  result <- compute_spc_results_bfh(
    data = test_data,
    chart_type = "i",
    x_var = "maaned",
    y_var = "indikator",
    use_cache = FALSE
  )

  expect_false(is.null(result$plot))

  # ScaleContinuousPosition-tælling:
  # - BFHcharts::bfh_qic() tilføjer 1 default scale_x_continuous
  # - execute_bfh_request() tilføjer 1 text-labels scale_x_continuous
  # Pre-fix #450: 1 + 2 = 3 (bfh_result$plot fik scale tilføjet, og
  # samme reference fik scale tilføjet igen efter transform).
  # Post-fix #450: 1 + 1 = 2.
  scale_classes <- vapply(result$plot$scales$scales, function(s) class(s)[1], character(1))
  pos_scales <- sum(scale_classes == "ScaleContinuousPosition")
  # Text-x-axis chart må højst have 2 x-scales efter #450
  # (BFHcharts default + vores labels). Pre-fix var det 3.
  expect_lte(pos_scales, 2L)
})

test_that("execute_bfh_request: numeric-x-axis plot påvirkes ikke af #450-fix", {
  skip_if_not_installed("BFHcharts")

  # Numerisk x => prepare_spc_data() opretter ikke .x_labels_-kolonne =>
  # x_scale forbliver NULL => ingen layers tilføjes (hverken før eller efter).
  test_data <- data.frame(
    x = 1:10,
    y = c(5, 7, 6, 8, 7, 9, 8, 10, 9, 11)
  )

  result <- compute_spc_results_bfh(
    data = test_data,
    chart_type = "i",
    x_var = "x",
    y_var = "y",
    use_cache = FALSE
  )

  expect_false(is.null(result$plot))
  # Numerisk x har normal BFHcharts-default x-scale; vi tester bare
  # at det ikke crashed efter fix.
  expect_s3_class(result$plot, "ggplot")
})
