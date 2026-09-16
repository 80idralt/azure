# Uppgift V38 - IaC med ARM-templates

**Repo:** https://github.com/80idralt/azure/tree/master/v38

**Namn:** Idris Altun

**Klass:** MOV25

**Datum:** 2026-09-16

## Syfte

Veckans uppgift går ut på att arbeta med Infrastructure as Code (IaC) med ARM-templates i Azure, så att miljön kan återskapas från repot i stället för att klickas fram i portalen.

## Utgångsläge

Mallen ligger i `v38/templates/azuredeploy.json`, parametervärdena i `v38/templates/azuredeploy.parameters.json`. Deployas mot `rg-novatrix`.

## 1. Storage account

Storage-konto tillagt i mallen (`StorageV2`), namn, region och sku (`Standard_LRS`/`Standard_GRS`) som parametrar.

## 2. NSG och VNet

NSG med regel för HTTP/HTTPS (80, 443), samt VNet med ett subnät kopplat till NSG:n. Resursnamnen byggs från ett gemensamt prefix via variabler.

## Kommandon

```
az deployment group validate --resource-group rg-novatrix --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
az deployment group what-if --resource-group rg-novatrix --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
az deployment group create --resource-group rg-novatrix --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
```

## Resultat

Validering: `provisioningState: Succeeded`. `what-if` visade tre resurser att skapa, inget oväntat. Deploy: `provisioningState: Succeeded`, alla tre resurser skapade i `rg-novatrix` (`nsg-novatrix-web`, `vnet-novatrix`, `stnovatrixv38idr`), beroendet mellan VNet och NSG bekräftat i svaret.

## Så återskapas miljön

1. Klona repot och gå till `v38/templates`.
2. `az group create --name rg-novatrix --location swedencentral` (om gruppen inte redan finns).
3. Kör kommandona under Kommandon i ordning: validate, what-if, create.

Ingen manuell klick i portalen behövs, allt styrs av `azuredeploy.json` och `azuredeploy.parameters.json`.

Testat i praktiken: rev hela `rg-novatrix`, klonade repot till en ren mapp, och körde stegen ovan. Alla tre resurser kom tillbaka med samma namn och samma beroende, `provisioningState: Succeeded`.

