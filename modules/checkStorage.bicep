@description('Link to call')
param storageName string

@description('forceUpdateTag property, used to force the execution of the script resource when no other properties have changed.')
param utcValue string = utcNow()

var deploymentScriptContent = loadTextContent('../scripts/checkStorage.sh')

resource checkStorageDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${storageName}CheckStorage'
  location: resourceGroup().location
  kind: 'AzureCLI'
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.30.0'
    environmentVariables: [
      {
        name: 'StorageName'
        value: storageName
      }
    ]
    scriptContent: deploymentScriptContent
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
}
