# Uppgift V35 - IAM och identitet

**Repo:** https://github.com/80idralt/azure/tree/master/v35

**Namn:** Idris Altun

**Klass:** MOV25

**Datum:** 2026-08-26

## Syfte
Novatrix har sedan v34 en server i Azure. Nu ska jag bestämma vem som får göra vad med den. Driften behöver kunna sköta servern, utvecklarna behöver bara kunna titta. Ingen ska ha mer behörighet än den behöver för sitt jobb.

Jag har gjort hela den här uppgiften för hand i Azure Portal.

## Utgångsläge
Jag bygger vidare på miljön från v34:

- Resursgrupp: `rg-novatrix-v34` i `swedencentral`
- I den ligger `vm-novatrix-web` med disk, nätverkskort, nätverk, publikt IP och NSG

## Vad jag gjorde

### 1. Skapade två användare
Jag gick till **Microsoft Entra ID → Users → New user → Create new user** och skapade en användare för varje roll på företaget.

| Namn | Inloggning |
|---|---|
| Anna Drift | `drift-anna@idrisaltun2029hotmail.onmicrosoft.com` |
| Erik Utveckling | `utveckling-erik@idrisaltun2029hotmail.onmicrosoft.com` |

Jag döpte dem efter mönstret `roll-förnamn`, så syns det redan på inloggningsnamnet vilket team de tillhör.

### 2. Skapade två grupper
Sen gjorde jag en grupp per roll under **Entra ID → Groups → New group**. Jag valde **Security** som grupptyp och **Assigned** som medlemskap, och la in rätt person i varje grupp direkt när jag skapade dem.

| Grupp | Medlem |
|---|---|
| Azure-Drift | Anna Drift |
| Azure-Utveckling | Erik Utveckling |

Anledningen till att jag använder grupper är att folk byter jobb men rollerna finns kvar. Kommer det in en ny utvecklare lägger jag bara till hen i `Azure-Utveckling`, så får hen rätt åtkomst automatiskt. Jag behöver aldrig gå in och peta i behörigheterna på resursgruppen igen.

### 3. Gav grupperna behörighet
Behörigheterna satte jag på resursgruppen under **rg-novatrix-v34 → Access control (IAM) → Add → Add role assignment**. Jag valde rollen först och sen gruppen. Ingen av användarna har fått behörighet direkt på sitt konto, allt går via grupperna.

| Grupp | Roll |
|---|---|
| Azure-Drift | Contributor |
| Azure-Utveckling | Reader |

Så här ser det ut i **Access control (IAM) → Role assignments** på resursgruppen efteråt:

![Rolltilldelningarna på rg-novatrix-v34](images/accesskontrol.png)

Två saker är värda att lägga märke till i listan. **Type** säger `Group` på båda mina tilldelningar, alltså ligger behörigheten på grupperna och inte på personerna. Och **Scope** säger `This resource`, medan mitt eget Owner står som `Subscription (Inherited)`. Det är skillnaden mellan en behörighet som bara gäller den här miljön och en som ärvs uppifrån och gäller överallt.

**Varför jag satte behörigheten på resursgruppen och inte på hela prenumerationen:** roller ärvs nedåt i Azure. Hade jag lagt dem på prenumerationen skulle de gälla varje ny resursgrupp jag skapar resten av kursen. Nu gäller de bara Novatrix miljö.

**Varför drift fick Contributor:** de ska kunna sköta driften själva. Starta och stoppa servern, ändra brandväggsregler, skapa nya resurser när det behövs. Contributor ger dem det, men den får inte dela ut behörigheter till andra. Det är därför jag valde Contributor och inte Owner, för en Owner kan höja sina egna rättigheter.

**Varför utveckling bara fick Reader:** utvecklarna behöver se hur miljön är byggd när de felsöker. Kolla IP-adresser, se vad som är driftsatt, titta på konfigurationen. De behöver inte kunna ändra något. Reader kan bara läsa, ingenting annat.

**Ingen fick Owner.** Den rollen har jag kvar på mitt eget adminkonto.

Att behörigheten går via gruppen och inte via kontot syns när man öppnar en användare i Entra ID och går till **Azure role assignments**. Rollen står där, men kolumnen **Assigned To** visar gruppen.

![Eriks behörigheter: Reader på rg-novatrix-v34 via Azure-Utveckling](images/eriksbehorigheter124229.png)

![Annas behörigheter: Contributor på rg-novatrix-v34 via Azure-Drift](images/annasbehorigheter124249.png)

### Kontroll av det jag gjort
Så här läste jag av att allt blev rätt, allt i portalen:

- **Att rätt person hamnat i rätt grupp:** Entra ID → Groups → gruppen → **Members**. `Azure-Drift` innehåller Anna, `Azure-Utveckling` innehåller Erik.
- **Att grupperna fått rätt roll:** rg-novatrix-v34 → Access control (IAM) → fliken **Role assignments**. Där står `Azure-Drift` med Contributor och `Azure-Utveckling` med Reader.
- **Att ingen har behörighet direkt på sitt konto:** Entra ID → Users → användaren → **Azure role assignments**, som på bilderna ovan. Kolumnen Assigned To visar gruppen, inte personen.

