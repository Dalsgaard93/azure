
#########################################
### MUST BE ABLE TO RUN INDEPENDENTLY ###
#########################################

# Allow installing extensions without prompt:
# az config set extension.use_dynamic_install=yes_without_prompt

# If running old powershell, go to 7.3.2+
if($PSVersionTable.PSVersion.Major -lt  6) {pwsh}

# Variables
#$randomtal_dashes       = [guid]::NewGuid().toString()
#$randomtal_numberspacer = $randomtal_dashes.replace('-','4')
$unique_whoweare        = "rg-landingzone-businesscritical-adf-demo-"

$deployment_name            = $unique_whoweare + "-bddb_" + (Get-Date).ToLocalTime().ToString("yyyyMMddHHmmss")
# $rg_name                    = $unique_whoweare + "-rg-"   + (Get-Date).ToLocalTime().ToString("yyyyMMddHHmmss")
$rg_name                    = $unique_whoweare + (Get-Date).ToLocalTime().ToString("yyyyMMddHHmmss")
$bicep_file                 = $PSScriptRoot + "\" + "az_complete_template.bicep"
# $deployment_parameter_file  = "Deploy_DB_bicep_params.json"

$location_to_deploy = "westeurope"

Write-Output "deployment_name `t=`t`t $deployment_name"
Write-Output "rg_name `t`t=`t`t $rg_name"
Write-Output "bicep_file `t`t=`t`t $bicep_file"

# Generate Destroy-all script for this dynamic RG
#Write-Output "Delete the RG oneliner --> Run the file: delete_RG_$rg_name.bat"
#"az group delete --name $rg_name && del delete_RG_$rg_name.ps1" | Out-File -filepath "delete_RG_$rg_name.bat"

################################
############ Script ############
################################

# Recipe:
# V Create RG
# V Create Azure Storage Account
# V Create Databricks instance in RG
# V Create Azure Keyvault + secrets til Storage Account
# V Create ManagedIdentities for ADF access to AKV, Databricks
# V Create Azure Data Factory + Linkedservices
# Importer notebook i DB, der genererer stor table i Blob
# Importer notebook i DB, der kører komplekse queries

# Azure CLI still-working way

# Create RG
$location_to_deploy = az group create --name $rg_name --location $location_to_deploy

# Deploy
# Create Azure Storage Account
# Create Azure KeyVault
# Create Databricks instance in RG

az deployment group create `
  --name $deployment_name `
  --resource-group $rg_name `
  --template-file $bicep_file `

Write-Output '---------------------------------'
Write-Output '--------- Failure Logs ----------'
Write-Output '---------------------------------'

$FailureList = az deployment operation group list `
--resource-group $rg_name `
--name $deployment_name `
--query "[?properties.provisioningState=='Failed']"
Write-output 'Failed deployments:'
Write-output $FailureList

# Write-Output 'Go here in Incognito browser:'
# Write-Output 'https://portal.azure.com/#@raso42nc1outlook.onmicrosoft.com/resource/subscriptions/27ba9f4d-c0f6-4b5b-9442-d4af32d0bf3f/resourceGroups/$rg_name/overview'

# $deleteResourcePrompt = Read-Host -Prompt 'Would you like to delete the newly created resource group (y/n)?'
# if ($deleteResourcePrompt -eq 'y') {
#   az group delete -y --name $rg_name #&& Remove-Item delete_RG_$rg_name.ps1
#   Write-Output "Resource group $rg_name has been deleted"
# }


###############################
## End of Bicep
## Start of post-bicep deployment setup
###############################
