@description('Azure AD Tenant ID.')
param tenantId string

@description('Service Principal ID.')
param spId string

@description('Service Principal Secret.')
@secure()
param spPassword string

@description('Site name.')
param siteName string

@description('Azure AD Application Secret.')
@secure()
param appPassword string

@description('forceUpdateTag property, used to force the execution of the script resource when no other properties have changed.')
param utcValue string = utcNow()

var deploymentScriptContent = loadTextContent('../scripts/aad-app.sh')

resource aadAppDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'aadAppDeployment'
  location: resourceGroup().location
  kind: 'AzureCLI'
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.30.0'
    environmentVariables: [
      {
        name: 'AppPassword'
        secureValue: appPassword
      }
      {
        name: 'TenantId'
        value: tenantId
      }
      {
        name: 'SpId'
        value: spId
      }
      {
        name: 'SpPassword'
        secureValue: spPassword
      }
      {
        name: 'SiteName'
        value: siteName
      }
    ]
    scriptContent: deploymentScriptContent
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

output applicationId string = aadAppDeploymentScript.properties.outputs.appId
