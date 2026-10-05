# Uppgift V41: Nordvik Fastigheter - Hyresgästportal (Examination)

**Repo:** https://github.com/80idralt/azure/tree/master/v41

**Namn:** Idris Altun

**Klass:** MOV25

**Datum:** 2026-10-05

## Syfte

Nordvik Fastigheter AB förvaltar bostäder och lokaler och vill lansera en hyresgästportal i molnet. Kärnan i portalen är en felanmälan: en hyresgäst fyller i rubrik, beskrivning och en bild på felet och skickar in den. Förvaltare tar emot och hanterar anmälningarna, ekonomi har läsande insyn. Portalen ska driftsättas säkert och med kontrollerad åtkomst, med lagring för dokument och bilder provisionerad som kod, och med ett automatiserat arbetsflöde mot Nordviks Microsoft 365.

Nordvik är ett annat företag med andra behov än Novatrix. Samma Azure-tekniker som använts genom kursen (v34-v40) återanvänds som mönster, men datamodellen, rollerna och lösningen är medvetet omdesignade för Nordviks felanmälan, inte en namnbytt kopia av tidigare veckors lösningar.

## Innehåll

Allt för examinationen ligger i mappen `v41`. Strukturen byggs upp delmoment för delmoment:

- [ ] Del A: Dokumentation av centrala tjänster och virtualiseringsnivåer
- [ ] Delmoment 1: Compute - värdmiljö och felanmälningsformulär
- [ ] Delmoment 2: IAM - roller för hyresgäst, förvaltare, ekonomi
- [x] Delmoment 3: Nätverk och säkerhet - defense in depth
- [x] Delmoment 4: Storage - säker lagring för anmälningar och bilder
- [ ] Delmoment 5: IaC - ARM-templates, versionshanterat
- [ ] Delmoment 6: Automation och integration - Power Automate mot SharePoint/Teams
- [ ] Delmoment 7: Dokumentation - hur lösningen planerats, implementerats och kan återskapas

## Namngivning

Följer kursens namnmönster typ-företag-syfte, t.ex. `rg-nordvik`, `vm-nordvik-web`, `vnet-nordvik`. Storage account: `stnordvik80idralt02` (typ + företag + användarnamn + löpnummer, `01` var redan taget globalt så löpnumret höjdes).

## Delmoment 1: Compute

Portalen består av två delar med olika behov. Hyresgästen ska kunna logga in och skicka in en felanmälan dygnet runt, men trafiken är mycket ojämn: nästan ingen trafik 00-06, toppar 07-09 och 17-20, och upp mot 120 samtidiga användare vid månadsskifte eller en driftstörning. Samtidigt ska lösningen tåla att en enskild instans faller bort, och Nordvik vill inte betala för kapacitet som står still nattetid.

En vanlig virtuell maskin, eller en enskild container, är alltid en enda instans och uppfyller inte kravet på att tåla att en instans faller bort.

**Valet:** hela compute-delen körs som **Azure Functions i Flex Consumption-planen**, samma tjänst som i v40. Serverless löser både kraven på en gång utan extra arbete: Azure sprider automatiskt körningar över flera instanser, så det finns aldrig en enda instans att förlora, och kostnaden går mot noll när ingen använder portalen.

Två funktionsappar, båda i Flex Consumption-planen, Python 3.11, med ett gemensamt lagringskonto för sin egen drift (`stnordvik80idralt03`, separat från affärsdatan, se Storage):

- `func-nordvik-portal` (publik) - visar inloggning och felanmälningsformuläret (rubrik, beskrivning, bild). Kopplad till `snet-app`.
- `func-nordvik-arenden` (bara nåbar inifrån nätverket) - tar emot anmälan, sparar den, och startar Power Automate-flödet. Kopplad till `snet-func`.

