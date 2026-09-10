# Uppgift V37 - Storage

**Repo:** https://github.com/80idralt/azure/tree/master/v37

**Namn:** Idris Altun

**Klass:** MOV25

**Datum:** 2026-09-10

## Syfte

Novatrix kundtjänst tar emot ärenden via ett webbformulär, men hittills har det bara varit en sida — inget som skickas in sparas någonstans. Den här veckan får lösningen ett lagringslager: ett ställe dit inskickade ärenden och bifogade filer hamnar, skilt från servern, så att data finns kvar även om servern byts ut. Åtkomsten ska vara säkrad, inget ska ligga öppet.

Lagringen och säkerheten runt den gjorde jag först för hand i portalen, sedan som kod. Att koppla in själva formuläret görs på labben och beskrivs i avsnitt 3.

## Utgångsläge

Jag bygger vidare på samma miljö som förut, `rg-novatrix-v34` i `swedencentral`, ingenting rivs:

- `vm-novatrix-web` från v34, nu i `snet-web` efter v36
- Behörighetsmodellen och den hanterade identiteten `id-novatrix-app` från v35
- `snet-db` från v36 — ett privat subnät utan väg ut till internet, förberett för just lagringen. `nsg-db-v36` har redan regeln `Allow-Web-To-Storage` (443 från webbsubnätet)

`id-novatrix-app` skapade jag i v35 med kommentaren att den skulle kopplas ihop med lagringen först nu. Det är det som händer den här veckan.

## 1. Repo

La till mappen för v37 med `scripts/`, `images/` och `public/`, och skrev den här README:n. La också en `.gitattributes` i repot som tvingar LF-radbrytningar på skalskript och YAML, så att skript och cloud-init inte går sönder när de körs på Linux.

I `scripts/` ligger nu inte bara veckans lagringsskript utan hela kedjan som bygger miljön från v34 och framåt. Tanken är att allt ska finnas samlat på ett ställe inför IaC-veckan. Mer om det i avsnitt 6.

## 2. Skapa lagringen

### Storage account

Jag skapade kontot i portalen under **Storage accounts → Create**, i `rg-novatrix-v34` och samma region som VM:en.

| Inställning | Värde | Varför |
|---|---|---|
| Namn | `stnovatrixv37idr` | Måste vara globalt unikt i hela Azure. `st` + företag + vecka + initialer |
| Region | `Sweden Central` | Samma som VM och nätverk — lägre fördröjning, ofta lägre kostnad |
| Prestanda | `Standard` | Enkla ärendefiler behöver ingen premium-SSD |
| Kontotyp | `StorageV2` | Den moderna kontotypen |
| Redundans | `LRS` | Tre kopior inom ett datacenter, billigast |
| Standardnivå | `Hot` | Ärenden läses aktivt när de kommer in |

**Blob, inte Files.** Files är en nätverksmapp (SMB) som flera servrar monterar som en enhet. Det jag behöver är att appen lägger objekt som nås via en adress — det är precis vad Blob är byggt för. Novatrix ärenden och bilagor hör hemma i Blob.

### Val av lagringsnivå

Ett ärende är färskt när det kommer in. Supporten öppnar det, läser bilagan, svarar kunden, ofta flera gånger de första dagarna. Sedan blir det tyst. Lagringsnivån i Azure är en avvägning mellan vad det kostar att förvara data och vad det kostar att läsa den:

- **Hot** — dyrast per lagrad GB, men billigast per läsning och ingen avgift för att hämta data. För data som läses ofta.
- **Cool** — billigare lagring, dyrare läsning, datan ska ligga kvar minst 30 dagar. För sällanläst data.
- **Archive** — billigast av alla att förvara, men datan ligger offline och tar timmar att återställa, minst 180 dagar. För ren arkivdata.

Novatrix ärenden läses aktivt när de är aktuella, så Hot är rätt nivå: läsningarna blir billiga och svarstiden direkt. Att lägga aktiva ärenden på Cool hade sparat nästan ingenting på lagringen, eftersom datamängden är liten, men gjort varje läsning dyrare. Hot + LRS är alltså ett medvetet val — Hot för att datan läses ofta, LRS för att en labbmiljö med testdata inte behöver kopior i en annan region.

