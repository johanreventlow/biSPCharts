# Export API Specification (Delta)

## MODIFIED Requirements

### Requirement: PNG Export Implementation

The export module MUST delegate PNG generation to `BFHcharts::bfh_export_png()` instead of the internal `generate_png_export()` function. The internal function SHALL be removed as part of this migration.

#### Scenario: User downloads PNG from export modal

**Given** user has generated an SPC chart
**And** user opens the export modal
**When** user selects PNG format and clicks download
**Then** the system MUST call `BFHcharts::bfh_export_png()` with appropriate parameters
**And** the PNG file SHALL be downloaded with correct dimensions and DPI

---

### Requirement: PDF Export Implementation

The export module MUST delegate PDF generation to `BFHcharts::bfh_export_pdf()` instead of the internal `export_spc_to_typst_pdf()` function. All internal Typst functions SHALL be removed.

#### Scenario: User downloads PDF from export modal

**Given** user has generated an SPC chart
**And** user has filled in export metadata (title, department, analysis)
**When** user clicks PDF download button
**Then** the system MUST call `BFHcharts::bfh_export_pdf()` with metadata
**And** the PDF file SHALL be generated with hospital branding

---

### Requirement: bfh_qic_result Object Storage

The application MUST store the full `bfh_qic_result` S3 object from BFHcharts. The system SHALL NOT store only the ggplot component, as BFHcharts export functions require the complete S3 object.

#### Scenario: Chart generation stores full result

**Given** user uploads data and configures chart parameters
**When** the system calls `BFHcharts::bfh_qic()`
**Then** the full `bfh_qic_result` object MUST be stored in `app_state$visualization$result`
**And** the plot component (`result$plot`) SHALL be displayed in the UI

---

## REMOVED Requirements

- `generate_png_export()` function from `R/fct_export_png.R`
- `export_spc_to_typst_pdf()` function from `R/fct_export_typst.R`
- `create_typst_document()` function from `R/fct_export_typst.R`
- `compile_typst_to_pdf()` function from `R/fct_export_typst.R`
- `export_chart_for_typst()` function from `R/fct_export_typst.R`
