targetScope = 'resourceGroup'

param tags object = {}

@description('Enable the additional Web App slot.')
param slotEnabled bool

@minLength(2)
@maxLength(60)
param webAppName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('App Service Plan id to host the app')
param appServicePlanId string

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

@description('Ghost container full image name and tag')
param ghostContainerImage string

@description('Storage account name to store Ghost content files')
param storageAccountName string

@description('Storage account name to store Staging Ghost content files')
param slotStorageAccountName string = ''

@description('File share name on the storage account to store Ghost content files')
param fileShareName string

@description('Path to mount the file share in the container')
param containerMountPath string

param slotName string

var containerImageReference = 'DOCKER|${ghostContainerImage}'

var storageAccountAccessKey = listKeys(existingStorageAccount.id, existingStorageAccount.apiVersion).keys[0].value

var slotStorageAccountAccessKey = slotEnabled ? listKeys(existingSlotStorageAccount.id, existingSlotStorageAccount.apiVersion).keys[0].value : ''

resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
}

resource existingSlotStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = if (slotEnabled) {
  name: slotStorageAccountName
}

resource webApp 'Microsoft.Web/sites@2021-01-15' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    clientAffinityEnabled: false
    serverFarmId: appServicePlanId
    httpsOnly: true
    enabled: true
    reserved: true
    siteConfig: {
      http20Enabled: true
      httpLoggingEnabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      linuxFxVersion: containerImageReference
      alwaysOn: true
      use32BitWorkerProcess: false
      azureStorageAccounts: {
        ContentFilesVolume: {
          type: 'AzureFiles'
          accountName: storageAccountName
          shareName: fileShareName
          mountPath: containerMountPath
          accessKey: storageAccountAccessKey
        }
      }
    }
  }
}

resource siteConfig 'Microsoft.Web/sites/config@2021-01-15' = {
  parent: webApp
  name: 'web'
  properties: {
    ipSecurityRestrictions: [
      {
        ipAddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        tag: 'ServiceTag'
        priority: 300
        name: 'Access from Azure Front Door'
        description: 'Rule for access from Azure Front Door'
      }
    ]
  }
}

resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: webApp
  name: 'WebAppDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
  }
}

resource webAppStaging 'Microsoft.Web/sites/slots@2021-02-01' = if (slotEnabled) {
  parent: webApp
  name: slotName
  location: location
  tags: tags
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    clientAffinityEnabled: false
    serverFarmId: appServicePlanId
    httpsOnly: true
    enabled: true
    reserved: true
    siteConfig: {
      http20Enabled: true
      httpLoggingEnabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      linuxFxVersion: containerImageReference
      alwaysOn: true
      use32BitWorkerProcess: false
      azureStorageAccounts: {
        ContentFilesVolume: {
          type: 'AzureFiles'
          accountName: slotStorageAccountName
          shareName: fileShareName
          mountPath: containerMountPath
          accessKey: slotStorageAccountAccessKey
        }
      }
    }
  }
}

resource slotConfig 'Microsoft.Web/sites/slots/config@2021-02-01' = if (slotEnabled) {
  parent: webAppStaging
  name: 'web'
  properties: {
    ipSecurityRestrictions: [
      {
        ipAddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        tag: 'ServiceTag'
        priority: 300
        name: 'Access from Azure Front Door'
        description: 'Rule for access from Azure Front Door'
      }
    ]
  }
}

resource stgWebAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (slotEnabled) {
  scope: webAppStaging
  name: 'WebAppDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
  }
}

output name string = webApp.name
output hostName string = webApp.properties.hostNames[0]
output principalId string = webApp.identity.principalId

output stagingName string = slotEnabled ? webAppStaging.name : ''
output stagingHostName string = slotEnabled ? webAppStaging.properties.hostNames[0] : ''
output stagingPrincipalId string = slotEnabled ? webAppStaging.identity.principalId : ''

output principalIds array = slotEnabled ? concat(array(webApp.identity.principalId), array(webAppStaging.identity.principalId)) : array(webApp.identity.principalId)
