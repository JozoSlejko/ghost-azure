@description('Name of the Function App.')
param functionAppName string

@description('Storage account name for function')
param storageAccountName string

@description('Front door hostname')
param frontdoorHostName string

@description('Azure AD Application Secret.')
param appPasswordUri string

@description('App Insights Key')
param applicationInsightsInstrumentationKey string

@description('App Insights Conn String')
param applicationInsightsConnectionString string

resource existingFunctionApp 'Microsoft.Web/sites@2020-09-01' existing = {
  name: functionAppName
}

resource existingFaStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
}

resource functionAppSettings 'Microsoft.Web/sites/config@2021-01-15' = {
  parent: existingFunctionApp
  name: 'appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsightsInstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsightsConnectionString
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'node'
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${existingFaStorageAccount.name};AccountKey=${listKeys(existingFaStorageAccount.id, existingFaStorageAccount.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${existingFaStorageAccount.name};AccountKey=${listKeys(existingFaStorageAccount.id, existingFaStorageAccount.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
    WEBSITE_CONTENTSHARE: '${toLower(functionAppName)}files'
    MICROSOFT_PROVIDER_AUTHENTICATION_SECRET: '@Microsoft.KeyVault(SecretUri=${appPasswordUri})'
    // Ghost-specific settings
    GhostAdminApiKey: 'placeholder'
    GhostApiUrl: 'https://${frontdoorHostName}'
  }
}
