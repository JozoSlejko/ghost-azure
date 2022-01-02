@description('Name of the User Assigned Identity.')
param name string

@description('Optional. Tags of the resource.')
param tags object = {}

resource userMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: name
  location: resourceGroup().location
  tags: tags
}

@description('The name of the user assigned identity')
output msiName string = userMsi.name

@description('The resource ID of the user assigned identity')
output msiResourceId string = userMsi.id

@description('The principal ID of the user assigned identity')
output msiPrincipalId string = userMsi.properties.principalId

@description('The Client ID of the user assigned identity')
output msiClientId string = userMsi.properties.clientId
