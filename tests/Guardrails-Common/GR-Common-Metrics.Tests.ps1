Describe "Enhanced Metrics and Debugging Functions Tests" {
    BeforeAll {
        # Import the module
        Import-Module "$PSScriptRoot/../../src/Guardrails-Common/GR-Common.psm1" -Force
        
        # Mock external dependencies
        Mock Get-AzContext -MockWith {
            return @{
                Tenant = @{ Id = "test-tenant-id" }
                Subscription = @{ Id = "test-subscription-id" }
                Account = @{ Id = "test-account@domain.com" }
            }
        } -ModuleName GR-Common
        
        Mock Send-OMSAPIIngestionFile -MockWith { } -ModuleName GR-Common
        Mock Get-GSAAutomationVariable -MockWith { param($Name) return "test-$Name" } -ModuleName GR-Common
        Mock Get-AzRoleAssignment -MockWith {
            return @(
                @{
                    RoleDefinitionName = "Contributor"
                    Scope = "/subscriptions/test-sub/resourceGroups/test-rg"
                    ObjectType = "ServicePrincipal"
                    DisplayName = "test-account"
                }
            )
        } -ModuleName GR-Common
        Mock Write-Debug -MockWith { } -ModuleName GR-Common
        Mock Write-Warning -MockWith { } -ModuleName GR-Common
    }

    Context "Start-GSAModuleTimer Function Tests" {
        It "Should create timer object with correct properties" {
            $timer = Start-GSAModuleTimer -ModuleName "Test-Timer-Module"
            
            $timer.ModuleName | Should -Be "Test-Timer-Module"
            $timer.StartTime | Should -Not -BeNullOrEmpty
            $timer.StartTime | Should -BeOfType [DateTime]
        }
    }

    Context "Stop-GSAModuleTimer Function Tests" {
        It "Should calculate metrics when stopping timer" {
            $timer = @{
                ModuleName = "Test-Timer-Module"
                StartTime = (Get-Date).AddSeconds(-5)
            }
            
            $metrics = Stop-GSAModuleTimer -Timer $timer -ModuleStatus "Success" -ResultCount 3
            
            $metrics.ModuleName | Should -Be "Test-Timer-Module"
            $metrics.ModuleStatus | Should -Be "Success" 
            $metrics.ResultCount | Should -Be 3
            $metrics.RuntimeSeconds | Should -BeGreaterThan 0
        }
        
        It "Should return runtime in seconds as a number" {
            $timer = @{
                ModuleName = "Test-Timer-Module"
                StartTime = (Get-Date).AddSeconds(-10)
            }
            
            $metrics = Stop-GSAModuleTimer -Timer $timer -ModuleStatus "Success"
            
            $metrics.RuntimeSeconds | Should -BeOfType [double]
            $metrics.RuntimeSeconds | Should -BeGreaterThan 5
        }
        
        It "Should handle different module statuses" {
            $timer = @{
                ModuleName = "Test-Module"
                StartTime = (Get-Date).AddSeconds(-2)
            }
            
            @("Success", "Failed", "Warning") | ForEach-Object {
                $metrics = Stop-GSAModuleTimer -Timer $timer -ModuleStatus $_
                $metrics.ModuleStatus | Should -Be $_
            }
        }
    }

    Context "Function Parameter Validation Tests" {
        It "Should have required parameters defined correctly" {
            $command = Get-Command Add-GSADebugMetrics
            
            # Check that required parameters exist
            $requiredParams = $command.Parameters.Keys | Where-Object { 
                $command.Parameters[$_].Attributes.Mandatory -contains $true 
            }
            
            $requiredParams | Should -Contain "WorkSpaceID"
            $requiredParams | Should -Contain "WorkspaceKey" 
            $requiredParams | Should -Contain "ModuleName"
            $requiredParams | Should -Contain "ModuleStartTime"
            $requiredParams | Should -Contain "ModuleEndTime"
            $requiredParams | Should -Contain "ModuleStatus"
            $requiredParams | Should -Contain "ReportTime"
        }
        
        It "Should have parameter validation for ModuleStatus" {
            $command = Get-Command Add-GSADebugMetrics
            $statusParam = $command.Parameters["ModuleStatus"]
            
            # Check that ValidateSet attribute exists
            $validateSet = $statusParam.Attributes | Where-Object { $_.TypeId.Name -eq "ValidateSetAttribute" }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain "Success"
            $validateSet.ValidValues | Should -Contain "Failed"
            $validateSet.ValidValues | Should -Contain "Warning"
        }
        
        It "Should have parameter validation for RunbookType" {
            $command = Get-Command Add-GSARunbookPerformanceMetrics
            $typeParam = $command.Parameters["RunbookType"]
            
            $validateSet = $typeParam.Attributes | Where-Object { $_.TypeId.Name -eq "ValidateSetAttribute" }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain "Main"
            $validateSet.ValidValues | Should -Contain "Backend"
        }
    }

    Context "Function Existence Tests" {
        It "Should have Add-GSADebugMetrics function available" {
            Get-Command Add-GSADebugMetrics -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Add-GSARunbookPerformanceMetrics function available" {
            Get-Command Add-GSARunbookPerformanceMetrics -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Get-GSAAutomationAccountPermissions function available" {
            Get-Command Get-GSAAutomationAccountPermissions -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Start-GSAModuleTimer function available" {
            Get-Command Start-GSAModuleTimer -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Stop-GSAModuleTimer function available" {
            Get-Command Stop-GSAModuleTimer -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context "JSON Structure Tests" {
        It "Should create proper timer structure" {
            $timer = Start-GSAModuleTimer -ModuleName "JSON-Test-Module"
            
            $timer.ContainsKey("ModuleName") | Should -Be $true
            $timer.ContainsKey("StartTime") | Should -Be $true
            $timer.Keys.Count | Should -Be 2
        }
        
        It "Should create proper metrics structure" {
            $timer = @{
                ModuleName = "JSON-Test-Module"
                StartTime = (Get-Date).AddSeconds(-3)
            }
            
            $metrics = Stop-GSAModuleTimer -Timer $timer -ModuleStatus "Success" -ResultCount 5 -ErrorDetails "test error"
            
            $metrics.ContainsKey("ModuleName") | Should -Be $true
            $metrics.ContainsKey("StartTime") | Should -Be $true
            $metrics.ContainsKey("EndTime") | Should -Be $true
            $metrics.ContainsKey("RuntimeSeconds") | Should -Be $true
            $metrics.ContainsKey("ModuleStatus") | Should -Be $true
            $metrics.ContainsKey("ResultCount") | Should -Be $true
            $metrics.ContainsKey("ErrorDetails") | Should -Be $true
        }
    }
}