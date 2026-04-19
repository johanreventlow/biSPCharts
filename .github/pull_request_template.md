<!-- Behold relevante sektioner; slet dem der ikke passer. -->

## Beskrivelse

<!-- Kort beskrivelse af hvad denne PR ændrer og hvorfor. -->

## Type

- [ ] Bug fix
- [ ] Ny feature
- [ ] Refactor (ingen adfærdsændring)
- [ ] Docs/test/chore
- [ ] Breaking change (kræver MAJOR bump + NEWS.md-entry)

## Relaterede issues

<!-- fx: Closes #123, Relateret til #456 -->

## Test plan

- [ ] Unit tests bestået (`devtools::test()` eller `testthat::test_file(...)`)
- [ ] Manual functionality test gennemført
- [ ] Ingen regressioner i relaterede tests
- [ ] NEWS.md opdateret (hvis bruger-synlig ændring)

## Security review — kræves for ændringer i supply-chain-følsomme filer

Hvis denne PR ændrer **en eller flere** af følgende filer, skal reviewer
eksplicit verificere security-impact inden approval:

- [ ] `.Rprofile` (auto-executing ved R session-start)
- [ ] `.Renviron` eller anden secrets-håndtering
- [ ] `dev/git-hooks/*` (kører automatisk ved git-operationer)
- [ ] `dev/install_git_hooks.R` (symlink-creation)
- [ ] `.github/workflows/*` (CI/CD-pipelines med repo-adgang)
- [ ] `tests/e2e/setup.R` eller andre test-bootstrap-filer
- [ ] `DESCRIPTION` (nye dependencies eller `Remotes:`-entries)
- [ ] `renv.lock` (bundlede afhængigheder)

**Review-checklist ved supply-chain-filer:**
1. Ingen netværkskald (`curl`, `download.file`, `httr::GET` uden explicit purpose)
2. Ingen fil-skrivning uden for logs/temp
3. Ingen `system()`/`system2()`-kald uden sanitiseret input
4. Ingen code fra eksterne kilder uden pinned hash/version
5. Ændringer matcher PR-beskrivelsen (ingen "incidental" additions)

Se `.Rprofile`-header for baggrund (#247 M5).

## Danish-language checklist

- [ ] UI-tekst og fejlbeskeder på dansk
- [ ] NEWS.md-entry på dansk
- [ ] Commit-message format: `type(scope): beskrivelse`
- [ ] Ingen Claude attribution footers
