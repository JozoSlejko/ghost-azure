param webAppName string

@description('Link to call')
param link string

@description('forceUpdateTag property, used to force the execution of the script resource when no other properties have changed.')
param utcValue string = utcNow()

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
    scriptContent: '! wget \${Link} &>/dev/null'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
  }
}
