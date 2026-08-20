# Uppgift V34 - Compute: driftsättning av Novatrix kundtjänst

**Repo:** https://github.com/80idralt/azure
**Namn:** Idris Altun
**Klass:** MOV25
**Datum:** 2026-08-20

## Syfte
Novatrix AB vill flytta sin kundtjänst till molnet. Den här veckan sätts en virtuell server upp i Azure och en enkel webbsida med ett ärendeformulär (namn, e-post, meddelande) driftsätts på den.

## Genomförande

### 1. Resursgrupp och VM
*(fylls i)*

### 2. Anslutning via SSH
Satte behörighet på SSH-nyckeln så att endast min användare kan läsa den. Första försöket gav felet `Bad permissions ... This private key will be ignored` eftersom grupper som `Autentiserade användare` fortfarande hade rättigheter kvar på filen. Löste det genom att nollställa behörigheterna helt innan de sattes om.

```powershell
icacls .\vm-novatrix-web_key.pem /reset
icacls .\vm-novatrix-web_key.pem /inheritance:r
icacls .\vm-novatrix-web_key.pem /grant:r "$($env:USERNAME):R"
icacls .\vm-novatrix-web_key.pem
```

```
.\vm-novatrix-web_key.pem IDRISDESKTOP\altun:(R)
```

Anslöt sedan till servern:

```powershell
ssh -i .\vm-novatrix-web_key.pem azureuser@51.12.242.137
```

Resultat: Inloggad som `azureuser` på `vm-novatrix-web` (Ubuntu 24.04.4 LTS), prompt `azureuser@vm-novatrix-web:~$`.

### 3. Installera Nginx
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

### 4. Driftsätt kundtjänstsidan
*(fylls i)*

### 5. Verifiering
*(fylls i)*

## Resultat


