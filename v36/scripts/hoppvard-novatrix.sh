#!/usr/bin/env bash
#
# Bygger hoppvärden för Novatrix v36 (VG-delen).
# Körs i Azure Cloud Shell (bash) eller lokalt med Azure CLI.
#
# Körs EFTER natverk-novatrix.sh. Skriptet förutsätter att vnet-novatrix-v36,
# snet-web, snet-db och nsg-web-v36 redan finns.
#
# Ordningen spelar roll: subnätet först, sedan säkerhetsgruppen och dess
# regler, sedan kopplingen mellan dem, och sist själva maskinen. Regeln på
# webben pekas om allra sist, när admin-subnätet finns att peka på.

# --- Värden att ändra vid behov --------------------------------------------
# RG går att sätta utifrån när skriptet körs, till exempel:
# RG=rg-novatrix-v36-test bash hoppvard-novatrix.sh
# Gör man inte det används rg-novatrix-v34.
RG="${RG:-rg-novatrix-v34}"
LOC="swedencentral"
VNET="vnet-novatrix-v36"

# Publik nyckel som redan når webbservern. Samma nyckel på hoppvärden gör
# att ett enda nyckelpar räcker hela vägen in.
SSH_KEY_PUB="${SSH_KEY_PUB:-$HOME/.ssh/id_rsa.pub}"
# ---------------------------------------------------------------------------


# --- 1. Admin-subnätet ----------------------------------------------------
# snet-admin, 10.0.3.0/24. Här står hoppvärden, och det här är enda stället
# i nätet med SSH öppet mot internet.

az network vnet subnet create \
    --resource-group "$RG" \
    --vnet-name "$VNET" \
    --name snet-admin \
    --address-prefixes 10.0.3.0/24


# --- 2. Skapa säkerhetsgruppen -------------------------------------------
# nsg-admin-v36

az network nsg create \
    --resource-group "$RG" \
    --name nsg-admin-v36 \
    --location "$LOC"


# --- 3. Regler i nsg-admin-v36 -----------------------------------------
# 100  Allow-SSh-Admin   22 från min publika IPv4
# 4096 Deny-All-Inbound  allt annat
#
# -4 tvingar IPv4. SSH går över v4, och ifconfig.me svarar ibland med en
# IPv6-adress som då gör regeln obrukbar.

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name nsg-admin-v36 \
    --name Allow-SSh-Admin \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes $(curl -s -4 ifconfig.me) \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 22

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name nsg-admin-v36 \
    --name Deny-All-Inbound \
    --priority 4096 \
    --direction Inbound \
    --access Deny \
    --protocol '*' \
    --source-address-prefixes '*' \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges '*'


# --- 4. Koppla säkerhetsgruppen till subnätet --------------------------
# nsg-admin-v36 -> snet-admin

az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$VNET" \
    --name snet-admin \
    --network-security-group nsg-admin-v36


# --- 5. Hoppvärden ------------------------------------------------------
# Standard_B2ats_v2 är minsta storleken i regionen, och den ska bara
# förmedla SSH. --nsg "" hindrar Azure från att lägga en egen NSG på
# nätverkskortet; skyddet ligger på subnätet, precis som för webben.
# On-demand: webben (2) + hoppvärden (2) fyller regionens kvot på 4 kärnor
# exakt, så miljön kan inte samexistera med en andra maskin.

az vm create \
    --resource-group "$RG" \
    --name vm-novatrix-jump \
    --location "$LOC" \
    --image Ubuntu2404 \
    --size Standard_B2ats_v2 \
    --admin-username azureuser-web \
    --ssh-key-values "$SSH_KEY_PUB" \
    --vnet-name "$VNET" \
    --subnet snet-admin \
    --nsg "" \
    --public-ip-sku Standard \
    --os-disk-name vm-novatrix-jump-osdisk


# --- 6. Peka om webbens SSH-regel ------------------------------------
# I G-delen nådde SSH webben direkt från min egen adress. Nu ska vägen in
# gå via hoppvärden, så källan i Allow-SSh blir admin-subnätet i stället.
# Webben har därmed ingen SSH-yta mot internet alls.

az network nsg rule update \
    --resource-group "$RG" \
    --nsg-name nsg-web-v36 \
    --name Allow-SSh \
    --source-address-prefixes 10.0.3.0/24
