////////////////////////////////////////
///////////// Resource Group ///////////
////////////////////////////////////////

@description('Location for all resources.')
param location string = resourceGroup().location

//--------------------------- Virtual Networks

@description('CIDR range for the private subnet.')
param privateSubnetCidr string = '10.179.0.0/18'

@description('The name of the private subnet to create.')
param privateSubnetName string = 'private-subnet'

@description('CIDR range for the public subnet..')
param publicSubnetCidr string = '10.179.64.0/18'

@description('The name of the public subnet to create.')
param publicSubnetName string = 'public-subnet'

@description('CIDR range for the vnet.')
param vnetCidr string = '10.179.0.0/16'

@description('The name of the virtual network to create.')
param vnetName string = 'databricks-vnet'


/////////////////////////////////////////
////// Storage Account - ADLS Gen2 //////
/////////////////////////////////////////

param storageAccountName string = string('storacc4${uniqueString(resourceGroup().id)}')
param storageAccountNameBlobContainerName string = string('storeblobcont4${uniqueString(resourceGroup().id)}')
param storageAccountName_url string = 'https://${storageAccountName}.dfs.core.windows.net'

////////////////////////////////////////
///////////// Data Factory /////////////
////////////////////////////////////////

param dataFactoryUserManagedIdentityForKeyVault string = string('dataFacUserMI4${uniqueString(resourceGroup().id)}')
param dataFactoryName string = string('dataFac4${uniqueString(resourceGroup().id)}')
param AKV_baseUrl string = 'https://${keyVaultName}.vault.azure.net/'
var adf_Credential_AKV_name = 'ADF_Cred_for_AKV_LS'
var adf_Credential_Databricks_name = 'ADF_Cred_for_Databricks_LS'
var adf_LS_AKV = 'ADF_AKV_LS'
var adf_LS_Datalake = 'ADF_ADLS_Gen2_LS'
var adf_LS_Databricks = 'ADF_Databricks_LS'

////////////////////////////////////////
/////////////// Keyvault ///////////////
////////////////////////////////////////

@description('Specifies the name of the key vault.')
param keyVaultName string = string('keyvault-${uniqueString(resourceGroup().id)}')

// @description('Specifies whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.')
// // VMs can retrieve certificates
// param enabledForDeployment bool = true

// @description('Specifies whether Azure Disk Encryption is permitted to retrieve secrets from the vault and unwrap keys.')
// param enabledForDiskEncryption bool = true

// @description('Specifies whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
// // ARM can retrieve values
// param enabledForTemplateDeployment bool = true

@description('Specifies the permissions to keys in the vault. Valid values are: all, encrypt, decrypt, wrapKey, unwrapKey, sign, verify, get, list, create, update, import, delete, backup, restore, recover, and purge.')
param keysPermissions array = [
  'list', 'get', 'set'
]

@description('Specifies the permissions to secrets in the vault. Valid values are: all, get, list, set, delete, backup, restore, recover, and purge.')
param secretsPermissions array = [
  'list', 'get', 'set'
]


@description('Specifies the name of the secret:  Az Storage Account for the Data Lake')
param secretName_devdatalake string = 'DevDatalakeAccessKey'

////////////////////////////////////////
//////////// Databricks ////////////////
////////////////////////////////////////

@description('The name of the User Managed Identity to access Databricks.')
param dataBricksUserManagedIdentity string = string('dataBricksUserMI4${uniqueString(resourceGroup().id)}')

@description('Specifies whether to deploy Azure Databricks workspace with secure cluster connectivity (SCC) enabled or not (No Public IP)')
param disablePublicIp bool = false

@description('The name of the network security group to create.')
param nsgName string = 'databricks-nsg'

@description('The pricing tier of workspace.')
@allowed([
  'trial'
  'standard'
  'premium'
])
param databricks_pricingTier string = 'premium'

