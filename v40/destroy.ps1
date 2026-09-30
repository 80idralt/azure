# River hela v40-miljön. Tar några minuter.
# Körs från valfri mapp, till exempel:  .\v40\destroy.ps1

$rgName = "rg-novatrix"

Write-Host "River $rgName..."
az group delete --name $rgName --yes
Write-Host "Klart! $rgName är borttagen."
