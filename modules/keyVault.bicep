targetScope = 'resourceGroup'

param tags object = {}

@description('Key Vault name')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Secret name to store')
@minLength(1)
@maxLength(127)
param keyVaultSecretName string

@description('Secret value to store')
@secure()
param keyVaultSecretValue string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

@description('Service principal ID to provide access to the vault secrets')
param servicePrincipalIds array

var accessPolicies = [for servicePrincipal in servicePrincipalIds: {
  tenantId: subscription().tenantId
  objectId: servicePrincipal
  permissions: {
    secrets: [
      'get'
    ]
  }
}]

resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    accessPolicies: accessPolicies
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyVault
  name: keyVaultSecretName
  properties: {
    value: keyVaultSecretValue
  }
}

resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
  name: 'KeyVaultDiagnostics'
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
        category: 'AuditEvent'
        enabled: true
      }
    ]
  }
}

output databasePasswordSecretUri string = keyVaultSecret.properties.secretUri
