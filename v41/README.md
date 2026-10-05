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

Följer kursens namnmönster typ-företag-syfte, t.ex. `rg-nordvik`, `vm-nordvik-web`, `vnet-nordvik`. Storage account: `stnordvik80idralt01` (typ + företag + användarnamn + löpnummer).
