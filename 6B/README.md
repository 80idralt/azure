# Uppgift 6B - Elastiskt, övervakat och händelsestyrt

**Repo:** https://github.com/80idralt/azure/tree/master/6B

**Namn:** Idris Altun

**Klass:** MOV25

**Datum:** 2026-10-01

Frivillig komplettering till Uppgift 6. Novatrix ärendenotis från v39 byggs om med Azures egna tjänster i stället för Power Automate.

## Moduler

| Modul | Mapp | Status |
|---|---|---|
| 1. Händelsestyrt | [`modul-1-handelsestyrt/`](modul-1-handelsestyrt/) | Klar och verifierad, inklusive VG-bredd |
| 2. Elastiskt | [`modul-2-elastiskt/`](modul-2-elastiskt/) | Klar och verifierad, inklusive VG-bredd (autoskalning och lasttest) |
| 3. Övervakat och styrt | [`modul-3-overvakat/`](modul-3-overvakat/) | Klar och verifierad, inklusive VG-bredd (policy och KQL) |

## Modul 1 i korthet

Ett nytt ärende i containern `arenden` startar via Event Grid en Azure Function i Python. Funktionen skriver ärendet i en tabell, skickar ett mejl via Azure Communication Services och postar ett kort i Teams-kanalen `Kundtjänst` genom en egen bot. Allt använder hanterade identiteter och är driftsatt med ARM-mallar. Detaljer, motiveringar och resultat finns i [modulens README](modul-1-handelsestyrt/README.md).

## Modul 2 i korthet

v39:s enda webb-VM är utbytt mot ett VM Scale Set bakom en lastbalanserare. Autoskalningen lägger till en VM när CPU:n ligger över 70 % i 5 minuter och tar bort en när den ligger under 30 %. Ett lasttest visade förloppet 1 → 2 → 1. Ett budgetlarm sattes innan testet. Detaljer i [modulens README](modul-2-elastiskt/README.md).

## Modul 3 i korthet

Webben från Modul 2 får ett övervakningslager. En agent på varje VM skickar `Heartbeat` och CPU till Log Analytics, där KQL-frågor visar vilka VM:ar som lever och hur lasten fördelas per VM. Ett larm mejlar via en action group när snitt-CPU:n ligger över 80 % i 5 minuter, alltså när autoskalningen vid 70 % inte räcker. En Azure Policy nekar resurser som saknar taggen `projekt`, så att kostnaderna kan följas upp per projekt. Detaljer i [modulens README](modul-3-overvakat/README.md).

## Så körs Modul 1

Förkrav: Azure CLI (inloggad med `az login`), Azure Functions Core Tools v4 och PowerShell 7.4 eller senare. Boten och Teams-appen sätts upp en gång enligt modulens README.

Bygg, publicera och skicka ett testärende:

```powershell
.\6B\modul-1-handelsestyrt\deploy.ps1
```

Riv testmiljön:

```powershell
.\6B\modul-1-handelsestyrt\destroy.ps1
```

## Så körs Modul 2

Fyll i `adminIp` och `sshPublicKey` i `modul-2-elastiskt/templates/azuredeploy.parameters.json`. Bygg sedan från `6B/modul-2-elastiskt/templates`:

```powershell
az group create --name rg-novatrix-m2 --location swedencentral
az deployment group create --resource-group rg-novatrix-m2 --template-file azuredeploy.json --parameters "@azuredeploy.parameters.json"
```

Lasttestet och alla kontroller står i [modulens README](modul-2-elastiskt/README.md#kommandon). Riv direkt efter testet:

```powershell
az group delete --name rg-novatrix-m2 --yes --no-wait
```

## Så körs Modul 3

Fyll i `adminIp` och `sshPublicKey` i `modul-3-overvakat/templates/azuredeploy.parameters.json`. Bygg sedan från `6B/modul-3-overvakat/templates`:

```powershell
az group create --name rg-novatrix-m3 --location swedencentral --tags projekt=novatrix modul=6b-modul3
az deployment group create --resource-group rg-novatrix-m3 --template-file azuredeploy.json --parameters "@azuredeploy.parameters.json"
az deployment group create --resource-group rg-novatrix-m3 --template-file policy.json
```

Lasttest, KQL-frågor och policyprovet står i [modulens README](modul-3-overvakat/README.md#kommandon). Riv direkt efter testet:

```powershell
az group delete --name rg-novatrix-m3 --yes --no-wait
```
