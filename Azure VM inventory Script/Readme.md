#Azure IaaS VM inventory Script

This PS Script would get all the inventory details for Azure VMs. 
By default it will get inventory of all VMs in the default subscription
You can optionally specify a list of VMs in the CSV format like below.

name,resourceGroupName
vm01,rg01
vm02,rg02

It will prompt for Azure account credentials if there are no cached credentials.
