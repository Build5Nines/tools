@minLength(1)
param location string = resourceGroup().location

param resourcePrefix string = 'b59-dev'

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

@allowed([
  'Static'
  'Dynamic'
])
param publicIpAddressType string = 'Dynamic'


@description('URI of the the ZIP file of lab files to download to VM')
param customScriptFilesZipUri string = ''
@description('Folder to download the lab files to')
param customScriptFilesDestFolder string = 'C:\\lab'

@description('List of software to install on the VM')
param customScriptInstallOptions string = 'Chrome|VSCode|Git|PowerShell|AzureCLI|AzurePowerShell|Terraform|NodeJS|Python'

var customScriptFolder = 'https://raw.githubusercontent.com/build5nines/tools/main/iac/azure/b59-dev-vm/scripts/'
var customScriptFileName = 'configure-vm.ps1'
var customScriptUri = '${customScriptFolder}${customScriptFileName}'
var customScriptCommandToExecute = 'powershell -ExecutionPolicy Unrestricted -File "${customScriptFileName}" -sourceZipUrl "${customScriptFilesZipUri}" -destinationFolder "${customScriptFilesDestFolder}" -installOptions "${customScriptInstallOptions}"'


var virtualMachineZone = '1'
var resourceNamePrefix = '${resourcePrefix}-${uniqueString(resourceGroup().id)}'
var computerName = 'build5nines'

var tags = {
  Name: 'Build5Nines Dev VM'
  IaC: 'Azure Bicep'
  source: 'https://github.com/Build5Nines/tools/blob/main/iac/azure/b59-dev-vm/deploy.bicep'
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: '${resourceNamePrefix}-nic'
  location: location
  dependsOn: [
  ]
  tags: tags
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
  tags: tags
  properties: {
    securityRules: networkSecurityGroupRules
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: '${resourceNamePrefix}-vnet'
  location: location
  tags: tags
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
  tags: tags
  properties: {
    publicIPAllocationMethod: publicIpAddressType
    dnsSettings: {
      domainNameLabel: resourceNamePrefix
    }
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
  tags: tags
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


resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  name: 'ConfigureVM'
  location: location
  parent: virtualMachine
  dependsOn: [
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: false
    settings: {
      fileUris: [
        customScriptUri
      ]
      commandToExecute: customScriptCommandToExecute
    }
  }
}


output adminUsername string = adminUsername

output virtualMachineFQDN string = publicIpAddress.properties.dnsSettings.fqdn
output publicIpAddress string = publicIpAddress.properties.ipAddress

output virtualNetworkResourceId string = virtualNetwork.id
output virtualMachineResourceId string = virtualMachine.id
