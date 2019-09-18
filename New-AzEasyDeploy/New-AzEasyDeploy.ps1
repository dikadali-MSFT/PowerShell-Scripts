##########################################################################################################################################
# Truly One-click IaaS deployment Script for CSS issue repros. Goal is to have a one liner cmd-let for any type of IaaS deployment scenarios module should be auto-imported into CloudShell.
# This PS Script would deploy an Unmanaged windows VM with a specified resourceGroup & VM name.
# It will automatically create a new Virtual Network, Subnets, Dynamic Public IP address, nsg rules, etc.
# This file was downloaded from https://github.com/
# Target Customers
# + All CSS IaaS VM pod, networking pod teams globally. SQL teams, AzureSQL, PaaS teams 
# UseCases: 
# - Quick VM deployment for issue repros of dev/test purposes for CSS
# - End users who wants to test new Azure features
# - End customers who wants to test marketplace images
# - Easy to cleanup Az resources as it creates under new resource group
# - May include PaaS webapp deployments as well
# Highlights : 
# -------------
# This script will prompt for Azure account credentials if there are no cached credentials
# Feel free to change this file to fit your needs.
# To deploy Linux modify the script accordingly 
# Upcoming Features: 
# ------------------
# Deployment switch parameter for Managed/unmanaged, Premium, Data disks, Disk Encryption
# Option for Linux images CentOS, Suse, Redhat.
# Create 2nd VM on the existing Vnet created. 
# Multiple VM's with AV set - both Windows & Linux, managed/unmanaged disks.
# Switch for AAD login.
# Option to specify multi nic cards
# Deploy multiple VM's in same subnets - say 1-5
# Deploy multiple VM's in different vnets - say 1-5 ; Add vnet peerings automatically 
# Deploy multiple VM's in different locations with options - managed/unmanaged disks, premium/standard HDD, custom network parameters.
# Ability to specify OS for multi VM's eg. windows,linux,windows (should take default os version) or OSsku arrary.
# Ability to specify market place images eg datalake, Python Anaconda ML VMs, SQL clusterss etc.
# provide this as default module in CloudShell for quick deployments.
# Need to have paramanter consistency with Public Az deploymnet templates
##########################################################################################################################################
<#
.SYNOPSIS
New-AzEasyDeploy.ps1 - Azure VM deployment Script.

.DESCRIPTION 
This PS Script would deploy an Unmanaged VM with a specified resourceGroup & VM name.

It will prompt for Azure account credentials if there are no cached credentials.

.OUTPUTS
Results are output to screen, as well as optional log file(yet to be implemented).

.PARAMETER vmName
Specifies the name for your VM

.PARAMETER location
Specifies the Azure region location for your VM. A default location is used if none is specified.

.PARAMETER resourceGroupName
Specifies the Resource Group for your VM. A default name is used if none is specified.

.PARAMETER vmSize
Specifies the Size of your VM. A default value is used if none is specified.

.PARAMETER username
Set an username to login to the VM. A default value is used if none is specified.

.PARAMETER password
Secifies a password to login to the VM. A default value is used if none is specified.

.PARAMETER Log
Writes a log file to help with troubleshooting.

.PARAMETER vnetAddressPrefix
Allows you to specify Virtual Network AddressPrefix. A default value of "192.168.0.0/16" is used if none is specified.

.PARAMETER subnetAddressPrefix
Allows you to specify Subnet AddressPrefix. A default value of "192.168.1.0/24" is used if none is specified.

.EXAMPLE
.\New-AzEasyDeploy.ps1
Create an managed VM with default names in the script and outputs the results to the shell window.

.EXAMPLE
.\New-AzEasyDeploy.ps1 -vmName temp1000 -resourceGroupName temp1000
Specify VM name and resource group name for VM deployment and outputs the results to the shell window.

.EXAMPLE
.\New-AzEasyDeploy.ps1  
Specify VM custom network AddressPrefix parameters

.LINK


.NOTES
Written by: Dinesh Kadali

