function Test-ExemptionExists {
    param (
        [string] $ScopeId,
        [array]  $requiredPolicyExemptionIds
    )
    $exemptionsIds=(Get-AzPolicyExemption -Scope $ScopeId -ErrorAction SilentlyContinue).Properties.PolicyDefinitionReferenceIds
    [System.Collections.ArrayList] $policyExemptionList = New-Object System.Collections.ArrayList

    if ($null -ne $exemptionsIds)
    {
        foreach ($exemptionId in $exemptionsIds)
        {
            $isExempt = $exemptionId -in $requiredPolicyExemptionIds
            $result = [PSCustomObject] @{
                isExempt = $isExempt 
                exemptionId = $exemptionId
            }
            $policyExemptionList.add($result) | Out-Null
        }
    }

    return $policyExemptionList
}

function Test-ComplianceForSubscription {
    param (
        [System.Object] $obj,
        [System.Object] $subscription,
        [string] $PolicyID,
        [array]  $requiredPolicyExemptionIds,
        [string] $objType
    )
    $strPattern = "/providers/microsoft.authorization/policysetdefinitions/(.*)"
    if ($PolicyID -match $strPattern){
        $PolicyID = $matches[1]
    }
    Write-Host "Get compliance details for Subscription : $($subscription.DisplayName)"
    $complianceDetails = Get-AzPolicyState | Where-Object{ $_.SubscriptionId -eq $($subscription.SubscriptionID) } | Where-Object{ $_.PolicySetDefinitionName -eq $PolicyID}  
    
    If ($null -eq $complianceDetails) {
        Write-Host "No compliance details found for $objType : $($obj.DisplayName) and subscription: $($subscription.DisplayName)"
    }
    else{   
        $complianceDetails = $complianceDetails | Where-Object{$_.PolicyAssignmentScope -like "*$($obj.TenantId)*" }
        $requiredPolicyExemptionIds_smallCaps = @()
        foreach ($str in $requiredPolicyExemptionIds) {
            $requiredPolicyExemptionIds_smallCaps += $str.ToLower()
        }
        # Filter for GR7 required policies
        $complianceDetails = $complianceDetails | Where-Object{ $_.PolicyDefinitionReferenceId -in $requiredPolicyExemptionIds_smallCaps}
        
        if ($objType -eq "subscription"){
            Write-Host "$($complianceDetails.count) Compliance details found for subscription: $($subscription.DisplayName)"
        }
        else {
            Write-Host "$($complianceDetails.count) Compliance details found for $objType : $($obj.DisplayName) and subscription: $($subscription.DisplayName)"                            
        }
        
    }

    return $complianceDetails
}

