# Pre-Release Checklist

Køres før hvert release-tag (`vX.Y.Z`) — alle punkter SKAL bekræftes.

## 1. Kode og tests

- [ ] `devtools::test()` grøn (0 FAIL, 0 ERR)
- [ ] `devtools::check()` ren — 0 ERRORs, 0 WARNINGs
- [ ] `R CMD check --as-cran --no-tests --no-manual --no-vignettes --no-build-vignettes` — 0 WARNINGs
- [ ] Manuelle smoke-tests: app starter, upload virker, chart renderes

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
| `'::' import not declared from: 'BFHllm'` | BFHllm fjernet midlertidigt fra DESCRIPTION (Python/reticulate-dep) — reaktivér ved `BFHllm` i Imports |
| Namespace not imported from: `grDevices` | `grDevices` bruges implicit via andre pakker — behold i Imports for klarhed |

**Opdatér tabellen** hvis nye NOTEs tilføjes — en ukommenteret NOTE er et signal om at undersøge.

---

*Sidst opdateret: 2026-04-24 (improve-package-hygiene #287)*
