# Uppgift V34 - Compute: driftsättning av Novatrix kundtjänst

**Repo:** https://github.com/80idralt/azure/tree/master/v34  
**Namn:** Idris Altun  
**Klass:** MOV25  
**Datum:** 2026-08-24  

## Syfte
Novatrix AB vill flytta sin kundtjänst till molnet. Den här veckan sätts en virtuell server upp i Azure och en enkel webbsida med ett ärendeformulär (namn, e-post, meddelande) driftsätts på den.

---

## Manuellt Genomförande (Grundkoncept)
För att visa förståelse för molntjänsterna genomfördes uppgiften först manuellt.

### 1. Resursgrupp och VM
Skapade resursgruppen och den virtuella maskinen via Azure-portalens guide "Create a virtual machine".

- **Resursgrupp:** `rg-novatrix-v34`, region `swedencentral`
- **VM-namn:** `vm-novatrix-web`
- **Image:** Ubuntu Server 24.04 LTS (`canonical:ubuntu-24_04-lts:server`)
- **Storlek:** `Standard_B2ats_v2` billig burstable ARM-instans, vald med tanke på kostnad eftersom Novatrix inte behöver mer prestanda än så för en enkel kundtjänstsida.
- **Autentisering:** SSH-nyckelpar genererades av portalen, admin-användare `azureuser-web`.
- **Nätverk:** publikt IP `51.12.243.134`, nätverkssäkerhetsgrupp `vm-novatrix-web-nsg` med inkommande regler för SSH (port 22) och HTTP (port 80).

### 2. Cost management: budget och alerts
Satte upp en budget på resursgruppsnivå i Azure Portal för att hålla koll på förbrukningen mot startkrediten. Budgeten `bg-rg-novatrixvecka34` är satt till 100 SEK/månad för resursgruppen, med aktiva mailnotifieringar vid 50 % och 90 % av budgeten.

### 3. Anslutning via SSH
Satte behörighet på SSH-nyckeln så att endast min användare kan läsa den via `icacls`, och anslöt sedan till servern:

```powershell
ssh -i .\vm-novatrix-web-key.pem azureuser-web@51.12.243.134
```

### 4. Installera Nginx
Uppdaterade paketlistan och installerade webbservern Nginx.

```bash
sudo apt update
sudo apt install nginx -y
systemctl status nginx
```

Verifierade genom att surfa till serverns IP, där Nginx standardsida visades.

![Nginx välkomstsida](bilder/nginx-welkomstsida.png)

### 5. Driftsätt kundtjänstsidan
Skrev kundtjänstsidan (`public/index.html`) med rubrik och ärendeformulär lokalt, kopierade den till servern via `scp`, och flyttade den till Nginx webbrot med `sudo mv`.

*   **Responsiv design:** Sidan är anpassad för desktop och mobila enheter.
*   **Inbäddad CSS:** All styling hanteras i samma fil för att minimera antalet anrop.

### 6. Verifiering
Surfade till `http://51.12.243.134` och kontrollerade att Novatrix kundtjänstsida visas med ärendeformuläret (Ditt namn, Din E-post, Meddelande och knappen "Skicka ärende").

![Novatrix kundtjänstsida](bilder/Skarmbild185314.png)

---

## Utmaning för Väl godkänt (VG) - Infrastruktur som kod (IaC)

För att uppnå VG-kravet rev jag sedan ner miljön och byggde upp den helt från grunden med kod och automatisering (IaC), så hela lösningen kan återskapas från repot utan manuella steg i portalen.

Automatiseringen är byggd helt utan externa verktyg för att hålla nere komplexiteten, och använder sig exklusivt av Azure CLI-skript (PowerShell) och `cloud-init`.

### Konfigurationsfilerna (Filstruktur)

*   **`deploy.ps1`** - Huvudskriptet som skapar resursgruppen och provisionerar VM:en (`Standard_B2ats_v2`). Skriptet öppnar även port 80 och returnerar den genererade publika IP-adressen.
*   **`cloud-init.yaml`** - Skickas med som custom-data vid VM-skapandet. När servern startar kör den automatiskt paketuppdateringar, installerar Nginx och Git, klonar detta repo, och placerar webbsidan i `/var/www/html/`.
*   **`destroy.ps1`** - Städskript som med ett kommando raderar hela resursgruppen i bakgrunden (`--no-wait`). Möjliggör ett kostnadsmedvetet arbetssätt där miljön snabbt rivs ner när dagen är slut.

### Vad servern kör
Inga filer laddas upp från den lokala datorn under körning. Istället bygger min lokala dator infrastrukturen, varpå den nya servern automatiskt klonar källkoden (`80idralt/azure`) direkt från GitHub via instruktionerna i `cloud-init.yaml`. Eftersom servern hämtar koden från GitHub måste ändringar vara pushade innan driftsättning.

### Kommandon för att köra miljön

```powershell
az login       # Loggar in i Azure
./deploy.ps1   # Driftsätter hela miljön och returnerar IP-adressen
./destroy.ps1  # Raderar miljön i bakgrunden för att spara pengar
```

### Verifiering server

När `deploy.ps1` är färdigt tar det cirka en minut för `cloud-init` att installera Nginx och hämta koden, därefter finns Novatrix-sidan live och serveras dynamiskt från detta arkiv. Hela miljön kan därmed rivas och byggas om identiskt med ett enda kommando, utan ett enda klick i portalen.

Kontroll av tjänstens status på servern:

```bash
systemctl status nginx
``` 

**Terminalutskrift:**

```text
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-08-24 10:42:35 UTC; 4min 31s ago
       Docs: man:nginx(8)
    Process: 8497 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 8498 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 8500 (nginx)
      Tasks: 3 (limit: 1045)
     Memory: 2.3M (peak: 2.6M)
        CPU: 18ms
     CGroup: /system.slice/nginx.service
             ├─8500 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             ├─8501 "nginx: worker process"
             └─8502 "nginx: worker process"
```