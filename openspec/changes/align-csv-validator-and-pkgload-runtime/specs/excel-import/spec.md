## ADDED Requirements

### Requirement: CSV-validator accepterer alle delimiter-formater som parser understøtter

`R/fct_file_validation.R` SHALL anvende samme delimiter-detektion som `R/fct_file_parse_pure.R`. En CSV-fil med delimiter (semikolon, komma, tab, eller auto-detekterbar) som parseren kan håndtere SHALL passere validator uden afvisning.

Begrundelse: Asymmetri mellem validator og parser → bruger får falsk afvisning af gyldig fil. Brugerens fejlbesked ("Filen kunne ikke valideres") matcher ikke appens reelle parser-kapabilitet.

#### Scenario: Komma-separeret fil accepteres
- **WHEN** bruger uploader CSV med komma-delimiter (eksempel: amerikansk export-format)
- **THEN** `validate_csv_file()` returnerer success
- **AND** parser læser filen korrekt

#### Scenario: Tab-separeret fil accepteres
- **WHEN** bruger uploader TSV med tab-delimiter
- **THEN** `validate_csv_file()` returnerer success
- **AND** parser læser filen korrekt

#### Scenario: Semikolon-separeret fil bevarer eksisterende adfærd
- **WHEN** bruger uploader dansk-standard CSV med semikolon-delimiter og komma-decimal
- **THEN** validator + parser accepterer som i dag (regression)

#### Scenario: BOM håndteres
- **WHEN** CSV har UTF-8 BOM (`\xEF\xBB\xBF`) i header
- **THEN** validator + parser accepterer; BOM strippes ved parsing
