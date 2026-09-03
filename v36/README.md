# Uppgift V36 - Nätverk och säkerhet

**Repo:** https://github.com/80idralt/azure/tree/master/v36

**Namn:** Idris Altun

**Klass:** MOV25

**Datum:** 2026-09-03

## Syfte

Efter v34 har Novatrix en server i molnet, men på nätverksnivå finns inget skydd runt den. Den här veckan bygger jag det. Tanken är enkel: ärendeformuläret ska gå att nå för vem som helst, medan lagringen där ärenden och bilagor ska hamna från och med v37 ska ligga avskilt, dit ingen utifrån kommer åt. Grunddelen gjorde jag för hand i portalen.

## Utgångsläge

Jag utgår från det som redan finns: `vm-novatrix-web` från v34 och behörighetsmodellen från v35, allt i resursgruppen `rg-novatrix-v34` i `swedencentral`. Nätverket som VM-guiden satte upp i v34 var ett enda platt nät utan uppdelning, så det gör jag om. En VM kan inte byta VNet i efterhand, så jag raderade den och skapade en ny från samma OS-disk i det nya subnätet. Webbsidan och allt installerat följde med.

## 1. Repo

La till mappen för v36 och skrev den här README:n.

## 2. Virtuellt nätverk

Jag skapade ett eget VNet och delade det i två subnät, ett för webben och ett för den kommande lagringen.

| Namn | Adressintervall | Roll |
|---|---|---|
| `vnet-novatrix-v36` | `10.0.0.0/16` | Hela nätet, `swedencentral` |
| `snet-web` | `10.0.1.0/24` | Publikt, för webbservern med formuläret |
| `snet-db` | `10.0.2.0/24` | Privat subnät (ingen väg ut till internet), tomt än så länge, förberett för lagringen i v37 |
| `default` | `10.0.0.0/24` | Standardsubnätet som skapades automatiskt, används inte, ska bort |

`/16` på nätet och `/24` per subnät, det räcker gott och är lätt att hålla ordning på. Poängen med uppdelningen är att webben och lagringen ska behandlas olika. Webben måste gå att nå utifrån, lagringen ska inte det. Tar någon sig in via webben ska de inte stå direkt vid databasen.

```
az network vnet subnet list -g rg-novatrix-v34 --vnet-name vnet-novatrix-v36 \
  --query "[].{Namn:name, Prefix:addressPrefixes[0], NSG:networkSecurityGroup.id}" -o table

Namn      Prefix       NSG
--------  -----------  -----------------
default   10.0.0.0/24
snet-web  10.0.1.0/24  .../nsg-web-v36
snet-db   10.0.2.0/24  .../nsg-db-v36
```

![Subnäten](images/subnets.png)

## 3. NSG:er

Varje subnät fick en egen nätverkssäkerhetsgrupp. Utgående trafik rörde jag inte, den ligger kvar på Azures standard.

**`nsg-web-v36`** på `snet-web`:

| Prio | Namn | Riktning | Källa | Port | Åtgärd | Varför |
|---|---|---|---|---|---|---|
| 100 | `Allow-Http-Https` | In | `*` (internet) | 80, 443 | Allow | Formuläret ska nås av kunder |
| 200 | `Allow-SSh` | In | `31.208.59.112` | 22 | Allow | Jag måste kunna sköta servern, men bara jag |
| 4096 | `Deny-All-Inbound` | In | `*` | `*` | Deny | Gör "stäng allt annat" tydligt i listan |

**`nsg-db-v36`** på `snet-db`:

| Prio | Namn | Riktning | Källa | Port | Åtgärd | Varför |
|---|---|---|---|---|---|---|
| 100 | `Allow-Web-To-Storage` | In | `10.0.1.0/24` | 443 | Allow | Bara webben ska nå lagringen, och bara över HTTPS |
| 4096 | `Deny-All-Inbound` | In | `*` | `*` | Deny | Stoppar allt utom webben, även trafik från andra subnät |

