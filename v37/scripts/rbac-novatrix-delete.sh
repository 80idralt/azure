#!/bin/bash
#Novatrix - ta bort rolltilldelningarna - v35

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

#Ta bort tilldelningarna
az role assignment delete --assignee $DRIFT --role "Contributor" --scope $RG
az role assignment delete --assignee $UTV --role "Reader" --scope $RG
az role assignment delete --assignee $EKON --role "Cost Management Reader" --scope $RG
az role assignment delete --assignee $NAT --role "Network Contributor" --scope $RG
az role assignment delete --assignee $SUPP --role "Reader" --scope $RG
az role assignment delete --assignee $BACKUP --role "Backup Operator" --scope $RG
