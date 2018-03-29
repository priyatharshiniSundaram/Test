param(
[string]$settingFile="C:\Users\cloudo\Documents\NSG-IAC\Settings\NSG_Input_Settings.json",
[string]$armNsgTemplateFile = "C:\Users\cloudo\Documents\NSG-IAC\Template\nsg-armtemplate.json",
[string]$armSubnetNsgTemplateFile = "C:\Users\cloudo\Documents\NSG-IAC\Template\subnet-armtemplate.json",
[string]$armNicNsgTemplateFile = "C:\Users\cloudo\Documents\NSG-IAC\Template\nic-armtemplate.json",
$unitTestMode=$false
 )
 function Get-SubnetArray {
 param
    (
        [parameter(Mandatory = $true)][System.Object[]]$SubnetInfo
    )
$subnetArray = @()

    for ($i = 0; $i -lt $SubnetInfo.Length; $i++) {
        $SubnetHash = @{}
            #Write-Verbose $SubnetInfo.Length
            $SubnetHash.Add('name', $SubnetInfo[$i].name)
            $SubnetHash.Add('addressPrefix',$SubnetInfo[$i].addressPrefix)
            $SubnetArray += $SubnetHash
    }
                
    return ,$SubnetArray
}
function Get-NicArray {
 param
    (
        [parameter(Mandatory = $true)][System.Object[]]$NicInfo
    )
$nicArray = @()

    for ($i = 0; $i -lt $NicInfo.Length; $i++) {
        $nicHash = @{}
            #Write-Verbose $SubnetInfo.Length
            $nicHash.Add('subnetName', $NicInfo[$i].subnetName)
            $nicHash.Add('name',$NicInfo[$i].name)
            $nicHash.Add('ipConfigName',$NicInfo[$i].ipConfigName)
            $nicHash.Add('privateIP',$NicInfo[$i].privateIP)
            $nicArray += $nicHash
    }
                
    return ,$nicArray
}
function Get-NsgRulesArray {
    param
    (
        [parameter(Mandatory = $true)][System.Object[]]$SecurityRules
    )

    $NsgRulesArray = @()

    for ($i = 0; $i -lt $SecurityRules.length; $i++) {
        $SecurityRulesHash = @{}
           # Write-Verbose "Add subnet $($Subnets[$i].name) - $($Subnets[$i].addressPrefix)" -Verbose
            $SecurityRulesHash.Add('name', $SecurityRules[$i].name)
            $SecurityRulesHash.Add('description', $SecurityRules[$i].description)
            $SecurityRulesHash.Add('direction', $SecurityRules[$i].direction)
            $SecurityRulesHash.Add('priority', $SecurityRules[$i].priority)
            $SecurityRulesHash.Add('sourceAddressPrefix', $SecurityRules[$i].sourceAddressPrefix)
            $SecurityRulesHash.Add('destinationAddressPrefix', $SecurityRules[$i].destinationAddressPrefix)
            $SecurityRulesHash.Add('sourcePortRange', $SecurityRules[$i].sourcePortRange)
            $SecurityRulesHash.Add('destinationPortRange', $SecurityRules[$i].destinationPortRange)
            $SecurityRulesHash.Add('access', $SecurityRules[$i].access)
            $SecurityRulesHash.Add('protocol', $SecurityRules[$i].protocol)
            $NsgRulesArray += $SecurityRulesHash
    }
                
    return ,$NsgRulesArray
}