Längst ner i varje NSG ligger Azures egna regler, och den sista, `DenyAllInBound`, nekar allt som ingen tidigare regel har släppt igenom. Grundläget är alltså redan stängt.

Jag la ändå in en egen `Deny-All-Inbound` överst bland mina regler i båda grupperna, men av två olika skäl. På webben är den mest för tydlighetens skull, så att "stäng allt annat" står i klartext i listan i stället för att bara vara underförstått. På det privata subnätet gör den verklig nytta: Azures inbyggda regler släpper in all trafik som kommer inifrån VNet:et, alltså även från `default`-subnätet och det jag bygger senare. Min neka-regel stänger den dörren, så att bara webben (`10.0.1.0/24`) faktiskt når lagringen.

Portalen sätter en varningstriangel på reglerna eftersom de går före Azures regel för trafik från lastbalanserare. Det gör inget här, det finns ingen lastbalanserare.

Det här är defense in depth i praktiken. Behörigheterna från v35 är ett lager. NSG:n framför webben är ett till. Att lagringen ligger i ett eget subnät som bara webben når är ett tredje. Och att SSH är låst till min adress i stället för öppen mot hela internet är ett fjärde. Går ett lager sönder finns nästa kvar.

```
az network nsg rule list -g rg-novatrix-v34 --nsg-name nsg-web-v36 -o table

Name              Priority  SourceAddressPrefixes  Access  Protocol  DestinationPortRanges
----------------  --------  ---------------------  ------  --------  ---------------------
Allow-Http-Https  100       *                      Allow   TCP       80 443
Allow-SSh         200       31.208.59.112          Allow   TCP       22
Deny-All-Inbound  4096      *                      Deny    *         *

az network nsg rule list -g rg-novatrix-v34 --nsg-name nsg-db-v36 -o table

Name                  Priority  SourceAddressPrefixes  Access  Protocol  DestinationPortRanges
--------------------  --------  ---------------------  ------  --------  ---------------------
Allow-Web-To-Storage  100       10.0.1.0/24            Allow   TCP       443
Deny-All-Inbound      4096      *                      Deny    *         *
```

![nsg-web-v36](images/nsgwebv36.png)
![nsg-db-v36](images/nsginbounddb36.png)

## 4. Lösningen i nätverket

Den nya `vm-novatrix-web` kör nu i `snet-web` med privat IP `10.0.1.4` och samma publika IP som förut, `20.240.247.212`. NSG:n satte jag på subnätet och inte på nätverkskortet, det blir enklare att hålla reda på och räcker här. Verktyget Effective security rules bekräftar att reglerna i `nsg-web-v36` verkligen slår igenom på maskinen fast de ligger på subnätet. `snet-db` står tomt och väntar på v37.

Sen städade jag. Det gamla platta VNet:et, dess nätverkskort, den gamla NSG:n och en publik IP som ingen längre använde fick åka. Kvar i resursgruppen ligger bara det som faktiskt används.

```
az network nic delete       -g rg-novatrix-v34 -n vm-novatrix-webVMNic
az network public-ip delete  -g rg-novatrix-v34 -n vm-novatrix-web-ip
az network vnet delete       -g rg-novatrix-v34 -n vm-novatrix-webVNET
az network nsg delete        -g rg-novatrix-v34 -n vm-novatrix-webNSG

az resource list -g rg-novatrix-v34 --query "[].{Namn:name, Typ:type}" -o table

Namn                     Typ
-----------------------  -----------------------------------------------
vnet-novatrix-v36        Microsoft.Network/virtualNetworks
nsg-web-v36              Microsoft.Network/networkSecurityGroups
nsg-db-v36               Microsoft.Network/networkSecurityGroups
nic-web-v36              Microsoft.Network/networkInterfaces
vm-novatrix-web          Microsoft.Compute/virtualMachines
vm-novatrix-web-osdisk   Microsoft.Compute/disks
vm-novatrix-webPublicIP  Microsoft.Network/publicIPAddresses
id-novatrix-app          Microsoft.ManagedIdentity/userAssignedIdentities
```

