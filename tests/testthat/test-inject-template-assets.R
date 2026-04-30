#  Tests for inject_template_assets()
#
#  Spec: openspec/specs/export-preview (ADDED via adopt-bfhcharts-assets-companion)
#
#  Scenarier dækket:
#   1. BFHchartsAssets installeret + reachable -> delegation virker, returns invisible(TRUE)
#   2. BFHchartsAssets ikke installeret -> log_warn + invisible(FALSE), kaster ej error
#   3. BFHchartsAssets::inject_bfh_assets() fejler -> safe_operation fallback til FALSE

test_that("inject_template_assets returns invisible(FALSE) when BFHchartsAssets missing", {
  mockery::stub(inject_template_assets, "requireNamespace", FALSE)

  tmp <- tempfile("inject-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  result <- expect_invisible(inject_template_assets(tmp))
  expect_false(result)
})

test_that("inject_template_assets does not raise error when companion missing", {
  mockery::stub(inject_template_assets, "requireNamespace", FALSE)

  tmp <- tempfile("inject-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  expect_no_error(inject_template_assets(tmp))
})

test_that("inject_template_assets delegates to companion when available", {
  skip_if_not_installed("BFHchartsAssets")

  tmp <- tempfile("inject-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  result <- inject_template_assets(tmp)
  expect_true(result)

  # Verificér at companion-pakken faktisk har staged assets
  expect_gt(length(list.files(file.path(tmp, "fonts"))), 0L)
  expect_gt(length(list.files(file.path(tmp, "images"))), 0L)
})

test_that("inject_template_assets returns FALSE when companion's inject fails", {
  mockery::stub(inject_template_assets, "requireNamespace", TRUE)
  mockery::stub(
    inject_template_assets,
    "BFHchartsAssets::inject_bfh_assets",
    function(td) stop("simuleret companion-fejl")
  )

  tmp <- tempfile("inject-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  result <- inject_template_assets(tmp)
  expect_false(result)
})
