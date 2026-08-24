$rgName     = "rg-novatrix-v34"
$location   = "swedencentral"
$vmName     = "vm-novatrix-web"
$adminUser  = "azureuser-web"
$cloudInit  = "./cloud-init.yaml"

az group create --name $rgName --location $location

az vm create `
  --resource-group $rgName `
  --name $vmName `
  --image Ubuntu2404 `
  --admin-username $adminUser `
  --custom-data $cloudInit `
  --size Standard_B2ats_v2 `
  --os-disk-name "$vmName-osdisk" `
  --generate-ssh-keys `
  --public-ip-sku Standard

az vm open-port --resource-group $rgName --name $vmName --port 80 --priority 100

$publicIp = az vm show -d -g $rgName -n $vmName --query publicIps -o tsv
Write-Host "Klart! Surfa till: http://$publicIp"