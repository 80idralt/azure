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
- [ ] Delmoment 3: Nätverk och säkerhet - defense in depth
- [ ] Delmoment 4: Storage - säker lagring för anmälningar och bilder
- [ ] Delmoment 5: IaC - ARM-templates, versionshanterat
- [ ] Delmoment 6: Automation och integration - Power Automate mot SharePoint/Teams
- [ ] Delmoment 7: Dokumentation - hur lösningen planerats, implementerats och kan återskapas

## Namngivning

Följer kursens namnmönster typ-företag-syfte, t.ex. `rg-nordvik`, `vm-nordvik-web`, `vnet-nordvik`. Storage account: `stnordvik80idralt02` (typ + företag + användarnamn + löpnummer, `01` var redan taget globalt så löpnumret höjdes).

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
