#!/usr/bin/env bash
#
# Bygger nätverkslagret för Novatrix v36 från grunden.
# Körs i Azure Cloud Shell (bash) eller lokalt med Azure CLI.
#
# Ordningen spelar roll: nät och subnät först, sedan säkerhetsgrupper och
# regler, och allra sist kopplingen mellan NSG och subnät.

# --- Värden att ändra vid behov --------------------------------------------
# RG går att sätta utifrån när skriptet körs, till exempel:
# RG=rg-novatrix-v36-test bash natverk-novatrix.sh
# Gör man inte det används rg-novatrix-v34.
RG="${RG:-rg-novatrix-v34}"
LOC="swedencentral"
VNET="vnet-novatrix-v36"
# ---------------------------------------------------------------------------


# --- 1. Skapa VNet och första subnätet -------------------------------------
# vnet-novatrix-v36, 10.0.0.0/16, i swedencentral
# första subnätet: snet-web, 10.0.1.0/24

az network vnet create \
    --resource-group "$RG" \
    --name "$VNET" \
    --location "$LOC" \
    --address-prefixes 10.0.0.0/16 \
    --subnet-name snet-web \
    --subnet-prefixes 10.0.1.0/24


# --- 2. Skapa fler subnät ---------------------------------------------------
# snet-db, 10.0.2.0/24

az network vnet subnet create \
    --resource-group "$RG" \
    --vnet-name "$VNET" \
    --name snet-db \
    --address-prefixes 10.0.2.0/24


# --- 3. Skapa säkerhetsgrupperna --------------------------------------------
# nsg-web-v36 och nsg-db-v36

az network nsg create \
    --resource-group "$RG" \
    --name nsg-web-v36 \
    --location "$LOC"

az network nsg create \
    --resource-group "$RG" \
    --name nsg-db-v36 \
    --location "$LOC"


# --- 4. Regler i nsg-web-v36 ------------------------------------------------
# 100  Allow-Http-Https   80 och 443 från alla
# 200  Allow-SSh          22 från min publika IP
# 4096 Deny-All-Inbound   allt annat

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name nsg-web-v36 \
    --name Allow-Http-Https \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes '*' \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 80 443

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name nsg-web-v36 \
    --name Allow-SSh \
    --priority 200 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes $(curl -s ifconfig.me) \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 22

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name nsg-web-v36 \
    --name Deny-All-Inbound \
    --priority 4096 \
    --direction Inbound \
    --access Deny \
    --protocol '*' \
    --source-address-prefixes '*' \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges '*'


# --- 5. Regler i nsg-db-v36 -------------------------------------------------
# 100  Allow-Web-To-Storage  443 från 10.0.1.0/24
# 4096 Deny-All-Inbound      allt annat

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name nsg-db-v36 \
    --name Allow-Web-To-Storage \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes 10.0.1.0/24 \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 443

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name nsg-db-v36 \
    --name Deny-All-Inbound \
    --priority 4096 \
    --direction Inbound \
    --access Deny \
    --protocol '*' \
    --source-address-prefixes '*' \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges '*'


# --- 6. Koppla säkerhetsgrupperna till subnäten -----------------------------
# nsg-web-v36 -> snet-web
# nsg-db-v36  -> snet-db

az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$VNET" \
    --name snet-web \
    --network-security-group nsg-web-v36

az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$VNET" \
    --name snet-db \
    --network-security-group nsg-db-v36
