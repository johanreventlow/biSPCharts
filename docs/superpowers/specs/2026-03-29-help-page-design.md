# Design: Hjælpeside — SPC-teori og app-vejledning

## Baggrund

SPCify mangler en hjælpeside der forklarer SPC-grundbegreber og vejleder brugeren i at bruge appen. Målgruppen er danske klinikere og kvalitetsmedarbejdere — fra helt nye til SPC til brugere der kender konceptet men har brug for app-specifik hjælp.

## Krav

1. **Placering:** Tilgængelig via link i app-headeren, visuelt adskilt fra wizard-trinene (Upload/Analysér/Eksportér). Brugerens data og tilstand bevares når de navigerer til hjælpesiden.
2. **Indhold:** Bagt ind i appen (offline-tilgængeligt, opdateres med app-release).
3. **Struktur:** Én scrollbar side med sektioner og ankerlinks i toppen, så brugere kan springe til relevant afsnit.
4. **Sprog:** Dansk. Fagtermer forklares ved første brug.
5. **Progression:** SPC-teori først, derefter app-vejledning — brugeren forstår "hvorfor" før "hvordan".

## Navigation

Et ekstra element i `bslib::page_navbar` placeret i `right` slot (eller efter wizard-trinene med visuelt skel) med et bog-ikon og teksten "Hjælp" eller "Lær om SPC". Implementeres som `nav_panel` så brugerens session bevares ved navigation.

## Indholdsstruktur (storyboard)

### Sektion 1: "Hvad er SPC?"

**Formål:** Giv brugeren den grundlæggende forståelse på 30 sekunder.

**Indhold:**
- SPC (Statistical Process Control) er en metode til at forstå variation i processer over tid.
- Udviklet af Walter Shewhart i 1920'erne, nu central i klinisk kvalitetsarbejde.
- Kernebudskab: "Al data varierer. Spørgsmålet er om variationen er tilfældig eller meningsfuld."

**Illustration:** Et simpelt seriediagram (run chart) fra appen der viser en stabil proces. Screenshot af trin 2 med et run chart uden signaler.

---

### Sektion 2: "To typer variation"

**Formål:** Forankre den vigtigste skelnen i SPC.

**Indhold:**
- **Tilfældig variation** (common cause): Naturlig støj i alle processer. Processen er forudsigelig inden for grænser. Kræver systemændringer for at reducere.
- **Særlig variation** (special cause): Ikke-tilfældige signaler fra usædvanlige hændelser. Kan undersøges og handles direkte.
- Advarsel mod "tampering": At reagere på tilfældig variation som om den var meningsfuld gør processen værre, ikke bedre (jf. SPC-manifestet).

**Illustration:** To seriediagrammer side om side — én stabil proces (ingen signaler), én med tydeligt niveauskift (serielængde-signal). Screenshots fra appen med henholdsvis ren data og data med indsat skift.

---

### Sektion 3: "Sådan læser du et seriediagram"

**Formål:** Gør brugeren i stand til at aflæse et seriediagram.

**Indhold:**
- **Centrallinje (median):** Halvdelen af punkterne ligger over, halvdelen under.
- **Serie (run):** Konsekutive punkter på samme side af medianen. En lang serie tyder på et skift.
- **Krydsning:** Når linjen krydser medianen. For få krydsninger tyder på clustering.

**Illustration:** Screenshot fra appen med visuelle annotationer (tilføjes manuelt til screenshot):
- Pil til centrallinje med label "Centrallinje (median)"
- En serie markeret med bracket og label "Serie: 7 punkter over medianen"
- Krydsningspunkter markeret

---

### Sektion 4: "Anhøj-reglerne"

**Formål:** Forklare de to regler der detekterer ikke-tilfældig variation.

**Indhold:**
- **Regel 1 — Serielængde:** Hvis den længste serie overstiger en grænse baseret på antal datapunkter (ca. log2(n)+3), er der tegn på et niveauskift i processen.
- **Regel 2 — Antal krydsninger:** Hvis der er for få krydsninger af medianen i forhold til hvad man forventer, er der tegn på clustering eller stratificering i data.
- **Hvorfor disse regler:** De tilpasser sig automatisk til datasættets størrelse og kræver ingen antagelser om dataens fordeling — i modsætning til traditionelle kontroldiagram-regler.
- Reglerne er udviklet af Jacob Anhøj og valideret i peer-reviewed forskning (BMJ Quality & Safety, 2015).

**Illustration:** Screenshot fra appen der viser et diagram med Anhøj-signal detekteret. Value boxes i bunden der viser "Serielængde-signal" eller "Krydsnings-signal" med rød/grøn indikation.

---

### Sektion 5: "Kontroldiagrammer"

**Formål:** Forklare forskellen fra seriediagrammer og hvornår kontroldiagrammer bruges.

**Indhold:**
- Kontroldiagrammer tilføjer **kontrolgrænser** (3-sigma grænser) baseret på dataens naturlige variation.
- Punkter uden for kontrolgrænserne er stærke signaler om særlig variation.
- **Seriediagram vs. kontroldiagram:** Start altid med et seriediagram. Brug kontroldiagram når du har brug for at opdage punkter der ligger ekstremt langt fra gennemsnittet.
- **Charttyper i appen:**
  - Seriediagram (Run Chart): Simpleste type, bruger medianen
  - I-chart: Individuelle målinger (fx ventetid, temperatur)
  - P-chart: Andele/procenter (fx andel patienter med komplikation)
  - C-chart: Tællinger (fx antal fald per måned)
  - U-chart: Rater (fx antal infektioner per 1000 plejedage)

