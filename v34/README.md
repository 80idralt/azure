# Uppgift V34 - Compute: driftsättning av Novatrix kundtjänst

**Repo:** https://github.com/80idralt/azure/tree/master/v34

**Namn:** Idris Altun

**Klass:** MOV25

**Datum:** 2026-08-21

## Syfte
Novatrix AB vill flytta sin kundtjänst till molnet. Den här veckan sätts en virtuell server upp i Azure och en enkel webbsida med ett ärendeformulär (namn, e-post, meddelande) driftsätts på den.

## Genomförande

### 1. Resursgrupp och VM
Skapade resursgruppen och den virtuella maskinen via Azure-portalens guide "Create a virtual machine".

- **Resursgrupp:** `rg-novatrix-v34`, region `swedencentral`
- **VM-namn:** `vm-novatrix-web`
- **Image:** Ubuntu Server 24.04 LTS (`canonical:ubuntu-24_04-lts:server`)
- **Storlek:** `Standard_B2ats_v2` billig burstable ARM-instans, vald med tanke på kostnad eftersom Novatrix inte behöver mer prestanda än så för en enkel kundtjänstsida
- **Autentisering:** SSH-nyckelpar genererades av portalen under skapandet och laddades ner som `vm-novatrix-web-key.pem`, admin-användare `azureuser-web`
- **Nätverk:** publikt IP `51.12.243.134`, nätverkssäkerhetsgrupp `vm-novatrix-web-nsg` med inkommande regler för SSH (port 22) och HTTP (port 80)

Verifierade att resurserna skapats korrekt genom att gå igenom dem manuellt i Azure Portal:

- **Resursgrupper** → `rg-novatrix-v34` → status `Succeeded`, innehåller VM, disk, nätverkskort, publikt IP och nätverkssäkerhetsgrupp.
- **vm-novatrix-web** → Overview → Status: `Running`, Public IP address: `51.12.243.134`.
- **vm-novatrix-web-nsg** → Inbound security rules → `SSH` (port 22) och `nginx-allow-http` (port 80), båda `Allow`.

### 2. Cost management: budget och alerts
Satte upp en budget på resursgruppsnivå i Azure Portal (Cost Management) för att hålla koll på förbrukningen mot startkrediten.

Verifierade i Azure Portal under **Cost Management + Billing → Budgets** att budgeten `bg-rg-novatrixvecka34` visas med rätt belopp, omfattning och alert-trösklar:

| Fält | Värde |
|---|---|
| Budget | 100 SEK / månad |
| Omfattning | Resursgrupp `rg-novatrix-v34` |
| Period | 2026-08-01 – 2026-12-31 |
| Aktuell förbrukning | 0,0 SEK |
| Alert 1 | E-post vid **50 %** av budget (> 50 SEK) till `idrisaltun@hotmail.com` |
| Alert 2 | E-post vid **90 %** av budget (> 90 SEK) till `idrisaltun@hotmail.com` |

Budgeten `bg-rg-novatrixvecka34` är satt till 100 SEK/månad för resursgruppen `rg-novatrix-v34`, med två aktiva mailnotifieringar till `idrisaltun@hotmail.com`: vid 50 % och vid 90 % av budgeten. Aktuell förbrukning vid kontrolltillfället: 0,0 SEK.

### 3. Anslutning via SSH
Satte behörighet på SSH-nyckeln så att endast min användare kan läsa den. Första försöket gav felet `Bad permissions ... This private key will be ignored` eftersom grupper som `Autentiserade användare` fortfarande hade rättigheter kvar på filen. Löste det genom att nollställa behörigheterna helt innan de sattes om.

```powershell
icacls .\vm-novatrix-web-key.pem /reset
icacls .\vm-novatrix-web-key.pem /inheritance:r
icacls .\vm-novatrix-web-key.pem /grant:r "$($env:USERNAME):R"
icacls .\vm-novatrix-web-key.pem
```

```
.\vm-novatrix-web-key.pem IDRISDESKTOP\altun:(R)
```

Anslöt sedan till servern:

```powershell
ssh -i .\vm-novatrix-web-key.pem azureuser-web@51.12.243.134
```

Resultat: Inloggad som `azureuser-web` på `vm-novatrix-web` (Ubuntu 24.04.4 LTS), prompt `azureuser-web@vm-novatrix-web:~$`.

### 4. Installera Nginx
Uppdaterade paketlistan och installerade webbservern Nginx.

```bash
sudo apt update
sudo apt install nginx -y
systemctl status nginx
```

Resultat:

```
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-08-20 12:25:45 UTC; 12s ago
   Main PID: 8346 (nginx)
      Tasks: 3 (limit: 977)
```

Nginx körs och är aktiverat för att starta automatiskt vid omstart.

Verifierade genom att surfa till `http://51.12.243.134` i webbläsaren. Nginx standardsida ("Welcome to nginx!") visades direkt, vilket bekräftar att port 80 redan var öppen i nätverkssäkerhetsgruppen och att webbservern svarar.

![Nginx välkomstsida](images/nginx-welkomstsida.png)

### 5. Driftsätt kundtjänstsidan
Skrev kundtjänstsidan (`public/index.html`) med rubrik och ärendeformulär (namn, e-post, meddelande) lokalt, och kopierade sedan filen till servern via `scp`. Flyttade den därefter till Nginx webbrot med `sudo mv`.

```powershell
scp -i E:\MOV25\Uppgifter\Azure\vm-novatrix-web-key.pem -r E:\MOV25\GitHub\azure\v34\public\* azureuser-web@51.12.243.134:~/
ssh -i E:\MOV25\Uppgifter\Azure\vm-novatrix-web-key.pem azureuser-web@51.12.243.134 "sudo mv ~/index.html /var/www/html/"
```

Resultat: `index.html` flyttad till `/var/www/html/` på servern och ersatte Nginx standardsida.

### 6. Verifiering
Surfade till `http://51.12.243.134` och kontrollerade att Novatrix kundtjänstsida visas med ärendeformuläret (fälten Ditt namn, Din E-post och Meddelande, samt knappen "Skicka ärende").

![Novatrix kundtjänstsida med ärendeformulär](images/Skarmbild185314.png)

## Resultat
En Ubuntu-VM (`vm-novatrix-web`) kör Nginx och serverar Novatrix kundtjänstsida med ärendeformulär, nåbar på `http://51.12.243.134`. Koden och dokumentationen ligger versionshanterade i detta repo.
## Utmaning för Väl godkänt (VG)
Istället för att klicka sig fram servern i portalen (Azure), är det tänkt att hela miljön ska kunna automatiseras, dvs. att allt sätts upp från kod. Detta är beskrivningen för hur det gjordes.
