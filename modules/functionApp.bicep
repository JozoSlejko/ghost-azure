@description('Azure AD Tenant ID.')
param tenantId string

@description('Azure AD Application ID.')
param appId string

@description('Azure AD Application Secret.')
@secure()
param appPassword string

param tags object = {}

@minLength(2)
@maxLength(60)
param webAppName string

param frontdoorHostName string

param appInsightsIntrumentationKey string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('App Service Plan id to host the function app')
param appServicePlanId string

@description('Storage account name for function')
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
          value: appInsightsIntrumentationKey
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
          value: 'DefaultEndpointsProtocol=https;AccountName=${existingFaStorageAccount.name};AccountKey=${listKeys(existingFaStorageAccount.id, existingFaStorageAccount.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${existingFaStorageAccount.name};AccountKey=${listKeys(existingFaStorageAccount.id, existingFaStorageAccount.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
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
          value: 'https://${frontdoorHostName}'
        }
        {
          name: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
          value: appPassword
        }
      ]
      use32BitWorkerProcess: false
      linuxFxVersion: 'Node|16'
    }
  }
}

resource authSettings 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: function
  name: 'authsettingsV2'    
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        isAutoProvisioned: false
        registration: {
          openIdIssuer: '${environment().authentication.loginEndpoint}${tenantId}/v2.0'
          clientId: appId
          clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
        }
        validation: {
          allowedAudiences: [
              'api://${appId}'
          ]
        }
      }
    }
  }       
}

output name string = function.name
output hostName string = function.properties.hostNames[0]
