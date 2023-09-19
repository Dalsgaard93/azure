
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
$unique_whoweare        = "kpmg"

$deployment_name            = $unique_whoweare + "-bddb_" + (Get-Date).ToLocalTime().ToString("yyyyMMddHHmmss")
$rg_name                    = $unique_whoweare + "-rg-"   + (Get-Date).ToLocalTime().ToString("yyyyMMddHHmmss")
$bicep_file                 = $PSScriptRoot + "\" + "az_databricks_complete_template.bicep"
# $deployment_parameter_file  = "Deploy_DB_bicep_params.json"

$location_to_deploy = "westeurope"

Write-Output "deployment_name `t=`t`t $deployment_name"
Write-Output "rg_name `t`t=`t`t $rg_name"
Write-Output "bicep_file `t`t=`t`t $bicep_file"

# Post-bicep deployment variables
# $dbscopename = "Azure_Scope"


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
  #--parameters resourceNamePrefix=kpmg


Write-Output '---------------------------------'
Write-Output '--------- Failure Logs ----------'
Write-Output '---------------------------------'

$FailureList = az deployment operation group list `
--resource-group $rg_name `
--name $deployment_name `
--query "[?properties.provisioningState=='Failed']"
Write-output 'Failed deployments:'
Write-output $FailureList

Write-Output 'Go here in Incognito browser:'
Write-Output 'https://portal.azure.com/#@raso42nc1outlook.onmicrosoft.com/resource/subscriptions/27ba9f4d-c0f6-4b5b-9442-d4af32d0bf3f/resourceGroups/$rg_name/overview'

# $deleteResourcePrompt = Read-Host -Prompt 'Would you like to delete the newly created resource group (y/n)?'
# if ($deleteResourcePrompt -eq 'y') {
#   az group delete -y --name $rg_name #&& Remove-Item delete_RG_$rg_name.ps1
#   Write-Output "Resource group $rg_name has been deleted"
# }


###############################
## End of Bicep
## Start of post-bicep deployment setup
###############################

# Src for this
# https://cloudarchitected.com/2020/01/using-azure-ad-with-the-azure-databricks-api/

# Get Databricks name instance - Requires there to just be ONE workspace
$DATABRICKS_WORKSPACE = $(az databricks workspace list --resource-group "$rg_name" | jq .[0].name -r)

$tenantId = $(az account show --query tenantId -o tsv)
$wsId = $(az resource show --resource-type Microsoft.Databricks/workspaces -g "$rg_name" -n "$DATABRICKS_WORKSPACE" --query id -o tsv)

# Write-Output "wsId is $wsId"

# Get a token for the global Databricks application - OAuth2 token
# The resource name is fixed and never changes.
$token_response = $(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d)
$token = $( $token_response | jq .accessToken -r )
# Write-Output "token is $token"

# Get a token for the Azure management API - This is for changing stuff about the workspace in general
$token_response_for_management = $(az account get-access-token --resource https://management.core.windows.net/)
$azToken = $($token_response_for_management | jq .accessToken -r )
# Write-Output "azToken is $azToken"


# Generate Personal Access Token for API calls. Quota limit of 600 tokens.
$api_response_for_create_token = $(curl -sf https://$location_to_deploy.azuredatabricks.net/api/2.0/token/create `
  -H "Authorization: Bearer $token" `
  -H "X-Databricks-Azure-SP-Management-Token:$azToken" `
  -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" `
  -d '{ "lifetime_seconds": 3600, "comment": "this is an example token" }')

# Write-Output "api_response_for_create_token is $api_response_for_create_token"

$DATABRICKS_TOKEN = $( $api_response_for_create_token | jq .token_value -r )
Write-Output "DATABRICKS_TOKEN is $DATABRICKS_TOKEN"

# Now we can call the actual Databricks workspace to do actual stuff,



# # Test: Get list of clusters (Empty)
# $api_response_for_list_clusters = $(curl -sf https://westeurope.azuredatabricks.net/api/2.0/clusters/list `
#   -H "Authorization: Bearer $token" `
#   -H "X-Databricks-Azure-SP-Management-Token:$azToken" `
#   -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId")

# # Write-Output "api_response_for_list_clusters is $api_response_for_list_clusters"
