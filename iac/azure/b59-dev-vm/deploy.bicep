@minLength(1)
param location string = resourceGroup().location

param resourcePrefix string = 'b59-dev-'

param adminUsername string = 'b59user'

@secure()
param adminPassword string

param networkSecurityGroupRules array = [
  {
    name: 'RDP'
    properties: {
      priority: 300
      protocol: 'TCP'
      access: 'Allow'
      direction: 'Inbound'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '3389'
    }
  }
]

param ipAaddressPrefixes array = [
  '10.1.0.0/16'
]

param virtualMachineSize string = 'Standard_D4s_v5'
param publicIpAddressType string = 'Static'

var virtualMachineZone = '1'
var resourceNamePrefix = '${resourcePrefix}-${uniqueString(resourceGroup().id)}'
var computerName = 'build5nines'

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: '${resourceNamePrefix}-nic'
  location: location
  dependsOn: [
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddress.id
            properties: {
              deleteOption: 'Detach'
            }
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: '${resourceNamePrefix}-nsg'
  location: location
  properties: {
    securityRules: networkSecurityGroupRules
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: '${resourceNamePrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ipAaddressPrefixes
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.1.0.0/24'
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2020-08-01' = {
  name: '${resourceNamePrefix}-ip'
  location: location
  properties: {
    publicIPAllocationMethod: publicIpAddressType
  }
  sku: {
    name: 'Standard'
  }
  zones: [
    virtualMachineZone
  ]
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: '${resourceNamePrefix}-vm'
  location: location
  dependsOn: [
  ]

  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'fromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
      }
      imageReference: {
        publisher: 'microsoftvisualstudio'
        offer: 'visualstudio2022'
        sku: 'vs-2022-ent-latest-ws2022'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Detach'
          }
        }
      ]
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          enableHotpatching: false
          patchMode: 'AutomaticByOS'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  zones: [
    virtualMachineZone
  ]
}

output adminUsername string = adminUsername

output publicIpAddress string = publicIpAddress.properties.ipAddress

output virtualNetworkResourceId string = virtualNetwork.id
output virtualMachineResourceId string = virtualMachine.id