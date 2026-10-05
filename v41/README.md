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

Två funktionsappar, samma uppdelning som tidigare tänkt för nätverket:

- `func-nordvik-portal` (publik) - visar inloggning och felanmälningsformuläret (rubrik, beskrivning, bild).
- `func-nordvik-arenden` (bara nåbar inifrån nätverket) - tar emot anmälan, sparar den, och startar Power Automate-flödet.

*Byggs i nästa steg, uppdateras när klart.*

## Delmoment 2: IAM

Tre roller, enligt least privilege:

- **Hyresgäst:** ingen egen Entra-identitet. Loggar in i appen med ett hyresgästnummer (mot en egen liten lista, inte Entra ID), hyresgästnumret bär med sig vilken fastighet/lägenhet personen hör till. Appen visar bara den inloggade hyresgästens egna anmälningar. En skarp lösning med 5500 externa hyresgäster hade använt Entra External ID/B2C, men det är inget kursen gått igenom, så det är en medveten avgränsning.
- **Förvaltare** och **Ekonomi:** riktiga Entra-identiteter, en grupp var. Grupperna är satta upp som **Microsoft 365-grupper** istället för vanliga säkerhetsgrupper, så en och samma grupp ger tre saker: en RBAC-roll mot rätt container i lagringskontot, en egen Teams-kanal som tar emot notiser, och en mejladress dit det akuta mejlet går. Förvaltare och ekonomi loggar in i portalen med sina riktiga Entra-konton, och appen styr vad de får göra utifrån gruppmedlemskapet.

Grupperna skapades med PowerShell-modulen MicrosoftTeams (`New-Team`), inte `az ad group create`, eftersom den bara skapar en vanlig säkerhetsgrupp utan Team och mejladress:

```
$forvaltare = New-Team -DisplayName "Nordvik-Forvaltare" -MailNickName "nordvik-forvaltare" -Visibility Private -Description "Förvaltare, hanterar felanmälningar"
$ekonomi = New-Team -DisplayName "Nordvik-Ekonomi" -MailNickName "nordvik-ekonomi" -Visibility Private -Description "Ekonomi, läsande insyn i felanmälningar"
```

| Grupp | Group ID |
|---|---|
| `Nordvik-Forvaltare` | `82f89c0e-2ccd-4a4b-a273-b633e2cd2805` |
| `Nordvik-Ekonomi` | `292b7363-2955-43ae-859f-fd2ad29d0605` |

RBAC-rolltilldelningarna läggs på när lagringen och funktionerna finns på plats.

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
