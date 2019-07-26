<#
.SYNOPSIS
get-AzVMDetails.ps1 - Azure VM inventory Script.

.DESCRIPTION 
This PS Script would get all the inventory details for Azure VMs. 
By default it will get inventory of all VMs in the default subscription
You can optionally specify a list of VMs in the CSV format like below.

name,resourceGroupName
vm01,rg01
vm02,rg02

It will prompt for Azure account credentials if there are no cached credentials.

.OUTPUTS
Results are output to screen, as well as optional log file(yet to be implemented).

.PARAMETER VMListCSVFilePath
Specifies the list of VMs 

.PARAMETER path_to_store_inventory_csv_files
Specifies the output of inventory files. A default location is used if none is specified.

.EXAMPLE
.\get-AzureVMDetials.ps1
Get VM inventory for all VMs in the default subscription

.EXAMPLE
.\get-AzureVMDetials.ps1 -VMListCSVFilePath “d:\servers.txt"
Get VM inventory for the list of VMs specified in the CSV file

.EXAMPLE
.\get-AzureVMDetials.ps1 -Subscription_id "" 
Get VM inventory for all VMs in the specified subscription


.LINK


.NOTES
Written by: Dinesh Kadali

Find me on:

* Github:	https://github.com/dikadali

Additional Credits (code contributions and testing):
- Saurabh D, https://github.com/saurabhdhiraj


License:

The MIT License (MIT)

Copyright (c) 2019 Dinesh Kadali

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Change Log
V1.00, 12/07/2019 - Initial version


#>



[CmdletBinding()]

    Param(
        [Parameter( Mandatory=$False, ValueFromPipeline=$True)]
        [String[]] $azureVMList,   

        [Parameter( Mandatory=$False)]
        [String] $Subscription_id,

        [Parameter( Mandatory=$False)]
        [String] $VMListCsvFilePath,

        [Parameter( Mandatory=$False)]
        [String] $path_to_store_inventory_csv_files = "d:\AzureVMInventory",

        [Parameter(Mandatory=$false)]
        [string] $Subscription=$false
 
    )
$VerbosePreference = "Continue"
$StartTime = Get-Date

$AzModuleVersion = "1.3.0"
# Verify that the Az module is installed 
if (!(Get-InstalledModule -Name Az -MinimumVersion $AzModuleVersion -ErrorAction SilentlyContinue)) {
    Write-Host "This script requires to have Az Module version $AzModuleVersion installed..
    It was not found, please install from: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps"
    exit
}

# Login to Az if not already login with powershell cached credentials. 
if (!($currentSubscriptionID=(Get-AzContext).Subscription.id)) {
    Write-Host "Logging in...";
    Login-AzAccount
}
else{
    Write-Host "Logged in Using cached credentials to current `r Subscription id : $currentSubscriptionID "
}


# select subscription
if($Subscription_id){
    Write-Host "Selecting subscription: $Subscription_id";
    Select-AzSubscription -Subscription $Subscription_id;
}

