Azure IaaS VM inventory Script
===================================
This PS Script would get all the inventory details for Azure VMs. 
By default it will get the inventory of all VMs in the default subscription
You can optionally specify a list of VMs in the CSV format like below.

name,resourceGroupName

vm01,rg01

vm02,rg02

It will prompt for Azure account credentials if there are no cached credentials.

Output fields
================
 - VMName
 - ResourceGroupName
 - VMStatus
 - Location
 - VMSize
 - OSDiskName
 - OSDiskType
 - OSVersion
 - AdminUserName
 - vnetName
 - NICResourceId
 - PrivateIP
 - PublicIP
 - PublicIP_FQDN
 - DiskType
 - OSDiskID/URI
 - DataDiskCount
 - DataDiskNames
 - DataDisksDetailsAll (DiskName - DiskSize - DiskURI)
 - BootDiagnosticStatus
 - BootDiagnosticsStorageAccount
 - VM Tags
 - OSDiskCreateOption
 - OSDiskCachingType
 - OSDiskEncryption Status
 - DataDiskEncryption Status
