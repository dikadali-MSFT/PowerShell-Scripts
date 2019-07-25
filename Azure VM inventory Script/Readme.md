Azure IaaS VM inventory Script
===================================
This PS Script would get all the inventory details for Azure VMs. 
By default it will get the inventory of all VMs in the default subscription
You can optionally specify a list of VMs in the CSV format like below.

name,resourceGroupName

vm01,rg01

vm02,rg02

It will prompt for Azure account credentials if there are no cached credentials.

EXAMPLE 1
===========
.\get-AzureVMDetials.ps1
Get VM inventory for all VMs in the default subscription
EXAMPLE 2
===========
.\get-AzureVMDetials.ps1 -VMListCSVFilePath “d:\servers.txt"
Get VM inventory for the list of VMs specified in the CSV file
EXAMPLE 3
=============
.\get-AzureVMDetials.ps1 -Subscription_id "" 
Get VM inventory for all VMs in the specified subscription


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
