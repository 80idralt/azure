#!/usr/bin/env bash
#
# Lagringslagret för Novatrix v37 som kod: storage account, privat Blob-
# container, och den hanterade identiteten från v35 kopplad till webbservern
# med läsbehörighet på blob-data.
#
# Körs i Azure Cloud Shell (bash) eller lokalt efter "az login".

# Git Bash gör om /-argument till Windows-sökvägar. Raden stänger av det.
export MSYS_NO_PATHCONV=1

RG="${RG:-rg-novatrix-v34}"
LOC="swedencentral"
STORAGE="${STORAGE:-stnovatrixv37idr}"   # måste vara globalt unikt
CONTAINER="arenden"
VM="vm-novatrix-web"
APP_IDENTITY="id-novatrix-app"


# --- 1. Storage account: StorageV2, Standard, LRS, Hot, HTTPS, anonym av ---
az storage account create \
    --name "$STORAGE" --resource-group "$RG" --location "$LOC" \
    --sku Standard_LRS --kind StorageV2 --access-tier Hot \
    --https-only true --min-tls-version TLS1_2 \
    --allow-blob-public-access false


# --- 2. Container "arenden" för ärenden och bilagor, privat ---------------
az storage container create \
    --name "$CONTAINER" --account-name "$STORAGE" \
    --auth-mode login --public-access off


# --- 3. Häng id-novatrix-app på webbservern -----------------------------
APP_ID=$(az identity show -g "$RG" -n "$APP_IDENTITY" --query id -o tsv)
az vm identity assign --resource-group "$RG" --name "$VM" --identities "$APP_ID"


# --- 4. Läsbehörighet på blob-data för identiteten (scope = kontot) ------
# Dataroller är skilda från roller på kontot; Owner räcker inte. Skrivrätt
# läggs till när formuläret kopplas in.
APP_PRINCIPAL=$(az identity show -g "$RG" -n "$APP_IDENTITY" --query principalId -o tsv)
STORAGE_ID=$(az storage account show -g "$RG" -n "$STORAGE" --query id -o tsv)
az role assignment create \
    --assignee-object-id "$APP_PRINCIPAL" --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Reader" --scope "$STORAGE_ID"
