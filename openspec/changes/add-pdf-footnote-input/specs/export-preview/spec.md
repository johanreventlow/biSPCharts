# export-preview Specification — Delta (add-pdf-footnote-input)

## ADDED Requirements

### Requirement: Eksport SHALL understøtte footnote som separat tekst-element i Typst-template

PDF-eksport SHALL acceptere et valgfrit `footnote`-felt i metadata-pipeline, der renderes som adskilt tekst-blok under SPC-chart i Typst-template — IKKE som ggplot-caption brændt ind i plot-pixels. Footnote SHALL bruges til klinisk dataattribution (fx "Datakilde: KvalDB udtræk YYYY-MM-DD") og være konsistent på tværs af preview, PNG og PDF-output.

#### Scenario: Bruger indtaster footnote til PDF-eksport

- **GIVEN** bruger har genereret SPC-chart og navigeret til trin 3 (Eksport)
- **WHEN** bruger indtaster "Datakilde: KvalDB udtræk 2026-04-29" i footnote-feltet
- **AND** klikker download-PDF
- **THEN** PDF skal indeholde footnote-tekst som adskilt element under chart-billedet
- **AND** preview-billedet skal vise footnote i samme position som downloadet PDF
- **AND** chart-pixels skal være uændret (footnote ej brændt ind i plot)

#### Scenario: Bruger eksporterer uden footnote

- **GIVEN** footnote-feltet er tomt eller indeholder kun whitespace
- **WHEN** bruger downloader PDF
- **THEN** PDF skal renderes uden footnote-element (ingen tom blok eller layout-shift)
- **AND** preview skal være visuelt identisk med downloadet PDF

#### Scenario: Bruger forsøger at indtaste footnote længere end EXPORT_FOOTNOTE_MAX_LENGTH

- **GIVEN** bruger indtaster 1000 tegn footnote (overstiger 500-tegn-cap)
- **WHEN** validate_export_inputs() kaldes før eksport
- **THEN** eksporten SHALL afbrydes med dansk fejlbesked om længde-grænse
- **AND** ingen download-handler SHALL trigges
- **AND** UI SHALL vise tegn-counter feedback før submit

### Requirement: Footnote-input SHALL escapes via escape_typst_metadata

Bruger-indtastet footnote SHALL processeres af `escape_typst_metadata()` før indsættelse i Typst-template, jf. defense-in-depth-mønster (#486). Markup-tegn (`*`, `_`, `[`, `]`, `<`, `>`, `@`, `#`, `$`, backtick, line-leading `=`/`-`/`+`/`/`) SHALL escapes så footnote rendres som plain-text.

#### Scenario: Footnote indeholder markup-tegn

- **GIVEN** bruger indtaster "Datakilde: *intern* rapport @afd"
- **WHEN** metadata bygges til Typst-template
- **THEN** footnote-værdi i metadata SHALL være `"Datakilde: \\*intern\\* rapport \\@afd"`
- **AND** Typst-render SHALL vise plain-text uden bold/reference-fortolkning

### Requirement: Footnote SHALL inkluderes i LLM-context-cap

Når bruger trigger AI-improvement-suggestion-feature, SHALL footnote-feltet være underlagt samme længde-cap som andre free-text-felter (`truncate_llm_context_fields`, jf. #489). Beskytter mod cost-amplification ved store footnote-inputs.

#### Scenario: Footnote sendes til BFHllm som del af context

- **GIVEN** bruger har indtastet footnote og trigger AI-suggestion
- **WHEN** `truncate_llm_context_fields()` processerer context
- **THEN** footnote SHALL truncates til `EXPORT_DESCRIPTION_MAX_LENGTH` (2000 tegn) hvis nødvendigt
- **AND** truncation SHALL logges på info-niveau