```
$vnetId = az network vnet show --resource-group rg-nordvik --name vnet-nordvik --query id -o tsv

az functionapp create --resource-group rg-nordvik --name func-nordvik-arenden --storage-account stnordvik80idralt03 --flexconsumption-location swedencentral --runtime python --runtime-version 3.11 --vnet $vnetId --subnet snet-func --tags avdelning=fastighetsforvaltning kostnadsstalle=nordvik-portal

az functionapp create --resource-group rg-nordvik --name func-nordvik-portal --storage-account stnordvik80idralt03 --flexconsumption-location swedencentral --runtime python --runtime-version 3.11 --vnet $vnetId --subnet snet-app --tags avdelning=fastighetsforvaltning kostnadsstalle=nordvik-portal
```

VNet-kopplingen styr bara utgående trafik (vägen till lagringen), inte vem som får ringa in. `func-nordvik-arenden` stängs därför separat för publik åtkomst, så bara `func-nordvik-portal` kan nå den:

```
az functionapp config access-restriction add --resource-group rg-nordvik --name func-nordvik-arenden --rule-name allow-portal --priority 100 --action Allow --vnet-name vnet-nordvik --subnet snet-app
```

`func-nordvik-portal` har `vnetRouteAllEnabled: true`, så all dess utgående trafik, inklusive anrop till `func-nordvik-arenden`, går via `snet-app`. Regeln släpper bara in trafik därifrån, allt annat nekas automatiskt så fort en regel finns:

```
[
  { "action": "Allow", "name": "allow-portal", "priority": 100, "vnetSubnetResourceId": ".../subnets/snet-app" },
  { "action": "Deny", "name": "Deny all", "priority": 2147483647, "ipAddress": "Any" }
]
```

### Koden i `func-nordvik-arenden`

Koden ligger i [`arenden/function_app.py`](arenden/function_app.py). Den tar emot rubrik, beskrivning, kategori, fastighet och hyresgästnummer, bygger ett eget id (`fa-åååmmdd-ttmmss-slump`, egen prefix så det inte liknar v40:s `arende-`), sparar en JSON-fil plus en eventuell bild i containern `anmalningar`, och postar vidare till Power Automate när flödet finns. Tidpunkten sparas läsbart som `2026-10-05:09:19` istället för en svårläst ISO-tidsstämpel.

Testat med curl, samma sätt som tidigare veckor:

```
PS> curl.exe -i -X POST -F "rubrik=Trasig kran" -F "beskrivning=Droppar konstant i koket" -F "kategori=vatten" -F "fastighet=Fastighet 12" -F "hyresgast=HG-1042" "https://func-nordvik-arenden.azurewebsites.net/api/arenden"
HTTP/1.1 200 OK
<h1>Tack för din anmälan</h1><p>Ditt ärende är sparat med id fa-20261005-091910-9b9388, mottaget 2026-10-05:09:19.</p>
```

Lagringskontot och funktionen är båda stängda för publik åtkomst, så för att se filen krävdes ett tillfälligt undantag (eget IP), borttaget direkt efter kontrollen:

```
PS> az storage blob list --account-name stnordvik80idralt02 --container-name anmalningar --auth-mode key --query "[].name" -o table
Result
--------------------------------------
fa-20261005-091910-9b9388/anmalan.json
```

*Inloggning (Easy Auth) och `func-nordvik-portal` byggs i nästa steg.*

## Delmoment 2: IAM

Tre roller, enligt least privilege:

- **Hyresgäst:** ingen egen Entra-identitet. Loggar in i appen med ett hyresgästnummer (mot en egen liten lista, inte Entra ID), hyresgästnumret bär med sig vilken fastighet/lägenhet personen hör till. Appen visar bara den inloggade hyresgästens egna anmälningar. En skarp lösning med 5500 externa hyresgäster hade använt Entra External ID/B2C, men det är inget kursen gått igenom, så det är en medveten avgränsning.
- **Förvaltare** och **Ekonomi:** riktiga Entra-identiteter. Varje roll representeras av **två grupper** med varsitt syfte, inte en enda grupp som gör allt:
  - `Nordvik-Forvaltare` / `Nordvik-Ekonomi` — **Microsoft 365-grupper**, skapade för att få en Teams-kanal (notiser) och en mejladress (det akuta mejlet) på köpet.
  - `sg-nordvik-forvaltare` / `sg-nordvik-ekonomi` — vanliga **säkerhetsgrupper**, används för RBAC mot lagringen och för inloggningen i portalen.

  Planen var från början en enda grupp som gjorde allt tre. Det stötte på en verklig begränsning: Azure tillåter bara säkerhetsaktiverade grupper i RBAC-rolltilldelningar, och en Microsoft 365-grupp är det inte som standard (`(GroupTypeNotSupported) Only security-enabled groups can be used in role assignments`). Att göra en grupp till både Microsoft 365-grupp och säkerhetsaktiverad på samma gång går bara via direkta Microsoft Graph-anrop, långt utanför kursens verktyg, så lösningen blev två grupper per roll istället för en.

