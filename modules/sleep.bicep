@description('Time to sleep in seconds.')
param time string = '60'

@description('forceUpdateTag property, used to force the execution of the script resource when no other properties have changed.')
param utcValue string = utcNow()

resource sleepDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'sleepDeployment'
  location: resourceGroup().location
  kind: 'AzureCLI'
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.30.0'
    environmentVariables: [
      {
        name: 'SleepTime'
        value: time
      }
    ]
    scriptContent: 'sleep \${SleepTime}s'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
  }
}
