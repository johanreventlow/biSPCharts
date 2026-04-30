## ADDED Requirements

### Requirement: PDF asset-injection SHALL delegate to BFHchartsAssets companion package

`inject_template_assets(template_dir)` SHALL delegate proprietary asset staging to the private companion package `BFHchartsAssets` via its exported `inject_bfh_assets(template_dir)` function. biSPCharts SHALL NOT bundle Mari fonts, Arial fonts, or hospital logos in its own `inst/templates/` tree; assets SHALL be sourced exclusively from the companion package at runtime.

**Rationale:**

- biSPCharts is distributed as a public repository under MIT license. Bundled proprietary fonts (Mari — Region Hovedstaden custom; Arial — Microsoft/Monotype) and hospital brand assets (Logo_Bispebjerg variants) cannot legally be redistributed under MIT.
- BFHcharts (>= 0.11.1) documents the companion-package pattern as the canonical asset distribution mechanism for organizational deployments.
- Centralizing assets in `BFHchartsAssets` (private repo, organizational license) eliminates license exposure at the source-code distribution boundary while preserving full hospital branding in production deployments (Posit Connect Cloud).

**Implementation contract:**

`inject_template_assets()` SHALL:

1. Check `requireNamespace("BFHchartsAssets", quietly = TRUE)`
2. If available: call `BFHchartsAssets::inject_bfh_assets(template_dir)` and return `invisible(TRUE)`
3. If unavailable: log a warning and return `invisible(FALSE)`
4. Preserve the public function signature `inject_template_assets(template_dir)` for backward compatibility

#### Scenario: BFHchartsAssets installed and reachable

- **GIVEN** `BFHchartsAssets` is installed in the R library
- **AND** `template_dir` is a valid Typst template staging directory
- **WHEN** `inject_template_assets(template_dir)` is called
- **THEN** all bundled fonts SHALL be copied to `<template_dir>/fonts/`
- **AND** all bundled images SHALL be copied to `<template_dir>/images/`
- **AND** the function SHALL return `invisible(TRUE)`

```r
test_that("inject_template_assets delegates to companion when available", {
  skip_if_not_installed("BFHchartsAssets")
  tmp <- tempfile("inject-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_invisible(inject_template_assets(tmp))
  expect_gt(length(list.files(file.path(tmp, "fonts"))), 0L)
  expect_gt(length(list.files(file.path(tmp, "images"))), 0L)
})
```

#### Scenario: BFHchartsAssets not installed

- **GIVEN** `BFHchartsAssets` is NOT installed
- **WHEN** `inject_template_assets(template_dir)` is called
- **THEN** the function SHALL log a warning identifying the missing package
- **AND** SHALL return `invisible(FALSE)`
- **AND** SHALL NOT raise an error

#### Scenario: biSPCharts repository SHALL NOT contain proprietary assets

- **GIVEN** the biSPCharts public repository
- **WHEN** a maintainer inspects `inst/templates/typst/bfh-template/`
- **THEN** only `bfh-template.typ` SHALL be present
- **AND** `fonts/` and `images/` subdirectories SHALL NOT be tracked in git
- **AND** `.gitignore` SHALL contain explicit patterns blocking these subdirectories

#### Scenario: manifest.json SHALL document BFHchartsAssets dependency for Posit Connect Cloud

- **GIVEN** biSPCharts is being prepared for Posit Connect Cloud deployment
- **WHEN** `rsconnect::writeManifest()` is invoked
- **THEN** `manifest.json` SHALL contain a `packages.BFHchartsAssets` entry
- **AND** that entry SHALL include `Remote*` metadata fields (`RemoteType`, `RemoteHost`, `RemoteUsername`, `RemoteRepo`, `RemoteSha`)
- **AND** SHALL include `Github*` fields (`GithubRepo`, `GithubSHA`)
- **AND** Connect Cloud install with `GITHUB_PAT` env var set SHALL successfully install `BFHchartsAssets` from its private GitHub repository
