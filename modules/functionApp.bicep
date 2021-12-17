targetScope = 'resourceGroup'

param tags object = {}

@minLength(2)
@maxLength(60)
param webAppName string

param frontdoorHostName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('App Service Plan id to host the app')
param appServicePlanId string

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

@description('Storage account name to store Ghost content files')
param storageAccountName string

resource existingFaStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
}

resource function 'Microsoft.Web/sites@2021-01-15' = {
  name: webAppName
  kind: 'Functionapp'
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: 'applicationInsights.outputs.InstrumentationKey'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
            name: 'FUNCTIONS_WORKER_RUNTIME'
            value: 'node'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${existingFaStorageAccount.name};AccountKey=${listKeys(existingFaStorageAccount.id, existingFaStorageAccount.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${existingFaStorageAccount.name};AccountKey=${listKeys(existingFaStorageAccount.id, existingFaStorageAccount.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${toLower(webAppName)}files'
        }
        {
          name: 'GhostAdminApiKey'
          value: ''
        }
        {
          name: 'GhostApiUrl'
          value: frontdoorHostName
        }
      ]
      use32BitWorkerProcess: false
      linuxFxVersion: 'Node|16'
    }
  }
}

resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: function
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

output name string = function.name
output hostName string = function.properties.hostNames[0]
