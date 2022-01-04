@description('The name of the environment. This must be Development or Production.')
@allowed([
  'Development'
  'Production'
])
param environmentName string

@description('Azure AD Tenant ID.')
param aadTenantId string

@description('Deployment Service principal ID - used by AAD App Deployment Script')
param spId string

@description('Deployment Service principal secret - used by AAD App Deployment Script')
@secure()
param spPassword string

@description('Prefix to use when creating the resources in this deployment.')
param applicationNamePrefix string

@description('Azure AD Application Secret - used by the Function App External Authentication')
@secure()
param appPassword string

@description('Enable the additional Web App slot.')
@allowed([
  'Yes'
  'No'
])
param webSlotEnabled string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('MySQL server password')
@secure()
param databasePassword string

@description('Ghost container full image name and tag')
param ghostContainerName string = 'ghost:4.32.0-alpine'

@description('Azure Container registry name where the image is hosted')
param azureContainerRegistryName string = 'jacrtst01'

@description('Azure Container registry resource group')
param acrRgName string = 'j-acr-tst-01'

param baseTime string = utcNow('yyyy-MM-dd')

var environmentCode = environmentName == 'Production' ? 'prd' : 'dev'

var slotName = environmentName == 'Production' ? 'stg' : 'tst'

var containerRegistryUrl = 'https://${existingAzureContainerRegistry.properties.loginServer}' // Docker Hub example: 'https://index.docker.io/v1'
var containerImageReference = 'DOCKER|${existingAzureContainerRegistry.properties.loginServer}/${ghostContainerName}'

var webAppName = '${applicationNamePrefix}-web-${environmentCode}-${uniqueString(resourceGroup().id)}'
var appServicePlanName = '${applicationNamePrefix}-asp-${environmentCode}-${uniqueString(resourceGroup().id)}'

var functionName = '${applicationNamePrefix}-fa-${environmentCode}-${uniqueString(resourceGroup().id)}'
var faAppServicePlanName = '${applicationNamePrefix}-fa-asp-${environmentCode}-${uniqueString(resourceGroup().id)}'
var faResourceGroup = 'rg-${applicationNamePrefix}-fa-${environmentCode}'

var logAnalyticsWorkspaceName = '${applicationNamePrefix}-la-${environmentCode}-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = '${applicationNamePrefix}-ai-${environmentCode}-${uniqueString(resourceGroup().id)}'

var keyVaultName = '${take('${applicationNamePrefix}-kv-${environmentCode}-${uniqueString(resourceGroup().id)}', 24)}'

var storageAccountName = '${take('${applicationNamePrefix}sa${environmentCode}${uniqueString(resourceGroup().id)}', 24)}'
var slotStorageAccountName = '${take('${applicationNamePrefix}sa${slotName}${uniqueString(resourceGroup().id)}', 24)}'
var faStorageAccountName = '${take('${applicationNamePrefix}safa${uniqueString(resourceGroup().id)}', 24)}'

var mySQLServerName = '${applicationNamePrefix}-mysql-${environmentCode}-${uniqueString(resourceGroup().id)}'
var slotMySQLServerName = '${applicationNamePrefix}-mysql-${slotName}-${uniqueString(resourceGroup().id)}'
var databaseLogin = 'ghost'
var databaseName = 'ghost'

var ghostContentFileShareName = 'contentfiles'
var ghostContentFilesMountPath = '/var/lib/ghost/content_files'

var frontDoorName = '${applicationNamePrefix}-fd-${environmentCode}-${uniqueString(resourceGroup().id)}'
// var wafPolicyName = '${applicationNamePrefix}waf${uniqueString(resourceGroup().id)}'

var tags = {
  'owner': 'jozoslejko'
  'environment': environmentName
  'provisioned-by': 'bicep'
  'last-provisioned': baseTime
}

var slotEnabled = (webSlotEnabled == 'Yes') ? true : false

var servicePrincipalIds = concat(array(webAppUserAssignedIdentity.outputs.msiPrincipalId), array(slotWebAppUserAssignedIdentity.outputs.msiPrincipalId), array(function.outputs.faPrincipalId))

@description('Define the SKUs for each component based on the environment type.')
var environmentConfigurationMap = {
  Production: {
    environmentCode: 'prd'
    appServicePlan: {
      sku: {
        name: 'S1'
      }
    }
    storageAccount: {
      sku: {
        name: 'Standard_GRS'
      }
    }
    mySqlServer: {
      sku: {
        name: 'GP_Gen5_2'
      }
      backup: {
        geoRedundantBackup: 'Enabled'
      }
    }
    logAnalyticsWorkspace: {
      sku: {
        name: 'PerGB2018'
      }
    }
  }
  Development: {
    environmentCode: 'dev'
    appServicePlan: {
      sku: {
        name: 'S1'
      }
    }
    storageAccount: {
      sku: {
        name: 'Standard_LRS'
      }
    }
    mySqlServer: {
      sku: {
        name: 'B_Gen5_1'
      }
      backup: {
        geoRedundantBackup: 'Disabled'
      }
    }
    logAnalyticsWorkspace: {
      sku: {
        name: 'PerGB2018'
      }
    }
  }
}

