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
Satte behörighet på SSH-nyckeln (endast min användare får läsa den) och kopplade upp mot servern.

```powershell
icacls .\vm-novatrix-web_key.pem /inheritance:r
icacls .\vm-novatrix-web_key.pem /grant:r "$($env:USERNAME):R"
ssh -i .\vm-novatrix-web_key.pem azureuser@<PUBLIK-IP>
```

Resultat: *(fylls i efter lyckad inloggning)*

### 3. Installera Nginx
*(fylls i)*

### 4. Driftsätt kundtjänstsidan
*(fylls i)*

### 5. Verifiering
*(fylls i)*

## Resultat


