targetScope = 'resourceGroup'

param baseTime string = utcNow('yyyy-MM-dd')

@description('The name of the environment. This must be Development or Production.')
@allowed([
  'Development'
  'Production'
])
param environmentName string

@description('Prefix to use when creating the resources in this deployment.')
param applicationNamePrefix string = 'ghost'

@description('Enable the additional Web App slot.')
param slotEnabled bool

@description('App Service Plan pricing tier')
param appServicePlanSku string = 'S1'

@description('Log Analytics workspace pricing tier')
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('Storage account pricing tier')
param storageAccountSku string = 'Standard_LRS'

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('MySQL server SKU')
param mySQLServerSku string = 'B_Gen5_1'

@description('MySQL server password')
@secure()
param databasePassword string

@description('Ghost container full image name and tag')
param ghostContainerName string = 'ghost:4.29.0-alpine'

@description('Container registry where the image is hosted')
param containerRegistryUrl string = 'https://index.docker.io/v1'

var environmentCode = environmentName == 'Production' ? 'prd' : 'dev'

var slotName = environmentName == 'Production' ? 'stg' : 'tst'

var webAppName = '${applicationNamePrefix}-web-${environmentCode}-${uniqueString(resourceGroup().id)}'
var appServicePlanName = '${applicationNamePrefix}-asp-${environmentCode}-${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = '${applicationNamePrefix}-la-${environmentCode}-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = '${applicationNamePrefix}-ai-${environmentCode}-${uniqueString(resourceGroup().id)}'

var keyVaultName = '${take('${applicationNamePrefix}-kv-${environmentCode}-${uniqueString(resourceGroup().id)}', 24)}'

var storageAccountName = '${take('${applicationNamePrefix}sa${environmentCode}${uniqueString(resourceGroup().id)}', 24)}'
var slotStorageAccountName = '${take('${applicationNamePrefix}sa${slotName}${uniqueString(resourceGroup().id)}', 24)}'

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

module logAnalyticsWorkspace './modules/logAnalyticsWorkspace.bicep' = {
  name: 'logAnalyticsWorkspaceDeploy'
  params: {
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: location
  }
}

module storageAccount 'modules/storageAccount.bicep' = {
  name: 'storageAccountDeploy'
  params: {
    tags: tags
    storageAccountName: storageAccountName
    storageAccountSku: storageAccountSku
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
    storageAccountSku: storageAccountSku
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
    storageAccountAccessKey: storageAccount.outputs.accessKey
    slotStorageAccountName: slotStorageAccount.outputs.name
    slotStorageAccountAccessKey: slotStorageAccount.outputs.accessKey
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
    appServicePlanSku: appServicePlanSku
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
    mySQLServerSku: mySQLServerSku
  }
}

module frontDoor 'modules/frontDoor.bicep' = {
  name: 'FrontDoorDeploy'
  params: {
    tags: tags
    environmentName: environmentName
    frontDoorName: frontDoorName
    wafPolicyName: wafPolicyName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    webAppName: webApp.outputs.name
  }
}

output webAppName string = webApp.outputs.name
output webAppPrincipalId string = webApp.outputs.principalId
output webAppHostName string = webApp.outputs.hostName

var endpointHostName = frontDoor.outputs.frontendEndpointHostName

output endpointHostName string = endpointHostName
