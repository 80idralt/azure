# Uppgift V38 - IaC med ARM-templates

**Repo:** https://github.com/80idralt/azure/tree/master/v38

**Namn:** Idris Altun

**Klass:** MOV25

**Datum:** 2026-09-17

## Syfte

Veckans uppgift går ut på att arbeta med Infrastructure as Code (IaC) med ARM-templates i Azure, så att miljön kan återskapas från repot i stället för att klickas fram i portalen.

## Struktur

En enda mall, `v38/templates/azuredeploy.json`, med värdena i en separat parameterfil, `v38/templates/azuredeploy.parameters.json`. Deployas mot resursgruppen `rg-novatrix`.

Valde en fil i stället för flera länkade mallar: miljön är fortfarande liten och sammanhållen för ett företag, en fil ger ett enda deploy-kommando utan beroenden mellan flera filer att hålla reda på.

## 1. Storage account

Storage-konto (`StorageV2`), namn, region och sku (`Standard_LRS`/`Standard_GRS`) som parametrar, eftersom de skiljer sig mellan miljöer och namnet dessutom måste vara globalt unikt.

## 2. Nätverk

VNet med tre subnät (`snet-web`, `snet-db`, `snet-admin`), varsin NSG. Webbregeln (80, 443) är öppen för alla, databasregeln bara från webb-subnätet, admin-regeln bara från en given IP-parameter. Resursnamnen byggs från ett gemensamt prefix (`namePrefix`) via variabler, så allt hänger ihop och kan bytas på ett ställe.

## Parametrar att fylla i

- `storageName` - måste vara globalt unikt
- `adminIp` - den egna publika IP-adressen, SSH-åtkomst till admin-subnätet begränsas till den
- `namePrefix`, `location`, `sku` - har rimliga standardvärden, behöver oftast inte ändras

## Kommandon

```
az deployment group validate --resource-group rg-novatrix --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
az deployment group what-if --resource-group rg-novatrix --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
az deployment group create --resource-group rg-novatrix --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
```

## Resultat

Validering och `what-if`: `provisioningState: Succeeded`, inget oväntat. Deploy: `provisioningState: Succeeded`, alla fem resurser skapade i `rg-novatrix` (`stnovatrixv38idr`, `nsg-novatrix-web`, `nsg-novatrix-db`, `nsg-novatrix-admin`, `vnet-novatrix`), beroendena mellan VNet och NSG:erna bekräftade i svaret.

## Versionshantering

Mallen och README:t är committade och pushade till GitHub.

<img src="images/readme-commit-diff.png" alt="Diff av README.md-commiten på GitHub" width="750">

## Så återskapas miljön

1. Klona repot och gå till `v38/templates`.
2. `az group create --name rg-novatrix --location swedencentral` (om gruppen inte redan finns).
3. Kör kommandona under Kommandon i ordning: validate, what-if, create.

Ingen manuell klick i portalen behövs, allt styrs av `azuredeploy.json` och `azuredeploy.parameters.json`.

Testat i praktiken på en tidigare, mindre version av mallen (storage, en NSG och VNet, tre resurser): rev hela `rg-novatrix`, klonade repot till en ren mapp, och körde stegen ovan. Alla tre resurser kom tillbaka med samma namn och samma beroende, `provisioningState: Succeeded`. Dagens fullständiga mall (fem resurser) är validerad och deployad, se Resultat ovan.

<img src="images/rg-novatrix-resurser.png" alt="rg-novatrix vid den tidigare, mindre versionen: nsg-novatrix-web, stnovatrixv38idr och vnet-novatrix, 1 Succeeded deployment" width="750">
<img src="images/rg-riven.png" alt="Resursgrupper efter rivning: bara NetworkWatcherRG kvar" width="750">
<img src="images/rg-atskapad-tom.png" alt="rg-novatrix återskapad men tom, efter az group create" width="750">
<img src="images/rg-novatrix-aterskapad.png" alt="rg-novatrix med alla tre resurser tillbaka, byggt från den rena klonen" width="750">

