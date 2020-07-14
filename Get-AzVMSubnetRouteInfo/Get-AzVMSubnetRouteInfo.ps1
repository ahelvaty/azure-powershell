
# Determine and Assign file path
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$FileCreationDate = Get-Date -Format "yyyy-MM-dd-HH-mm"
$FileName = "Prod_VM_SubnetRouteInfo_" + $FileCreationDate + ".csv"
$reportSaveLocation = Join-Path -Path $DesktopPath -ChildPath $FileName


#Uncomment the below if you need to log into Azure
#login-azaccount

#Variable to run script for a single subscription or all subscriptions COMMENT OUT -SubscriptionId for full Sub Loop on both try and catch
# - Example: $subscriptions = Get-AzSubscription #-SubscriptionId "345395af-dab3-4547-9ebb-bbb00ceffcac"
try {
    $subscriptions = Get-AzSubscription -SubscriptionId "SUBSCRIPTION_ID"
}
catch {
    $subscriptions = Get-AzureRMSubscription -SubscriptionId "SUBSCRIPTION_ID"
}

#Do not edit below this line
#___________________________

#Starting script to loop through all VMs
$report = @()

foreach ($subscription in $subscriptions) {
    # Set subscription
    try {
        Set-AzContext $subscription
    }
    catch {
        Set-AzureRMContext $subscription
    }
    $subscription = Get-AzContext
    $subscriptionName = $subscription.Subscription.Name
    $subId = $subscription.Subscription.Id
    
    # Grab all VMs in subscription
    try {
        $vms = Get-AzVM
    }
    catch {
        $vms = Get-AzureRMVM
    }
    
    # Grab all NICs in subscription
    try {
        $vmNics = Get-AzNetworkInterface
    }
    catch {
        $vmNics = Get-AzureRMNetworkInterface
    }
    
    # Grab all VNet Data in subscription
    try {
        $vnets = Get-AzVirtualNetwork
    }
    catch {
        $vnets = Get-AzureRMVirtualNetwork
    }
    
    # Grab all Route Tables in subscription
    try {
        $routeTables = Get-AzRouteTable
    }
    catch {
        $routeTables = Get-AzureRMRouteTable
    }
    

    Write-Host -ForegroundColor Green "Located" $($vms.Count) "Virtual Machines within subscription" $($subscriptionName)
    $counterPosition = 1

    foreach ($vm in $vms) {
        Write-Host -ForegroundColor Green "Pulling info for virtual machine" $($vm.Name) "within" $($subscriptionName) "-" $($counterPosition)"/"$($vms.Count)
        $info = "" | Select-Object vmName, applicationID, vmLocation, resourceGroupName, subscriptionName, subscriptionID, vmIP, vmSubnetName, SubnetCIDR, NextHopIpAddress, subnetRouteTableName
        
        # Array of NIC IDs
        $vmNicIds = $vmNics.Id
        # Index of NIC IDs
        $vmNicIdIndex = [array]::IndexOf($vmNicIds, $vm.NetworkProfile.NetworkInterfaces[0].Id)
        # VM NIC - acquired from $vmNics object 
        $vmNic = $vmNics[$vmNicIdIndex]

        # VM NIC Subnet ID
        $vmNicSubnetId = $vmNic.IpConfigurations.Subnet.Id

        # Splitting Subnet ID into array to obtain Subnet Name
        $vmNicSubnetIdSPLIT = $vmNicSubnetId.Split("/")
        # Assigning Subnet Name to variable
        $vmNicSubnetName = $vmNicSubnetIdSPLIT[-1]

        # Splitting Subnet ID into array to obtain VNET ID
        $vmNicSubnetIdSPLITVNET = $vmNicSubnetId.Split("/subnets/")
        # Assigning VNET ID to variable
        $vmNicVnetId = $vmNicSubnetIdSPLITVNET[0]

        # Array of VNET IDs
        $vnetIds = $vnets.Id
        # Index of VNET IDs
        $vmVnetIdIndex = [array]::IndexOf($vnetIds, $vmNicVnetId)
        # VM NIC VNET - acquired from $vnets object
        $vmVnet = $vnets[$vmVnetIdIndex]

        # Array of VNET Subnet IDs
        $vmVnetSubnetIds = $vmVnet.Subnets.Id
        # Index of VNET Subnet IDs
        $vmVnetSubnetIdIndex = [array]::IndexOf($vmVnetSubnetIds, $vmNicSubnetId)
        # VM NIC Subnet - acquired from $vmVnet.Subnets object
        $vmNicSubnet = $vmVnet.Subnets[$vmVnetSubnetIdIndex]

        # Subnet Address Prefix (CIDR)
        $vmNicSubnetCIDR = $vmNicSubnet.AddressPrefix[0]

        # Determine if Route Table exists and assign the respective Route Table Name accordingly
        if ($vmNicSubnet.RouteTable) {
            # Assigning Route Table ID to variable
            $vmNicSubnetRouteTableID = $vmNicSubnet.RouteTable.Id
            # Splitting Subnet Route Table ID into array to obtain Route Table Name
            $vmNicSubnetRouteTableIDSPLIT = $vmNicSubnetRouteTableID.Split("/")
            # Subnet Route Table
            $vmNicSubnetRouteTableName = $vmNicSubnetRouteTableIDSPLIT[-1]
        }
        else {
            $vmNicSubnetRouteTableName = ""
        }

        if ($vmNicSubnetRouteTableName) {
            # Array of Route Table Names
            $routeTableNames = $routeTables.Name
            # Index of Route Table Namess
            $routeTableNameIndex = [array]::IndexOf($routeTableNames, $vmNicSubnetRouteTableName)
            # VM NIC Route Table - acquired from $routeTables object
            $vmNicRouteTable = $routeTables[$routeTableNameIndex]
            if ($vmNicRouteTable.Routes) {
                # Array of Route Table Names
                $RouteTableRouteNames = $vmNicRouteTable.Routes.Name
                if ($RouteTableRouteNames -contains "Internet-UDR") {
                    # Index of Route Table Names
                    $routeTableRouteNameIndex = [array]::IndexOf($routeTableRouteNames, "Internet-UDR")
                    # VM NIC Route Table
                    $vmNicRouteTableRoute = $vmNicRouteTable.Routes[$routeTableRouteNameIndex]
                    # VM NIC Route Table Route Next Hop IP Address
                    $vmNicRouteTableRouteNextHopIpAddress = $vmNicRouteTableRoute.NextHopIpAddress
                }
                else {
                    $vmNicRouteTableRouteNextHopIpAddress = ""
                }
            }
            else {
                $vmNicRouteTableRouteNextHopIpAddress = ""
            }
        }
        else {
            $vmNicRouteTableRouteNextHopIpAddress = ""
        }

        $info.vmName = $vm.Name
        $info.applicationID = $vm.Tags.ApplicationID
        $info.vmLocation = $vm.Location
        $info.vmIP = $vmNic.IpConfigurations[0].PrivateIpAddress
        $info.vmSubnetName = $vmNicSubnetName
        $info.resourceGroupName = $vm.resourceGroupName
        $info.subscriptionName = $($subscriptionName)
        $info.subscriptionID = $subId
        $info.SubnetCIDR = $vmNicSubnetCIDR
        $info.NextHopIpAddress = $vmNicRouteTableRouteNextHopIpAddress
        $info.subnetRouteTableName = $vmNicSubnetRouteTableName
        $report+=$info
        $counterPosition++

    }
}
$report | Format-Table vmName, applicationID, vmLocation, resourceGroupName, subscriptionName, subscriptionID, vmIP, vmSubnetName, SubnetCIDR, NextHopIpAddress, subnetRouteTableName
$report | Export-Csv -Path $reportSaveLocation -NoTypeInformation

