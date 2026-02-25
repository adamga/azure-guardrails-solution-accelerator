Import-Module '.\src\GUARDRAIL 1 PROTECT USER ACCOUNTS AND IDENTITIES\Audit\Check-UserAccountGCEventLogging.psm1'

Describe "Check-UserAccountGCEventLogging" {
    BeforeAll {
        $LAWResourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-logging/providers/Microsoft.OperationalInsights/workspaces/law-security"
        $requiredLogs = @(
            'AuditLogs', 'SignInLogs', 'NonInteractiveUserSignInLogs', 'ServicePrincipalSignInLogs',
            'ManagedIdentitySignInLogs', 'ProvisioningLogs', 'ADFSSignInLogs', 'RiskyUsers',
            'UserRiskEvents', 'NetworkAccessTrafficLogs', 'RiskyServicePrincipals',
            'ServicePrincipalRiskEvents', 'EnrichedOffice365AuditLogs', 'MicrosoftGraphActivityLogs',
            'RemoteNetworkHealthLogs'
        )
        $msgTable = @{
            retentionNotMet = "Retention not met for {0}."
            logsNotCollected = "Missing required logs."
            readOnlyLaw = "Missing read-only lock for {0}."
            nonCompliantLaw = "Workspace {0} not found."
            gcEventLoggingCompliantComment = "Compliant."
        }
    }

    Context "When LAW is tagged for Sentinel" {
        BeforeEach {
            Mock Select-AzSubscription -ModuleName Check-UserAccountGCEventLogging {}
            Mock Get-AzOperationalInsightsWorkspace -ModuleName Check-UserAccountGCEventLogging {
                [PSCustomObject]@{
                    RetentionInDays = 365
                    Tags = @{ service = "sentinel" }
                }
            }
            Mock get-AADDiagnosticSettings -ModuleName Check-UserAccountGCEventLogging {
                @([PSCustomObject]@{
                    properties = [PSCustomObject]@{
                        workspaceId = $LAWResourceId
                        logs = $requiredLogs | ForEach-Object { [PSCustomObject]@{ enabled = $true; category = $_ } }
                    }
                })
            }
            Mock Get-AzResourceLock -ModuleName Check-UserAccountGCEventLogging {}
        }

        It "does not enforce a read-only lock" {
            $result = Check-UserAccountGCEventLogging -LAWResourceId $LAWResourceId -RequiredRetentionDays 180 -ControlName "GR1" -ItemName "User Account GC Event Logging Check" -itsgcode "AU-2" -msgTable $msgTable -ReportTime "2024-01-01"
            $result.ComplianceResults.ComplianceStatus | Should -Be $true
            Should -Invoke Get-AzResourceLock -ModuleName Check-UserAccountGCEventLogging -Times 0
        }
    }

    Context "When LAW is not tagged for Sentinel" {
        BeforeEach {
            Mock Select-AzSubscription -ModuleName Check-UserAccountGCEventLogging {}
            Mock Get-AzOperationalInsightsWorkspace -ModuleName Check-UserAccountGCEventLogging {
                [PSCustomObject]@{
                    RetentionInDays = 365
                    Tags = @{ service = "security" }
                }
            }
            Mock get-AADDiagnosticSettings -ModuleName Check-UserAccountGCEventLogging {
                @([PSCustomObject]@{
                    properties = [PSCustomObject]@{
                        workspaceId = $LAWResourceId
                        logs = $requiredLogs | ForEach-Object { [PSCustomObject]@{ enabled = $true; category = $_ } }
                    }
                })
            }
            Mock Get-AzResourceLock -ModuleName Check-UserAccountGCEventLogging { $null }
        }

        It "remains non-compliant when read-only lock is missing" {
            $result = Check-UserAccountGCEventLogging -LAWResourceId $LAWResourceId -RequiredRetentionDays 180 -ControlName "GR1" -ItemName "User Account GC Event Logging Check" -itsgcode "AU-2" -msgTable $msgTable -ReportTime "2024-01-01"
            $result.ComplianceResults.ComplianceStatus | Should -Be $false
            $result.ComplianceResults.Comments | Should -Be ($msgTable.readOnlyLaw -f "law-security")
            Should -Invoke Get-AzResourceLock -ModuleName Check-UserAccountGCEventLogging -Times 1
        }
    }
}
