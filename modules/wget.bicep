param webAppName string

@description('Link to call')
param link string

@description('forceUpdateTag property, used to force the execution of the script resource when no other properties have changed.')
param utcValue string = utcNow()

var deploymentScriptContent = loadTextContent('../scripts/wget.sh')

resource wgetDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${webAppName}wgetDeployment'
  location: resourceGroup().location
  kind: 'AzureCLI'
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.30.0'
    environmentVariables: [
      {
        name: 'Link'
        value: link
      }
    ]
    scriptContent: deploymentScriptContent
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
}
