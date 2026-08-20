# Dokumentation - repostruktur och historik

Denna fil dokumenterar arbetet som gjorts i repot `azure` (repostruktur, README:s och namngivning), inte själva Azure-uppgifterna.

## Vad som gjorts (kronologisk logg)

1. Skapade `UppgiftV34/README.md` med grundstruktur (rubrik, namn, kurs).
2. Lade till och tog senare bort en statusrad i `UppgiftV34/README.md`.
3. Lade till namn (Idris Altun) och kursnamn (Azure) i `UppgiftV34/README.md`.
4. Skapade mapparna `UppgiftV35`-`UppgiftV41`, var och en med en README.md enligt samma mall som V34.
5. Utökade `UppgiftV34/README.md` med rubrik "Compute: driftsättning av Novatrix kundtjänst" samt sektionerna Syfte, Vad jag gjorde, Kommandon och Resultat.
6. Skapade root-`README.md` för hela repot med kursintro (MOV25 - Microsoft Azure) och en Innehåll-checklista som länkar till respektive veckomapp, samt ett avsnitt "Om Novatrix" som beskriver det fiktiva företaget kursen bygger kring.
7. Länkade samtliga veckor (V34-V41) i checklistan till sina respektive mappar.
8. Döpte om samtliga veckomappar från `Uppgift V##` (med mellanslag) till `UppgiftV##` (utan mellanslag) och uppdaterade länkarna i root-README:n därefter.

## Struktur

```
azure/
├── README.md          # Repo-översikt, kursintro, checklista per vecka
├── Doc/
│   └── README.md       # Denna fil - dokumentation av repoarbetet
├── UppgiftV34/
│   └── README.md        # Vecka 34 - Compute (driftsättning av Novatrix kundtjänst)
├── UppgiftV35/ ... UppgiftV41/
│   └── README.md        # Mallar för kommande veckor
```

## Namnstandard

- Mappnamn: `UppgiftV<veckonummer>` utan mellanslag (t.ex. `UppgiftV34`).
- Varje veckomapp innehåller en README.md med sektionerna: Syfte, Vad jag gjorde, Kommandon, Resultat.