Ett rimligt nästa steg vore en livscykelregel som automatiskt flyttar ärenden äldre än till exempel sex månader till Cool. Då får man arkivbesparingen på det gamla utan att offra prestanda på det som är aktuellt.

Kryptering i vila är på automatiskt, Azure sköter det, inget att slå på.

<img src="images/storageaccount.png" alt="Granska och skapa: Basics, Advanced och Security" width="650">
<img src="images/stnovatrixv37idr.png" alt="Kontots översikt: rg-novatrix-v34, Sweden Central, Standard, LRS, StorageV2" width="750">

### Blob-container

Under **Containers → + Container** skapade jag `arenden`, för inskickade ärenden och bilagor. Åtkomstnivån lämnade jag på **Private (no anonymous access)** — ingen ska kunna läsa innehållet utan att vara behörig.

Sen laddade jag upp en testfil, `arendebild.jpg`, för att ha något att verifiera mot. Filen fick blob-adressen:

```
https://stnovatrixv37idr.blob.core.windows.net/arenden/arendebild.jpg
```

<img src="images/container2.png" alt="Containern arenden med testfilen" width="750">
<img src="images/container1.png" alt="Blobbens egenskaper: Block blob, Hot, server-krypterad" width="550">

### Kontot i text

```
[ Klistras in: az storage account show -g rg-novatrix-v34 -n stnovatrixv37idr -o table ]
```

## 3. Koppla formuläret till lagringen

Görs på labben. Kort sagt: en liten mottagare på `vm-novatrix-web` tar emot det inskickade formuläret och lägger ärendet, plus en eventuell bifogad bild, som blobar i containern `arenden`. Mottagaren skriver via `id-novatrix-app` — ingen nyckel i koden.

I `public/index.html` är fil-fältet och `enctype="multipart/form-data"` redan på plats. Det som återstår är att peka `action` mot mottagaren.

Verifieringen att ett inskickat testärende faktiskt hamnar i containern hör till det här momentet och redovisas i avsnitt 5.

## 4. Säkra åtkomsten

### 4.1 Stäng publik åtkomst

Två grundinställningar kontrollerade jag på kontot under **Settings → Configuration**:

| Inställning | Läge |
|---|---|
| Allow Blob anonymous access | Disabled |
| Secure transfer required (HTTPS) | Enabled |

Nyare konton har anonym åtkomst avstängd som standard, men jag bekräftade det. Ärenden är inte offentligt material, så ingenting ska gå att läsa utan inloggning. HTTPS-kravet gör att trafiken till och från lagringen är krypterad.

<img src="images/containerconfiguration.png" alt="Configuration: anonym åtkomst Disabled, secure transfer Enabled" width="750">

### 4.2 Appen når lagringen via hanterad identitet, inte nyckel

En åtkomstnyckel ger full åtkomst till hela kontot, har ingen tidsgräns och går inte att spåra till en person. Hamnar den i kod är kontot i praktiken öppet. Därför använder appen en hanterad identitet i stället — Azure sköter inloggningen och det finns inget lösenord som kan läcka.

Jag hängde `id-novatrix-app` på webbservern under **vm-novatrix-web → Identity → User assigned**, och gav den sedan rollen **Storage Blob Data Reader** på storage-kontot under **Access control (IAM)**.

<img src="images/vmidentity.png" alt="id-novatrix-app kopplad till vm-novatrix-web" width="750">
<img src="images/rolltilldelad.png" alt="Storage Blob Data Reader tilldelad id-novatrix-app, scope This resource" width="750">

**User-assigned, inte VM:ens egen.** En VM kan ha en inbyggd (system-assigned) identitet som föds och dör med maskinen. `id-novatrix-app` är i stället fristående — den överlevde att VM:en raderades och byggdes om i v36, och den är den identitet jag förberedde för det här redan i v35.

