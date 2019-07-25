
##########################################################################
# This PS Script would deploy an Unmanaged VM with a specified resourceGroup & VM name
# This script will prompt for Azure account credentials if there are no cached credentials
# This file was downloaded from https://github.com/
# Feel free to change this file to fit your needs.
##########################################################################
<#
.SYNOPSIS
1Click-AzureVMDeployment.ps1 - Azure VM deployment Script.

.DESCRIPTION 
This PS Script would deploy an Unmanaged VM with a specified resourceGroup & VM name.

This script will prompt for Azure account credentials if there are no cached credentials.

.OUTPUTS
Results are output to screen, as well as optional log file(yet to be implemented).

.PARAMETER vmName
Specifies the name for your VM

.PARAMETER location
Specifies the Azure region location for your VM. A default location is used if none is specified.

.PARAMETER resourceGroup
Specifies the Resource Group for your VM. A default name is used if none is specified.

.PARAMETER vmSize
Specifies the Size of your VM. A default value is used if none is specified.

.PARAMETER username
Set an username to login to the VM. A default value is used if none is specified.

.PARAMETER password
Secifies a password to login to the VM. A default value is used if none is specified.

.PARAMETER Log
Writes a log file to help with troubleshooting.

.EXAMPLE
.\1Click-AzureVMDeployment.ps1
 and outputs the results to the shell window.

.EXAMPLE
.\1Click-AzureVMDeployment.ps1 
Checks the server and outputs the results to the shell window.

.EXAMPLE
.\1Click-AzureVMDeployment.ps1 


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
V1.00, 05/07/2012 - Initial version
V1.01, 05/08/2012 - Minor bug fixes and removed Edge Tranport checks

#>


[CmdletBinding()]


param (
        [Parameter( Mandatory=$false)]
        [string]$vmName,

        [Parameter( Mandatory=$false)]
        [string]$resourceGroup,   

        [Parameter( Mandatory=$false)]
        [string]$location="southeastasia" ,   

        [Parameter( Mandatory=$false)]
        [string]$vmSize = "Standard_B2ms", 

        [Parameter( Mandatory=$false)]
        [string]$username = 'azureadmin',                     

        [Parameter( Mandatory=$false)]
        [String]$password = "P@sswrd1234",              

        [Parameter( Mandatory=$false)]
        [switch]$ReportMode,
        
        [Parameter( Mandatory=$false)]
        [switch]$SendEmail,

        [Parameter( Mandatory=$false)]
        [switch]$AlertsOnly,    
        
        [Parameter( Mandatory=$false)]
        [switch]$Log
    )

# Variables for common values
$vmName = "vm-200"
$resourceGroup = "vm-200"
#$location = "southeastasia"                 #Get-AzureRmLocation |Format-Table  #Eg : eastus2, westus, southindia
#$vmSize = "Standard_B2ms"                   #Standard_B2ms, Standard_DS2 , Standard_E2s_v3, "Standard_DS3"

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



# Login to AzureRM if not already logged on. 
$SubScriptionName = 'MS subsription'
If (!(Get-AzureRmContext).Subscription.Name) {
  Login-AzureRmAccount
  #Login-AzureRmAccount -Subscription $SubscriptionName
}

#Enter VM credentials 
#update : moved this to parameters
#$username = "azureadmin" ; $password = "P@sswrd1234"
$secureStringPwd = $password | ConvertTo-SecureString -AsPlainText -Force 
$cred = new-object -typename System.Management.Automation.PSCredential -Argumentlist $username, $secureStringPwd

# Create user object, optional if you are using above SecureStringPwd
#$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create a resource group
New-AzureRmResourceGroup -Name $resourceGroup -Location $location

# Create a subnet configuration
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name "$vmname-Subnet$(Get-Random -maximum 100)" -AddressPrefix 192.168.1.0/24

# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name "$vmname-vNET$(Get-Random -maximum 100)" -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig

# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name "$vmname-publicip$(Get-Random -maximum 100)" -AllocationMethod Dynamic -IdleTimeoutInMinutes 4  -DomainNameLabel "$vmname-vm"
###Ref : https://docs.microsoft.com/en-us/powershell/module/azurerm.network/set-azurermpublicipaddress?view=azurermps-6.13.0
###Set DNS for the VM
$publicIp = Get-AzureRmPublicIpAddress -Name $pip.name -ResourceGroupName $resourceGroup
#$publicIp.DnsSettings.DomainNameLabel = "$vmname-vm"
#Set-AzureRmPublicIpAddress -PublicIpAddress $publicIp

echo "Created Public DNS record for VM : $(($pip.DnsSettingsText | Out-String | ConvertFrom-Json).Fqdn)" 
#https://stackoverflow.com/questions/16575419/powershell-retrieve-json-object-by-field-value
echo "Now please wait while deploying the new Azure VM...."

# Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name "$vmname-RDPrule$(Get-Random -maximum 100)"  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 3389 -Access Allow

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name "$vmname-NSG$(Get-Random -maximum 100)" -SecurityRules $nsgRuleRDP

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name "$vmname-Nic$(Get-Random -maximum 100)" -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

#Create a Storage Account
$sa=New-AzureRmStorageAccount -ResourceGroupName $resourceGroup `
  -Name ("$vmname"+"stract$(Get-Random -maximum 100)").Replace("-","") `
  -Location $location `
  -SkuName Standard_LRS `
  -Kind StorageV2 


# Create a virtual machine configuration
$vm = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName $PublisherName -Offer $offer -Skus $osSKU -Version latest 

$osDiskName = "$vmname"+"-OsDisk"
$osDiskUri = '{0}vhds/{1}-{2}.vhd' `
        -f $sa.PrimaryEndpoints.Blob.ToString(), $vmName.ToLower(), $osDiskName

$vm = Set-AzureRmVMOSDisk -VM $vm -Name $osDiskName -VhdUri $osDiskUri -CreateOption fromimage

$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id


# Create a virtual machine

$vmstatus=New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vm 

if($vmstatus.IsSuccessStatusCode)
{ 
    echo "=================================================================================" 
    echo " successfully create VM : $vmname" 
    echo " Public DNS : $(($pip.DnsSettingsText | Out-String | ConvertFrom-Json).Fqdn)" 
    echo " username   : $username" 
}else{
    echo "Please resolve errors $vmstatus"
}