function Test-ParameterSet1
{
    param
    (
        [parameter(Mandatory = $true)][System.Object]$settings
    )
     if ($null -eq $applicationFileJson.subscriptions) {throw "Missing subscriptions field in settings file"}
    foreach ($subscription in $applicationFileJson.subscriptions)
    {
        if ($null -eq $subscription.subscriptionId) {throw "Missing subscription Id field in settings file"}
         if ($null -eq $settings.applicationName) {throw "Missing applicationName in settings file for $($subscription.subscriptionId)"}
        if ($null -eq $settings.environmentName) {throw "Missing virtualNetworkName in settings file for $($subscription.subscriptionId)"}
        foreach ($vault in $settings.workLoads)
		{
			if ($null -eq $vault.resourceGroupName) {throw "Missing resourceGroupName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.networkSecurityGroupSettings.value.name) {throw "Missing NetworkSecurityGroupName in settings file for $($subscription.subscriptionId)"} 
			if ($null -eq $vault.networkSecurityGroupSettings.value.securityRules) {throw "Missing securityRules in settings file for $($subscription.subscriptionId)"}
			if ($null -eq $vault.neworexisting) {throw "Missing parameter new NSG or Existing NSG in settings file for $($subscription.subscriptionId)"}
}		
    } # Subscription
    return $true
 }
 function Test-ParameterSet2
{
    param
    (
        [parameter(Mandatory = $true)][System.Object]$settings
    )
     if ($null -eq $applicationFileJson.subscriptions) {throw "Missing subscriptions field in settings file"}
    foreach ($subscription in $applicationFileJson.subscriptions)
    {
        if ($null -eq $subscription.subscriptionId) {throw "Missing subscription Id field in settings file"}
        foreach ($vault in $settings.Assignment)
		{
		if ($null -eq $vault.nicOrSubnet) {throw "Missing nicOrSubnet in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.nsgName) {throw "Missing nsgName in settings file for $($subscription.subscriptionId)"}
			if ($null -eq $vault.NSGresourceGroupName) {throw "Missing NSGresourceGroupName in settings file for $($subscription.subscriptionId)"}

}		
    } # Subscription
    return $true
 }
 function Publish-NsgRuleConfig()
 {
    #[OutputType([String])]
 param
 (
    [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile,
    [parameter(Mandatory = $true)][string]$resourceGroupName,
    [parameter(Mandatory = $true)][string]$networkSecurityGroupSettings,
    [parameter(Mandatory = $true)][string]$neworexisting,
    [parameter(Mandatory = $true)][string]$noofsecurityrules,
    [parameter(Mandatory = $true)][string]$environmentName
 )try {
    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction Stop   
}
catch {
    $resourceGroup = $null
}
if ($null -eq $resourceGroup)
{
    $message = "Resource group $resourceGroupName not found, deployment stop"
    Write-Verbose $message
    return $message
}
else 
    {
        # Prepare deployment variables
		Write-Verbose "ResourceGroup Found"
			
        $networkSecurityGroupSettingsJson = Get-JsonParameterSet -settingsFileName $networkSecurityGroupSettings

        if($neworexisting -eq "new")
        {
            #New NSG & SecurityRules Config
            Write-Verbose "Deployment Started - Creating New NSG under ResourceGroup $($armDeployment.ResourceGroupName)"
            $newNsgRuledeploymentParameters =  @{}
            $newNsgRuledeploymentParameters.Add('neworExisting',$neworexisting)
            $newNsgRuledeploymentParameters.Add('environment',$environmentName)
            $newNsgRuledeploymentParameters.Add('noofsecurityrules', [int] $noofsecurityrules)
            $newNsg = @{}
            $newNsg.Add('name',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.name)
            $newNsg.Add('description',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.description)
            $newNsg.Add('direction',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.direction)
            $newNsg.Add('priority',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.priority)
            $newNsg.Add('sourceAddressPrefix',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.sourceAddressPrefix)
            $newNsg.Add('destinationAddressPrefix',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.destinationAddressPrefix)
            $newNsg.Add('sourcePortRange',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.sourcePortRange)
            $newNsg.Add('destinationPortRange',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.destinationPortRange)
            $newNsg.Add('access',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.access)
            $newNsg.Add('protocol',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.protocol)
            $newNsgRulesArray = Get-NsgRulesArray -SecurityRules $networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.securityRules
            $newNsg.Add('securityRules',$newNsgRulesArray)
            $newNsgRuledeploymentParameters.Add('networkSecurityGroupSettings',$newNsg)
            $deploymentParameters = $newNsgRuledeploymentParameters
        } 
        else {
            Write-Verbose "Deployment Started - Creating Security rule's on Existing NSG under ResourceGroup $($armDeployment.ResourceGroupName)"
            $existingNsgRuledeploymentParameters =  @{}
            $existingNsgRuledeploymentParameters.Add('neworExisting',$neworexisting)
            $existingNsgRuledeploymentParameters.Add('environment',$environmentName)
            $existingNsgRuledeploymentParameters.Add('noofsecurityrules', [int] $noofsecurityrules)
            $existingNsg = @{}
            $existingNsg.Add('name',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.name)
            $existingNsg.Add('description',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.description)
            $existingNsg.Add('direction',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.direction)
            $existingNsg.Add('priority',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.priority)
            $existingNsg.Add('sourceAddressPrefix',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.sourceAddressPrefix)
            $existingNsg.Add('destinationAddressPrefix',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.destinationAddressPrefix)
            $existingNsg.Add('sourcePortRange',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.sourcePortRange)
            $existingNsg.Add('destinationPortRange',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.destinationPortRange)
            $existingNsg.Add('access',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.access)
            $existingNsg.Add('protocol',$networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.protocol)
            $newNsgSRulesArray = Get-NsgRulesArray -SecurityRules $networkSecurityGroupSettingsJson.WorkLoads.networkSecurityGroupSettings.value.securityRules
            $existingNsg.Add('securityRules',$newNsgSRulesArray)
            $existingNsgRuledeploymentParameters.Add('networkSecurityGroupSettings',$existingNsg)
            $deploymentParameters = $existingNsgRuledeploymentParameters
        }
        # Unlock ResourceGroup
		Unlock-ResourceGroup $resourceGroupName
        write-verbose "ResourceGroup Unlocked"
        #Deploy the infrastructure
        Write-Verbose "NSG Creation Template: $armDeploymentTemplateFile"    
       $armDeployment = New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $armDeploymentTemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('yyyyMMdd-HHmm'))`
                                            -ResourceGroupName $resourceGroupName `
                                            -TemplateFile $armDeploymentTemplateFile `
                                            -TemplateParameterObject $deploymentParameters `
                                            -Force 
        Lock-ResourceGroup $resourceGroupName
        Write-Verbose "ResourceGroup Locked"
        Write-Verbose "Deployment on resource group $($armDeployment.ResourceGroupName) $($armDeployment.ProvisioningState) $($armDeployment.Timestamp)"
        return $armDeployment.ProvisioningState
	
    }
}
function Set-NsgAssignment
{
 [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low'
    )]
param
 (
    [parameter(Mandatory = $true)][string]$armNicNsgTemplateFile,
    [parameter(Mandatory = $true)][string]$armSubnetNsgTemplateFile,
    [parameter(Mandatory = $true)][string]$nsgDeploymentSettings,
    [parameter(Mandatory = $true)][string]$nicOrSubnet,
    [parameter(Mandatory = $true)][string]$nsgName,
    [parameter(Mandatory = $true)][string]$nsgResourceGroupName

 )
$AssignmentSettingsJson = Get-JsonParameterSet -settingsFileName $nsgDeploymentSettings
$AssInfo=$AssignmentSettingsJson.Assignment
if($PSCmdlet.ShouldProcess($AssInfo))
 {
if($nicOrSubnet -eq 'subnet')
{
    $noOfSubnet=$AssInfo.subnetSettings.value.subnet.Count
    $VnetRGName=$AssInfo.subnetSettings.value.VNETResourceGrupName
        $subnetDeployment=@{}
        $subnetDeployment.Add('noOfSubnet',[int]$noOfSubnet)
        $subnetDeployment.Add('nsgName',$nsgName)
        $subnetDeployment.Add('nicOrSubnet',$nicOrSubnet)
        $subnetDeployment.Add('NSGresourceGroupName',$nsgResourceGroupName)
        $SubnetArr=@()
        $SubnetArr=Get-SubnetArray ` -SubnetInfo $AssignmentSettingsJson.Assignment.subnetSettings.value.subnet
        $vnetName=$AssignmentSettingsJson.Assignment.subnetSettings.value.VnetNameOfSubnet
        $targetObject=@{}
        $targetObject.Add('subnet',$SubnetArr)
        $targetObject.Add('VnetNameOfSubnet',$vnetName)
        $targetObject.Add('VNETResourceGrupName',$VnetRGName)
        $subnetDeployment.Add('subnetSettings',$targetObject)
        Unlock-ResourceGroup $VnetRGName
        Write-Verbose "$VnetRGName unlocked"
       $armDeployment=New-AzureRmResourceGroupDeployment -ResourceGroupName $VnetRGName -TemplateFile $armSubnetNsgTemplateFile -TemplateParameterObject $subnetDeployment
        Lock-ResourceGroup $VnetRGName
        Write-Verbose "$VnetRGName Locked"
        Write-Verbose "Deployment on resource group $($armDeployment.ResourceGroupName) $($armDeployment.ProvisioningState) $($armDeployment.Timestamp)"
        return $armDeployment.ProvisioningState
    }
    else
    {
        $noOfNic=$AssInfo.nicSettings.value.nic.Count
        $nicRGName=$AssInfo.nicSettings.value.NICResourceGrupName
        $nicDeployment=@{}
        $nicDeployment.Add('noOfNic',[int]$noOfNic)
        $nicDeployment.Add('nsgName',$nsgName)
        $nicDeployment.Add('nicOrSubnet',$nicOrSubnet)
        $nicDeployment.Add('NSGresourceGroupName',$nsgResourceGroupName)
        $nicArr=@()
        Write-Output "Nic resources" $AssignmentSettingsJson.Assignment.nicSettings.value.nic
        $nicArr=Get-NicArray ` -NicInfo $AssignmentSettingsJson.Assignment.nicSettings.value.nic
        $vnetName=$AssignmentSettingsJson.Assignment.nicSettings.value.VnetNameOfNic
        $targetObject=@{}
        $targetObject.Add('nic',$nicArr)
        $targetObject.Add('NICResourceGrupName',$nicRGName)
         $targetObject.Add('VnetNameOfNic',$vnetName)
        $nicDeployment.Add('nicSettings',$targetObject)
        Unlock-ResourceGroup $nicRGName
        Write-Verbose "$nicRGName unlocked"
       $armDeployment= New-AzureRmResourceGroupDeployment -ResourceGroupName $nicRGName -TemplateFile $armNicNsgTemplateFile -TemplateParameterObject $nicDeployment
        Lock-ResourceGroup $nicRGName
        Write-Verbose "$nicRGName Locked"
        Write-Verbose "Deployment on resource group $($armDeployment.ResourceGroupName) $($armDeployment.ProvisioningState) $($armDeployment.Timestamp)"
        return $armDeployment.ProvisioningState
    }
    }
    
}
function Publish-Infrastructure
{
param(
        [parameter(Mandatory = $true)][string]$settingsFileName,
        [parameter(Mandatory = $true)][string]$armNsgTemplateFile,
        [parameter(Mandatory = $true)][string]$armSubnetNsgTemplateFile,
        [parameter(Mandatory = $true)][string]$armNicNsgTemplateFile
     )
    $settings = Get-JsonParameterSet -settingsFileName $settingsFileName
	$deploymentIsSucceeded = $true
    $workloadCount = $settings.WorkLoads.Count
    $AssignmentCount=$settings.Assignment.Count
    Write-Verbose "workloadCounts: $workloadCount"
    Write-Verbose "AssignmentCounts: $AssignmentCount"
    $applicationName = $settings.applicationName
               $environmentName = $settings.environmentName
                $applicationFile = "C:\Users\cloudo\Documents\NSG-IAC\SettingsByWorkload\" + "nv_" + $applicationName + ".workload.json"
                $applicationFile = Get-FileFullPath -fileName $applicationFile  -rootPath $PSScriptRoot
                $applicationFileJson = Get-JsonParameterSet -settingsFileName $applicationFile
                $policyCount = $applicationFileJson.subscriptions.Count
                if($policyCount -ge 1)
                {  
                    for($i = 0;$i -lt $policyCount; $i++)
                    { 
                        if($applicationFileJson.subscriptions[$i].environmentName -eq $environmentName)
                        {
                            $subscriptionId = $applicationFileJson.subscriptions[$i].subscriptionId 
                            Write-Verbose "Environment Subscription: $($subscriptionId)"
                            Set-ContextIfNeeded -SubscriptionId $subscriptionId
                            }
                            }
                            }
    if ($null -ne $settings.WorkLoads) 
	{
        for($i = 0;$i -lt $workloadCount; $i++)
            { 
               
                $null = Test-ParameterSet1 -settings $settings
                $policyCount = $applicationFileJson.subscriptions.Count
                            foreach ($nsg in $settings.WorkLoads)
                            {
                                $neworexisting = $nsg.neworexisting
								$resourceGroupName = $nsg.resourceGroupName
           						$noofsecurityrules = $nsg.networkSecurityGroupSettings.value.securityRules.Length  
                                Write-Verbose ""
                                Write-Verbose "Ready to start deployment in subscription $subscriptionId under resource group: $resourceGroupName"
                                $result = Publish-NsgRuleConfig `
                                -armDeploymentTemplateFile $armNsgTemplateFile `
                                -resourceGroupName $resourceGroupName `
								-networkSecurityGroupSettings $settingsFileName `
								-noofsecurityrules $noofsecurityrules `
								-neworexisting $neworexisting `
                                -environmentName $environmentName	
                                if ($result -ne 'Succeeded') {$deploymentIsSucceeded = $false}
                                 
                            
                        
                    }
                
                if ($deploymentIsSucceeded -eq $false) 
    {
        $errorID = 'Deployment failure'
        $errorCategory = [System.Management.Automation.ErrorCategory]::LimitsExceeded
        $errorMessage = 'Deployment failed'
        $exception = New-Object -TypeName System.SystemException -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,$errorID, $errorCategory, $null
        Throw $errorRecord
    }
    else 
    {
       Write-Verbose "Security Rules added to the NSG !!!" 
         
    }
            }
           
            }
             if($null -ne $settings.Assignment) 
            {
            $null = Test-ParameterSet2 -settings $settings
            foreach ($op in $settings.Assignment)
                            {
                           $nsgName=$op.nsgName
                            $nsgResourceGroupName=$op.NSGresourceGroupName
                            $nicOrSubnet=$op.nicOrSubnet
                                Write-Verbose "Ready to start NSG Rules Assignment in subscription $subscriptionId from NSG resource group: $nsgResourceGroupName"
                                $result = Set-NsgAssignment `
                                -armNicNsgTemplateFile $armNicNsgTemplateFile `
                                -armSubnetNsgTemplateFile $armSubnetNsgTemplateFile `
								-nsgDeploymentSettings $settingsFileName `
                                -nicOrSubnet $nicOrSubnet `
                                -nsgName $nsgName `
                                -nsgResourceGroupName $nsgResourceGroupName
                                if ($result  -ne 'Succeeded') {$deploymentIsSucceeded = $false}   
                            }if ($deploymentIsSucceeded -eq $false) 
    {
        $errorID = 'Deployment failure'
        $errorCategory = [System.Management.Automation.ErrorCategory]::LimitsExceeded
        $errorMessage = 'Deployment failed'
        $exception = New-Object -TypeName System.SystemException -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,$errorID, $errorCategory, $null
        Throw $errorRecord
    }
    else 
    {
        return $true    
    }
            
         }
   
}

 if ($unitTestMode)
{
    #do nothing
    Write-Verbose 'Unit test mode, no deployment' -Verbose
}
else 
{
    #Log in Azure if not already done
    try 
    {
        $azureRmContext = Get-AzureRmContext -ErrorAction Stop
    }
    catch 
    {
      #Write-Verbose "Subscription is not found" 
      $result = Add-AzureRmAccount
      $azureRmContext = $result.Context 
       
    }
    Write-Verbose "Subscription Id : $($azureRmContext.Subscription.Id)" -Verbose
    $VerbosePreference = 'Continue'

    # Get required setting files and path. Throw if not found

    $armNsgTemplateFile = Get-FileFullPath -fileName $armNsgTemplateFile -rootPath $PSScriptRoot
    $armSubnetNsgTemplateFile = Get-FileFullPath -fileName $armSubnetNsgTemplateFile -rootPath $PSScriptRoot
    $armNsgTemplateFile = Get-FileFullPath -fileName $armNsgTemplateFile -rootPath $PSScriptRoot
    $settingsFileName = Get-FileFullPath -fileName $settingFile -rootPath $PSScriptRoot
	  
	Write-Verbose "Full path of NSGRuleTemplate File: $armDeploymentTemplateFile" -Verbose
    Write-Verbose "Full path of NSGAssignmentTemplate File: $armAssignmentTemplateFile" -Verbose
    Write-Verbose "Full path of Setting File: $settingsFileName" -Verbose
   
    # Deploy infrastructure
    return Publish-Infrastructure `
       -settingsFileName $settingsFileName `
        -armNsgTemplateFile $armNsgTemplateFile `
        -armSubnetNsgTemplateFile $armSubnetNsgTemplateFile `
        -armNicNsgTemplateFile $armNicNsgTemplateFile    
}