Rollen är i skrivande stund **Storage Blob Data Reader** — läsa och lista blobar. När formuläret kopplas in (avsnitt 3) byter jag den mot **Storage Blob Data Contributor** med containern `arenden` som scope, så att appen får skriva ärenden men bara dit, inget annat på kontot. Det är least privilege: minsta behörighet som räcker för uppgiften.

Nyckelåtkomsten (shared key) är kvar i kontots standardläge, påslagen — jag stängde inte av den. RBAC via den hanterade identiteten är den robusta metoden, och att helt stänga av nycklarna är ett extra steg som inte krävs här.

### 4.3 SAS för tillfällig delning

Ska en bilaga delas tillfälligt med en tekniker vill jag inte lämna ut en nyckel. Då genererar jag i stället en SAS — en signerad länk med exakt de rättigheter och den tid jag väljer.

På `arendebild.jpg` → **Generate SAS** satte jag:

| Fält | Värde |
|---|---|
| Permissions | Read |
| Giltighetstid | 1 timme |
| Protokoll | HTTPS only |
| Omfång | Just den här blobben |

Snävast möjliga: bara läsa, bara den filen, kort tid. Går den ut slutar den fungera av sig själv.

<img src="images/sasbild.png" alt="Generate SAS: Read, 1 timme, HTTPS only" width="550">

### 4.4 Begränsa nätverksåtkomsten

Görs denna vecka. Utöver behörigheterna lägger jag ett nätverkslager framför kontot: standardåtgärden sätts till **Neka**, och bara `snet-db` släpps in, via en privat endpoint. Det knyter an till v36, där `nsg-db-v36` redan har regeln `Allow-Web-To-Storage` (443 från webbsubnätet) — nu finns det en tjänst bakom den regeln. Vid behov kan jag också lägga till min egen IP för att kunna administrera kontot.

### Åtkomsten i översikt

Så här ser åtkomsten till lagringen ut när veckan är klar:

| Container | Åtkomstmetod | Vem når vad |
|---|---|---|
| `arenden` | RBAC via hanterad identitet | `id-novatrix-app` läser och skriver ärenden och bilagor. Inget anonymt. |
| `arenden`, enskild blob | Kort läs-SAS | Tillfällig delning med t.ex. en tekniker: bara läsa, bara den filen, HTTPS, tidsbegränsat |
| Kontot | Nätverksregel | Bara `snet-db` via privat endpoint, plus min IP vid behov. Allt annat nekas. |

Skrivrollen (avsnitt 4.2) och nätverksraden (avsnitt 4.4) är på plats när de momenten är klara.

## 5. Verifiera och dokumentera

Att inställningarna syns i portalen bevisar bara att jag gjort dem. Så jag testade åtkomsten:

| Test | Vad jag gjorde | Resultat |
|---|---|---|
| Naken blob-URL | Öppnade blob-adressen utan SAS i ett inkognitofönster | **Nekad** — `PublicAccessNotPermitted` |
| Giltig SAS | Öppnade samma blob med `?sp=r&...&sig=...` | **Bilden visas** |
| Utgången SAS | Skapade en SAS med kort giltighet, öppnade efter att tiden gått ut | **Nekad** — `AuthenticationFailed`, "Signature not valid in the specified time frame" |
| Eget konto mot blob-data | Bytte till "Microsoft Entra user account" i containern | **Nekad** — "You do not have permissions to list the data" |
| Inskickat testärende | Skickade in formuläret med en bilaga | *Görs på labben — ärendet ska hamna i `arenden`* |
| Åtkomst från ej tillåten IP | Nådde kontot från en adress utanför nätverksregeln | *Görs efter 4.4 — ska blockeras* |

<img src="images/naknaurl.png" alt="Naken URL nekas: PublicAccessNotPermitted" width="750">
<img src="images/lankbild.png" alt="Giltig SAS: bilden visas i webbläsaren" width="500">
<img src="images/nekadsas.png" alt="Utgången SAS nekas: AuthenticationFailed" width="750">
<img src="images/switchentra.png" alt="Eget konto nekas läsa blob-data trots Owner" width="700">

