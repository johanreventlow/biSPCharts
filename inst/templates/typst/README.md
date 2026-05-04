# Typst Templates

biSPCharts ejer ingen Typst-templates. Authoritative kilde:
`BFHcharts::system.file('templates/typst/bfh-template', package = 'BFHcharts')`.

## PDF/PNG-eksport pipeline

1. `BFHcharts::bfh_export_pdf()` / `bfh_create_typst_document()` stager
   `bfh-template/`-mappen fra BFHcharts-pakken ind i `temp_dir`.
2. `inject_template_assets()` (`R/utils_server_export.R`) delegerer til
   `BFHchartsAssets::inject_bfh_assets()` for at populere fonts + logoer.
3. Quarto Typst-compile læser staged template + injicerede assets.

## Hvorfor ingen lokal kopi

Lokal kopi af `bfh-template/bfh-template.typ` + `bfh_horisonal.typ` blev
fjernet som follow-up til #399 (fonts cleanup). De var ej refereret af
R-kode efter migration til BFHcharts/BFHchartsAssets-ejerskab og var
divergent fra authoritative BFHcharts-version (legacy `bfh-diagram2`-funktion
ej kaldt).

## Rapportér template-issues

Brug `.github/ISSUE_TEMPLATE/bfhchart-feature-request.md` til at logge
feature-requests / bugs mod BFHcharts.
