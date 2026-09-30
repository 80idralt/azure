# Bygger hela v40-miljön från repot: mallen, funktionens kod och containerns image.
# Körs från valfri mapp, till exempel:  .\v40\deploy.ps1
# Kräver: Azure CLI (inloggad med az login), Azure Functions Core Tools v4, PowerShell 7.4+

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true   # stanna direkt om ett az-kommando misslyckas

$rgName   = "rg-novatrix"
$location = "swedencentral"
$imageTag = "1.2"

$mall      = Join-Path $PSScriptRoot "templates" "azuredeploy.json"
$parametrar = Join-Path $PSScriptRoot "templates" "azuredeploy.parameters.json"
$funktion  = Join-Path $PSScriptRoot "function"
$container = Join-Path $PSScriptRoot "container"

# --- 1. Bygga huset: allt utom containern -------------------------------
Write-Host "1/3 Bygger resurserna från mallen..."
az group create --name $rgName --location $location --output none
az deployment group create --resource-group $rgName `
  --template-file $mall `
  --parameters "@$parametrar" `
  --output none

$out = az deployment group show --resource-group $rgName --name azuredeploy `
  --query properties.outputs -o json | ConvertFrom-Json

# --- 2. Flytta in möblerna: funktionens kod och containerns image -------
Write-Host "2/3 Laddar upp funktionens kod och bygger imagen..."
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

az acr build --registry $out.acrName.value --image "novatrix-web:$imageTag" $container

# --- 3. Öppna dörren: samma mall igen, nu med containern ----------------
Write-Host "3/3 Startar containern..."
az deployment group create --resource-group $rgName `
  --template-file $mall `
  --parameters "@$parametrar" deployContainer=true imageTag=$imageTag `
  --output none

Write-Host "Klart! Surfa till: $($out.webUrl.value)"