Microsoft 365-grupperna, skapade med PowerShell-modulen MicrosoftTeams:

```
$forvaltare = New-Team -DisplayName "Nordvik-Forvaltare" -MailNickName "nordvik-forvaltare" -Visibility Private -Description "Förvaltare, hanterar felanmälningar"
$ekonomi = New-Team -DisplayName "Nordvik-Ekonomi" -MailNickName "nordvik-ekonomi" -Visibility Private -Description "Ekonomi, läsande insyn i felanmälningar"
```

Säkerhetsgrupperna, skapade med `az ad group create` (ger `securityEnabled: true` per automatik, till skillnad från `New-Team`):

```
az ad group create --display-name "sg-nordvik-forvaltare" --mail-nickname "sgnordvikforvaltare"
az ad group create --display-name "sg-nordvik-ekonomi" --mail-nickname "sgnordvikekonomi"
```

| Grupp | Syfte | ID |
|---|---|---|
| `Nordvik-Forvaltare` | Teams + mejl | `82f89c0e-2ccd-4a4b-a273-b633e2cd2805` |
| `Nordvik-Ekonomi` | Teams + mejl | `292b7363-2955-43ae-859f-fd2ad29d0605` |
| `sg-nordvik-forvaltare` | RBAC + inloggning | `836c0262-c307-4b2d-91fe-5c89dfb6c286` |
| `sg-nordvik-ekonomi` | RBAC + inloggning | `b11988a3-db82-4ca7-ab72-b0a960f1d752` |

RBAC-rolltilldelningarna, scopade till `anmalningar`-containern, inte hela kontot:

```
$scope = "/subscriptions/4dd214c0-94b5-48db-8f8c-efe2cf8e2f20/resourceGroups/rg-nordvik/providers/Microsoft.Storage/storageAccounts/stnordvik80idralt02/blobServices/default/containers/anmalningar"

az role assignment create --assignee 836c0262-c307-4b2d-91fe-5c89dfb6c286 --role "Storage Blob Data Contributor" --scope $scope
az role assignment create --assignee b11988a3-db82-4ca7-ab72-b0a960f1d752 --role "Storage Blob Data Reader" --scope $scope
```

Funktionernas egna hanterade identiteter fick samma behandling, också scopat till `anmalningar`:

| Identitet | Roll |
|---|---|
| `func-nordvik-arenden` (system-assigned) | Storage Blob Data Contributor — sparar anmälningar |
| `func-nordvik-portal` (system-assigned) | Storage Blob Data Reader — visar listor, skriver aldrig direkt |

## Delmoment 3: Nätverk och säkerhet

Lagringen ska inte vara publikt åtkomlig. Lösningen är ett virtuellt nätverk med en **privat endpoint**, en egen ingång till lagringskontot som bara syns inifrån nätverket, i kombination med en **privat DNS-zon** som gör att kontots namn slår upp till en privat adress istället för en publik, bara för den som frågar inifrån vnet:et.

