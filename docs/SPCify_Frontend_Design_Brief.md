# SPCify — Frontend Design Brief

## Hvad er SPCify?

SPCify er en webapplikation til **Statistical Process Control (SPC)** for kliniske kvalitetsteams på Bispebjerg og Frederiksberg Hospital (BFH), Region Hovedstaden, Danmark. Brugerne er sygeplejersker, læger og kvalitetskoordinatorer der skal lave SPC-diagrammer (kontroldiagrammer) til at overvåge og forbedre kliniske processer.

---

## Brugerprofil

- **Primære brugere:** Danske sundhedsprofessionelle (sygeplejersker, læger, kvalitetskoordinatorer)
- **Teknisk niveau:** Ikke-tekniske — de kender Excel, men ikke programmering
- **Kontekst:** Bruges til kvalitetsarbejde, audit, og ledelsesrapportering
- **Sprog:** 100% dansk UI — alle labels, fejlbeskeder, hjælpetekster
- **Enheder:** Primært desktop (hospitalscomputere), sekundært tablets

---

## Brugerens rejse (workflow)

```
1. ÅBEN APP
   → Ser velkomstside eller tom arbejdsplads

2. UPLOAD DATA
   → Klik "Upload datafil" → vælg CSV eller Excel
   → Data vises i redigerbar tabel

3. KONFIGURER KOLONNER
   → App auto-detekterer X-akse (dato), Y-akse (værdi), nævner, noter
   → Brugeren kan justere manuelt via dropdown-menuer

4. SE SPC-DIAGRAM
   → Diagrammet genereres automatisk med centrallinje og kontrolgrænser
   → Anhøj-regler (statistiske tests) vises som nøgletal
   → Brugeren kan skifte diagramtype, sætte udviklingsmål, fryse baseline

5. REDIGER DATA
   → Redigér direkte i tabellen (Excel-lignende)
   → Diagrammet opdateres automatisk

6. EKSPORTÉR
   → Vælg format: PDF (med AI-forslag), PNG, eller PowerPoint
   → Udfyld metadata (titel, afdeling, datadefinition, forbedringsmål)
   → Download formateret fil til rapportering
```

---

## Indholdsområder i applikationen

Applikationen har to hovedområder:

### 1. Analyse (hovedarbejdsplads)

Indeholder fire indholdselementer:

- **SPC-diagram** — det centrale element. Interaktivt diagram med hurtige indstillinger (diagramtype, y-akse enhed, udviklingsmål, baseline). Bør have mest plads.
- **Anhøj-regler nøgletal** — tre statistiske metrics med ikoner og signalfarver (se detaljer nedenfor)
- **Datatabel** — redigerbar Excel-lignende tabel med mulighed for at redigere kolonnenavne, tilføje kolonner/rækker
- **Kolonne-mapping** — knapper til manuelt at angive kolonner eller auto-detektere dem

### 2. Eksport

Indeholder to elementer:

- **Eksport-indstillinger** — format (PDF/PNG/PPTX), metadata-felter, AI-forbedringsforslag
- **Live preview** — forhåndsvisning af det eksporterede dokument

---

## Alle form-inputs

### Data-konfiguration

| Felt | Type | Dansk label | Eksempel/Placeholder |
|------|------|-------------|----------------------|
| Titel | text | Titel på indikator | "Infektioner pr. 1000 sengedage" |
| Definition | textarea | Datadefinition | "Angiv kort, hvad indikatoren..." |
| Mål | text | Udviklingsmål | "fx >=90%, <25 eller >" |
| Baseline | text | Evt. baseline | "fx 68%, 0,7 el. 22" |
| Diagramtype | dropdown | Diagram type | Se diagramtyper nedenfor |
| Y-akse enhed | dropdown | Y-akse enhed | Tal, Procent (%), Rate, Tid mellem hændelser |

### Kolonne-mapping

| Felt | Dansk label | Påkrævet | Forklaring |
|------|-------------|----------|------------|
| X-akse | X-akse (tidsakse) | Ja | Tidsakse — typisk datokolonne |
| Y-akse | Y-akse (værdiakse) | Ja | Værdiakse — den målte størrelse |
| Nævner | Nævner (n) | Betinget | Påkrævet for P/U-kort (andele/rater) |
| Faseskift | Opdel proces | Nej | Kolonne der markerer faseskift |
| Freeze | Fastfrys niveau | Nej | Kolonne der fryser baseline-beregning |
| Kommentarer | Kommentar (noter) | Nej | Kolonne med annoteringstekst |

### Eksport-metadata

| Felt | Type | Dansk label | Max tegn |
|------|------|-------------|----------|
| Titel | textarea | Titel | 200 |
| Afdeling | text | Afdeling/Afsnit | 100 |
| Datadefinition (PDF) | textarea | Datadefinition | 2000 |
| Forbedringsmål (PDF) | textarea | Forbedringsmål | 2000 |
| Format | radio | Eksport Format | PDF / PNG / PowerPoint |
| Størrelse (PNG) | dropdown | Størrelse | Lille / Medium / Stor |
| Opløsning (PNG) | dropdown | DPI (Opløsning) | 72, 96, 150, 300 |