var managedResourceGroupName = 'databricks-rg-${databricks_workspaceName}'
var trimmedMRGName = substring(managedResourceGroupName, 0, min(length(managedResourceGroupName), 90))
var managed_databricks_RId = '${subscription().id}/resourceGroups/${trimmedMRGName}'

@description('The name of the Azure Databricks workspace to create.')
param databricks_workspaceName string = string('dbricks-${uniqueString(resourceGroup().id)}')


////////////////////////////////////////
/////////    Managed Identities ////////
////////////////////////////////////////



////////////////////////////////////////
/////////    STORAGE    ////////////////
////////////////////////////////////////

resource storageAccountRI 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_GRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    isHnsEnabled: true
  }
}

resource storageAccountRI_Blob 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  name: 'default'
  parent: storageAccountRI
  properties: {
    automaticSnapshotPolicyEnabled: false
    changeFeed: {
      enabled: false
      // retentionInDays: int
    }
    containerDeleteRetentionPolicy: {
      allowPermanentDelete: true
      // days: 7
      // enabled: false
    }
    //defaultServiceVersion: 'string'
    deleteRetentionPolicy: {
      allowPermanentDelete: true
      days: 7
      enabled: false
    }
    isVersioningEnabled: false
    restorePolicy: {
      days: 7
      enabled: false
    }
  }
}

resource storageAccountRI_Blob_Container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: storageAccountNameBlobContainerName
  parent: storageAccountRI_Blob
  properties: {
    //defaultEncryptionScope: null
    //denyEncryptionScopeOverride: falsey
    //enableNfsV3AllSquash: false
    //enableNfsV3RootSquash: false
    publicAccess: 'Blob'
  }
}

////////////////////////////////////////
/////////// DATA FACTORY ///////////////
////////////////////////////////////////

resource dataFactoryRI 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {//BUGFIX: Cannot be empty, known Azure deployment bug (2020+)
      '${dataFactoryManagedIdentityForKeyVaultRI.id}': {
      } /* ttk bug --> Just for info --> This CANNOT BE EMPTY */
      '${dataBricksUserManagedIdentityRI.id}': {
      } /* ttk bug --> Just for info --> This CANNOT BE EMPTY */
    }
  }
  properties: {
    globalParameters: {
      env: {
        type: 'string'
        value: 'test'
    }
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource adf_Credential_AKV_RI 'Microsoft.DataFactory/factories/credentials@2018-06-01' = {
  // parent: dataFactoryRI
  // Warning RASO: This Linter rule is BS and breaks the Bicep if used!
  // https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter-rule-use-parent-property
  name: '${dataFactoryRI.name}/${adf_Credential_AKV_name}'
  properties: {
    type: 'ManagedIdentity'
    typeProperties: {
      resourceId: dataFactoryManagedIdentityForKeyVaultRI.id
    }
  }
}

resource adf_Credential_Databricks_RI 'Microsoft.DataFactory/factories/credentials@2018-06-01' = {
  // parent: dataFactoryRI
  // Warning RASO: This Linter rule is BS and breaks the Bicep if used!
  // https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter-rule-use-parent-property
  name: '${dataFactoryRI.name}/${adf_Credential_Databricks_name}'
  properties: {
    type: 'ManagedIdentity'
    typeProperties: {
      resourceId: dataBricksUserManagedIdentityRI.id
    }
  }
}


resource adf_LinkedService_AKV_RI 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  // parent: dataFactoryRI
  // Warning RASO: This Linter rule is BS and breaks the Bicep if used!
  // https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter-rule-use-parent-property
  name: '${dataFactoryRI.name}/${adf_LS_AKV}'
  properties: {
    type: 'AzureKeyVault'
    typeProperties: {
      baseUrl: AKV_baseUrl
      credential: {
        referenceName: adf_Credential_AKV_name
        type: 'CredentialReference'
      }  
    }
  }
  dependsOn: [adf_Credential_AKV_RI]
}

resource adf_LinkedService_ADLS_Gen2_RI 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  // parent: dataFactoryRI
  // Warning RASO: This Linter rule is BS and breaks the Bicep if used!
  // https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter-rule-use-parent-property
  name: '${dataFactoryRI.name}/${adf_LS_Datalake}'
  properties: {
    annotations: []
    type: 'AzureBlobFS'
    typeProperties: {
      url: storageAccountName_url
      accountKey: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: 'ADF_AKV_LS'
          type: 'LinkedServiceReference'
        }
        secretName: 'DevDatalakeAccessKey'
      }
    }
  }
  dependsOn: [
    adf_LinkedService_AKV_RI
  ]
}


