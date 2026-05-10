# test-pdf-preview-temp-png.R
# Cycle E NEW1 (Codex 2026-05-10): regression-tests for temp-PNG-akkumulation-fix.
#
# Pre-fix: generate_pdf_preview() kaldte tempfile(fileext='.png') hver gang.
# renderImage(deleteFile=FALSE) ryddede ikke filen. Paa Connect-long-sessions
# akkumuleres ~40 PNGs/min worst case under typing -> 100MB+ per session.
#
# Post-fix:
#   1. generate_pdf_preview() har preview_path-parameter
#   2. mod_export_server.R passer session-scoped sti der overskrives
#   3. setup_session_cleanup() unlinker bfh_preview_*-pattern paa session-end

test_that("generate_pdf_preview() har preview_path-parameter", {
  require_internal("generate_pdf_preview", mode = "function")
  formals_list <- formals(generate_pdf_preview)
  expect_true(
    "preview_path" %in% names(formals_list),
    info = "Cycle E NEW1: generate_pdf_preview() skal have preview_path-arg"
  )
  # Default skal vaere NULL for bagudkompatibilitet
  expect_true(
    is.null(formals_list$preview_path),
    info = "preview_path default skal vaere NULL for bagudkompatibilitet"
  )
})

test_that("generate_pdf_preview() bruger preview_path naar leveret", {
  require_internal("generate_pdf_preview", mode = "function")
  body_text <- paste(deparse(body(generate_pdf_preview)), collapse = "\n")
  # Verificer at preview_path bruges (via %||% fallback eller direkte)
  expect_true(
    grepl("preview_path", body_text),
    info = "generate_pdf_preview body skal referere preview_path-arg"
  )
})

test_that("mod_export_server.R caller passer session-scoped preview_path", {
  require_internal("mod_export_server", mode = "function")
  body_text <- paste(deparse(body(mod_export_server)), collapse = "\n")
  expect_true(
    grepl("session_preview_path|preview_path\\s*=\\s*session", body_text),
    info = paste(
      "mod_export_server skal kalde generate_pdf_preview() med",
      "session-scoped preview_path (Cycle E NEW1)"
    )
  )
  # Verificer at sti bruger session-token for unikhed
  expect_true(
    grepl("session\\$token", body_text),
    info = "session_preview_path skal inkludere session$token for unikhed mellem samtidige sessions"
  )
})

test_that("setup_session_cleanup() unlinker bfh_preview_*-PNGs paa session-end", {
  require_internal("setup_session_cleanup", mode = "function")
  body_text <- paste(deparse(body(setup_session_cleanup)), collapse = "\n")
  expect_true(
    grepl("bfh_preview_", body_text),
    info = "setup_session_cleanup skal cleanup bfh_preview_*-pattern (NEW1 defense-in-depth)"
  )
  expect_true(
    grepl("unlink", body_text),
    info = "Cleanup skal kalde unlink"
  )
})
