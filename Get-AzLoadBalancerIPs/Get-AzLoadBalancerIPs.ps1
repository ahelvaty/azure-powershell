# Azure Load Balancer IP Grab
# Instructions: Copy the entire contents of this file and paste into a Powershell session OR run this file from commandline

# Login to Azure
az login

Write-Host "Obtaining List of Subscriptions within your Tenant" -ForegroundColor Blue
# Get list of subscriptions
try {
    $GetSUBS = Get-AzSubscription | Select-Object Id, Name
}
catch {
    $GetSUBS = Get-AzureRMSubscription | Select-Object Id, Name
}
$GetSUBS | Format-Table | Out-String | Write-Host
# Request user input to set subscription
Write-Host 'What Subscription is this Load Balancer located in? (List of Subscriptions is above)' -ForegroundColor Red
$Subscription = Read-Host 'Input Sub ID or NAME (ID if there is a space in the name)'
# Set subscription
try {
    Set-AzContext $Subscription
}
catch {
    Set-AzureRMContext $Subscription
}

# Get list of Load Balancers
try {
    $GETLBs = Get-AzLoadBalancer | Select-Object Name, ResourceGroupName, Location
}
catch {
    $GETLBs = Get-AzureRMLoadBalancer | Select-Object Name, ResourceGroupName, Location
}
$GETLBs | Format-Table | Out-String | Write-Host
# Request user input to set Load Balancer Resource Group
Write-Host "What Resource Group is the Load Balancer located in? (List above)" -ForegroundColor Red
$LoadBalancerRG = Read-Host 'Input Load Balancer Resource Group'
try {
    $GETUPLBs = Get-AzLoadBalancer -ResourceGroupName $LoadBalancerRG | Select-Object Name, ResourceGroupName, Location
}
catch {
    $GETUPLBs = Get-AzureRMLoadBalancer -ResourceGroupName $LoadBalancerRG | Select-Object Name, ResourceGroupName, Location
}
$GETUPLBs | Format-Table | Out-String | Write-Host
# Request user input to set Load Balancer Name
Write-Host "What is the Name of the Load Balancer? (List above)" -ForegroundColor Red
$LoadBalancerName = Read-Host 'Input Load Balancer Name'
# Assign Load Balancer Object to variable
try {
    $LoadBalancerPS = Get-AzLoadBalancer -ResourceGroupName $LoadBalancerRG -Name $LoadBalancerName
}
catch {
    $LoadBalancerPS = Get-AzureRMLoadBalancer -ResourceGroupName $LoadBalancerRG -Name $LoadBalancerName
}

# Get Public IP Addresses in the respective resource group
try {
    $LBPublicIPs = Get-AzPublicIpAddress -ResourceGroupName $LoadBalancerRG
}
catch {
    $LBPublicIPs = Get-AzureRMPublicIpAddress -ResourceGroupName $LoadBalancerRG
}

# Get Network Interfaces in the respective resource group
try {
    $LBNICs = Get-AzNetworkInterface -ResourceGroupName $LoadBalancerRG
}
catch {
    $LBNICs = Get-AzureRMNetworkInterface -ResourceGroupName $LoadBalancerRG
}

# Determine and Assign file path
$DesktopPath = [Environment]::GetFolderPath("Desktop")
Write-Host "The path to your Desktop is: " $DesktopPath -ForegroundColor Green
$FileCreationDate = Get-Date -Format "MM-dd-yyyy"
$FileName = "azureLBIPGrab_" + $FileCreationDate + ".csv"
$PathToFile = $DesktopPath + "/" + $FileName
Write-Host "The path to your Azure Load Balancer IP Grab .csv file is: " $PathToFile -ForegroundColor Green

# IMPORTANT: Writing SEP to Excel file to ensure excel interprets commas as the List Separator
"sep=," | Out-File -FilePath $PathToFile



Write-Host "Writing headers to .csv file" -ForegroundColor Green
# Write headers to .csv
"Inbound NAT Rule" + "," + "Protocol" + "," + "FrontendPort" + "," + "BackendPort" + "," + "FrontendIPConfig" + "," + "DomainNameLabel" + "," + "FQDN" + "," + "Public IP" + "," + "BackendIPNIC" + "," + "BackendIPConfig" + "," + "Private IP" | Out-File -FilePath $PathToFile -Append

Write-Host "On to the Load Balancer Data!" -ForegroundColor Blue
Write-Host "..."
$InboundNATRules = $LoadBalancerPS.InboundNatRules
foreach ($Rule in $InboundNATRules) {
    # Grab the Frontend IP Configuration ID and Name
    $FEIPConfigId = $Rule.FrontendIPConfiguration.Id
    $FEIPConfigIdSPLIT = $FEIPConfigId.Split("/")
    $FEIPConfigName = $FEIPConfigIdSPLIT[-1]
    # Grab the Public IP from the Frontend IP Configuration
    $FEIPPublicIPNameArray = $LBPublicIPs.Name
    $FEIPPublicIPNameIndex = [array]::IndexOf($FEIPPublicIPNameArray, $FEIPConfigName)
    $FEIPPublicIP = $LBPublicIPs[$FEIPPublicIPNameIndex].IpAddress
    # Grab the PIP Domain Name Label (DNL) from the Frontend IP Configuration
    $FEIPPublicIPDNL = $LBPublicIPs[$FEIPPublicIPNameIndex].DnsSettings.DomainNameLabel
    # Grab the PIP Fully Qualified Domain Name (FQDN) from the Frontend IP Configuration
    $FEIPPublicIPFQDN = $LBPublicIPs[$FEIPPublicIPNameIndex].DnsSettings.Fqdn
    # Grab the Backend IP Configuration ID, NIC, and Name
    $BEIPConfigId = $Rule.BackendIPConfiguration.Id
    foreach ($NIC in $LBNICs) {
        if ($BEIPConfigId -match $NIC.Name) {
            $NICName = $NIC.Name
        }
    }
    $BEIPConfigIdSPLIT = $BEIPConfigId.Split("/")
    $BEIPConfigName = $BEIPConfigIdSPLIT[-1]
    # Grab the List of IP Configurations on the NIC
    $BEIPNICNameArray = $LBNICs.Name
    $BEIPNICNameIndex = [array]::IndexOf($BEIPNICNameArray, $NICName)
    $BEIPNIC = $LBNICs[$BEIPNICNameIndex]
    $BEIPNICIPConfigsArray = $BEIPNIC.IpConfigurations
    # Grab the Private IP from the Backend IP Configuration
    $BEIPNICIPConfigsIndex = [array]::IndexOf($BEIPNICIPConfigsArray, $BEIPConfigName)
    $BEIPNICIPConfigPrivateIP = $BEIPNICIPConfigsArray[$BEIPNICIPConfigsIndex].PrivateIpAddress
    # Write LB information to CSV
    $Rule.Name + "," + $Rule.Protocol + "," + $Rule.FrontendPort + "," + $Rule.BackendPort + "," + $FEIPConfigName + "," + $FEIPPublicIPDNL + "," + $FEIPPublicIPFQDN + "," + $FEIPPublicIP + "," + $NICName + "," + $BEIPConfigName + "," + $BEIPNICIPConfigPrivateIP | Out-File -FilePath $PathToFile -Append
}
Write-Host "Done!"
Write-Host "..."

Write-Host "The Azure Load Balancer Grab is Finished!" -ForegroundColor Blue