//ERROR: adb-8283046438390506.6.azuredatabricks.net URI not good, --> real: https://adb-8283046438390506.6.azuredatabricks.net/
//De er helt ens? ... er det skygge for mis-validering af cluster navn?
//FIXME
resource adf_LS_Databricks_RI 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  // parent: dataFactoryRI
  // Warning RASO: This Linter rule is BS and breaks the Bicep if used!
  // https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter-rule-use-parent-property
  name: '${dataFactoryRI.name}/${adf_LS_Databricks}'
  properties: {
    annotations: []
    type: 'AzureDatabricks'
    typeProperties: {//FIXME
      domain: databricks_workspace_RI.properties.workspaceUrl // 'https://adb-669668464853418.18.azuredatabricks.net'
      authentication: 'MSI'
      workspaceResourceId: databricks_workspace_RI.id //'/subscriptions/27ba9f4d-c0f6-4b5b-9442-d4af32d0bf3f/resourceGroups/kpmg-rg-20230815152653/providers/Microsoft.Databricks/workspaces/dbricks-34rxwkh5ew3pk'
      existingClusterId: '0816-144243-THISISNOTVERIFIEDATM'//'0816-144243-bm1lnn4v'
      credential: {
        referenceName: adf_Credential_Databricks_name
        type: 'CredentialReference'
      }
    }
  }
  // dependsOn: [
  //   adf_LinkedService_AKV_RI
  // ]
}

////////////////////////////////////////
/////////// KEY VAULT //////////////////
////////////////////////////////////////

param roleAssignmentKeyVaultHemmeligOfficerName string = string('roleAssignmentKeyVault${uniqueString(resourceGroup().id)}')

resource dataFactoryManagedIdentityForKeyVaultRI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: dataFactoryUserManagedIdentityForKeyVault
  location: location
}


@description('This is the built-in Key Vault Secrets Officer role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
resource keyVaultSecretOfficerRoleDefinitionRI 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: keyvaultRI
  name: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
}


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(roleAssignmentKeyVaultHemmeligOfficerName)
  properties: {
    roleDefinitionId: keyVaultSecretOfficerRoleDefinitionRI.id
    principalId: dataFactoryManagedIdentityForKeyVaultRI.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource keyvaultRI 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    publicNetworkAccess: 'enabled'
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        objectId: dataFactoryManagedIdentityForKeyVaultRI.properties.principalId
        //RASO: Isnt this decided by the KVSO role??
        permissions: {
          keys: []
          secrets: [ 'get', 'list', 'set', 'delete', 'backup', 'restore', 'recover' ]
          certificates: []
          storage: []
        }
        tenantId: tenant().tenantId
      }
    ]
    createMode: 'default'
    enabledForDeployment: true // VMs can retrieve certificates
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true // ARM can retrieve values
    enablePurgeProtection: true // Can ONLY be true?? .. So we set the retention down to the minimum
    softDeleteRetentionInDays: 7 // Minimum allowed
    enableRbacAuthorization: true // Should be false in prod (RBAC overrides KeyVault roles)
    enableSoftDelete: false // Should be true in prod
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Set the keys from Storage Account
resource secretADLSGen2 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyvaultRI
  name: secretName_devdatalake
  properties: {
    value: storageAccountRI.listKeys().keys[0].value
  }
}

