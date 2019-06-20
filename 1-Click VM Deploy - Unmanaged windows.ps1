
##########################################################################
# This PS Script would deploy an Unmanaged VM with a specified resourceGroup & VM name
# This file was downloaded from https://github.com/
# Feel free to change this file to fit your needs.
##########################################################################

# Variables for common values
$vmName = "delete02"
$resourceGroup = "delete01"
$location = "southeastasia"
$vmSize = "Standard_B2ms"                    #Standard_B2ms, Standard_DS2 , Standard_E2s_v3, "Standard_DS3"

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


#Enter VM credentials
$username = "azureadmin"
$password = "P@sswrd1234"
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
  -Name ("$vmname"+"stract$(Get-Random -maximum 100)") `
  -Location $location `
  -SkuName Standard_LRS `
  -Kind StorageV2 

# skus = 2016-Datacenter, 2012-R2-Datacenter,  https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage#table-of-commonly-used-windows-images
# size = Standard_DS2 , Standard_E2s_v3
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


#<Optional> Creates 2nd VM in same vnet & Resourcegroup 
#$vmName2 = "bmw02"