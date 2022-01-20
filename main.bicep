param functionSku string = 'f1'
var functionPrefix = 'python-kurs'
param location string = resourceGroup().location

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: '${functionPrefix}-location'
  location: resourceGroup().location
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
    }
    accessTier: 'Hot'
  }
  sku: {
    name: 'Standard_LRS'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: '${functionPrefix}-appi'
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource plan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${functionPrefix}-plan'
  location: resourceGroup().location
  sku: {
    name: 'Y1'
  }
  properties: {}
}



resource functionApp 'Microsoft.Web/sites@2020-12-01' = {
  name: '${functionPrefix}-${location}'
  location: resourceGroup().location
  kind: 'functionapp'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageaccount};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys('${storageaccount.id}', '${storageaccount.apiVersion}').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageaccount};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys('${storageaccount.id}', '${storageaccount.apiVersion}').keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsights.properties.InstrumentationKey}'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
      ]
    }
    httpsOnly: true
  }
}
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'pythonkurs-keyvault'
  location: resourceGroup().location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
  }
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/functionAppHostKey'
  properties: {
    value: listKeys('${functionApp.id}/host/default', functionApp.apiVersion).functionKeys.default
  }
}

output functionAppHostName string = functionApp.properties.defaultHostName