`id-novatrix-app` är den hanterade identiteten från v35. Den rörde jag inte, den kopplas in först i v37.

![vm-novatrix-web i snet-web](images/vmnovatrixoverview.png)
![Effektiva säkerhetsregler för nic-web-v36](images/effectivrules.png)
![Resursgruppen efter städning](images/renanovatrix.png)

## 5. Verifiering

Att reglerna syns i portalen bevisar bara att jag lagt in dem, inte att de gör något. Så jag testade på två sätt.

Först med Network Watcher och IP flow verify, som simulerar ett paket och säger vilken regel som avgör:

| Paket | Resultat | Regel |
|---|---|---|
| `10.0.1.4:80` från `8.8.8.8` | Allowed | `Allow-Http-Https` |
| `10.0.1.4:443` från `8.8.8.8` | Allowed | `Allow-Http-Https` |
| `10.0.1.4:22` från `8.8.8.8` | Denied | `Deny-All-Inbound` |
| `10.0.1.4:22` från `31.208.59.112` | Allowed | `Allow-SSh` |
| `10.0.1.4:3389` från `8.8.8.8` | Denied | `Deny-All-Inbound` |

![IP flow verify, port 80](images/verifyport80.png)
![IP flow verify, SSH från min IP](images/verify22ok.png)
![IP flow verify, SSH från främmande IP](images/verify22diny.png)

Sen på riktigt. Från min egen dator:

```
curl.exe -I http://20.240.247.212                -> HTTP/1.1 200 OK
curl.exe -I --max-time 5 https://20.240.247.212  -> curl: (7) Could not connect
ssh azureuser-web@20.240.247.212 "hostname"      -> vm-novatrix-web
```

HTTP funkar. HTTPS gör det inte, men det är inte nätverket som stoppar det, porten är öppen i NSG:n. Nginx kör bara ingen TLS än. SSH funkar från min adress.

Och från en annan maskin, en Windows Server-VM jag kör i Hyper-V som går ut mot internet med en annan publik adress (`31.208.57.44`):

```
ssh azureuser-web@20.240.247.212    -> ssh: connect to host ... port 22: Connection timed out
curl.exe -s ifconfig.me             -> 31.208.57.44
curl.exe -I http://20.240.247.212   -> HTTP/1.1 200 OK
```

Samma bild från båda hållen. Webben är öppen för alla, SSH bara för mig, resten stängt. Att en helt annan maskin når sidan men blir utelåst från SSH visar att regeln tittar på var trafiken kommer ifrån, inte bara vilken port det gäller.

![Novatrix kundtjänstsida i webbläsaren](images/novatrixform.png)

## 6. Nätverksskiss

![Nätverksdesign v36](images/natverksskiss-v36.png)

## 7. Resultat

| Trafik | Vad som händer |
|---|---|
| HTTP och HTTPS från internet mot webben | Släpps in |
| SSH från min IP `31.208.59.112` | Släpps in |
| SSH, RDP och allt annat från andra adresser | Stoppas |
| Internet mot det privata subnätet | Stoppas |
| Webben mot det privata subnätet på port 443 | Släpps in |

Kort sagt: 80 och 443 öppet för alla, 22 bara för mig, allt annat stängt, och lagringssubnätet helt utan väg in från internet.

## 8. Väl godkänt (VG)

Det jag tänker bygga vidare på, i `scripts/`:

- Hela nätet som kod med `az network`, så att det går att återskapa från repot utan att klicka
- Fler lager, till exempel en bastion i ett eget admin-subnät så att ingen server behöver ha SSH öppet mot internet alls
- En genomgång av vilka hot designen skyddar mot: portskanning mot en exponerad admin-port, att någon tar sig från webben vidare in mot lagringen, och att en kapad backend skickar ut data