Find me on:

* My Blog:	
* Twitter:	
* LinkedIn:	
* Github:	https://github.com/dikadali

Additional Credits (code contributions and testing):
- <Name>, https://github.com/<userid>


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
V1.00, 17/06/2019 - Initial version
V1.01, 22/06/2012 - Minor bug fixes and added filter to remove '-' for storage account

#>


[CmdletBinding()]
# Variables for common values
#$vmName = "vm10"
#$resourceGroupName = "vm10"
#$location = "southeastasia"                 #Get-AzLocation |Format-Table  #Eg : eastus2, westus, southindia
#$vmSize = "Standard_B2ms"                   #Standard_B2ms, Standard_DS2 , Standard_E2s_v3, "Standard_DS3"

param (
        [Parameter( Mandatory=$false)]
        [string]$vmName="demo"+(Get-Random -maximum 100),

        [Parameter( Mandatory=$false)]
        [string]$resourceGroupName=$vmName,   

        [Parameter( Mandatory=$false)]
        [string]$location="southeastasia" ,   

        [Parameter( Mandatory=$false)]
        [string]$vmSize = "Standard_B2ms", 

        [Parameter( Mandatory=$false)]
        [string]$username = 'azureadmin',                     

        [Parameter( Mandatory=$false)]
        [String]$password = "Def@ult1234",              
      
        [Parameter( Mandatory=$false)]
        [String]$vnetAddressPrefix="192.168.0.0/16",

        [Parameter( Mandatory=$false)]
        [string]$subnetAddressPrefix="192.168.1.0/24",    
        
        [Parameter( Mandatory=$false)]
        [switch]$Log,
     
        [Parameter( Mandatory=$false)]
        [switch]$Unmanaged=$false,

        [Parameter( Mandatory=$false)]
        [String]$storageAccountType="Standard_LRS",

        [Parameter( Mandatory=$false)]
        [String]$availabilitySetName=$null,

        [Parameter( Mandatory=$false)]
        [switch]$Premium=$false  
    )

#'Standard_LRS', 'Premium_LRS', 'StandardSSD_LRS', 'UltraSSD_LRS'    



#Windows 
$PublisherName= "MicrosoftWindowsServer" ;   $Offer ="WindowsServer"  ; $osSKU="2016-Datacenter" 
#CentOS
#$PublisherName= "OpenLogic" ;   $Offer ="CentOS" ; $osSKU="7.6" ; 
#Ubuntu
#$PublisherName= "Canonical" ;   $Offer ="UbuntuServer" ; $osSKU="19.04" ; 

#Examples
## Offer==> UbuntuServer,CentOS,CentOS-LVM, CentOS-SRIOV, RHEL, rhel-byos 
## osSKU ==> 19.04, 19.04-DAILY, 7.6(centos), 7.5(rhel), 2012-R2-Datacenter, 2016-Datacenter
# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage#table-of-commonly-used-windows-images


$AzModuleVersion = "1.3.0"
# Verify that the Az module is installed 
if (!(Get-InstalledModule -Name Az -MinimumVersion $AzModuleVersion -ErrorAction SilentlyContinue)) {
    Write-Host "This script requires to have Az Module version $AzModuleVersion installed..
    It was not found, please install from: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps"
    exit
}


# Login to Az if not already logged on and powershell has cached credentials. 
if (!($currentSubscriptionID=(Get-AzContext).Subscription.id)) {
    Write-Host "Logging in...";
    Login-AzAccount
}
else{
    Write-Host "Logged in Using cached credentials with current Subscription id $currentSubscriptionID "
}


#Enter VM credentials 
#update : moved this to parameters
#$username = "azureadmin" ; $password = "P@sswrd1234"
$secureStringPwd = $password | ConvertTo-SecureString -AsPlainText -Force 
$cred = new-object -typename System.Management.Automation.PSCredential -Argumentlist $username, $secureStringPwd
#Command to ask user password in the prompt
#$password = Read-Host "Enter VM password" -AsSecureString

