#!/usr/bin/env bash
#
# Lagringslagret för Novatrix v37 som kod: storage account, privat Blob-
# container, den hanterade identiteten från v35 kopplad till webbservern
# med skrivbehörighet på containern, och en nätverksregel som låser kontot
# till webb-subnätet.
#
# Körs i Azure Cloud Shell (bash) eller lokalt efter "az login".
# Sätt ADMIN_IP till din publika IP eller ett litet intervall om du vill nå
# kontot från portalen efter att nätverksregeln slagits på, t.ex.:
#   ADMIN_IP=203.0.113.0/24 bash storage-novatrix.sh

# Git Bash gör om /-argument till Windows-sökvägar. Raden stänger av det.
export MSYS_NO_PATHCONV=1

RG="${RG:-rg-novatrix-v34}"
LOC="swedencentral"
STORAGE="${STORAGE:-stnovatrixv37idr}"   # måste vara globalt unikt
CONTAINER="arenden"
VNET="vnet-novatrix-v36"
SUBNET="snet-web"
VM="vm-novatrix-web"
APP_IDENTITY="id-novatrix-app"
ADMIN_IP="${ADMIN_IP:-}"


# --- 1. Storage account: StorageV2, Standard, LRS, Hot, HTTPS, anonym av ---
az storage account create \
    --name "$STORAGE" --resource-group "$RG" --location "$LOC" \
    --sku Standard_LRS --kind StorageV2 --access-tier Hot \
    --https-only true --min-tls-version TLS1_2 \
    --allow-blob-public-access false


# --- 2. Container "arenden" för ärenden och bilagor, privat ---------------
# --auth-mode login loggar in med Entra ID. Den som kör behöver en
# blob-dataroll på kontot, annars lägg till --account-key.
az storage container create \
    --name "$CONTAINER" --account-name "$STORAGE" \
    --auth-mode login --public-access off


# --- 3. Häng id-novatrix-app på webbservern -----------------------------
APP_ID=$(az identity show -g "$RG" -n "$APP_IDENTITY" --query id -o tsv)
az vm identity assign --resource-group "$RG" --name "$VM" --identities "$APP_ID"


# --- 4. Skrivbehörighet på containern för identiteten ------------------
# Dataroller är skilda från roller på kontot; Owner räcker inte. Contributor
# scopat till just containern: appen får skriva ärenden dit, inget annat.
APP_PRINCIPAL=$(az identity show -g "$RG" -n "$APP_IDENTITY" --query principalId -o tsv)
STORAGE_ID=$(az storage account show -g "$RG" -n "$STORAGE" --query id -o tsv)
az role assignment create \
    --assignee-object-id "$APP_PRINCIPAL" --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Contributor" \
    --scope "$STORAGE_ID/blobServices/default/containers/$CONTAINER"


# --- 5. Nätverksregel: lås kontot till webb-subnätet ------------------
# Service endpoint på snet-web, tillåt det subnätet (och ev. din admin-IP),
# neka allt annat. Lägg till det tillåtna först, sätt Neka sist.
az network vnet subnet update \
    --resource-group "$RG" --vnet-name "$VNET" --name "$SUBNET" \
    --service-endpoints Microsoft.Storage

az storage account network-rule add \
    --resource-group "$RG" --account-name "$STORAGE" \
    --vnet-name "$VNET" --subnet "$SUBNET"

if [ -n "$ADMIN_IP" ]; then
    az storage account network-rule add \
        --resource-group "$RG" --account-name "$STORAGE" \
        --ip-address "$ADMIN_IP"
fi

az storage account update \
    --name "$STORAGE" --resource-group "$RG" --default-action Deny
