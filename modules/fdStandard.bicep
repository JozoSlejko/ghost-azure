param tags object = {}

param webNames array

@minLength(5)
@maxLength(64)
param frontDoorName string

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

// resource definitions

resource frontDoorProfile 'Microsoft.Cdn/profiles@2020-09-01' = {
  name: frontDoorName
  location: 'global'
  tags: tags
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  properties: {}
}

resource afdEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2020-09-01' = [for endpoint in webNames: {
  name: endpoint
  location: 'global'
  parent: frontDoorProfile
  properties: {
    originResponseTimeoutSeconds: 60
    enabledState: 'Enabled'
  }
}]

resource afdOriginGroup 'Microsoft.Cdn/profiles/originGroups@2020-09-01' = [for endpoint in webNames: {
  name: endpoint
  parent: frontDoorProfile
  properties: {
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    sessionAffinityState: 'Disabled'
  }
}]

resource afdOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2020-09-01' = [for (endpoint, index) in webNames: {
  name: endpoint
  parent: afdOriginGroup[index]
  properties: {
    hostName: '${endpoint}.azurewebsites.net'
    originHostHeader: '${endpoint}.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 50
    enabledState: 'Enabled'
  }

}]

resource afdEndpointRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2020-09-01' = [for (endpoint, index) in webNames: {
  name: endpoint
  parent: afdEndpoint[index]
  dependsOn: [
    afdOrigin
  ]
  properties: {
    originGroup: {
      id: afdOriginGroup[index].id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    queryStringCachingBehavior: 'IgnoreQueryString'
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }

}]

resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'FrontDoorDiagnostics'
  scope: frontDoorProfile
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output frontDoorEndpointHostNames array = [for (endpoint, i) in webNames: {
  endpointHostName: afdEndpoint[i].properties.hostName
}]
