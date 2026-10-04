# Bygger hela 6B-miljön från repot: mallen, funktionens kod och Event Grid-kopplingen.
# Avslutas med ett testärende som ger ett mejl och ett Teams-kort.
# Förkrav: rg-novatrix-bot byggd med templates/bot.json och Teams-appen installerad i teamet.
# Körs från valfri mapp, till exempel:  .\6B\modul-1-handelsestyrt\deploy.ps1
# Kräver: Azure CLI (inloggad med az login), Azure Functions Core Tools v4, PowerShell 7.4+

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true   # stanna direkt om ett az-kommando misslyckas

$rgName   = "rg-novatrix-6b"
$location = "swedencentral"

$mall       = Join-Path $PSScriptRoot "templates" "azuredeploy.json"
$parametrar = Join-Path $PSScriptRoot "templates" "azuredeploy.parameters.json"
$eventgrid  = Join-Path $PSScriptRoot "templates" "eventgrid.json"
$funktion   = Join-Path $PSScriptRoot "novatrix-fn"

# --- 1. Bygga huset: lagring, tabell, mejltjänst, funktionens plats -----
Write-Host "1/4 Bygger resurserna från mallen..."
az group create --name $rgName --location $location --output none
az deployment group create --resource-group $rgName `
  --template-file $mall `
  --parameters "@$parametrar" `
  --output none

$out = az deployment group show --resource-group $rgName --name azuredeploy `
  --query properties.outputs -o json | ConvertFrom-Json

# --- 2. Flytta in koden ---------------------------------------------------
Write-Host "2/4 Laddar upp funktionens kod..."
Push-Location $funktion
try {
    for ($forsok = 1; $forsok -le 5; $forsok++) {
        try {
            func azure functionapp publish $out.funcName.value --python
            break
        }
        catch {
            if ($forsok -eq 5) { throw }
            Write-Host "Rollerna har inte slagit igenom än, väntar 60 sekunder (försök $forsok av 5)..."
            Start-Sleep -Seconds 60
        }
    }
}
finally {
    Pop-Location
}

# --- 3. Koppla ringklockan: lagringen säger till funktionen --------------
Write-Host "3/4 Kopplar Event Grid till funktionen..."
az deployment group create --resource-group $rgName `
  --template-file $eventgrid `
  --output none

# --- 4. Testärende --------------------------------------------------------
$id = "arende-test-" + (Get-Date -Format "yyyyMMdd-HHmmss")
Write-Host "4/4 Laddar upp testärendet $id..."
$fil = Join-Path ([System.IO.Path]::GetTempPath()) "$id.json"
@{
    id         = $id
    namn       = "Idris Test"
    epost      = "giremiramov@Altun1980.onmicrosoft.com"
    meddelande = "Testärende från deploy.ps1."
    skapat     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
} | ConvertTo-Json | Set-Content -Path $fil -Encoding utf8

az storage blob upload --account-name $out.storageName.value `
  --container-name arenden --name "$id/arende.json" `
  --file $fil --auth-mode key --overwrite --output none
Remove-Item $fil

Write-Host "Klart! Inom en minut ska ett mejl med ämnet 'Nytt ärende: $id' komma (kolla även skräpposten) och ett kort från Novatrix dyka upp i Teams-kanalen Kundtjänst."
Write-Host "Tabellen: lagringskontot $($out.storageName.value) -> Storage browser -> Tables -> arendelogg"
