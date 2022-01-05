param webAppName string

@description('Link to call')
param webAppLink string

@description('Link to call')
param slotWebAppLink string = ''

@description('Time to sleep in seconds.')
param time string

@description('forceUpdateTag property, used to force the execution of the script resource when no other properties have changed.')
param utcValue string = utcNow()

var deploymentScriptContent = loadTextContent('../scripts/wget.sh')

resource wgetDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${webAppName}Wget'
  location: resourceGroup().location
  kind: 'AzureCLI'
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.30.0'
    environmentVariables: [
      {
        name: 'WebAppLink'
        value: webAppLink
      }
      {
        name: 'SlotWebAppLink'
        value: slotWebAppLink
      }
      {
        name: 'SleepTime'
        value: time
      }
    ]
    scriptContent: deploymentScriptContent
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
    timeout: 'PT20M'
  }
}
