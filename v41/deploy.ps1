param(
    [string]$ResourceGroup = "rg-nordvik",
    [string]$Location = "swedencentral"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$flowUrl = Read-Host "Klistra in Power Automate-flodets HTTP-trigger-URL"

# flowUrl innehaller '&'-tecken som kommandoradsskalet (cmd.exe bakom az.cmd)
# felaktigt tolkar som kommandoavskiljare. Skriver darfor en tillfallig
# parameterfil istallet for att skicka vardet som text pa kommandoraden.
$parametrar = Get-Content "$scriptDir\templates\azuredeploy.parameters.json" -Raw | ConvertFrom-Json
$parametrar.parameters.flowUrl.value = $flowUrl
$parametrar.parameters.location.value = $Location
$tempParametrar = Join-Path $env:TEMP "nordvik-parametrar-tillfallig.json"
$parametrar | ConvertTo-Json -Depth 10 | Set-Content $tempParametrar

az group create --name $ResourceGroup --location $Location | Out-Null

az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "$scriptDir\templates\azuredeploy.json" `
    --parameters "@$tempParametrar"

Remove-Item $tempParametrar

$out = az deployment group show --resource-group $ResourceGroup --name azuredeploy --query properties.outputs -o json | ConvertFrom-Json

function Publish-UtanHalsokontroll($funcName, $mappsokvag) {
    # func-nordvik-arenden ar medvetet last for all trafik utom fran snet-app,
    # sa "func publish"-verktygets inbyggda halsokontroll fran den har datorn
    # kommer aldrig lyckas (det ar helt ofarligt, bara brus). Zip-deploy
    # gor sjalva kodleveransen utan att forsoka ringa upp appen efterat.
    $zipPath = Join-Path $env:TEMP "$funcName.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath }
    Compress-Archive -Path "$mappsokvag\*" -DestinationPath $zipPath -Force
    az functionapp deployment source config-zip --resource-group $ResourceGroup --name $funcName --src $zipPath --build-remote true
    Remove-Item $zipPath
}

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

Publish-UtanHalsokontroll $out.arendenFuncName.value "$scriptDir\arenden"
Publish-MedForsok $out.portalFuncName.value "$scriptDir\portal"

Write-Host ""
Write-Host "Klart. Portalen finns pa:" $out.portalUrl.value
