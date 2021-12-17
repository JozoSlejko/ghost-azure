targetScope = 'resourceGroup'

@description('The name of the environment. This must be Development or Production.')
@allowed([
  'Development'
  'Production'
])
param environmentName string

@description('Prefix to use when creating the resources in this deployment.')
param applicationNamePrefix string = 'ghost'

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
param ghostContainerName string = 'ghost:4.29.0-alpine'

@description('Container registry where the image is hosted')
param containerRegistryUrl string = 'https://index.docker.io/v1'

param baseTime string = utcNow('yyyy-MM-dd')

var environmentCode = environmentName == 'Production' ? 'prd' : 'dev'

var slotName = environmentName == 'Production' ? 'stg' : 'tst'

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
var databaseLogin = 'ghost'
var databaseName = 'ghost'

var ghostContentFileShareName = 'contentfiles'
var ghostContentFilesMountPath = '/var/lib/ghost/content_files'

var siteUrl = 'https://${frontDoorName}.azurefd.net'

var frontDoorName = '${applicationNamePrefix}-fd-${environmentCode}-${uniqueString(resourceGroup().id)}'
var wafPolicyName = '${applicationNamePrefix}waf${uniqueString(resourceGroup().id)}'

var tags = {
  'owner': 'jozoslejko'
  'environment': environmentName
  'provisioned-by': 'bicep'
  'last-provisioned': baseTime
}

var slotEnabled = (webSlotEnabled == 'Yes') ? true : false

@description('Define the SKUs for each component based on the environment type.')
var environmentConfigurationMap = {
  Production: {
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
        name: 'GP_Gen5_4'
      }
    }
    logAnalyticsWorkspace: {
      sku: {
        name: 'PerGB2018'
      }
    }
  }
  Development: {
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
    }
    logAnalyticsWorkspace: {
      sku: {
        name: 'PerGB2018'
      }
    }
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

module slotStorageAccount 'modules/storageAccount.bicep' = if (slotEnabled == 'Yes') {
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
    keyVaultSecretName: 'databasePassword'
    keyVaultSecretValue: databasePassword
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    servicePrincipalIds: webApp.outputs.principalIds
    location: location
  }
}

module webApp './modules/webApp.bicep' = {
  name: 'webAppDeploy'
  params: {
    tags: tags
    slotEnabled: slotEnabled
    slotName: slotName
    webAppName: webAppName
    appServicePlanId: appServicePlan.outputs.id
    ghostContainerImage: ghostContainerName
    storageAccountName: storageAccount.outputs.name
    slotStorageAccountName: slotEnabled ? slotStorageAccount.outputs.name : ''
    fileShareName: ghostContentFileShareName
    containerMountPath: ghostContentFilesMountPath
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module webAppSettings 'modules/webAppSettings.bicep' = {
  name: 'webAppSettingsDeploy'
  params: {
    slotEnabled: slotEnabled
    slotName: slotName
    webAppName: webApp.outputs.name
    applicationInsightsConnectionString: applicationInsights.outputs.ConnectionString
    applicationInsightsInstrumentationKey: applicationInsights.outputs.InstrumentationKey
    containerRegistryUrl: containerRegistryUrl
    containerMountPath: ghostContentFilesMountPath
    databaseHostFQDN: mySQLServer.outputs.fullyQualifiedDomainName
    slotDatabaseHostFQDN: ''
    databaseLogin: '${databaseLogin}@${mySQLServer.outputs.name}'
    databasePasswordSecretUri: keyVault.outputs.databasePasswordSecretUri
    databaseName: databaseName
    siteUrl: siteUrl
    slotSiteUrl: webApp.outputs.stagingHostName
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
  }
}

module frontDoor 'modules/frontDoor.bicep' = {
  name: 'FrontDoorDeploy'
  params: {
    tags: tags
    frontDoorName: frontDoorName
    wafPolicyName: wafPolicyName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    webAppName: webApp.outputs.name
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


// Function
module function './modules/functionApp.bicep' = {
  name: 'functionAppDeploy'
  scope: resourceGroup(faResourceGroup)
  params: {
    tags: tags
    webAppName: functionName
    appInsightsIntrumentationKey: applicationInsights.outputs.InstrumentationKey
    appServicePlanId: faAppServicePlan.outputs.id
    storageAccountName: faStorageAccount.outputs.name
    location: location
    frontdoorHostName: frontDoor.outputs.frontendEndpointHostName
  }
}


// Function app section end
///////////////////////////////////////////////////////////

// Outputs

output webAppName string = webApp.outputs.name
output webAppPrincipalId string = webApp.outputs.principalId
output webAppHostName string = webApp.outputs.hostName
output endpointHostName string = frontDoor.outputs.frontendEndpointHostName
output faName string = function.outputs.name