function Check-StatusDataInTransit {
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param (
        [System.Object] $objList,
        [string] $objType, #subscription or management Group
        [array]  $requiredPolicyExemptionIds,
        [string] $PolicyID,
        [string] $ControlName,
        [string] $ItemName,
        [string] $LogType,
        [string] $itsgcode,
        [hashtable] $msgTable,
        [Parameter(Mandatory=$true)]
        [string] $ReportTime,
        [string] $CloudUsageProfiles = "3",  # Passed as a string
        [string] $ModuleProfiles,
        [switch] $EnableMultiCloudProfiles # New feature flag, default to false    
    )   
    [System.Collections.ArrayList] $tempObjectList = New-Object System.Collections.ArrayList

    foreach ($obj in $objList)
    {
        Write-Verbose "Checking $objType : $($obj.Name)"
        Write-Verbose "PBMM policy PolicyID is $PolicyID"

        # Find scope
        if ($objType -eq "subscription"){
            $tempId="/subscriptions/$($obj.Id)"
        }
        else {
            $tempId=$obj.Id                              
        }
        Write-Host "Scope is $tempId"
        
        # Find assigned policy list from PBMM policy for the scope
        $AssignedPolicyList = Get-AzPolicyAssignment -scope $tempId -PolicyDefinitionId $PolicyID
        If ($null -eq $AssignedPolicyList -or (-not ([string]::IsNullOrEmpty(($AssignedPolicyList.Properties.NotScopesScope)))))
        {
            # PBMM initiative not applied
            $ComplianceStatus=$false
            $Comment = $msgTable.isNotCompliant + ' ' + $msgTable.pbmmNotApplied 
           
        }
        else {
            # PBMM initiative applied
            $Comment = $msgTable.pbmmApplied

            # List the policies within the PBMM initiative (policy set definition)
            $policySetDefinition = Get-AzPolicySetDefinition -Id $PolicyID
            $listPolicies = $policySetDefinition.Properties.policyDefinitions

            # Check all required policies are applied for this scope
            $appliedPolicies = $listPolicies.policyDefinitionReferenceId | Where-Object { $requiredPolicyExemptionIds -contains $_ }
            if($appliedPolicies.Count -ne $requiredPolicyExemptionIds.Count){
                # some required policies are not applied
                $ComplianceStatus=$false
                $Comment = $msgTable.isNotCompliant + ' ' + $Comment + ' ' + $msgTable.reqPolicyNotApplied
            }
            else{
                # All required policies are applied
                $Comment += ' ' + $msgTable.reqPolicyApplied

                # PBMM is applied and not excluded. Testing if specific policies haven't been excluded.
                $policyExemptionList = Test-ExemptionExists -ScopeId $tempId -requiredPolicyExemptionIds $requiredPolicyExemptionIds
                $exemptList = $policyExemptionList.exemptionId
                if ($ExemptList.Count -gt 0){   
                    # join all exempt policies to a string
                    $exemptListAllPolicies = $exemptList -join ", "
                    # boolean, exemption for GR7 required policies exists.
                    $ComplianceStatus=$false
                    $Comment += ' '+ $msgTable.grExemptionFound -f $exemptListAllPolicies
                }
                else {
                    # Required Policy Definitions are not exempt. Find compliance details for the assigned PBMM policy
                    $Comment += ' ' + $msgTable.grExemptionNotFound

                    # Check the number of resources and compliance for the required policies in applied PBMM initiative
                    # ----------------#
                    # Subscription
                    # ----------------#
                    if ($objType -eq "subscription"){
                        Write-Host "Find compliance details for Subscription : $($obj.Name)"
                        $subscription = @()
                        $subscription += New-Object -TypeName psobject -Property ([ordered]@{'DisplayName'=$obj.Name;'SubscriptionID'=$obj.Id})
                        
                        $currentSubscription = Get-AzContext
                        if($currentSubscription.Subscription.Id -ne $subscription.SubscriptionId){
                            # Set Az context to this subscription
                            Set-AzContext -SubscriptionId $subscription.SubscriptionID
                            Write-Host "AzContext set to $($subscription.DisplayName)"
                        }
    
                        $complianceDetailsSubscription = Test-ComplianceForSubscription -obj $obj -subscription $subscription -PolicyID $PolicyID -requiredPolicyExemptionIds $requiredPolicyExemptionIds -objType $objType
                        if ($null -eq $complianceDetailsSubscription) {
                            Write-Host "Compliance details for $($subscription.DisplayName) outputs as NULL"
                            $complianceDetailsList = $null
                        }
                        else{
                            $complianceDetailsList = $complianceDetailsSubscription | Select-Object `
                                Timestamp, ResourceId, ResourceLocation, ResourceType, SubscriptionId, `
                                ResourceGroup, PolicyDefinitionName, ManagementGroupIds, PolicyAssignmentScope, IsCompliant, `
                                ComplianceState, PolicyDefinitionAction, PolicyDefinitionReferenceId, ResourceTags, ResourceName
                        } 
                    }
                    else {
                        # For management groups, we don't check resource compliance details directly
                        $complianceDetailsList = $null
                    }

                    if ($null -eq $complianceDetailsList) {
                        # PBMM applied but complianceDetailsList is null i.e. no resources in this subscription to apply the required policies
                        Write-Host "Check for compliance details; outputs as NULL"
                        $resourceCompliant = 0 
                        $resourceNonCompliant = 0
                        $totalResource = 0
                        $countResourceCompliant = 0 
                        $countResourceNonCompliant = 0          
                    }
                    else{
                        # check the compliant & non-compliant resources only for required policies
                        $totalResource = $complianceDetailsList.Count
    
                        # Compliant resources
                        $resourceCompliant = $complianceDetailsList | Where-Object {$_.ComplianceState -eq "Compliant"}
                        $countResourceCompliant = $resourceCompliant.Count
    
                        # Non-compliant resources
                        $resourceNonCompliant = $complianceDetailsList | Where-Object {$_.ComplianceState -eq "NonCompliant"}
                        if (-not ($resourceNonCompliant -is [System.Array])) {
                            $resourceNonCompliant = @($resourceNonCompliant)
                        }
                        $countResourceNonCompliant = $resourceNonCompliant.Count
                    }
                    
                    # At this point PBMM initiative is applied. All required policies are applied. No exemption.
                    # Count Compliant & non-compliant resources and Total resources
                    if($totalResource -eq 0){
                        # complianceDetailsList is null i.e no resources to apply the required policies in this subscription
                        $ComplianceStatus=$true
                        $Comment = $msgTable.isCompliant + ' ' + $Comment + ' '+ $msgTable.noResource
                    }
                    elseif($totalResource -gt 0 -and ($countResourceCompliant -eq $totalResource)){
                        # All resources are compliant
                        $ComplianceStatus=$true
                        $Comment = $msgTable.isCompliant + ' ' + $Comment + ' '+ $msgTable.allCompliantResources
                    }
                    elseif($totalResource -gt 0 -and ($countResourceNonCompliant -eq $totalResource)){
                        # All resources are non-compliant
                        $ComplianceStatus=$false
                        $Comment = $msgTable.isNotCompliant + ' ' + $Comment + ' '+ $msgTable.allNonCompliantResources
                    }
                    elseif($totalResource -gt 0 -and $countResourceNonCompliant -gt 0 -and ($countResourceNonCompliant -lt $totalResource)){
                        # There are some resources that are non-compliant
                        $ComplianceStatus=$false
                        $Comment = $msgTable.isNotCompliant + ' ' + $Comment + ' '+ $msgTable.hasNonComplianceResounce -f $countResourceNonCompliant, $totalResource
                    }
                    else{
                        # All use cases are covered by now. Anything else?
                        # Do nothing 
                    }                   
                }

            }
        }

        # Add to the Object List 
        if ($null -eq $obj.DisplayName){
            $DisplayName=$obj.Name
        }
        else {
            $DisplayName=$obj.DisplayName
        }

        $c = New-Object -TypeName PSCustomObject -Property @{ 
            Type = [string]$objType
            Id = [string]$obj.Id
            Name = [string]$obj.Name
            DisplayName = [string]$DisplayName
            ComplianceStatus = [boolean]$ComplianceStatus
            Comments = [string]$Comment
            ItemName = [string]$ItemName
            itsgcode = [string]$itsgcode
            ControlName = [string]$ControlName
            ReportTime = [string]$ReportTime
        }

        if ($EnableMultiCloudProfiles) {
            if ($objType -eq "subscription") {
                $evalResult = Get-EvaluationProfile -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles -SubscriptionId $obj.Id
            } else {
                $evalResult = Get-EvaluationProfile -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles
            }
            
            if (!$evalResult.ShouldEvaluate) {
                if ($evalResult.Profile -gt 0) {
                    $c.ComplianceStatus = "Not Applicable"
                    $c | Add-Member -MemberType NoteProperty -Name "Profile" -Value $evalResult.Profile
                    $c.Comments = "Not evaluated - Profile $($evalResult.Profile) not present in CloudUsageProfiles"
                } else {
                    $ErrorList.Add("Error occurred while evaluating profile configuration")
                }
            } else {
                
                $c | Add-Member -MemberType NoteProperty -Name "Profile" -Value $evalResult.Profile
            }
        }        

        $tempObjectList.add($c)| Out-Null
    }
    return $tempObjectList
}

function Verify-ProtectionDataInTransit {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
            [string] $ControlName,
            [string] $ItemName,
            [string] $PolicyID, 
            [string] $itsgcode,
            [hashtable] $msgTable,
            [Parameter(Mandatory=$true)]
            [string] $ReportTime,
            [Parameter(Mandatory=$false)]
            [string] $CBSSubscriptionName,
            [string] $CloudUsageProfiles = "3",  # Passed as a string
            [string] $ModuleProfiles,  # Passed as a string
            [switch] $EnableMultiCloudProfiles # New feature flag, default to false    
    )
    $FinalObjectList = [System.Collections.ArrayList]@()
    $ErrorList = [System.Collections.ArrayList]@()
    $grRequiredPolicies=@("FunctionAppShouldOnlyBeAccessibleOverHttps","WebApplicationShouldOnlyBeAccessibleOverHttps", "ApiAppShouldOnlyBeAccessibleOverHttps", "OnlySecureConnectionsToYourRedisCacheShouldBeEnabled","SecureTransferToStorageAccountsShouldBeEnabled")
    #Check management groups
    try {
        $objs = Get-AzManagementGroup -ErrorAction Stop
    }
    catch {
        $Errorlist.Add("Failed to execute the 'Get-AzManagementGroup' command--verify your permissions and the installion of the Az.Resources module; returned error message: $_")
        throw "Error: Failed to execute the 'Get-AzManagementGroup' command--verify your permissions and the installion of the Az.Resources module; returned error message: $_"
    }
    [string]$type = "Management Group"
    if($EnableMultiCloudProfiles) {
        $FinalObjectList+=Check-StatusDataInTransit -objList $objs -objType $type -itsgcode $itsgcode -requiredPolicyExemptionIds $grRequiredPolicies -PolicyID $PolicyID -ReportTime $ReportTime -ItemName $ItemName -LogType $LogType -msgTable $msgTable -ControlName $ControlName -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles -EnableMultiCloudProfiles
    }
    else {
        $FinalObjectList+=Check-StatusDataInTransit -objList $objs -objType $type -itsgcode $itsgcode -requiredPolicyExemptionIds $grRequiredPolicies -PolicyID $PolicyID -ReportTime $ReportTime -ItemName $ItemName -LogType $LogType -msgTable $msgTable -ControlName $ControlName
    }
    #Check Subscriptions
    try {
        $objs = Get-AzSubscription -ErrorAction Stop | Where-Object {$_.State -eq "Enabled"} 
    }
    catch {
        $Errorlist.Add("Failed to execute the 'Get-AzSubscription' command--verify your permissions and the installion of the Az.Resources module; returned error message: $_")
        throw "Error: Failed to execute the 'Get-AzSubscription' command--verify your permissions and the installion of the Az.Resources module; returned error message: $_"
    }
    [string]$type = "subscription"

    if ($EnableMultiCloudProfiles) {   
        $FinalObjectList+=Check-StatusDataInTransit -objList $objs -objType $type -itsgcode $itsgcode -requiredPolicyExemptionIds $grRequiredPolicies -PolicyID $PolicyID -ReportTime $ReportTime -ItemName $ItemName -LogType $LogType -msgTable $msgTable  -ControlName $ControlName -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles -EnableMultiCloudProfiles
    }
    else {
        $FinalObjectList+=Check-StatusDataInTransit -objList $objs -objType $type -itsgcode $itsgcode -requiredPolicyExemptionIds $grRequiredPolicies -PolicyID $PolicyID -ReportTime $ReportTime -ItemName $ItemName -LogType $LogType -msgTable $msgTable -ControlName $ControlName
    } 
    $moduleOutput= [PSCustomObject]@{ 
        ComplianceResults = $FinalObjectList 
        Errors=$ErrorList
        AdditionalResults = $AdditionalResults
    }
    return $moduleOutput  
}