Samma sak går att läsa av med två kommandon, efter `az login`:

```powershell
az ad group member list --group "Azure-Drift" --query "[].displayName" -o tsv
az ad group member list --group "Azure-Utveckling" --query "[].displayName" -o tsv
```

```
Anna Drift
Erik Utveckling
```

```powershell
az role assignment list --resource-group rg-novatrix-v34 --query "[].{Namn:principalName, Typ:principalType, Roll:roleDefinitionName}" -o table
```

```
Namn              Typ    Roll
----------------  -----  -----------
Azure-Drift       Group  Contributor
Azure-Utveckling  Group  Reader
```

### 4. Verifiering

Att rolltilldelningen syns i portalen bevisar bara att jag gjort den, inte att den faktiskt stoppar någon. Så jag loggade in som Erik och testade på riktigt.

Jag öppnade ett inkognitofönster på portal.azure.com, så att jag inte råkade använda min egen adminsession, och loggade in som `utveckling-erik@idrisaltun2029hotmail.onmicrosoft.com`. Redan på startsidan syntes att kontot är begränsat, kostnadsrutan sa **"Du har inte behörighet att visa krediter"** eftersom Erik bara har behörighet på resursgruppen och inte på prenumerationen.

![Erik inloggad i portalen, utan behörighet att se krediter](images/eriksinloggning125240.png)

**Läsningen fungerade.** Erik kunde öppna `rg-novatrix-v34` och gå in på `vm-novatrix-web`. Han ser allt han behöver för att felsöka: att servern har status **Kör**, att den är en Ubuntu 24.04 av storleken Standard B2ats v2, vilken publik IP-adress den har och vilket nätverk den sitter i. Det är precis vad Reader ska ge.

![Erik ser den virtuella datorn och att den kör](images/erikserverigang.png)

**Ändringen stoppades.** Knapparna Starta om, Stoppa och Ta bort syns visserligen i menyn, portalen gråar inte ut dem. Men när jag klickade på Stoppa som Erik vägrade Azure, med ett tydligt besked om exakt vilken åtgärd han saknar behörighet för.

![Erik nekas att stoppa den virtuella datorn](images/eriknekad125317.png)

Det är de här två bilderna tillsammans som är beviset. Rollen är inte bara satt, den håller åt rätt håll: Erik kan se miljön men inte röra den. Att knapparna går att klicka på spelar ingen roll, för behörigheten kontrolleras av Azure när åtgärden faktiskt körs, inte av vad portalen visar.

### Anna med Contributor kan det Erik inte kan

Sen gjorde jag samma test med Anna, för att se att skillnaden mellan rollerna faktiskt märks. Jag loggade in som `drift-anna@idrisaltun2029hotmail.onmicrosoft.com` i ett eget inkognitofönster.

Redan på startsidan dök något intressant upp. Anna får samma varning som Erik: **"Du har inte behörighet att visa krediter"**. Hon är Contributor, men bara på resursgruppen. Kostnaderna ligger på prenumerationen, och dit når hon inte. Behörigheten slutar precis där jag satte den.

![Anna inloggad i portalen](images/annakonto.png)

Sen stoppade jag servern som henne. Det gick igenom direkt, utan felmeddelande, och statusen slog om till **Stoppad (frigjord)**. Frigjord betyder att servern är helt avstängd och att resurserna lämnats tillbaka, så den slutar kosta pengar medan den står still.

![vm-novatrix-web stoppad av Anna](images/annavmstoppat.png)

En detalj i den bilden är värd att titta på. Nu är knapparna Starta om, Stoppa och Viloläge utgråade, medan Starta är aktiv. Det ser ut som Eriks fall men är något helt annat: här är knapparna släckta för att maskinen redan är stoppad av mig tidigare, inte för att Anna saknar behörighet.

Till sist startade jag servern igen som Anna, så att miljön var tillbaka som den var.

![Anna startar servern igen](images/annamaskinstartat.png)

### Skillnaden mellan rollerna

| | Erik, Reader | Anna, Contributor |
|---|---|---|
| Se resursgruppen och VM:en | Ja | Ja |
| Stoppa och starta servern | Nej, nekades | Ja |
| Se prenumerationens krediter | Nej | Nej |

Det är den här skillnaden som är hela poängen. Båda kommer in i miljön, men bara den som behöver kunna ändra får göra det. Och ingen av dem når utanför resursgruppen.

## Resultat

| Vem | Vad de får göra | Var |
|---|---|---|
| Anna Drift, via Azure-Drift | Contributor, sköta hela miljön men inte dela ut behörigheter | `rg-novatrix-v34` |
| Erik Utveckling, via Azure-Utveckling | Reader, bara titta | `rg-novatrix-v34` |
| Jag själv, admin | Owner | Prenumerationen |

Ingen har behörighet direkt på sitt konto, ingen roll sträcker sig utanför resursgruppen, och rätten att dela ut åtkomst har bara jag. Och det är verifierat på riktigt, inte bara inställt.