resource existingAzureContainerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: azureContainerRegistryName
  scope: resourceGroup(acrRgName)
}

module webAppUserAssignedIdentity 'modules/userAssignedIdentity.bicep' = {
  name: 'webAppUserAssignedIdentityDeploy'
  params: {
    name: webAppName
    tags: tags
  }
}

module slotWebAppUserAssignedIdentity 'modules/userAssignedIdentity.bicep' = if (slotEnabled) {
  name: 'slotWebAppUserAssignedIdentityDeploy'
  params: {
    name: '${webAppName}-${slotName}'
    tags: tags
  }
}

module acrRoleAssignment 'modules/roleAssignment.bicep' = {
  name: 'acrRoleAssignmentDeploy'
  scope: resourceGroup(acrRgName)
  params: {
    principalId: webAppUserAssignedIdentity.outputs.msiPrincipalId
    roleDefinitionIdOrName: 'AcrPull'
    resourceGroupName: acrRgName
    principalType: 'ServicePrincipal'
  }
}

module slotAcrRoleAssignment 'modules/roleAssignment.bicep' = if (slotEnabled) {
  name: 'slotAcrRoleAssignmentDeploy'
  scope: resourceGroup(acrRgName)
  params: {
    principalId: slotWebAppUserAssignedIdentity.outputs.msiPrincipalId
    roleDefinitionIdOrName: 'AcrPull'
    resourceGroupName: acrRgName
    principalType: 'ServicePrincipal'
  }
}

module logAnalyticsWorkspace './modules/logAnalyticsWorkspace.bicep' = {
  name: 'logAnalyticsWorkspaceDeploy'
  params: {
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceSku: environmentConfigurationMap[environmentName].logAnalyticsWorkspace.sku.name
    location: location
  }
}

module storageAccount 'modules/storageAccount.bicep' = {
  name: 'storageAccountDeploy'
  params: {
    tags: tags
    storageAccountName: storageAccountName
    storageAccountSku: environmentConfigurationMap[environmentName].storageAccount.sku.name
    fileShareFolderName: ghostContentFileShareName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    location: location
  }
}

module slotStorageAccount 'modules/storageAccount.bicep' = if (slotEnabled) {
  name: 'slotStorageAccountDeploy'
  params: {
    tags: tags
    storageAccountName: slotStorageAccountName
    storageAccountSku: environmentConfigurationMap[environmentName].storageAccount.sku.name
    fileShareFolderName: ghostContentFileShareName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    location: location
  }
}

module keyVault './modules/keyVault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    tags: tags
    keyVaultName: keyVaultName
    databaseSecretName: 'databasePassword'
    databaseSecretValue: databasePassword // from Github Secrets
    faAdAppSecretName: 'functionAdAppPassword'
    faAdAppSecretValue: appPassword // from Github Secrets
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    servicePrincipalIds: servicePrincipalIds
    location: location
  }
}

