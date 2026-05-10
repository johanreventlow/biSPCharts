# Pre-Release Checklist

Køres før hvert release-tag (`vX.Y.Z`) — alle punkter SKAL bekræftes.

## 1. Kode og tests

```bash
# Unit tests
Rscript -e "devtools::test()"

# Tarball build + check
R CMD build . --no-manual
R CMD check biSPCharts_*.tar.gz --no-manual --as-cran

# Tarball-audit (ingen skjulte filer i tarball)
tar -tzf biSPCharts_*.tar.gz | grep -E '(\.claude|\.worktrees|\.DS_Store|\.Rcheck|Rplots\.pdf|\.backup)'

# Connect manifest-validering
Rscript dev/validate_connect_manifest.R manifest.json

# Test-classification manifest-validering
Rscript dev/classify_tests.R --validate

# Skip-audit (ingen uventede TODO-skips)
Rscript dev/audit_test_skips.R
```

- [ ] `devtools::test()` grøn (0 FAIL, 0 ERR)
- [ ] `R CMD check --as-cran` — 0 ERRORs, 0 WARNINGs (NOTEs: se §6)
- [ ] Tarball-audit returnerer ingen output
- [ ] Connect manifest OK
- [ ] Test-classification manifest OK
- [ ] Skip-audit: ingen uventede TODO-skips tilføjet
- [ ] E2E/shinytest2 workflow kørt manuelt: `gh workflow run shinytest2.yaml` — grøn

## 2. DESCRIPTION og versioning

- [ ] `Version:` bumpet korrekt (semver — se `~/.claude/rules/VERSIONING_POLICY.md`)
- [ ] `NEWS.md` har entry for ny version (ikke `(development)`)
- [ ] Ingen `(development)`-entries i NEWS.md for den nye version
- [ ] `devtools::document()` kørt → `NAMESPACE` + `man/` opdateret
- [ ] `NAMESPACE` diff reviewed — ingen uventede ændringer

## 3. Afhængigheder

- [ ] `renv::snapshot()` opdateret hvis nye pakker tilføjet
- [ ] Ingen `Remotes:` SHA-pinning — brug version lower-bounds
- [ ] Cross-repo deps: sibling-pakkebumps har separat `chore(deps):`-commit

## 4. Sikkerhed

- [ ] Ingen secrets i kode eller commits (`.Renviron` er i `.gitignore`)
- [ ] Ingen `browser()` eller rogue `print()`-statements
- [ ] Ingen `.DS_Store`, `Rplots.pdf`, `testthat-problems.rds` committed

## 5. Git og branch

- [ ] Ren `git status` (ingen uncommitted ændringer)
- [ ] PR merged til `develop` via review
- [ ] `develop` merged til `master` via PR
- [ ] Annoteret tag oprettet: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
- [ ] Tag pushed: `git push origin vX.Y.Z`

## 6. R CMD check kendte NOTEs (accepterede)

Følgende NOTEs er kendte og accepterede:

| NOTE | Begrundelse |
|------|-------------|
| Non-portable file names (`Mari Bold.otf`, `Mari Book.otf`) | BFHtheme font-filer med mellemrum i navn — extern pakke, kan ikke ændres |
| Non-ASCII characters (`app_initialization.R`, `app_server_main.R`) | Dansk UI-tekst i R-kode — intentionelt |
| `'::' import not declared from: 'BFHllm'` | BFHllm er optional i `Suggests` og deployes via `Remotes`; `manifest.json` skal valideres mod `DESCRIPTION` |
| Namespace not imported from: `grDevices` | `grDevices` bruges implicit via andre pakker — behold i Imports for klarhed |

**Opdatér tabellen** hvis nye NOTEs tilføjes — en ukommenteret NOTE er et signal om at undersøge.

---

---

## 8. CI gates (verificér at alle er grønne)

- [ ] `R-CMD-check` (smoke) — grøn på master-branch
- [ ] `R-CMD-check-gate` (tests + warnings) — grøn på PR mod master
- [ ] `release-gate` (tarball + --as-cran) — grøn på PR mod master
- [ ] `testthat` — grøn
- [ ] `skip-inventory` — grøn (ingen uventede TODO-stigninger)
- [ ] `validate-manifest` — grøn (test-classification + Connect manifest-sync)
- [ ] `shinytest2` — kør manuelt som pre-release gate: `gh workflow run shinytest2.yaml` (nightly + on-demand; inkluderer nu e2e-workflows-filter)

---

*Sidst opdateret: 2026-05-10 (production-readiness: konkrete gates + shinytest2 e2e-integration)*