# Create user object, optional if you are using above SecureStringPwd
#$cred = Get-Credential -Message "Enter a username and password for the virtual machine."
$vmcount=@("00","01","02","03","04","05","06")

#Create or check for existing resource group
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$ResourceGroupName' does not exist.";
    Write-Host "Creating resource group '$ResourceGroupName' in location '$location'";
    New-AzResourceGroup -Name $resourceGroupName -Location $location
}
else{
    Write-Host "Using existing resource group '$ResourceGroupName' from Location $resourceGroup.location";
}


# Create a subnet configuration
Write-Verbose "Creating subnet configuration for VM"
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name "$vmname-Subnet$(Get-Random -maximum 100)" -AddressPrefix $subnetAddressPrefix

# Create a virtual network
Write-Verbose "Creating vnet configuration for VM"
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location `
  -Name "$vmname-vNET$(Get-Random -maximum 100)" -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig

# Create a public IP address and specify a DNS name
Write-Verbose "Creating PublicIP configuration for VM"
$pip = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location `
  -Name "$vmname-publicip$(Get-Random -maximum 100)" -AllocationMethod Dynamic -IdleTimeoutInMinutes 4  -DomainNameLabel "$vmname-vm"

###Get DNS for the VM
$publicIp = Get-AzPublicIpAddress -Name $pip.name -ResourceGroupName $resourceGroupName

if($publicIp){
    Write-Host "Created Public DNS record for VM : $(($pip.DnsSettingsText | Out-String | ConvertFrom-Json).Fqdn)" -ForegroundColor Green 
    #https://stackoverflow.com/questions/16575419/powershell-retrieve-json-object-by-field-value
}

#Check for OS type and create NSG rules accordingly.
if ($PublisherName -ne "MicrosoftWindowsServer"){
    # Create an inbound network security group rule for port 22
    Write-Verbose "Creating NSG rules for Linux VM"
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name "$vmname-SSHrule$(Get-Random -maximum 100)"  -Protocol Tcp `
    -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
    -DestinationPortRange 22 -Access Allow

    # Create a network security group
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location `
    -Name "$vmname-NSG$(Get-Random -maximum 100)" -SecurityRules $nsgRuleSSH
}else {
    # Create an inbound network security group rule for port 3389
    Write-Verbose "Creating NSG rules for Windows VM"
    $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name "$vmname-RDPrule$(Get-Random -maximum 100)"  -Protocol Tcp `
    -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
    -DestinationPortRange 3389 -Access Allow
    # Create a network security group
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location `
    -Name "$vmname-NSG$(Get-Random -maximum 100)" -SecurityRules $nsgRuleRDP
}
# Create a virtual network card and associate with public IP address and NSG
Write-Verbose "Creating NIC card"
$nic = New-AzNetworkInterface -Name "$vmname-Nic$(Get-Random -maximum 100)" -ResourceGroupName $resourceGroupName -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

if($premium)
{
    $storageAccountType = "Premium_LRS" ; 
    Write-Verbose "Selected Premium disk for VM storage"
}

if($standardSSD)
{
    $storageAccountType = "StandardSSD_LRS" ; 
    Write-Verbose "Selected StandardSSD_LRS disk for VM storage"
}

