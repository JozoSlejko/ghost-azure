@description('Enable the additional Web App slot.')
param slotEnabled bool

param webAppName string

param slotName string

param frontDoorName string

resource existingWebApp 'Microsoft.Web/sites@2020-09-01' existing = {
  name: webAppName
}

resource existingSlotWebApp 'Microsoft.Web/sites/slots@2021-02-01' existing = if (slotEnabled) {
  name: '${webAppName}/${slotName}'
}

resource existingFrontDoor 'Microsoft.Cdn/profiles@2020-09-01' existing = {
  name: frontDoorName
}

resource siteConfig 'Microsoft.Web/sites/config@2021-01-15' = {
  parent: existingWebApp
  name: 'web'
  properties: {
    ipSecurityRestrictions: [
      {
        ipAddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        tag: 'ServiceTag'
        priority: 300
        headers: {
          'x-azure-fdid': [
            existingFrontDoor.properties.frontdoorId
          ]
        }
        name: 'Access from Azure Front Door'
        description: 'Rule for access from Azure Front Door'
      }
    ]
  }
}

resource slotConfig 'Microsoft.Web/sites/slots/config@2021-02-01' = if (slotEnabled) {
  parent: existingSlotWebApp
  name: 'web'
  properties: {
    ipSecurityRestrictions: [
      {
        ipAddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        tag: 'ServiceTag'
        priority: 300
        headers: {
          'x-azure-fdid': [
            existingFrontDoor.properties.frontdoorId
          ]
        }
        name: 'Access from Azure Front Door'
        description: 'Rule for access from Azure Front Door'
      }
    ]
  }
}