---

## Diagramtyper (SPC chart types)

| Dansk navn | Beskrivelse | Nævner påkrævet |
|------------|-------------|-----------------|
| Seriediagram m SPC (Run Chart) | Basal SPC — median uden kontrolgrænser | Nej (valgfri) |
| I-kort (Individuelle værdier) | Enkeltmålinger med kontrolgrænser | Nej |
| MR-kort (Moving Range) | Variationen mellem consecutive målinger | Nej |
| P-kort (Andele) | Andel af en population (fx infektionsrate) | Ja |
| P'-kort (Andele, standardiseret) | Standardiseret P-kort for varierende n | Ja |
| U-kort (Rater) | Rate pr. enhed (fx fald pr. sengedag) | Ja |
| U'-kort (Rater, standardiseret) | Standardiseret U-kort for varierende n | Ja |
| C-kort (Tællinger) | Antal hændelser (fx antal fejl) | Nej |
| G-kort (Tid mellem hændelser) | Tid/antal mellem sjældne hændelser | Nej |

---

## Hvad SPC-diagrammet viser

Et SPC-diagram er et tidsserie-plot med følgende elementer:

- **Datapunkter** forbundet med linjer — den målte værdi over tid
- **Centrallinje** — vandret linje (median eller gennemsnit) der viser det typiske niveau
- **Kontrolgrænser** (UCL/LCL) — øvre og nedre grænser beregnet fra data (kun for I/P/U/C-kort, ikke Run Chart)
- **Faseskift** — vertikal linje der opdeler diagrammet i faser med separate kontrolgrænser
- **Freeze** — baseline-beregning baseret på en delmængde af data (historiske værdier)
- **Udviklingsmål** — vandret mållinje (stiplet) der viser ønsket niveau
- **Annoteringsnoter** — tekst-labels ved specifikke datapunkter
- **Anhøj-regler markering** — farvede punkter der indikerer speciel variation (signal)

### Anhøj-regler (statistiske tests)

Tre nøgletal vises ved siden af diagrammet:

1. **Serielængde (Run length):** Antal konsekutive punkter på samme side af centrallinjen. For mange = signal om at processen har skiftet.
2. **Antal kryds af median:** Hvor mange gange dataserien krydser centrallinjen. For få = signal om systematisk variation.
3. **Punkter uden for kontrol:** Punkter der ligger uden for kontrolgrænserne. Indikerer speciel variation.

Hver metric vises med:
- Et ikon der visuelt illustrerer konceptet
- Den numeriske værdi
- Signalfarve (grøn = stabil proces, rød = signal om speciel variation)

---

## Eksportformater

### PDF
- Professionelt layout med diagram, metadata, datadefinition og forbedringsmål
- AI kan generere forbedringsforslag baseret på SPC-analysen
- Beregnet til ledelsesrapportering og kvalitetstavler

### PNG
- Tre størrelsespresets: Lille (800×600), Medium (1200×900), Stor (1920×1440)
- Justerbar opløsning (72-300 DPI)
- Beregnet til indsættelse i dokumenter og præsentationer

### PowerPoint
- Optimal slide-størrelse klar til præsentation
- Beregnet til afdelingsmøder og kvalitetskonferencer

---

## AI-integration

Applikationen kan generere forbedringsforslag via AI baseret på SPC-analysen:

- **Hvor:** I eksport-flowet, specifikt for PDF-format
- **Hvad:** En knap "Generér forslag med AI" der analyserer det aktuelle SPC-diagram og foreslår et forbedringsmål formuleret i klinisk relevant sprog
- **Rolle:** Hjælpende feature — brugeren kan redigere eller slette forslaget
- **Feedback:** Loading-indikator mens AI genererer, derefter redigerbar tekst

---

## Planlagte features

1. **Wizard-workflow** — trinbaseret opsætning for nye brugere der guider dem igennem upload → konfiguration → diagram → eksport
2. **Velkomstside** — guide til nye brugere med SPC-uddannelsesindhold
3. **Organisatorisk panel** — afdelingsvælger med prædefinerede hospitalsafdelinger
4. **Data summary** — opsummering af datakvalitet (antal rækker, manglende værdier)
5. **Kolonne-validering** — feedback-meddelelser under kolonne-inputs

---

## Design-mål

1. **Bevare den simple workflow** — upload → konfigurer → se diagram → eksportér
2. **Være intuitivt for ikke-tekniske brugere** — klinikere skal kunne bruge det uden træning
3. **Prioritere diagrammet** — SPC-diagrammet er det vigtigste element og bør dominere skærmen
4. **Minimere klik** — auto-detection og fornuftige defaults reducerer manuelle trin
5. **Understøtte dansk** — 100% dansk UI med klinisk terminologi
6. **Være visuelt professionelt** — rent, klinisk design med god læsbarhed
7. **Fungere på hospitalets computere** — desktop-first (ofte ældre hardware/browsere)
8. **Gøre eksport let** — one-click download af præsentationsklare dokumenter
9. **Integrere AI naturligt** — AI-forslag som hjælpende feature, ikke central
10. **Understøtte wizard-workflow** — trinbaseret opsætning for nye brugere
