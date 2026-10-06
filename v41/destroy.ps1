param(
    [string]$ResourceGroup = "rg-nordvik"
)

az group delete --name $ResourceGroup