**Illustration:** Screenshot af et P-chart fra appen med kontrolgrænser synlige. Eventuelt med et punkt uden for kontrol markeret.

---

### Sektion 6: "Sådan bruger du appen"

**Formål:** Konkret step-by-step vejledning.

**Indhold:**
- **Trin 1 — Upload:** Upload en CSV- eller Excel-fil, eller indsæt data direkte fra Excel. Appen registrerer automatisk dine kolonner.
- **Trin 2 — Analysér:** Vælg x-akse (typisk dato), y-akse (din indikator), og eventuelt en nævner (for andele/rater). Vælg charttype. Tilføj valgfrit: target, skift-markering (ved kendte procesændringer), frysning af baseline.
- **Trin 3 — Eksportér:** Se en preview af din PDF-rapport med automatisk genereret analysetekst. Rediger analysen efter behov, eller brug AI til at forfine den. Download som PDF, PNG eller PowerPoint.

**Illustration:** 3 screenshots — ét per trin, der viser den typiske tilstand med eksempeldata indlæst.

---

### Sektion 7: "Gode råd"

**Formål:** Praktiske anbefalinger baseret på SPC-manifestet og best practices.

**Indhold (bullet points):**
- Start altid med et seriediagram — det er det simpleste og mest robuste
- Brug mindst 12-15 datapunkter for at Anhøj-reglerne kan detektere signaler pålideligt
- Marker skift kun ved kendte procesændringer — ikke ved tilfældig variation
- Lad data tale: undgå at overfortolke enkelte punkter eller korte perioder
- Vis data som tidsserier, ikke som søjlediagrammer eller tabeller — rækkefølgen er vigtig
- En stabil proces er ikke nødvendigvis en god proces — den er bare forudsigelig

---

### Sektion 8: "Videre læsning"

**Formål:** Links til autoritativ litteratur for brugere der vil dykke dybere.

**Indhold:**
- Anhøj J. *Statistical Process Control for Healthcare.* [Online bog](https://anhoej.github.io/spc4hc/)
- Anhøj J. *qicharts2: Quality Improvement Charts.* [Vignette](https://anhoej.github.io/qicharts2/articles/qicharts2.html)
- Anhøj J, Olesen AV. Run charts revisited: a simulation study of run chart rules for detection of non-random variation in health care processes. *PLoS One* 2014. [Link](https://qualitysafety.bmj.com/content/26/1/81)
- Anhøj J. *SPC-manifestet: Otte principper for brug af data i kvalitetsudvikling.* [Link](https://www.anhoej.net/jacob_fag_spc-manifest.html)
- Anhøj J. *Det begyndte med øl — en kort historie om forbedringsmodellen.* [Link](https://www.anhoej.net/jacob_fag_det_begyndte_med_oel.html)

## Screenshot-liste (til manuelt at lave)

| Nr | Sektion | Beskrivelse | App-tilstand |
|----|---------|-------------|--------------|
| 1 | Hvad er SPC? | Run chart uden signaler, stabil proces | Trin 2, run chart, eksempeldata |
| 2a | To typer variation | Stabil proces (ingen signaler) | Trin 2, run chart, eksempeldata uden skift |
| 2b | To typer variation | Proces med niveauskift (serielængde-signal) | Trin 2, run chart, eksempeldata med skift indsat |
| 3 | Sådan læser du... | Diagram med annotationer (tilføjes manuelt) | Trin 2, run chart, tilføj pile/labels i billedbehandling |
| 4 | Anhøj-reglerne | Diagram med signal + value boxes | Trin 2, P-chart med alle 36 signaler, value boxes synlige |
| 5 | Kontroldiagrammer | P-chart med kontrolgrænser | Trin 2, P-chart, eksempeldata |
| 6a | Sådan bruger du... | Upload-siden med data valgt | Trin 1 efter fil-upload |
| 6b | Sådan bruger du... | Analyse-siden med diagram | Trin 2 med fuldt diagram |
| 6c | Sådan bruger du... | Eksport-siden med PDF preview | Trin 3 med PDF preview synlig |

## Teknisk implementation

- Ny fil: `R/mod_help_ui.R` — UI med HTML/markdown indhold
- Ny fil: `R/mod_help_server.R` — minimal server (kun for eventuel interaktivitet)
- Ændring i `R/app_ui.R` — tilføj hjælpe-panel i navbar's right slot
- Screenshots placeres i `inst/www/help/` som PNG-filer
- Indholdet skrives som Shiny UI-elementer (tags$h2, tags$p, tags$img etc.)

## Filer der ændres/oprettes

| Fil | Handling |
|-----|---------|
| `R/mod_help_ui.R` | Opret: Hjælpeside UI modul |
| `R/mod_help_server.R` | Opret: Minimal server modul |
| `R/app_ui.R` | Ændre: Tilføj hjælpe-nav i navbar |
| `R/app_server_main.R` | Ændre: Initialiser help modul |
| `inst/www/help/*.png` | Opret: Screenshots (manuelt) |
