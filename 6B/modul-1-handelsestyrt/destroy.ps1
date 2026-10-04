# River hela 6B-miljön. Tar några minuter.
# Körs från valfri mapp, till exempel:  .\6B\modul-1-handelsestyrt\destroy.ps1

$rgName = "rg-novatrix-6b"

Write-Host "River $rgName..."
az group delete --name $rgName --yes
Write-Host "Klart! $rgName är borttagen."