Det fjärde testet är det intressanta. Jag är Owner på prenumerationen, men Owner styr *kontot* — vem som får skapa, ändra och radera själva resursen. Det säger ingenting om *datan* inuti. För att läsa blobar krävs en egen dataroll (`Storage Blob Data Reader` eller `Contributor`), och den har mitt konto inte. Samma least privilege-tanke som förut, nu på datanivå.

## 6. VG — Lagringen som kod och robust åtkomst

### 6.1 Lagringen som kod

Lagringen finns som kod i `scripts/storage-novatrix.sh`: skapa kontot med rätt nivå och redundans, skapa containern privat, koppla `id-novatrix-app` till webbservern och ge den rollen på blob-data. Kör man filen byggs lagringen upp på nytt utan ett enda portalklick.

Skriptet har inga hemligheter i sig — det loggar in med `--auth-mode login` och använder identitetens objekt-id, inte en nyckel. Värden som kan behöva ändras, som kontonamn och resursgrupp, ligger överst som variabler.

*Fullständig listning läggs in när skriptet matchar portalarbetet (rollbyte + nätverksregel).*

### 6.2 Hela miljön som en kedja

`scripts/` samlar nu skripten från alla veckor på ett ställe:

| Skript | Bygger | Från vecka |
|---|---|---|
| `deploy.ps1` + `cloud-init.yaml` | Resursgrupp och webbserver | v34 |
| `rbac-novatrix.sh` | Rolltilldelningar på grupperna | v35 |
| `natverk-novatrix.sh` | VNet, subnät och säkerhetsgrupper | v36 |
| `hoppvard-novatrix.sh` | Hoppvärden | v36 (VG) |
| `storage-novatrix.sh` | Lagringen | v37 |

Lagringen hänger ihop med resten på två punkter. **Identiteten:** `storage-novatrix.sh` kopplar `id-novatrix-app` till `vm-novatrix-web`, samma identitet som skapades i v35, så att appen på servern kan nå blob-data utan lösenord. **Nätverket:** kontot ska bara nås från `snet-db` (avsnitt 4.4), subnätet som byggdes i v36 just för det här, med en NSG-regel som redan pekar från webben mot lagringen.

Nästa vecka samlas allt det här i en ARM-mall. Att skripten redan ligger samlade och använder samma namn och samma resursgrupp gör det steget mindre.

### 6.3 Robust åtkomst

Görs klart när rollen är bytt (avsnitt 4.2). Kärnan: appen når lagringen via den hanterade identiteten med en roll som bara gäller containern `arenden`, i stället för en kontonyckel. Det är robustare på fyra sätt — det finns ingen hemlighet som kan läcka, behörigheten är avgränsad till en container, varje anrop loggas mot en identitet, och identiteten överlever att servern byggs om (vilket hände i v36). En kontonyckel ger i stället full åtkomst till hela kontot, har ingen utgångstid och går inte att spåra till någon.

## Städning

Resursgruppen `rg-novatrix-v34` står kvar — hela miljön byggs vidare på den. VM:en stoppar jag när jag inte jobbar, den kostar medan den kör. Lagringen får ligga kvar till IaC-veckan. Testinnehållet är någon enstaka fil och kostar i praktiken ingenting.

## Kvar att göra

- Koppla formuläret så att ett inskickat ärende och en bilaga hamnar i `arenden` (avsnitt 3)
- Byt appens roll till Storage Blob Data Contributor på containern (avsnitt 4.2)
- Begränsa nätverksåtkomsten till kontot (avsnitt 4.4)
- Verifiera de två sista testerna i avsnitt 5
- Klistra in `az storage account show -o table` som text i avsnitt 2
- Färdigställ VG-avsnittet (6.1, 6.3) när koden matchar portalarbetet
- Döp om `lagring-novatrix.sh` till `storage-novatrix.sh`
- Bocka av v37 i rot-README vid inlämning