// Set the keys from Storage Account
// resource secretDatabricksAccessToken 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyvaultRI
//   name: secretName_devdatalake
//   properties: {
//     value: databricks_workspace_RI.ACCOUNTKEY_SOMEHOW_GET_IT_DYNAMICALLY
//   }
// }

////////////////////////////////////////
//////// Network Security Group ////////
////////////////////////////////////////
/* NSG stuff below (Network Securtiy Group - Firewall stuff) */

// resource managedResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
//   scope: subscription()
//   name: trimmedMRGName
// }

// resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
//   location: location
//   name: nsgName
//   properties: {
//     securityRules: [
//       {
//         name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-worker-inbound'
//         properties: {
//           description: 'Required for worker nodes communication within a cluster.'
//           protocol: '*'
//           sourcePortRange: '*'
//           destinationPortRange: '*'
//           sourceAddressPrefix: 'VirtualNetwork'
//           destinationAddressPrefix: 'VirtualNetwork'
//           access: 'Allow'
//           priority: 100
//           direction: 'Inbound'
//         }
//       }
//       {
//         name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-databricks-webapp'
//         properties: {
//           description: 'Required for workers communication with Databricks Webapp.'
//           protocol: 'Tcp'
//           sourcePortRange: '*'
//           destinationPortRange: '443'
//           sourceAddressPrefix: 'VirtualNetwork'
//           destinationAddressPrefix: 'AzureDatabricks'
//           access: 'Allow'
//           priority: 100
//           direction: 'Outbound'
//         }
//       }
//       {
//         name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-sql'
//         properties: {
//           description: 'Required for workers communication with Azure SQL services.'
//           protocol: 'Tcp'
//           sourcePortRange: '*'
//           destinationPortRange: '3306'
//           sourceAddressPrefix: 'VirtualNetwork'
//           destinationAddressPrefix: 'Sql'
//           access: 'Allow'
//           priority: 101
//           direction: 'Outbound'
//         }
//       }
//       {
//         name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-storage'
//         properties: {
//           description: 'Required for workers communication with Azure Storage services.'
//           protocol: 'Tcp'
//           sourcePortRange: '*'
//           destinationPortRange: '443'
//           sourceAddressPrefix: 'VirtualNetwork'
//           destinationAddressPrefix: 'Storage'
//           access: 'Allow'
//           priority: 102
//           direction: 'Outbound'
//         }
//       }
//       {
//         name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-worker-outbound'
//         properties: {
//           description: 'Required for worker nodes communication within a cluster.'
//           protocol: '*'
//           sourcePortRange: '*'
//           destinationPortRange: '*'
//           sourceAddressPrefix: 'VirtualNetwork'
//           destinationAddressPrefix: 'VirtualNetwork'
//           access: 'Allow'
//           priority: 103
//           direction: 'Outbound'
//         }
//       }
//       {
//         name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-eventhub'
//         properties: {
//           description: 'Required for worker communication with Azure Eventhub services.'
//           protocol: 'Tcp'
//           sourcePortRange: '*'
//           destinationPortRange: '9093'
//           sourceAddressPrefix: 'VirtualNetwork'
//           destinationAddressPrefix: 'EventHub'
//           access: 'Allow'
//           priority: 104
//           direction: 'Outbound'
//         }
//       }
//     ]
//   }
// }

// resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
//   location: location
//   name: vnetName
//   properties: {
//     addressSpace: {
//       addressPrefixes: [
//         vnetCidr
//       ]
//     }
//     subnets: [
//       {
//         name: publicSubnetName
//         properties: {
//           addressPrefix: publicSubnetCidr
//           networkSecurityGroup: {
//             id: nsg.id
//           }
//           delegations: [
//             {
//               name: 'databricks-del-public'
//               properties: {
//                 serviceName: 'Microsoft.Databricks/workspaces'
//               }
//             }
//           ]
//         }
//       }
//       {
//         name: privateSubnetName
//         properties: {
//           addressPrefix: privateSubnetCidr
//           networkSecurityGroup: {
//             id: nsg.id
//           }
//           delegations: [
//             {
//               name: 'databricks-del-private'
//               properties: {
//                 serviceName: 'Microsoft.Databricks/workspaces'
//               }
//             }
//           ]
//         }
//       }
//     ]
//   }
// }


