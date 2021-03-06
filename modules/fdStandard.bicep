param tags object = {}

param webNames array

@minLength(5)
@maxLength(64)
param frontDoorName string

@allowed([
  'Detection'
  'Prevention'
])
@description('The mode that the WAF should be deployed using. In \'Prevention\' mode, the WAF will block requests it detects as malicious. In \'Detection\' mode, the WAF will not block requests and will simply log the request.')
param wafMode string = 'Prevention'

@description('The list of managed rule sets to configure on the WAF.')
param wafManagedRuleSets array = [
  {
    ruleSetType: 'Microsoft_DefaultRuleSet'
    ruleSetVersion: '1.1'
  }
  {
    ruleSetType: 'Microsoft_BotManagerRuleSet'
    ruleSetVersion: '1.0'
  }
]

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

var domains = [for (endpoint, i) in webNames: {
  id: afdEndpoint[i].id
}]

// resource definitions

resource frontDoorProfile 'Microsoft.Cdn/profiles@2020-09-01' = {
  name: frontDoorName
  location: 'global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor' // The Microsoft-managed WAF rule sets require the premium SKU of Front Door.
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
    // healthProbeSettings: {
    //   probePath: '/'
    //   probeRequestType: 'HEAD'
    //   probeProtocol: 'Https'
    //   probeIntervalInSeconds: 100
    // }
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
    compressionSettings: {
      contentTypesToCompress: [
        'application/eot'
        'application/font'
        'application/font-sfnt'
        'application/javascript'
        'application/json'
        'application/opentype'
        'application/otf'
        'application/pkcs7-mime'
        'application/truetype'
        'application/ttf'
        'application/vnd.ms-fontobject'
        'application/xhtml+xml'
        'application/xml'
        'application/xml+rss'
        'application/x-font-opentype'
        'application/x-font-truetype'
        'application/x-font-ttf'
        'application/x-httpd-cgi'
        'application/x-javascript'
        'application/x-mpegurl'
        'application/x-opentype'
        'application/x-otf'
        'application/x-perl'
        'application/x-ttf'
        'font/eot'
        'font/ttf'
        'font/otf'
        'font/opentype'
        'image/svg+xml'
        'text/css'
        'text/csv'
        'text/html'
        'text/javascript'
        'text/js'
        'text/plain'
        'text/richtext'
        'text/tab-separated-values'
        'text/xml'
        'text/x-script'
        'text/x-component'
        'text/x-java-source'
      ]
      isCompressionEnabled: true
    }
    queryStringCachingBehavior: 'IgnoreQueryString'
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }

}]

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2020-11-01' = {
  name: 'WafPolicy'
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: wafMode
    }
    managedRules: {
      managedRuleSets: wafManagedRuleSets
    }
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2020-09-01' = {
  parent: frontDoorProfile
  name: 'SecurityPolicy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: domains
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

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