module appServicePlan './modules/appServicePlan.bicep' = {
  name: 'appServicePlanDeploy'
  params: {
    tags: tags
    appServicePlanName: appServicePlanName
    appServicePlanSku: environmentConfigurationMap[environmentName].appServicePlan.sku.name
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module applicationInsights './modules/applicationInsights.bicep' = {
  name: 'applicationInsightsDeploy'
  params: {
    tags: tags
    applicationInsightsName: applicationInsightsName
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module webApp './modules/webApp.bicep' = {
  name: 'webAppDeploy'
  dependsOn: [
    acrRoleAssignment
    slotAcrRoleAssignment
  ]
  params: {
    tags: tags
    environment: environmentName
    slotEnabled: slotEnabled
    slotName: slotName
    webAppName: webAppName
    appServicePlanId: appServicePlan.outputs.id
    webUserAssignedIdentityId: webAppUserAssignedIdentity.outputs.msiResourceId
    acrUserManagedIdentityClientID: webAppUserAssignedIdentity.outputs.msiClientId
    slotWebUserAssignedIdentityId: slotEnabled ? slotWebAppUserAssignedIdentity.outputs.msiResourceId : ''
    slotAcrUserManagedIdentityClientID: slotEnabled ? slotWebAppUserAssignedIdentity.outputs.msiClientId : ''
    containerRegistryUrl: containerRegistryUrl
    containerImageReference: containerImageReference
    storageAccountName: storageAccount.outputs.name
    slotStorageAccountName: slotEnabled ? slotStorageAccount.outputs.name : ''
    fileShareName: ghostContentFileShareName
    containerMountPath: ghostContentFilesMountPath
    databaseHostFQDN: mySQLServer.outputs.fullyQualifiedDomainName
    slotDatabaseHostFQDN: slotMySQLServer.outputs.fullyQualifiedDomainName
    databaseLogin: '${databaseLogin}@${mySQLServer.outputs.name}'
    databasePasswordSecretUri: keyVault.outputs.databasePasswordSecretUri
    databaseName: databaseName
    siteUrl: 'https://${webAppName}.azurefd.net'
    slotSiteUrl: slotEnabled ? 'https://${webAppName}-${slotName}.azurefd.net' : ''
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

// module ghostWebAppSettings 'modules/ghostWebAppSettings.bicep' = {
//   name: 'ghostWebAppSettingsDeploy'
//   params: {
//     environment: environmentName
//     slotEnabled: slotEnabled
//     slotName: slotName
//     webAppName: webApp.outputs.webNames[0]
//     containerRegistryUrl: containerRegistryUrl
//     containerMountPath: ghostContentFilesMountPath
//     databaseHostFQDN: mySQLServer.outputs.fullyQualifiedDomainName
//     slotDatabaseHostFQDN: slotEnabled ? slotMySQLServer.outputs.fullyQualifiedDomainName : ''
//     databaseLogin: '${databaseLogin}@${mySQLServer.outputs.name}'
//     databasePasswordSecretUri: keyVault.outputs.databasePasswordSecretUri
//     databaseName: databaseName
//     // siteUrl: 'https://${frontDoorName}.azurefd.net'
//     // slotSiteUrl: slotEnabled ? 'https://${webApp.outputs.stagingHostName}' : ''
//     siteUrl: 'https://${frontDoor.outputs.frontDoorEndpointHostNames[0].endpointHostName}'
//     slotSiteUrl: slotEnabled ? 'https://${frontDoor.outputs.frontDoorEndpointHostNames[1].endpointHostName}' : ''
//   }
// }

module wgetWebApp 'modules/wget.bicep' = {
  name: 'wgetWebApp'
  params: {
    link: 'https://${webApp.outputs.hostNames[0]}'
  }
}

module wgetSlotWebApp 'modules/wget.bicep' = {
  name: 'wgetSlotWebApp'
  params: {
    link: 'https://${webApp.outputs.hostNames[1]}'
  }
}

module webAppSleep 'modules/sleep.bicep' = {
  name: 'webAppSleep'
  dependsOn: [
    wgetWebApp
    wgetSlotWebApp
  ]
  params: {
    time: '300'
  }
}

module allWebAppSettings 'modules/webAppSettings.bicep' = {
  name: 'allWebAppSettingsDeploy'
  dependsOn: [
    webAppSleep
  ]
  params: {
    environment: environmentName
    slotEnabled: slotEnabled
    slotName: slotName
    webAppName: webAppName
    applicationInsightsConnectionString: applicationInsights.outputs.ConnectionString
    applicationInsightsInstrumentationKey: applicationInsights.outputs.InstrumentationKey
    containerRegistryUrl: containerRegistryUrl
    containerMountPath: ghostContentFilesMountPath
    databaseHostFQDN: mySQLServer.outputs.fullyQualifiedDomainName
    slotDatabaseHostFQDN: slotEnabled ? slotMySQLServer.outputs.fullyQualifiedDomainName : ''
    databaseLogin: '${databaseLogin}@${mySQLServer.outputs.name}'
    databasePasswordSecretUri: keyVault.outputs.databasePasswordSecretUri
    databaseName: databaseName
    // siteUrl: 'https://${frontDoorName}.azurefd.net'
    // slotSiteUrl: slotEnabled ? 'https://${webApp.outputs.stagingHostName}' : ''
    // siteUrl: 'https://${frontDoor.outputs.frontDoorEndpointHostNames[0].endpointHostName}'
    // slotSiteUrl: slotEnabled ? 'https://${frontDoor.outputs.frontDoorEndpointHostNames[1].endpointHostName}' : ''
    siteUrl: 'https://${webAppName}.azurefd.net'
    slotSiteUrl: slotEnabled ? 'https://${webAppName}-${slotName}.azurefd.net' : ''
  }
}

module wgetWebApp2 'modules/wget.bicep' = {
  name: 'wgetWebApp2'
  dependsOn: [
    allWebAppSettings
  ]
  params: {
    link: 'https://${webApp.outputs.hostNames[0]}'
  }
}

module wgetSlotWebApp2 'modules/wget.bicep' = {
  name: 'wgetSlotWebApp2'
  dependsOn: [
    allWebAppSettings
  ]
  params: {
    link: 'https://${webApp.outputs.hostNames[1]}'
  }
}

module webAppSleep2 'modules/sleep.bicep' = {
  name: 'webAppSleep2'
  dependsOn: [
    wgetWebApp2
    wgetSlotWebApp2
  ]
  params: {
    time: '300'
  }
}

module mySQLServer 'modules/mySQLServer.bicep' = {
  name: 'mySQLServerDeploy'
  params: {
    tags: tags
    administratorLogin: databaseLogin
    administratorPassword: databasePassword
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    mySQLServerName: mySQLServerName
    mySQLServerSku: environmentConfigurationMap[environmentName].mySqlServer.sku.name
    geoRedundantBackup: environmentConfigurationMap[environmentName].mySqlServer.backup.geoRedundantBackup
  }
}

module slotMySQLServer 'modules/mySQLServer.bicep' = if (slotEnabled) {
  name: 'slotMySQLServerDeploy'
  params: {
    tags: tags
    administratorLogin: databaseLogin
    administratorPassword: databasePassword
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    mySQLServerName: slotMySQLServerName
    mySQLServerSku: environmentConfigurationMap[environmentName].mySqlServer.sku.name
    geoRedundantBackup: environmentConfigurationMap[environmentName].mySqlServer.backup.geoRedundantBackup
  }
}

// module frontDoor 'modules/frontDoor.bicep' = {
//   name: 'frontDoorDeploy'
//   params: {
//     tags: tags
//     frontDoorName: frontDoorName
//     wafPolicyName: wafPolicyName
//     logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
//     webAppName: webApp.outputs.name
//   }
// }

module frontDoor 'modules/fdStandard.bicep' = {
  name: 'frontDoorDeploy'
  dependsOn: [
    webAppSleep2
  ]
  params: {
    frontDoorName: frontDoorName
    webNames: webApp.outputs.webNames
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module webAppIpRestriction 'modules/webAppIpRestriction.bicep' = {
  name: 'webAppIpRestrictionDeploy'
  params: {
    frontDoorName: frontDoor.name
    slotEnabled: slotEnabled
    slotName: slotName
    webAppName: webAppName
  }
}

// Function app section start
///////////////////////////////////////////////////////

// App Service Plan
module faAppServicePlan './modules/appServicePlan.bicep' = {
  name: 'faAppServicePlanDeploy'
  scope: resourceGroup(faResourceGroup)
  params: {
    tags: tags
    appServicePlanName: faAppServicePlanName
    appServicePlanSku: 'Y1'
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

// Storage account
module faStorageAccount 'modules/faStorageAccount.bicep' = {
  name: 'faStorageAccountDeploy'
  scope: resourceGroup(faResourceGroup)
  params: {
    tags: tags
    storageAccountName: faStorageAccountName
    storageAccountSku: environmentConfigurationMap[environmentName].storageAccount.sku.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    location: location
  }
}

// Sleep
module sleep 'modules/sleep.bicep' = {
  name: 'faStorageAccountSleepDeploy'
  scope: resourceGroup(faResourceGroup)
  dependsOn: [
    faStorageAccount
  ]
  params: {
    time: '240'
  }
}

// Azure AD application for Function authentication
module faAzureadApp 'modules/aadApp.bicep' = {
  name: 'faAzureAdAppDeploy'
  params: {
    appPassword: appPassword
    siteName: functionName
    spId: spId
    spPassword: spPassword
    tenantId: aadTenantId
  }
}

// Function
module function './modules/functionApp.bicep' = {
  name: 'functionAppDeploy'
  scope: resourceGroup(faResourceGroup)
  dependsOn: [
    sleep
  ]
  params: {
    appId: faAzureadApp.outputs.applicationId
    tenantId: aadTenantId
    tags: tags
    functionAppName: functionName
    appServicePlanId: faAppServicePlan.outputs.id
    storageAccountName: faStorageAccount.outputs.name
    location: location
  }
}

// Function settings
module functionAppSettings './modules/functionAppSettings.bicep' = {
  name: 'functionAppSettingsDeploy'
  scope:resourceGroup(faResourceGroup)
  params: {
    functionAppName: function.outputs.name
    storageAccountName: faStorageAccount.outputs.name
    frontdoorHostName: frontDoor.outputs.frontDoorEndpointHostNames[0].endpointHostName
    appPasswordUri: keyVault.outputs.functionAppPasswordSecretUri
    applicationInsightsConnectionString: applicationInsights.outputs.ConnectionString
    applicationInsightsInstrumentationKey: applicationInsights.outputs.InstrumentationKey
  }
}

// Function app section end
///////////////////////////////////////////////////////////

// Outputs

output endpointHostName string = frontDoor.outputs.frontDoorEndpointHostNames[0].endpointHostName
output slotWebAppHostName string = slotEnabled ? frontDoor.outputs.frontDoorEndpointHostNames[1].endpointHostName : ''

output faName string = function.outputs.name
output faHostName string = function.outputs.hostName