function get-AzVMdetails{
    

    
    #.\Reports\AzureRmDataDisks_$(Get-Date -UFormat "%d-%m-%Y-%H.%M.%S").csv
    $VerbosePreference = "Continue"
    $StartTime = Get-Date

    # Change the directory location to store the CSV files
    Set-Location -Path $path_to_store_inventory_csv_files

    # Create a new directory with the subscription name
    $folder = Get-ChildItem | where {$_.Name -like 'AzureVMInventory'}
    if( $folder -eq $null) {new-item $path_to_store_inventory_csv_files -ItemType Directory -Force }



    
    #####################################################################
    #    Fetch Virtual Machine Details                               #
    #####################################################################

        $vm_object = $null
        $vm_object = @()
        [array]$azureVMList = $null
        [array]$azureVMList = @()

        #Generating $azureVMList Arrary object from csv input file
 
        if($CSV_VMList){
            
            try{
                Test-Path $CSV_VMList -PathType Leaf -ErrorAction Stop
            }
            Catch{ 
                Write-Host "Please provide a valid CSV file" 
            }
            
            #import CSV file to an Azure VM array object
            $vm_list=import-csv $CSV_VMList
            foreach($vm in $vm_list)
            {
                Write-host "Importing VM-->" "VMName: "$vm.Name,  "ResourceGroup :" $vm.resourceGroupName
                [array]$azureVMList_temp = get-azvm -Name $vm.Name -ResourceGroupName $vm.resourceGroupName 
                
                if($azureVMList_temp)
                {
                    Write-Host "Couldn't find the VM : $vm.Name, ResourceGroup : $vm.resourceGroupName" -ForegroundColor Red 
                }
                $azureVMList = $azureVMList + $azureVMList_temp
            }    
            Write-Host "`r`nImported All VM from CSV file"  -ForegroundColor Green 
            
        }else{
            
            $azureVMList=Get-AzVM
            Write-Host "`r`nImported All VM from subscription" -ForegroundColor Green 
        }
        #$vms | fl * 

        $azureVMList | Format-Table


        # Iterating over the Virtual Machines under the subscription
            
            foreach($azureVMList_Iterator in $azureVMList){
            
            # Fetching the VM satus
            $vm_status = get-azvm -ResourceGroupName $azureVMList_Iterator.resourcegroupname -name $azureVMList_Iterator.name -Status

            #Fetching the private IP and Network details of the VM
            $VMNicName = $azureVMList_Iterator.NetworkProfile.NetworkInterfaces.Id.Split("/")[-1] 
            $VMNic = Get-AzNetworkInterface -ResourceGroupName $azureVMList_Iterator.resourcegroupname -Name $VMNicName
            $VMvNetName = $VMNic.IpConfigurations.Subnet.Id.Split("/")[8]
            #$vNet = Get-AzVirtualNetwork -ResourceGroupName $azureVMList_Iterator.resourcegroupname -Name $VMvNetName
            #Get Public IP details
            if($VMNic.IpConfigurations[0].PublicIpAddress.id){
                $public_ip_address_name = $VMNic.IpConfigurations[0].PublicIpAddress.Id.split("/")[8] 
                $publicip = get-azpublicipaddress -name $public_ip_address_name -resourcegroupname $azurevmlist_iterator.resourcegroupname -erroraction silentlycontinue

            }

            $private_ip_address = $vmnic.ipconfigurations.privateipaddress
            
<# Need to write code for multi NiC VMs
            foreach($azurenicdetails_iterator in $azurenicdetails){
                if($azurenicdetails_iterator.id -eq $azurevmlist_iterator.networkprofile.networkinterfaces.id) {
                #write-host $vm.networkinterfaceids
                $private_ip_address = $azurenicdetails_iterator.ipconfigurations.privateipaddress
                }
            }

  #>             

                #Fetching data disk names
                $data_disks = $azureVMList_Iterator.StorageProfile.DataDisks
                $data_disk_name_list = ""
                $data_disk_full_list = ""

                if($data_disks.Count -eq 0){
                            $data_disk_name_list = "No Data Disk Attached"
                            $data_disk_full_list = "No Data Disk Attached"
                            #write-host $data_disk_name_list
                }elseif($data_disks.Count -ge 1) {
                            
                    foreach ($data_disks_iterator in $data_disks) {
                        $data_disk_full_list_temp =  $data_disk_full_list + $data_disks_iterator.name + " --- " + $data_disks_iterator.DiskSizeGB + "GB --- " + $data_disks_iterator.ManagedDisk.id + $data_disks_iterator.vhd.uri + " ; `r`n "
                        $data_disk_full_list = $data_disk_full_list_temp
                    
                        #write-host $data_disk_name_list
                        $data_disk_name_list_temp = $data_disks_iterator.name + "; " + $data_disk_name_list 
                        $data_disk_name_list = $data_disk_name_list_temp
                    }
                
                }

                # Fetching OS Details (Managed / un-managed)

                if($azureVMList_Iterator.StorageProfile.OsDisk.manageddisk -eq $null){
                    # This is un-managed disk. It has VHD property

                    $os_disk_id = $azureVMList_Iterator.StorageProfile.OsDisk.Vhd.Uri
                    $disk_type= "Unmanaged"

                }else{
                    
                    $os_disk_id = $azureVMList_Iterator.StorageProfile.OsDisk.ManagedDisk.Id
                    $disk_type = "Managed"
                }

                #Get Boot Diagnostics related details
                $bootDiagnosticStatus = $azureVMList_Iterator.DiagnosticsProfile.BootDiagnostics.Enabled
                $bootDiagnosticsStorageAccount = $azureVMList_Iterator.DiagnosticsProfile.BootDiagnostics.StorageUri

                #Fetch all VM Encryption status
                $VMencryptionstatus=Get-AzVmDiskEncryptionStatus -ResourceGroupName $azureVMList_Iterator.ResourceGroupName -VMName $azureVMList_Iterator.name


                $vm_object_temp = new-object PSObject 
                $vm_object_temp | add-member -membertype NoteProperty -name "VMName" -Value $azureVMList_Iterator.Name
                $vm_object_temp | add-member -membertype NoteProperty -name "ResourceGroupName" -Value $azureVMList_Iterator.ResourceGroupName
                $vm_object_temp | add-member -membertype NoteProperty -name "VMStatus" -Value $vm_status.Statuses[1].DisplayStatus
                $vm_object_temp | add-member -membertype NoteProperty -name "Location" -Value $azureVMList_Iterator.Location
                $vm_object_temp | add-member -membertype NoteProperty -name "VMSize" -Value $azureVMList_Iterator.HardwareProfile.VmSize               
                $vm_object_temp | add-member -membertype NoteProperty -name "OSType" -Value $azureVMList_Iterator.StorageProfile.OsDisk.OsType
                $vm_object_temp | add-member -membertype NoteProperty -name "OSVersion" -Value $azureVMList_Iterator.StorageProfile.ImageReference.sku
                $vm_object_temp | add-member -membertype NoteProperty -name "AdminUserName" -Value $azureVMList_Iterator.OSProfile.AdminUsername            
                $vm_object_temp | add-member -membertype NoteProperty -name "vnetName" -Value $VMvNetName
                $vm_object_temp | add-member -membertype NoteProperty -name "NICResourceId" -Value $azureVMList_Iterator.NetworkProfile.NetworkInterfaces.id
                $vm_object_temp | add-member -membertype NoteProperty -name "PrivateIP" -Value $private_ip_address
                $vm_object_temp | add-member -membertype NoteProperty -name "PublicIP" -Value $publicip.IpAddress
                $vm_object_temp | add-member -membertype NoteProperty -name "PublicIP_FQDN" -Value $(($publicIp.DnsSettingsText | Out-String | ConvertFrom-Json).Fqdn)
                $vm_object_temp | add-member -membertype NoteProperty -name "DiskType" -Value $disk_type
                $vm_object_temp | add-member -membertype NoteProperty -name "OSDiskName" -Value $azureVMList_Iterator.StorageProfile.OsDisk.Name
                $vm_object_temp | add-member -membertype NoteProperty -name "OSDiskSizeGB" -Value $azureVMList_Iterator.StorageProfile.OsDisk.DiskSizeGB
                $vm_object_temp | add-member -membertype NoteProperty -name "OSDiskID/URI" -Value $os_disk_id
                $vm_object_temp | add-member -membertype NoteProperty -name "DataDiskCount" -Value $data_disks.Count
                $vm_object_temp | add-member -membertype NoteProperty -name "DataDiskNames" -Value $data_disk_name_list
                $vm_object_temp | add-member -membertype NoteProperty -name "DataDisksDetailsAll (DiskName - DiskSize - DiskURI)" -Value $data_disk_full_list
                $vm_object_temp | add-member -membertype NoteProperty -name "BootDiagnosticEnabled" -Value $bootDiagnosticStatus
                $vm_object_temp | add-member -membertype NoteProperty -name "BootDiagnosticsStorageAccount" -Value $bootDiagnosticsStorageAccount
                $vm_object_temp | add-member -membertype NoteProperty -name "VM Tags" -Value ($azureVMList_Iterator.tags | ConvertTo-json)
                $vm_object_temp | add-member -membertype NoteProperty -name "OSDiskCreateOption" -Value $azureVMList_Iterator.StorageProfile.OsDisk.CreateOption
                $vm_object_temp | add-member -membertype NoteProperty -name "OSDiskCachingType" -Value $azureVMList_Iterator.StorageProfile.OsDisk.Caching
                $vm_object_temp | add-member -membertype NoteProperty -name "OSDiskEncryption Status" -Value $VMencryptionstatus.OsVolumeEncrypted
                $vm_object_temp | add-member -membertype NoteProperty -name "DataDiskEncryption Status" -Value $VMencryptionstatus.DataVolumesEncrypted

                $vm_object += $vm_object_temp

                
            }

            $vm_object | Export-Csv "VM_Inventory_$(Get-Date -UFormat "%d-%m-%Y-%H.%M").csv" -NoTypeInformation -Force 
            #$vm_object 

}


get-AzVMdetails
Write-Host "Task completed in $((New-TimeSpan $StartTime (Get-Date)).TotalSeconds) Seconds. `r`n"
Write-Host "Please check output CSV file under folder $path_to_store_inventory_csv_files\VM_Inventory_$(Get-Date -UFormat "%d-%m-%Y-%H.%M").csv  "