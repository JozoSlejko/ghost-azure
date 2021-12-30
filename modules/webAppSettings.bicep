targetScope = 'resourceGroup'

@description('Enable the additional Web App slot.')
param slotEnabled bool

param slotName string

param webAppName string

param applicationInsightsInstrumentationKey string

param applicationInsightsConnectionString string

@description('MySQL server hostname')
param databaseHostFQDN string

@description('Ghost datbase name')
param databaseName string

@description('Ghost database user name')
param databaseLogin string

@description('Ghost database user password')
param databasePasswordSecretUri string

@description('Slot MySQL server hostname')
param slotDatabaseHostFQDN string

@description('Website URL to autogenerate links by Ghost')
param siteUrl string

@description('Staging Website URL to autogenerate links by Ghost')
param slotSiteUrl string

@description('Mount path for Ghost content files')
param containerMountPath string

@description('Container registry to pull Ghost docker image')
param containerRegistryUrl string

resource existingWebApp 'Microsoft.Web/sites@2020-09-01' existing = {
  name: webAppName
}

resource existingSlotWebApp 'Microsoft.Web/sites/slots@2021-02-01' existing = if (slotEnabled) {
  name: '${webAppName}/${slotName}'
}

resource webAppSettings 'Microsoft.Web/sites/config@2021-01-15' = {
  parent: existingWebApp
  name: 'appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsightsInstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsightsConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    XDT_MicrosoftApplicationInsights_Mode: 'default'
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
    DOCKER_REGISTRY_SERVER_URL: containerRegistryUrl
    // Ghost-specific settings
    NODE_ENV: 'production'
    GHOST_CONTENT: containerMountPath
    paths__contentPath: containerMountPath
    privacy_useUpdateCheck: 'false'
    url: siteUrl
    database__client: 'mysql'
    database__connection__host: databaseHostFQDN
    database__connection__user: databaseLogin
    database__connection__password: '@Microsoft.KeyVault(SecretUri=${databasePasswordSecretUri})'
    database__connection__database: databaseName
    database__connection__ssl: 'true'
    database__connection__ssl_minVersion: 'TLSv1.2'
  }
}

resource slotWebAppSettings 'Microsoft.Web/sites/slots/config@2021-02-01' = if (slotEnabled) {
  parent: existingSlotWebApp
  name: 'appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsightsInstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsightsConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    XDT_MicrosoftApplicationInsights_Mode: 'default'
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
    DOCKER_REGISTRY_SERVER_URL: containerRegistryUrl
    // Ghost-specific settings
    NODE_ENV: 'staging'
    GHOST_CONTENT: containerMountPath
    paths__contentPath: containerMountPath
    privacy_useUpdateCheck: 'false'
    url: slotSiteUrl
    database__client: 'mysql'
    database__connection__host: slotDatabaseHostFQDN
    database__connection__user: databaseLogin
    database__connection__password: '@Microsoft.KeyVault(SecretUri=${databasePasswordSecretUri})'
    database__connection__database: databaseName
    database__connection__ssl: 'true'
    database__connection__ssl_minVersion: 'TLSv1.2'
  }
}
