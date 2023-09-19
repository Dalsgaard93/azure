#########################################
### MUST BE ABLE TO RUN INDEPENDENTLY ###
#########################################

# If running in the old powershell 5.0, go to 7.3.2+
if($PSVersionTable.PSVersion.Major -lt  6) {pwsh}

#####################################################
#### START OF MANUAL INPUT HERE: RG and LOCATION ####
#####################################################

$rg_name = "kpmg-rg-20230821091510"
$location_to_deploy = "westeurope"
$create_clusters = 0
##################################
#### END OF MANUAL INPUT HERE ####
##################################

# global Databricks application
# The resource name is fixed and never changes.
$global_Databricks_application = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"

$DATABRICKS_WORKSPACE = $(az databricks workspace list --resource-group "$rg_name" | jq .[0].name -r)
$DATABRICKS_HOST = $(az databricks workspace list --resource-group "$rg_name" | jq .[0].workspaceUrl -r)

$tenantId = $(az account show --query tenantId -o tsv)
$wsId = $(az resource show --resource-type Microsoft.Databricks/workspaces -g "$rg_name" -n "$DATABRICKS_WORKSPACE" --query id -o tsv)

Write-Output "wsId is $wsId"

# Get a token for the global Databricks application - OAuth2 token
# The resource name is fixed and never changes.
$token_response = $( az account get-access-token --resource $global_Databricks_application )
$global_Databricks_token = $( $token_response | jq .accessToken -r )
# Write-Output "global_Databricks_token (Used for OAuth2) is $global_Databricks_token"

# Get a token for the Azure management API - This is for changing stuff about the workspace in general
$token_response_for_management = $(az account get-access-token --resource https://management.core.windows.net/)
$azToken = $($token_response_for_management | jq .accessToken -r )
# Write-Output "azToken is $azToken"


# Generate Personal Access Token (PAT) for API calls. Quota limit of 600 tokens.
$api_response_for_create_token = $(curl --silent -f https://$location_to_deploy.azuredatabricks.net/api/2.0/token/create `
  -H "Authorization: Bearer $global_Databricks_token" `
  -H "X-Databricks-Azure-SP-Management-Token:$azToken" `
  -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" `
  -d '{ "lifetime_seconds": 3600, "comment": "this is an example token" }')

# Write-Output "api_response_for_create_token is $api_response_for_create_token"

$DATABRICKS_TOKEN = $( $api_response_for_create_token | jq .token_value -r )
Write-Output "DATABRICKS_TOKEN is $DATABRICKS_TOKEN"

# Now we can call the actual Databricks workspace to do actual stuff,

function Dbricks-CallWorkspace-API {
  param (
      $APIEntry,
      $APIMethod,
      $DataPayload
  )
  # $api_response_for_workspace_API_call = $(curl --silent -f --request GET "https://${DATABRICKS_HOST}/api/2.0/$APIEntry" `
  $api_response_for_workspace_API_call = $(curl --request $APIMethod "https://${DATABRICKS_HOST}/api/2.0/$APIEntry" `
    --header "Authorization: Bearer ${DATABRICKS_TOKEN}" `
    --data $DataPayload)
  return $api_response_for_workspace_API_call
  # Write-Output "api_response_for_workspace_API_call is $api_response_for_workspace_API_call"
}

# THESE ALREADY WORK, so disabled
if($create_clusters > 0) {
  $create_small_cluster_def = Dbricks-CallWorkspace-API -APIEntry "clusters/create" -APIMethod POST -DataPayload '{
      "num_workers": 1,
      "cluster_name": "1-node-for-small-tasks",
      "spark_version": "13.2.x-scala2.12",
      "spark_conf": {
          "spark.databricks.delta.preview.enabled": "true"
      },
      "azure_attributes": {
          "first_on_demand": 1,
          "availability": "ON_DEMAND_AZURE",
          "spot_bid_max_price": -1
      },
      "node_type_id": "Standard_DS3_v2",
      "driver_node_type_id": "Standard_DS3_v2",
      "ssh_public_keys": [],
      "custom_tags": {},
      "init_scripts": [],
      "spark_env_vars": {},
      "autotermination_minutes": 120,
      "enable_elastic_disk": true,
      "enable_local_disk_encryption": false,
      "runtime_engine": "STANDARD",
      "data_security_mode": "NONE"
  }'
  Write-Output "create_small_cluster_def = $create_small_cluster_def"

  $create_variable_large_cluster_def = Dbricks-CallWorkspace-API -APIEntry "clusters/create" -APIMethod POST -DataPayload '{
    "autoscale": {
      "min_workers": 2,
      "max_workers": 8
    },
    "cluster_name": "2-to-8-nodes-for-large-tasks",
    "spark_version": "13.2.x-scala2.12",
    "spark_conf": {
        "spark.databricks.delta.preview.enabled": "true"
    },
    "azure_attributes": {
        "first_on_demand": 1,
        "availability": "ON_DEMAND_AZURE",
        "spot_bid_max_price": -1
    },
    "node_type_id": "Standard_DS3_v2",
    "driver_node_type_id": "Standard_DS3_v2",
    "ssh_public_keys": [],
    "custom_tags": {},
    "init_scripts": [],
    "spark_env_vars": {},
    "autotermination_minutes": 120,
    "enable_elastic_disk": true,
    "enable_local_disk_encryption": false,
    "runtime_engine": "STANDARD",
    "data_security_mode": "NONE"
  }'
  Write-Output "create_variable_large_cluster_def = $create_variable_large_cluster_def"
}

