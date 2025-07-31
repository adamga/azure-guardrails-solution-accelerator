#Future Params:
#Security

function Get-DefenderForCloudConfig {
    param (
        [Parameter(Mandatory=$true)]
        [string] $ControlName,
        [string] $itsginfosecdefender,
        [hashtable] $msgTable,
        [Parameter(Mandatory=$true)]
        [string] $ReportTime,
        [Parameter(Mandatory=$false)]
        [string] $CBSSubscriptionName,
        [string] $CloudUsageProfiles = "3",
        [string] $ModuleProfiles,
        [switch] $EnableMultiCloudProfiles,
        [Parameter(Mandatory=$false)]
        [string] $SecurityLAWResourceId
    )

    # Initialize result collections
    $FinalObjectList = [System.Collections.ArrayList]::new()
    $ErrorList = [System.Collections.ArrayList]::new()

    # Get enabled subscriptions
    $sublist = Get-AzSubscription -ErrorAction SilentlyContinue | 
               Where-Object { $_.State -eq 'Enabled' -and $_.Name -ne $CBSSubscriptionName }

    foreach ($sub in $sublist) {
        $result = Get-SubscriptionDefenderConfig -Subscription $sub -MsgTable $msgTable -SecurityLAWResourceId $SecurityLAWResourceId
        
        if ($EnableMultiCloudProfiles) {
            Add-ProfileToResult -Result $result -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles -SubscriptionId $sub.Id
        }

        $FinalObjectList.Add($result)
        $ErrorList.AddRange($result.Errors)
    }

    return [PSCustomObject]@{ 
        ComplianceResults = $FinalObjectList 
        Errors = $ErrorList
    }
}

function Get-SubscriptionDefenderConfig {
    param (
        [Parameter(Mandatory=$true)]
        $Subscription,
        [Parameter(Mandatory=$true)]
        $MsgTable,
        [Parameter(Mandatory=$false)]
        [string] $SecurityLAWResourceId
    )

    Select-AzSubscription -SubscriptionObject $Subscription | Out-Null

    $isCompliant = $true
    $comments = ""
    $errors = [System.Collections.ArrayList]::new()

    # Check if Sentinel is in use - if so, email notifications are not required
    $isSentinelInUse = Test-SentinelInUse -SecurityLAWResourceId $SecurityLAWResourceId
    
    # Check security contact info - only required if Sentinel is not in use
    try {
        $contactInfo = Get-SecurityContactInfo
        if (!$isSentinelInUse -and ([string]::IsNullOrEmpty($contactInfo.emails) -or [string]::IsNullOrEmpty($contactInfo.phone))) {
            $isCompliant = $false
            $comments += $MsgTable.noSecurityContactInfo -f $Subscription.Name
        } elseif ($isSentinelInUse -and ([string]::IsNullOrEmpty($contactInfo.emails) -or [string]::IsNullOrEmpty($contactInfo.phone))) {
            # Sentinel is in use, so we don't require email notifications but mention this in comments
            $comments += $MsgTable.sentinelInUseSoEmailNotRequired -f $Subscription.Name
        }
    } catch {
        $errors.Add("Error getting security contact info: $_")
    }

    # Check defender plans
    try {
        $defenderPlans = Get-AzSecurityPricing -ErrorAction Stop | 
                         Where-Object { $_.Name -notin 'CloudPosture', 'KubernetesService', 'ContainerRegistry' }
        
        if ($defenderPlans.PricingTier -contains 'Free') {
            $isCompliant = $false
            $comments += if ($comments) { " " } else { "" }
            $comments += $MsgTable.notAllDfCStandard -f $Subscription.Name
        }
    } catch {
        $errors.Add("Error checking defender plans: $_")
    }

    return [PSCustomObject]@{
        ComplianceStatus = $isCompliant
        Comments = $comments
        ItemName = $MsgTable.defenderMonitoring
        itsgcode = $itsginfosecdefender
        ControlName = $ControlName
        ReportTime = $ReportTime
        Errors = $errors
    }
}

function Get-SecurityContactInfo {
    $azContext = Get-AzContext
    $token = Get-AzAccessToken -TenantId $azContext.Subscription.TenantId 
    
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + $token.Token
    }
    $restUri = "https://management.azure.com/subscriptions/$($azContext.Subscription.Id)/providers/Microsoft.Security/securityContacts?api-version=2020-01-01-preview"
    $response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader
    return $response.properties
}

