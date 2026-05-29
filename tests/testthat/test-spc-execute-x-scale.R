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

test_that("execute_bfh_request: text-x labels appliceres ogsaa paa bfh_qic_result$plot (export-paths)", {
  # Regression: tidligere appliceredes x_scale + x_theme kun paa
  # standardized$plot (analyse-view), ej paa standardized$bfh_qic_result$plot
  # (raw S3-objekt brugt af eksport-pipelinen via bfh_export_pdf,
  # bfh_export_png + PDF preview-PNG via ggsave i generate_pdf_preview).
  # Konsekvens: PDF/PNG eksport viste numerisk fallback (1,2,3,...) for
  # tekst-x i stedet for original-labels (januar, februar, ...).
  skip_if_not_installed("BFHcharts")

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
  expect_false(is.null(result$bfh_qic_result))
  expect_false(is.null(result$bfh_qic_result$plot))

  # Helper: extract text-labels fra ScaleContinuousPosition i et plot
  extract_text_labels <- function(plot) {
    for (s in plot$scales$scales) {
      if ("x" %in% s$aesthetics && inherits(s, "ScaleContinuousPosition")) {
        if (is.character(s$labels) && length(s$labels) > 0) {
          return(s$labels)
        }
      }
    }
    NULL
  }

  std_labels <- extract_text_labels(result$plot)
  bfh_labels <- extract_text_labels(result$bfh_qic_result$plot)

  expect_equal(std_labels, c(
    "Jan", "Feb", "Mar", "Apr", "Maj", "Jun",
    "Jul", "Aug", "Sep", "Okt", "Nov", "Dec"
  ))
  expect_equal(bfh_labels, std_labels)
})

test_that("execute_bfh_request: x_labels propageret paa standardized output", {
  # Regression: x_labels-vector skal eksponeres paa standardized output saa
  # eksport-callere kan forwarde til BFHcharts::bfh_generate_details(x_labels=)
  # og dermed faa Periode-felt "januar - december" frem for "1970-01-01"-nonsens.
  skip_if_not_installed("BFHcharts")

  months_da <- c(
    "januar", "februar", "marts", "april", "maj", "juni",
    "juli", "august", "september", "oktober", "november", "december"
  )
  test_data <- data.frame(
    maaned = months_da,
    indikator = c(10, 12, 15, 13, 14, 16, 18, 17, 19, 20, 21, 22)
  )

  result <- compute_spc_results_bfh(
    data = test_data,
    chart_type = "i",
    x_var = "maaned",
    y_var = "indikator",
    use_cache = FALSE
  )

  expect_equal(result$x_labels, months_da)
})

extract_scale_x <- function(plot) {
  for (s in plot$scales$scales) {
    if ("x" %in% s$aesthetics && inherits(s, "ScaleContinuousPosition")) {
      return(s)
    }
  }
  NULL
}

test_that("execute_bfh_request: subsample begraenser breaks ved >12 tekst-labels", {
  # Regression: BFHcharts::bfh_subsample_label_indices() integration. Ved
  # n_labels > BFH_MAX_X_LABELS_TEXT (default 12) vises kun et subset af
  # labels (foerste anker + step-grid-alignede positioner).
  # Bemaerk: BFHcharts 0.22.1 dropped force-last anchor -- sidste *label*
  # vises kun naar (n - 1) %% step == 0. For n=52 (step=5) bliver sidste
  # synlige label 51, ikke 52 (BFHcharts issue #396 follow-up). Det sidste
  # *break* er dog n_labels (52) som akse-linje-anker med tom label, se
  # naeste test.
  skip_if_not_installed("BFHcharts")

  weeks <- paste0("Uge ", 1:52)
  test_data <- data.frame(uge = weeks, v = seq.int(52))

  result <- compute_spc_results_bfh(
    data = test_data,
    chart_type = "i",
    x_var = "uge",
    y_var = "v",
    use_cache = FALSE
  )

  # x_labels skal indeholde alle 52 (raw labels propageret)
  expect_equal(length(result$x_labels), 52L)

  scale_x <- extract_scale_x(result$plot)
  expect_false(is.null(scale_x))
  expect_lte(length(scale_x$breaks), 12L)
  expect_equal(scale_x$breaks[1], 1L) # foerste anker

  # Synlige labels (ikke-tomme) slutter ved 51 (step-grid-aligned), mens
  # break 52 er anker med tom label.
  nonblank_idx <- which(nzchar(scale_x$labels))
  expect_equal(scale_x$breaks[max(nonblank_idx)], 51L)
})

test_that("execute_bfh_request: akse-linje-anker straekker breaks til sidste observation", {
  # Regression (axis.line truncation): ggplot2 4.0 capper axis.line.x ved
  # yderste break. Da BFHcharts 0.22.1 dropper sidste label naar (n-1) ej
  # delelig med step, stoppede akse-linjen ved sidste synlige label i stedet
  # for ved sidste datapunkt. Fix: tilfoej n_labels som break med tom label.
  skip_if_not_installed("BFHcharts")

  # n=24 -> step=3, visible_idx slutter ved 22; 24 ej grid-aligned.
  months <- format(
    seq(as.Date("2025-01-01"), by = "month", length.out = 24), "%b %y"
  )
  test_data <- data.frame(maaned = months, v = seq.int(24))

  result <- compute_spc_results_bfh(
    data = test_data,
    chart_type = "i",
    x_var = "maaned",
    y_var = "v",
    use_cache = FALSE
  )

  scale_x <- extract_scale_x(result$plot)
  expect_false(is.null(scale_x))

  # Sidste break = n_labels (24) -> akse-linjen naar sidste observation.
  expect_equal(scale_x$breaks[length(scale_x$breaks)], 24L)
  # Anker-label er tom (24 ej synlig label-position).
  expect_identical(scale_x$labels[length(scale_x$labels)], "")
  # Sidste *synlige* label er fortsat 22 (okt 26).
  nonblank_idx <- which(nzchar(scale_x$labels))
  expect_equal(scale_x$breaks[max(nonblank_idx)], 22L)

  # Anker appliceres ogsaa paa eksport-plot (bfh_qic_result$plot).
  scale_x_exp <- extract_scale_x(result$bfh_qic_result$plot)
  expect_equal(scale_x_exp$breaks[length(scale_x_exp$breaks)], 24L)
})

test_that("execute_bfh_request: grid-aligned n tilfoejer ikke duplikat-anker", {
  # Naar n_labels allerede ligger paa step-grid (fx n=23: step=2, sidste
  # synlige=23), skal anker-logikken vaere no-op (ingen ekstra break/tom label).
  skip_if_not_installed("BFHcharts")

  labs23 <- paste0("P", 1:23)
  test_data <- data.frame(p = labs23, v = seq.int(23))

  result <- compute_spc_results_bfh(
    data = test_data,
    chart_type = "i",
    x_var = "p",
    y_var = "v",
    use_cache = FALSE
  )

  scale_x <- extract_scale_x(result$plot)
  expect_false(is.null(scale_x))
  # n=23, step=ceil(22/11)=2 -> visible slutter ved 23 (grid-aligned).
  expect_equal(scale_x$breaks[length(scale_x$breaks)], 23L)
  # Ingen tomme labels: anker er allerede en synlig position.
  expect_true(all(nzchar(scale_x$labels)))
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
