## ADDED Requirements

### Requirement: Tarball SHALL ikke indeholde udviklingsartefakter

Package-tarball (`biSPCharts_*.tar.gz`) genereret af `R CMD build` SHALL NOT indeholde nogen af følgende paths: `.claude/`, `.worktrees/`, `.Rproj.user/`, `.DS_Store`, `..Rcheck/`, `Rplots.pdf`, `*.backup`, `logs/`, `rsconnect/`, `todo/`, `updates/`. `.Rbuildignore` SHALL blokere dem via regex-patterns.

#### Scenario: Tarball audit finder artefakt

- **WHEN** CI-step `tar -tzf biSPCharts_*.tar.gz | grep -E '...'` kører
- **AND** matching path findes i tarball
- **THEN** workflow fejler
- **AND** error-besked indeholder den specifikke path og linje fra `.Rbuildignore` der burde have blokeret den

#### Scenario: Ren tarball

- **WHEN** audit-step kører på ren pakke
- **THEN** ingen matches fundet
- **AND** tarball-størrelse logges til workflow-output for regression-monitorering
