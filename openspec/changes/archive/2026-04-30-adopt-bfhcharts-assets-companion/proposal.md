## Why

biSPCharts har historisk indeholdt proprietære fonts (Mari, Arial) og hospital-logoer (Region Hovedstadens brand-ejendom) tracket i `inst/templates/typst/bfh-template/fonts/` og `images/` — i alt 30 filer. Repoet er **public** på GitHub (`johanreventlow/biSPCharts`), hvilket betyder at:

- Mari-fonts (Region Hovedstadens custom font, proprietær) er offentligt tilgængelige via git history
- Arial TTF-kopier (Microsoft/Monotype EULA) er offentligt tilgængelige via git history — eksplicit licens-overtrædelse
- Hospital-logoer er distribueret under MIT-licens (biSPCharts' egen license) hvilket Region Hovedstaden ikke har samtykket til

BFHcharts (>= 0.11.1) løser samme problem ved bevidst **ikke** at bundle proprietære assets, og eksponerer i stedet en `inject_assets`-callback (`bfh_export_pdf()` + `bfh_create_export_session()`) der lader downstream-forbrugere staage assets ved runtime.

Ny **`BFHchartsAssets`** privat companion-pakke (`johanreventlow/BFHchartsAssets` v0.1.0, oprettet 2026-04-29) hoster nu de proprietære assets i en privat distribution. biSPCharts SHALL adopt dette companion-mønster.

**Compliance-vinkel:** Forblivelsen af proprietære fonts i public git history er et åbent license-issue indtil eventuel history-purge. Denne change adresserer fremtidig tracking; history-purge er en separat bevidst beslutning der kræver `git filter-repo` plus force-push (destruktiv operation, kræver admin-godkendelse). Markeres som follow-up.

## What Changes

- **NON-BREAKING** for slutbrugere; intern API-signatur uændret
- DESCRIPTION: tilføj `BFHchartsAssets` til Suggests + Remotes, bump `BFHcharts (>= 0.11.0)` → `(>= 0.11.1)`
- `R/utils_server_export.R`: erstat `inject_template_assets()`-body med delegation til `BFHchartsAssets::inject_bfh_assets`. Bevar funktion-signatur for backward compat
- `git rm -r` af proprietære fonts + logos (~22 fonts + 7 logos) fra current tip
- `.gitignore`: defensive patterns mod fremtidig re-tracking
- `manifest.json` regen via `rsconnect::writeManifest()` med `Remote*`-felter for `BFHchartsAssets`
- Posit Connect Cloud `GITHUB_PAT` env var (manuelt admin-trin)
- NEWS / changelog entry

## Impact

**Affected specs:** `export-preview` — ADDED requirement: PDF asset-injection delegerer til BFHchartsAssets companion-pkg

**Affected code:**
- `DESCRIPTION` — Imports/Suggests/Remotes
- `R/utils_server_export.R:118-193` — inject_template_assets simplification
- `manifest.json` — regenereret
- `.gitignore` — defensive patterns
- 30 filer fjernet fra git tracking

**Cross-repo:** Forudsætter BFHchartsAssets v0.1.0 + BFHcharts v0.11.1 (begge release 2026-04-29).

**Out of scope:**
- Git history-purge (separat destruktiv operation)
- BFHcharts-side ændringer (allerede done i v0.11.1)
- BFHchartsAssets repo creation (done 2026-04-29)