function Test-SentinelInUse {
    param(
        [Parameter(Mandatory=$false)]
        [string] $SecurityLAWResourceId
    )
    
    try {
        # If no Security LAW Resource ID provided, check all Log Analytics workspaces in subscription
        $subscriptions = Get-AzSubscription -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Enabled' }
        
        foreach ($sub in $subscriptions) {
            Select-AzSubscription -SubscriptionObject $sub | Out-Null
            
            # If a specific LAW Resource ID is provided, check only that workspace
            if ($SecurityLAWResourceId) {
                $lawSubscription = $SecurityLAWResourceId.Split("/")[2]
                $lawRG = $SecurityLAWResourceId.Split("/")[4]
                $lawName = $SecurityLAWResourceId.Split("/")[8]
                
                # Only check the specified workspace if it's in the current subscription
                if ($sub.Id -eq $lawSubscription) {
                    if (Test-SentinelInWorkspace -SubscriptionId $sub.Id -ResourceGroup $lawRG -WorkspaceName $lawName) {
                        return $true
                    }
                }
            } else {
                # Check all LAW workspaces in current subscription
                $workspaces = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
                foreach ($workspace in $workspaces) {
                    if (Test-SentinelInWorkspace -SubscriptionId $sub.Id -ResourceGroup $workspace.ResourceGroupName -WorkspaceName $workspace.Name) {
                        return $true
                    }
                }
            }
        }
        return $false
    } catch {
        Write-Verbose "Error checking for Sentinel: $_"
        return $false
    }
}

function Test-SentinelInWorkspace {
    param(
        [Parameter(Mandatory=$true)]
        [string] $SubscriptionId,
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroup,
        [Parameter(Mandatory=$true)]
        [string] $WorkspaceName
    )
    
    try {
        # Check for Microsoft Sentinel solutions in the workspace
        $apiUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/intelligencePacks?api-version=2020-08-01"
        $response = Invoke-AzRestMethod -Uri $apiUrl -Method Get
        
        if ($response.StatusCode -eq 200) {
            $intelligencePacks = ($response.Content | ConvertFrom-Json).value
            # Check if SecurityInsights (Microsoft Sentinel) solution is enabled
            $sentinelSolution = $intelligencePacks | Where-Object { $_.Name -eq 'SecurityInsights' -and $_.Enabled -eq $true }
            if ($sentinelSolution) {
                Write-Verbose "Microsoft Sentinel found enabled in workspace $WorkspaceName"
                return $true
            }
        }
        
        # Also check for Microsoft Sentinel workspaces directly via SecurityInsights provider
        $sentinelApiUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.SecurityInsights/workspaces/$WorkspaceName?api-version=2023-02-01"
        $sentinelResponse = Invoke-AzRestMethod -Uri $sentinelApiUrl -Method Get
        
        if ($sentinelResponse.StatusCode -eq 200) {
            Write-Verbose "Microsoft Sentinel workspace found: $WorkspaceName"
            return $true
        }
        
        return $false
    } catch {
        Write-Verbose "Error checking Sentinel in workspace $WorkspaceName : $_"
        return $false
    }
}

function Add-ProfileToResult {
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject] $Result,
        [string] $CloudUsageProfiles,
        [string] $ModuleProfiles,
        [string] $SubscriptionId
    )

    try {
        $evalResult = Get-EvaluationProfile -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles -SubscriptionId $SubscriptionId
        if (!$evalResult.ShouldEvaluate) {
            if ($evalResult.Profile -gt 0) {
                $Result.ComplianceStatus = "Not Applicable"
                $Result | Add-Member -MemberType NoteProperty -Name "Profile" -Value $evalResult.Profile
                $Result.Comments = "Not evaluated - Profile $($evalResult.Profile) not present in CloudUsageProfiles"
            } else {
                $Result.Errors.Add("Error occurred while evaluating profile configuration")
            }
        } else {
            
            $Result | Add-Member -MemberType NoteProperty -Name "Profile" -Value $evalResult.Profile
        }
    }
    catch {
        $Result.Errors.Add("Error getting evaluation profile: $_")
    }
}
