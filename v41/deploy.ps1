$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$flowUrl = Read-Host "Klistra in Power Automate-flodets HTTP-trigger-URL"

az group create --name rg-nordvik --location swedencentral | Out-Null

az deployment group create `
    --resource-group rg-nordvik `
    --template-file "$scriptDir\templates\azuredeploy.json" `
    --parameters "@$scriptDir\templates\azuredeploy.parameters.json" `
    --parameters flowUrl=$flowUrl

$out = az deployment group show --resource-group rg-nordvik --name azuredeploy --query properties.outputs -o json | ConvertFrom-Json

function Publish-MedForsok($funcName, $mappsokvag) {
    Push-Location $mappsokvag
    for ($forsok = 1; $forsok -le 5; $forsok++) {
        try {
            func azure functionapp publish $funcName --python
            Pop-Location
            return
        }
        catch {
            if ($forsok -eq 5) { Pop-Location; throw }
            Write-Host "RBAC-rollerna har nog inte slagit igenom an, vantar 60 sekunder (forsok $forsok av 5)..."
            Start-Sleep -Seconds 60
        }
    }
}

Publish-MedForsok $out.arendenFuncName.value "$scriptDir\arenden"
Publish-MedForsok $out.portalFuncName.value "$scriptDir\portal"

Write-Host ""
Write-Host "Klart. Portalen finns pa:" $out.portalUrl.value