```
az network vnet create --name vnet-nordvik --resource-group rg-nordvik --location swedencentral --address-prefix 10.0.0.0/16 --subnet-name snet-data --subnet-prefix 10.0.1.0/24 --tags avdelning=fastighetsforvaltning kostnadsstalle=nordvik-portal

az network private-dns zone create --resource-group rg-nordvik --name privatelink.blob.core.windows.net

az network private-dns link vnet create --resource-group rg-nordvik --zone-name privatelink.blob.core.windows.net --name link-nordvik --virtual-network vnet-nordvik --registration-enabled false

$storageId = az storage account show --name stnordvik80idralt02 --resource-group rg-nordvik --query id -o tsv

az network private-endpoint create --name pe-nordvik-storage --resource-group rg-nordvik --vnet-name vnet-nordvik --subnet snet-data --private-connection-resource-id $storageId --group-id blob --connection-name pe-nordvik-storage-koppling

az network private-endpoint dns-zone-group create --resource-group rg-nordvik --endpoint-name pe-nordvik-storage --name default --private-dns-zone privatelink.blob.core.windows.net --zone-name blob

az storage account update --name stnordvik80idralt02 --resource-group rg-nordvik --default-action Deny
```

Sista kommandot stänger den sista öppningen. Lagringskontots nätverksregel gick från `Allow` till `Deny`, så allt som inte kommer via den privata endpointen avvisas. DNS-zongruppen skapade automatiskt rätt post:

```
stnordvik80idralt02.privatelink.blob.core.windows.net -> 10.0.1.4
```

Två egna subnät är förberedda för compute-delen, båda delegerade till `Microsoft.App/environments` (samma delegering som Azure Functions i Flex Consumption-planen använder för nätverksintegration):

```
az network vnet subnet create --name snet-app --resource-group rg-nordvik --vnet-name vnet-nordvik --address-prefixes 10.0.2.0/27 --delegations Microsoft.App/environments

az network vnet subnet create --name snet-func --resource-group rg-nordvik --vnet-name vnet-nordvik --address-prefixes 10.0.3.0/27 --delegations Microsoft.App/environments
```

`snet-app` används av `func-nordvik-portal`, `snet-func` av `func-nordvik-arenden`, så att den interna funktionen inte är nåbar utifrån.

**Om NSG:** `snet-data` har NSG-regler avstängda för privata endpoints som standard i Azure (`privateEndpointNetworkPolicies: Disabled`), så en NSG där skulle inte filtrera något på riktigt. NSG:n i den här lösningen läggs istället på compute-subnäten, med samma princip som i v36: en regel som uttrycker exakt det subnätets jobb.

## Delmoment 4: Storage

Felanmälningar har två sorters innehåll med olika livslängd. Bilderna som hör till en anmälan är färska och läses ofta i början, medan kontrakt och besiktningsprotokoll läses sällan efter de tre första månaderna. De läggs därför i varsin container i samma lagringskonto, med olika regler.

Resursgrupp och lagringskonto, taggat för ekonomins kostnadsuppföljning på avdelning/kostnadsställe:

```
az group create --name rg-nordvik --location swedencentral
az group update --name rg-nordvik --tags avdelning=fastighetsforvaltning kostnadsstalle=nordvik-portal

az storage account create --name stnordvik80idralt02 --resource-group rg-nordvik --location swedencentral --sku Standard_LRS --kind StorageV2 --access-tier Hot --allow-blob-public-access false --min-tls-version TLS1_2 --tags avdelning=fastighetsforvaltning kostnadsstalle=nordvik-portal
```

`--allow-blob-public-access false` stänger publik blobåtkomst på hela kontot direkt. Nätverket (privat endpoint) låses i nätverksdelen.

De två containrarna, båda utan publik åtkomst:

```
PS> az storage container create --account-name stnordvik80idralt02 --name anmalningar --auth-mode key --public-access off
{
  "created": true
}

PS> az storage container create --account-name stnordvik80idralt02 --name dokument --auth-mode key --public-access off
{
  "created": true
}
```

| Container | Innehåll | Tier |
|---|---|---|
| `anmalningar` | felanmälningar, bild plus uppgifter | Hot |
| `dokument` | kontrakt och besiktningsprotokoll | Hot, flyttas till Cool efter 90 dagar |

Lifecycle-policyn som sköter flytten till Cool ligger som kod i [`storage/lifecycle-policy.json`](storage/lifecycle-policy.json) och gäller bara filer i `dokument/`:

```
az storage account management-policy create --account-name stnordvik80idralt02 --resource-group rg-nordvik --policy @v41/storage/lifecycle-policy.json
```
