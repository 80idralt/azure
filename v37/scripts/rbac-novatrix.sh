#!/bin/bash
#Novatrix rolltilldelningar som kod - v35

#Git Bash gör om sökvägar som börjar med / till Windows-sökvägar.
#Raden nedan stänger av det, så att --scope skickas oförändrat till Azure.
export MSYS_NO_PATHCONV=1

#Hämta id till variabler
RG=$(az group show --name rg-novatrix-v34 --query id -o tsv)

DRIFT=$(az ad group show --group "Azure-Drift" --query id -o tsv)
UTV=$(az ad group show --group "Azure-Utveckling" --query id -o tsv)
EKON=$(az ad group show --group "Azure-Ekonomi" --query id -o tsv)
NAT=$(az ad group show --group "Azure-Natverk" --query id -o tsv)
SUPP=$(az ad group show --group "Azure-Support" --query id -o tsv)
BACKUP=$(az ad group show --group "Azure-Backup" --query id -o tsv)

#Tilldela roll till gruppen Azure-Drift
az role assignment create --assignee $DRIFT --role "Contributor" --scope $RG

#Tilldela roll till gruppen Azure-Utveckling
az role assignment create --assignee $UTV --role "Reader" --scope $RG

#Tilldela roll till gruppen Azure-Ekonomi
az role assignment create --assignee $EKON --role "Cost Management Reader" --scope $RG

#Tilldela roll till gruppen Azure-Natverk
az role assignment create --assignee $NAT --role "Network Contributor" --scope $RG

#Tilldela roll till gruppen Azure-Support
az role assignment create --assignee $SUPP --role "Reader" --scope $RG

#Tilldela roll till gruppen Azure-Backup
az role assignment create --assignee $BACKUP --role "Backup Operator" --scope $RG
