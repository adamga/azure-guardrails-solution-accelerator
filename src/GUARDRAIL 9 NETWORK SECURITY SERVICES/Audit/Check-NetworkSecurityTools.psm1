function Check-NetworkSecurityTools {
    param (
        [Parameter(Mandatory=$true)]
        [string] $ControlName,
        [Parameter(Mandatory=$true)]
        [string] $ItemName,
        [Parameter(Mandatory=$true)]
        [string] $itsgcode,
        [Parameter(Mandatory=$true)]
        [hashtable] $msgTable,
        [Parameter(Mandatory=$true)]
        [string] $ReportTime,
        [string] $CloudUsageProfiles = "3",
        [string] $ModuleProfiles,
        [switch] $EnableMultiCloudProfiles
    )

    $ResultsList = [System.Collections.ArrayList]::new()
    $ErrorList = [System.Collections.ArrayList]::new()

    try {
        $subs = Get-AzSubscription -ErrorAction Stop | 
                Where-Object { $_.State -eq 'Enabled' }
    }
    catch {
        $errorMessage = "Failed to get subscriptions. Error: $_"
        $ErrorList.Add($errorMessage)
        throw $errorMessage
    }

    foreach ($sub in $subs) {
        $IsCompliant = $false
        $Comments = ""
        
        try {
            Select-AzSubscription -SubscriptionObject $sub | Out-Null

            # Check for Azure Firewall
            $azureFirewalls = Get-AzFirewall -ErrorAction SilentlyContinue
            
            # Check for third-party firewall VMs from various vendors
            $allVMs = Get-AzVM -ErrorAction SilentlyContinue
            $firewallVMs = @()
            $detectedFirewallType = ""
            
            if ($allVMs) {
                foreach ($vm in $allVMs) {
                    $publisher = $vm.StorageProfile.ImageReference.Publisher
                    $offer = $vm.StorageProfile.ImageReference.Offer
                    
                    # Check for various firewall vendors
                    if ($publisher -eq "fortinet" -and $offer -like "*fortinet*fortigate*") {
                        $firewallVMs += $vm
                        $detectedFirewallType = "Fortigate Firewall"
                    }
                    elseif ($publisher -eq "paloaltonetworks" -and ($offer -like "vmseries*")) {
                        $firewallVMs += $vm
                        $detectedFirewallType = "Palo Alto Networks VM-Series Firewall"
                    }
                    elseif ($publisher -eq "checkpoint" -and $offer -like "check-point-cg-*") {
                        $firewallVMs += $vm
                        $detectedFirewallType = "Check Point CloudGuard Firewall"
                    }
                    elseif ($publisher -eq "cisco" -and ($offer -like "*firepower*" -or $offer -like "*fmcv*")) {
                        $firewallVMs += $vm
                        $detectedFirewallType = "Cisco Firepower Firewall"
                    }
                    elseif ($publisher -eq "barracudanetworks" -and $offer -like "*barracuda*firewall*") {
                        $firewallVMs += $vm
                        $detectedFirewallType = "Barracuda CloudGen Firewall"
                    }
                    elseif ($publisher -eq "sophos" -and $offer -like "*sophos*firewall*") {
                        $firewallVMs += $vm
                        $detectedFirewallType = "Sophos XG Firewall"
                    }
                    elseif ($publisher -eq "juniper-networks" -and $offer -like "*vsrx*") {
                        $firewallVMs += $vm
                        $detectedFirewallType = "Juniper vSRX Virtual Firewall"
                    }
                    elseif ($publisher -eq "forcepoint-llc" -and $offer -like "*ngfw*") {
                        $firewallVMs += $vm
                        $detectedFirewallType = "Forcepoint Next-Generation Firewall"
                    }
                }
            }
                        
            # Check for Application Gateway with WAF
            $appGateways = Get-AzApplicationGateway -ErrorAction SilentlyContinue
            $hasWAFEnabled = $false
            
            if ($appGateways) {
                foreach ($ag in $appGateways) {
                    if ($ag.Sku.Tier -like "*WAF*") {
                        $hasWAFEnabled = $true
                        break
                    }
                }
            }

            # Determine compliance and comments
            if ($azureFirewalls.Count -gt 0) {
                $IsCompliant = $true
                $Comments = $msgTable.firewallFound -f "Azure Firewall"
            }
            elseif ($firewallVMs.Count -gt 0) {
                $IsCompliant = $true
                $Comments = $msgTable.firewallFound -f $detectedFirewallType
            }
            elseif ($appGateways.Count -gt 0) {
                if ($hasWAFEnabled) {
                    $IsCompliant = $true
                    $Comments = $msgTable.wAFEnabled
                }
                else {
                    $IsCompliant = $false
                    $Comments = $msgTable.wAFNotEnabled
                }
            }
            else {
                $IsCompliant = $false
                $Comments = $msgTable.noFirewallOrGateway
            }

            $resultObject = [PSCustomObject]@{
                SubscriptionName = $sub.Name
                ComplianceStatus = $IsCompliant
                Comments = $Comments
                ItemName = $ItemName
                ControlName = $ControlName
                itsgcode = $itsgcode
                ReportTime = $ReportTime
            }

            if ($EnableMultiCloudProfiles) {
                $evalResult = Get-EvaluationProfile -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles -SubscriptionId $sub.Id
                if (!$evalResult.ShouldEvaluate) {
                    if ($evalResult.Profile -gt 0) {
                        $resultObject.ComplianceStatus = "Not Applicable"
                        $resultObject | Add-Member -MemberType NoteProperty -Name "Profile" -Value $evalResult.Profile
                        $resultObject.Comments = "Not evaluated - Profile $($evalResult.Profile) not present in CloudUsageProfiles"
                    }
                    else {
                        $ErrorList.Add("Error occurred while evaluating profile configuration")
                    }
                }
                else {
                    $resultObject | Add-Member -MemberType NoteProperty -Name "Profile" -Value $evalResult.Profile
                }
            }

            $ResultsList.Add($resultObject) | Out-Null
        }
        catch {
            $ErrorList.Add("Error processing subscription $($sub.Name): $_")
        }
    }

    return [PSCustomObject]@{
        ComplianceResults = $ResultsList
        Errors = $ErrorList
    }
}