if ($unmanaged) {

    #Code for unmanaged disk VM          
        #Create a Storage Account
        Write-Verbose "Creating Storage Account for VM"
        $sa=New-AzStorageAccount -ResourceGroupName $resourceGroupName `
        -Name ("$vmname"+"stract$(Get-Random -maximum 100)").Replace("-","") `
        -Location $location `
        -SkuName $storageAccountType `
        -Kind StorageV2 

        
        
        if($availabilitySetName){
            Write-Output "Adding AVSet configurations for Unmanaged disk VM"
            $AvailabilitySetConfig = Get-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName -ErrorAction SilentlyContinue
            if($AvailabilitySetConfig -eq  $null){
                #Create a new AV set if it was not existed
                $AvailabilitySetConfig = New-AzAvailabilitySet -Location $location -Name $AvailabilitySetName -ResourceGroupName $resourceGroupName `
                -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2
            } 
            # Create a virtual machine configuration
            $vm = New-AzvmConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetID $AvailabilitySetConfig.Id 
        }else{
            #Create vmConfig object without AV set  
            $vm = New-AzvmConfig -VMName $vmName -VMSize $vmSize 
        }

        # Create a virtual machine configuration object
        $vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $cred | `
        Set-AzVMSourceImage -PublisherName $PublisherName -Offer $offer -Skus $osSKU -Version latest 

        $osDiskName = "$vmname"+"-OsDisk"
        $osDiskUri = '{0}vhds/{1}-{2}.vhd' `
            -f $sa.PrimaryEndpoints.Blob.ToString(), $vmName.ToLower(), $osDiskName

        $vm = Set-AzVMOSDisk -VM $vm -Name $osDiskName -VhdUri $osDiskUri -CreateOption fromimage # -StorageAccountType $storageAccountType
        $vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id

        # Create a virtual machine
        $vmStatus=New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vm 

} else {
    #code for Managed disk VM
            #Check for Availability Set requirement
            if($availabilitySetName){
                Write-Output "Adding AVSet configurations for Managed disk VM"
                $AvailabilitySetConfig = Get-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName -ErrorAction SilentlyContinue
                if($AvailabilitySetConfig -eq  $null){
                    #Create a new AV set if it was not existed
                    $AvailabilitySetConfig = New-AzAvailabilitySet -Location $location -Name $AvailabilitySetName -ResourceGroupName $resourceGroupName `
                    -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2
                } 
                # Create a virtual machine configuration with AV Set
                $vmConfig = New-AzvmConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetID $AvailabilitySetConfig.Id 

            }else{
            #Create vmConfig object without AV set  
            $vmConfig = New-AzvmConfig -VMName $vmName -VMSize $vmSize 
            }

            #Create a VM managed os disk config
            Write-Verbose "Creating a VM with Managed disk"

            
            $osDiskName = "$vmname"+"-OsDisk"
            $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmName -Credential $cred  | `
                Add-AzVMNetworkInterface -Id $Nic.Id | `
                Set-AzVMOSDisk -Name "$osDiskName.vhd" -CreateOption fromimage -StorageAccountType $storageAccountType | `
                Set-AzVMBootDiagnostics -Disable | `
                Set-AzVMSourceImage -PublisherName $PublisherName -Offer $offer -Skus $osSKU -Version latest
            
            # Create the virtual machines
            Write-Output "Now, please wait while deploying your new Azure VM...." 
            $vmStatus=New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig
          
}
  

$commands = {
    if($vmStatus.IsSuccessStatusCode)
    { 
        Write-Output "=================================================================================" 
        Write-Output " Successfully created VM : $vmname" 
        Write-Output " Public DNS : $(($pip.DnsSettingsText | Out-String | ConvertFrom-Json).Fqdn)" 
        Write-Output " Username   : $username" 
    }else{
        Write-Output "Please resolve errors $vmStatus"
    }
    #open RDP console with pre-populated value of dns
    mstsc /v:$(($pip.DnsSettingsText | Out-String | ConvertFrom-Json).Fqdn)
    Exit
}

&$commands 


#start powershell -NoExit -Command "&\{mstsc /v:$(($pip.DnsSettingsText | Out-String | ConvertFrom-Json).Fqdn) }"

#Get-AzureRmResourceGroup -Name $resourceGroupName | Remove-AzureRmResourceGroup -Verbose -Force

#Get-AzResourceGroup -Name demo30 | Remove-AzResourceGroup -Verbose -Force

#Get-AzResourceGroup -Name temp | Remove-AzResourceGroup -Verbose -Force

#Get-AzComputeResourceSku | where {$_.Locations.Contains("eastus2")};