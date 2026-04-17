# Design: Unblock Publish Test-Gate

## Context

Test-suiten er i drift: 4 filer refererer til 17 ikke-eksisterende funktioner.
Publish-workflow er midlertidigt afblokeret via et `--skip-tests`-flag der er et
anti-pattern. Målet er at reetablere publish-gate som håndhævet sikkerhedslag
inden for få dages arbejde, uden at drukne i en større test-oprydning (som
reserveres til Change 2).

**Constraints:**
- Ingen breaking changes i `R/*.R` (public API) medmindre nødvendigt
- Må ikke introducere regressions i de 47 grønne + 62 green-partial filer
- Skal leverer ét målbart resultat: `broken-missing-fn = 0` og publish-gate håndhævet

**Stakeholders:**
- Maintainer (hurtig publish-gate genoprettelse)
- `/publish-to-connect` slash-kommandoen (kan køre uden flag)
- Change 2 "refactor-test-suite" (baseline-input)

## Goals

**Goals:**
- `devtools::test(stop_on_failure = TRUE)` returnerer exit 0
- `--skip-tests`-flag fjernet fra `dev/publish_prepare.R` og dokumentation
- Audit-rapport post-fix viser `broken-missing-fn = 0`
- NEWS.md dokumenterer alle fjernede/omdøbte/skippede tests med rationale
- Intet arbejde spildt på green-partial fails (de tilhører Change 2)

**Non-Goals:**
- Konvertere green-partial til green (Change 2)
- Konsolidere redundante filer (Change 2, jf. refactor-code-quality Phase 1)
- Rydde stubs og skipped-all (Change 2)
- Gendanne funktionalitet der ikke længere behøves i produktion
- Skrive nye tests for eksisterende adfærd

## Decisions

### Decision 1: Hybrid git-forensics (ikke blind slet, ikke grundig restaurering)

**What:** For hver manglende funktion køres en 10-minutters git-søgning der
vælger mellem: omdøb i test, slet test, opdatér signatur, eller skip med
TODO-marker. Beslutningen træffes pr. funktion, ikke pr. fil.

**Why:** Auditten afslørede at kun 17 funktioner er involveret — overkommeligt
at undersøge individuelt. Grundig restaurering (gendan funktion i `R/`) er ofte
unødvendig fordi funktionaliteten kan være migreret eller fjernet bevidst. Blind
sletning taber potentiel test-coverage for funktioner der blot blev omdøbt.

**Alternatives considered:**
- **Blind slet alle 4 filer:** Hurtigt, men taber test-coverage og gør fremtidig
  green-partial-oprydning sværere
- **Grundig restaurering (gendan alle 17 funktioner):** Alt for tidskrævende
  (måneder), og mange funktioner er sikkert slettet bevidst
- **Skip alle tests med TODO-markers:** Holder tests i live, men skaber tavs
  akkumulering af gæld uden klar ejerskab

### Decision 2: Time-boxed research (10 min pr. funktion)

**What:** Strikt 10-minutters timebox pr. manglende funktion. Overskrides
tiden → `skip("TODO: #203 follow-up")` og videre.

**Why:** Forhindrer at Change 1 sværger af som forsknings-projekt. Vi har en
klar deadline (publish-gate tilbage snart), og skipped tests er acceptabelt
midlertidigt — Change 2 vil alligevel røre alle filerne.

**Alternatives considered:**
- **Ingen timebox:** Risiko for at bruge 20+ timer på research
- **5 min timebox:** For kort — git-log-søgning tager tid at parse

### Decision 3: Hver fix i separat commit

**What:** Atomiske commits pr. testfil (eller pr. logisk fix), jf. projekt-regel
om atomisk commit-granularitet.

**Why:** Gør det muligt at reviewe/revertere enkelte fixes hvis nogle viser sig
forkerte. Giver klar historik for Change 2-brainstorm.

**Alternatives considered:**
- **Én stor commit:** Svær at reviewe og revertere
- **Commit pr. manglende funktion:** Over-granulært

### Decision 4: Publish-gate-reaktivering sker SIDST

**What:** Fjern `--skip-tests`-flag og dokumentation kun efter alle 4 testfiler
er fixed og auditten bekræfter `broken-missing-fn = 0`.

**Why:** Hvis vi fjerner flaget før tests er rene, blokeres maintaineren fra at
deployere ved hotfixes.

**Alternatives considered:**
- **Fjern flag først, derefter fix:** Risikabel afhængighedsvending
- **Behold flag men marker som deprecated:** Bag-ind-tilgang

### Decision 5: Ingen automatiseret forensics-script

