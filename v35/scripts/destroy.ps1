$rgName = "rg-novatrix-v34"

Write-Host "=== Raderar Novatrix-miljön ===" -ForegroundColor Yellow
Write-Host "Detta kan ta några minuter, men kommandot körs i bakgrunden..."

# --yes bekräftar raderingen, --no-wait gör att terminalen inte låser sig
az group delete --name $rgName --yes --no-wait

Write-Host "Radering påbörjad! Du kan stänga terminalen. Pengarna är säkrade!" -ForegroundColor Green