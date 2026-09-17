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

## 3. Storage-container

En privat blob-container (`arenden`) för inskickade ärenden, `publicAccess: None`. Namnet är hårdkodat, det är applikationslogik snarare än något som varierar mellan miljöer.

## 4. Hoppvärd

En VM (`vm-novatrix-jump`) i `snet-admin`, med publikt IP och nätverkskort, samma mönster som webbservern. SSH tillåts bara från `adminIp` via `nsg-novatrix-admin`.

VM-storleken (`vmSize`) blev `Standard_D2als_v6`, inte den ursprungliga `Standard_B2ats_v2`: kontot gick över till Pay-As-You-Go och fick tillfälligt 0 i kvot för hela B-seriens familjer i Sweden Central, bekräftat både via mallen och ett fristående test. D-seriens nyaste generation hade kvot och är dessutom billigast i den serien.

## 5. Webbserver

En VM (`vm-novatrix-web`) i `snet-web`, med publikt IP och nätverkskort, nås via HTTP/HTTPS enligt `nsg-novatrix-web`.

## 6. Identitet och behörighet

En hanterad identitet (`id-novatrix-app`) kopplad till webbservern, med rollen `Storage Blob Data Contributor` scopad till just `arenden`-containern, inte hela kontot. Det är så webbservern ska kunna skriva ärenden till lagringen utan lösenord i koden.

De mänskliga RBAC-grupperna från v35 (Azure-Drift, Azure-Utveckling m.fl.) är medvetet utelämnade, v38 kräver VM, nätverk, säkerhet och storage, inte IAM.

## Parametrar att fylla i

- `storageName` - måste vara globalt unikt
- `adminIp` - den egna publika IP-adressen, ändras ofta eftersom hemmauppkopplingar sällan har fast IP
- `sshPublicKey` - publik SSH-nyckel för inloggning på VM:arna
- `namePrefix`, `location`, `sku`, `adminUsername`, `vmSize` - har rimliga standardvärden, behöver oftast inte ändras

## Kommandon

```
az deployment group validate --resource-group rg-novatrix --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
az deployment group what-if --resource-group rg-novatrix --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
az deployment group create --resource-group rg-novatrix --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
```

## Resultat

Validering och `what-if`: `provisioningState: Succeeded`, inget oväntat. Deploy: `provisioningState: Succeeded`, alla 14 resurser skapade i `rg-novatrix`, beroendena bekräftade i svaret. Mallens `outputs` gav tillbaka rätt resurs-id:n.

Verifierade rolltilldelningen separat: `az role assignment list --scope <container-id>` visar `Storage Blob Data Contributor` på identitetens principal, scopad exakt till `arenden`.

Loggade in på hoppvärden med SSH för att bevisa att den faktiskt fungerar: `ssh -i novatrix_key azureuser-web@<publikt IP>`, kom in på Ubuntu 24.04.4, privat IP `10.0.3.4` i `snet-admin`, precis som avsett.

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