**What:** Git-forensics køres manuelt pr. funktion — ikke via dedikeret script.

**Why:** Scriptning ville tage længere tid end manuel udførelse for 17 unikke
funktioner. Den menneskelige vurdering pr. fund er for nuanceret til at
automatisere.

**Alternatives considered:**
- **Skriv `dev/forensics.R` der tager fn-navn og auto-suggests handling:**
  Spændende men scope-creep til Change 1

## Architecture

Change 1 er et ikke-kode-struktur-ændrende arbejde. "Arkitekturen" er en
**beslutningsprocedure** pr. manglende funktion:

```
For hver af de 17 manglende funktioner:
  1. Kør: git log --all --source --follow -S '<fn>' -- 'R/*.R'
  2. Kør: git log --all --source -S '<fn>' -- BFHcharts/ BFHtheme/ BFHllm/  (kontrollér sibling-migration)
  3. Analysér output (≤10 min):
     a. Fundet i commit hvor funktion blev omdøbt → note ny navn
     b. Fundet i commit hvor funktion blev slettet uden replacement → konkluder "død"
     c. Fundet i commit hvor funktion blev refaktoreret → note ny signatur
     d. Intet klart mønster → konkluder "uklart"
  4. Anvend handling på testen:
     a → sed-omdøb i testfil
     b → slet test_that-blok; bevar filen hvis andre tests findes
     c → opdatér kaldsignatur i testen
     d → wrap i skip("TODO: #203 follow-up — <fn> ikke lokaliseret")
  5. Log valg i NEWS.md-note (Change 1-entry)
  6. Commit
```

## Risks / Trade-offs

| Risiko | Sandsynlighed | Impact | Mitigation |
|--------|---------------|--------|------------|
| Funktion eksisterer under typo i test (ikke reel drift) | Lav | Lav | Git-søgning med substring-variationer fanger dette |
| Funktion migreret til sibling-pakke (BFHcharts/BFHllm) | Medium | Medium | Step 2 i proceduren checker sibling-pakker eksplicit |
| Fix introducerer regressions i anden fil | Lav | Medium | Audit køres post-fix; hvis kategori-fordeling forværres, analyser og ret |
| Timebox (10 min) for kort — taber vigtig historik | Medium | Lav | `skip()`-markers giver mulighed for revisit i Change 2 |
| Publish-gate eksponerer green-partial fails som blokerer | Høj | Høj | **Planned:** Change 2 adresserer green-partial — i mellemtiden kan `--skip-tests` genindføres hvis kritisk hotfix nødvendig |

**Vigtigste risiko:** At green-partial fails blokerer publish-gate selv efter
Change 1. Auditten viste at 62 filer er green-partial med ~200 samlede fails.
Disse fails bliver nu synlige for `devtools::test(stop_on_failure = TRUE)`.

**Mitigation:** To muligheder i slutningen af Change 1:

**Option A:** Accept at publish-gate fejler på green-partial fails. Dokumenter i
NEWS.md at Change 2 er påkrævet for fuld reaktivering, og at `--skip-tests`
skal bruges i nødstilfælde (som workaround er det ikke fjernet).

**Option B:** Midlertidigt markér green-partial fails som `skip()` så
`devtools::test()` passerer uden rent faktisk at løse fails. Hurtig gate-unblock
men flytter gælden til Change 2.

**Beslutning deferred:** Afhænger af hvad post-Change-1-audit faktisk viser.
Hvis antal af "unngåelige" fails er lavt (fx <10), kan vi hurtigt konvertere
dem til `skip()`; hvis højt, vælger vi Option A og overlader det til Change 2.

## Migration / Rollout Plan

Ingen migration nødvendig — dette er test-oprydning, ingen bruger-synlig ændring.

**Rollout:**
1. Branch `feat/unblock-publish-203` fra master (efter `feat/test-audit-203` er merged)
2. Implementér opgaver i `tasks.md` sekventielt
3. Merge til master via PR
4. Tagge ikke særskilt (ingen versions-bump nødvendig — tests og dev-scripts)

**Rollback:**
Hvis publish-gate forårsager problemer efter merge: revert commit der fjerner
`--skip-tests`-flaget (én commit). Test-fixes kan blive — de reducerer blot
støj i test-output.

## Open Questions

- **Option A vs B** besluttes i tasks.md fase 5 (verifikation) efter audit-rerun.
- **Merge-orden:** Skal `feat/test-audit-203` merges først (så audit-scriptet
  og rapporten bliver tilgængelige på master), eller skal vi arbejde off
  `feat/test-audit-203`-branchen og merge samlet? **Anbefaling:** Merge audit-
  branchen først, så Change 1 bygger på master.
