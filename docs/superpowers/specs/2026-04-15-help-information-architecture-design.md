# Design: Adskillelse af SPC-teori og app-vejledning

**Dato:** 2026-04-15
**Status:** Godkendt

## Baggrund

biSPCharts har i dag én hjælpeside ("Lær om SPC") der blander SPC-teori med app-vejledning. Brugerne er klinikere med basal SPC-introduktion, men som ikke kender værktøjet. De har to distinkte behov:

1. **Uddybe SPC-forståelse** — hvad betyder signalerne, hvornår handler man
2. **Lære værktøjet** — hvordan uploader jeg data, hvad gør indstillingerne

Disse behov dækkes bedst af separate informationsressourcer, kombineret med kontekstuel hjælp som sikkerhedsnet undervejs.

## Design

### 1. To separate hjælpesider i navbar

**Navbar ændres fra:**
```
Upload | Analysér | Eksportér | Lær om SPC
```

**Til:**
```
Upload | Analysér | Eksportér | Sådan bruger du appen | Lær om SPC
```

**"Sådan bruger du appen"** (ny side):
- Trin-for-trin gennemgang af hele flowet (Upload → Analysér → Eksportér)
- Forklaring af alle felter og indstillinger (Skift, Frys, diagramtyper, eksportfelter)
- Praktiske tips (dataformat, antal datapunkter)
- Skærmbilleder/illustrationer der viser hvad man ser i hvert trin

**"Lær om SPC"** (eksisterende side, renset for app-guide-indhold):
- Hvad er SPC?
- To typer variation
- Sådan læser du et seriediagram
- Anhøj-reglerne
- Kontroldiagrammer
- Gode råd
- Videre læsning

Punkt 6 ("Sådan bruger du appen") fjernes fra denne side — det indhold flyttes til den nye side og udvides.

**Rækkefølge i navbar:** App-guide før SPC-teori, fordi brugeren typisk spørger "hvordan bruger jeg det her?" før "hvad er teorien bag?"

### 2. Kontekstuel hjælp (info-ikoner + sammenklapbare paneler)

#### Info-ikoner

Små (i)-ikoner ved nøglefelter. Klik åbner en popover med 1-3 sætninger.

**Analysér-siden:**

| Felt | Hjælpetekst |
|------|-------------|
| Skift | Opdeler diagrammet i faser. Brug dette når du ved at processen er ændret på et bestemt tidspunkt (fx ny procedure indført). |
| Frys | Låser kontrolgrænserne baseret på en baseline-periode, så du kan se om nye data afviger fra det historiske niveau. |
| Diagramtype | Kompakt oversigt over hvornår man bruger hvilken type (Run, I, P, C, U). |
| Serielængde value box | Antal på hinanden følgende punkter på samme side af medianen. Hvis faktisk > forventet, er der tegn på et skift i processen. |
| Antal kryds value box | Antal gange linjen krydser medianen. Hvis faktisk < forventet, er der tegn på clustering i data. |
| Udviklingsmål | En vandret linje der viser jeres målsætning. Påvirker ikke beregninger. |

**Eksportér-siden:**

| Felt | Hjælpetekst |
|------|-------------|
| Datadefinition | Beskriv hvad indikatoren måler og hvordan data er opgjort. Fx: "Andel patienter mødt til ambulant aftale (mødt/tilkaldt), opgjort månedligt." |
| Analyse af processen | Beskriv hvad diagrammet viser — er processen stabil? Er der signaler? Hvad kan forklare eventuelle udsving? |

**Kvalitetssikring:** Eksisterende hjælpetekster (inkl. ved value boxes og kolonne-mappings) gennemgås, ensrettes i tone og kvalitetssikres for korrekthed.

#### Sammenklapbare paneler

- En diskret bjælke øverst på Analysér- og Eksportér-siden: "Hjælp til dette trin" med chevron-ikon
- Klik folder et kort afsnit ud der opsummerer hvad man skal gøre og hvorfor
- Starter sammenklappet, så erfarne brugere ikke forstyrres

**Analysér-panelet** forklarer: Vælg kolonner, vælg diagramtype, tjek om der er signaler i value boxes.

**Eksportér-panelet** forklarer: Udfyld metadata, skriv analysens konklusion, eksportér som PDF/PNG.

### 3. Velkomstsiden

Tilføj to diskrete tekstlinks under "Kom i gang"-knappen:

```
           [Kom i gang →]

  Ny her?  Sådan bruger du appen  ·  Lær om SPC
```

Små, diskrete links (ikke knapper). Til den bruger der tænker "vent, jeg er ikke klar endnu", uden at bremse den bruger der bare vil i gang.

## Hvad ændres IKKE

- Det eksisterende SPC-teoriindhold (punkt 1-5, 7-8) beholdes og forbliver på "Lær om SPC"-siden
- App-flowet (Upload → Analysér → Eksportér) ændres ikke
- Eksisterende kolonne-mapping beskrivelser beholdes (men kvalitetssikres)

## Afgrænsning

- Ingen guided tour / onboarding wizard — det er out of scope
- Ingen sidebar/drawer — vi bruger sammenklapbare paneler i stedet
- Screenshots/illustrationer til app-vejledningen kræver separat indsats og kan tilføjes iterativt

## Implementeringsnoter

- Ny navbar-tab kræver tilføjelse i Shiny UI (tabPanel i navbarPage)
- Sammenklapbare paneler kan implementeres med `shinyjs::toggle()` eller `bslib::accordion()`
- Info-ikoner kan implementeres med `bslib::tooltip()` eller `shiny::icon()` + popover
- Eksisterende "Lær om SPC"-indhold er defineret i R-koden — skal lokaliseres og refaktoreres