////////////////////////////////////////
////////////// Databricks //////////////
////////////////////////////////////////
/* Databricks Bicep settings */

param roleAssignmentContributorDBricksName string = string('roleAssignmentContributorDBricks${uniqueString(resourceGroup().id)}')

resource dataBricksUserManagedIdentityRI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: dataBricksUserManagedIdentity
  location: location
}

@description('This is the built-in Contributor role, but set for the Databricks workspace only. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
resource roleDefinition_Contributor_Databricks_RI 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: databricks_workspace_RI
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}



resource roleAssignment_MUI_Databricks_RI 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(roleAssignmentContributorDBricksName)
  properties: {
    roleDefinitionId: roleDefinition_Contributor_Databricks_RI.id
    principalId: dataBricksUserManagedIdentityRI.properties.principalId
    principalType: 'ServicePrincipal'
  }
}




//https://learn.microsoft.com/en-us/azure/templates/microsoft.databricks/2022-04-01-preview/workspaces?pivots=deployment-language-bicep
resource databricks_workspace_RI 'Microsoft.Databricks/workspaces@2023-02-01' = {
  name: databricks_workspaceName
  location: location
  sku: {
    name: databricks_pricingTier
  }
  // identity: {
  //   type: 'UserAssigned'
  //   userAssignedIdentities: {//BUGFIX: Cannot be empty, known Azure deployment bug (2020+)
  //     '${dataFactoryManagedIdentityForKeyVaultRI.id}': {
  //       // clientId: dataFactoryManagedIdentityForKeyVaultRI.properties.clientId
  //       // principalId: dataFactoryManagedIdentityForKeyVaultRI.properties.principalId
  //     } /* ttk bug --> Just for info --> This CANNOT BE EMPTY */
  //   }
  // }
  properties: {
    managedResourceGroupId: managed_databricks_RId
    // parameters: {
    //   customVirtualNetworkId: {
    //     value: vnet.id
    //   }
    //   customPublicSubnetName: {
    //     value: publicSubnetName
    //   }
    //   customPrivateSubnetName: {
    //     value: privateSubnetName
    //   }
    //   enableNoPublicIp: {
    //     value: disablePublicIp
    //   }
    // }
  }
}

output databricks_WorkspaceName string = databricks_workspaceName
output databricks_workspaceUrl string = databricks_workspace_RI.properties.workspaceUrl

//LS for the Databricks instance
// resource symbolicname 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
//   name: 'string'
//   parent: resourceSymbolicName
//   properties: {
//     annotations: [
//       any
//     ]
//     connectVia: {
//       parameters: {}
//       referenceName: 'string'
//       type: 'IntegrationRuntimeReference'
//     }
//     description: 'string'
//     parameters: {}
//     type: 'AzureDatabricks'
//     typeProperties: {
//       accessToken: {
//         type: 'string'
//         // For remaining properties, see SecretBase objects
//       }
//       authentication: any()
//       credential: {
//         referenceName: 'string'
//         type: 'CredentialReference'
//       }
//       domain: any()
//       encryptedCredential: any()
//       existingClusterId: any()
//       instancePoolId: any()
//       newClusterCustomTags: {}
//       newClusterDriverNodeType: any()
//       newClusterEnableElasticDisk: any()
//       newClusterInitScripts: any()
//       newClusterLogDestination: any()
//       newClusterNodeType: any()
//       newClusterNumOfWorker: any()
//       newClusterSparkConf: {}
//       newClusterSparkEnvVars: {}
//       newClusterVersion: any()
//       policyId: any()
//       workspaceResourceId: any()
//     }
//   }
// }