$akv_res_id = $( az resource list -g "kpmg-rg-20230821091510" --resource-type "Microsoft.KeyVault/vaults" | jq -r .[0].id )
$akv_res_name_for_dns = $( az resource list -g "kpmg-rg-20230821091510" --resource-type "Microsoft.KeyVault/vaults" | jq -r .[0].name )
$akv_dns_url = "https://$akv_res_name_for_dns.vault.azure.net/"
Write-Output "akv_res_id = $akv_res_id"
Write-Output "akv_dns_url = $akv_dns_url"

<#
 RASO: Databricks WORK IN PROGRESS under this line ###########
 20230823: Create Secret Scope does not work, useraadtoken error, despite using PAT (Personal Access Token) to authenticate with admin rights(afaik)
 https://docs.databricks.com/api/azure/workspace/secrets/createscope
 https://learn.microsoft.com/en-us/azure/databricks/security/secrets/secret-scopes#akv-ss
 https://stackoverflow.com/questions/71414233/create-azure-key-vault-backed-secret-scope-in-databricks-with-aad-token
#>
$create_secret_scope_to_akv = Dbricks-CallWorkspace-API -APIEntry "secrets/scopes/create" -APIMethod POST -DataPayload '{
  "scope": "secret_scope_to_AKV",
  "initial_manage_principal": "users",
  "scope_backend_type": "AZURE_KEYVAULT",
  "backend_azure_keyvault": {
    "resource_id": "$akv_res_id",
    "dns_name": "$akv_dns_url"
  }
}'
Write-Output "create_secret_scope_to_akv = $create_secret_scope_to_akv"


####### RASO: Databricks WORK IN PROGRESS under this line ###########

# $db_kv_resource_id  = "/subscriptions/f5d4962d-de4e-4548-a35a-c1e871ed4d60/resourceGroups/raso-rg-e96be4904f3b4442424823540a7c0e0acbf3/providers/Microsoft.KeyVault/vaults/oxjpey53bq7po"
# $db_kv_dns_name     = "https://oxjpey53bq7po.vault.azure.net/"

# $env:DATABRICKS_HOST        = "https://adb-4306737301153954.14.azuredatabricks.net/"
# $env:DATABRICKS_TOKEN       = "dapi540f8745db521f6477b0bb802be029fb-2"
#https://learn.microsoft.com/en-us/powershell/module/az.accounts/get-azaccesstoken?view=azps-9.3.0
# $env:DATABRICKS_AAD_TOKEN   = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/").Token

#For later: 
# Write-Output "Generate Databricks token"
# $env:databricks_host                  = https://$(Write-Output "$arm_output" | jq -r '.properties.outputs.databricks_output.value.properties.workspaceUrl')
# $env:databricks_workspace_resource_id = $(Write-Output "$arm_output" | jq -r '.properties.outputs.databricks_id.value')
# $env:databricks_aad_token             = $(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --output json | jq -r .accessToken) # Databricks app global id

# This does not work currently, must do manually!
# AAD token cannot be supplied correctly to Databricks CLI at the moment
# https://stackoverflow.com/questions/71177834/azure-databricks-automation-databricks-cli-authentication-issue-aad-token

# databricks secrets create-scope --scope $dbscopename --scope-backend-type AZURE_KEYVAULT --resource-id $db_kv_resource_id --dns-name $db_kv_dns_name

# API does not work either - JWT signature does not match locally computed signature
# $Url = "${env:DATABRICKS_HOST}api/2.0/secrets/scopes/create"
# $Headers = @{
#   "Content-Type"                            = "application/json"
#   "Authorization"                           = "Bearer $env:databricks_aad_token"
#   "X-Databricks-Azure-SP-Management-Token"  = "$env:DATABRICKS_TOKEN"
# }
# $Body = @{
#   "scope"                     = "$dbscopename"
#   "scope_backend_type"        = "AZURE_KEYVAULT"
#   "backend_azure_keyvault"    =
#   @{
#     "resource_id"             = "$db_kv_resource_id"
#     "dns_name"                = "$db_kv_dns_name"
#   }
#   "initial_manage_principal"  = "users"

# }
# Invoke-RestMethod -Method 'Post' -Uri $url -Headers $Headers -Body $body

############################### End of DB Scope to Keyvault


###############################
## End of post-bicep deployment setup
###############################
