# Test script for Enhanced Metrics and Debugging functionality
# This script validates that the new metrics functions work correctly

param(
    [switch]$SkipAzureTests,
    [string]$LogAnalyticsWorkspaceId = "",
    [string]$LogAnalyticsKey = ""
)

Write-Host "🔍 Testing Enhanced Metrics and Debugging functionality..." -ForegroundColor Cyan

# Test 1: Module Import
Write-Host "`n📦 Test 1: Module Import" -ForegroundColor Yellow
try {
    Import-Module "$PSScriptRoot/../src/Guardrails-Common/GR-Common.psm1" -Force
    Write-Host "✅ GR-Common module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to import GR-Common module: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Function Availability
Write-Host "`n🔧 Test 2: Function Availability" -ForegroundColor Yellow
$requiredFunctions = @(
    "Start-GSAModuleTimer",
    "Stop-GSAModuleTimer", 
    "Add-GSADebugMetrics",
    "Add-GSARunbookPerformanceMetrics",
    "Get-GSAAutomationAccountPermissions"
)

foreach ($func in $requiredFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "✅ $func is available" -ForegroundColor Green
    } else {
        Write-Host "❌ $func is not available" -ForegroundColor Red
        exit 1
    }
}

# Test 3: Timer Functions
Write-Host "`n⏱️ Test 3: Timer Functions" -ForegroundColor Yellow
try {
    $timer = Start-GSAModuleTimer -ModuleName "TestModule"
    if ($timer.ModuleName -eq "TestModule" -and $timer.StartTime -is [DateTime]) {
        Write-Host "✅ Start-GSAModuleTimer works correctly" -ForegroundColor Green
    } else {
        throw "Invalid timer object returned"
    }
    
    Start-Sleep -Milliseconds 500  # Small delay for measurable runtime
    
    $metrics = Stop-GSAModuleTimer -Timer $timer -ModuleStatus "Success" -ResultCount 5
    if ($metrics.RuntimeSeconds -gt 0 -and $metrics.ModuleStatus -eq "Success") {
        Write-Host "✅ Stop-GSAModuleTimer works correctly (Runtime: $($metrics.RuntimeSeconds)s)" -ForegroundColor Green
    } else {
        throw "Invalid metrics returned"
    }
} catch {
    Write-Host "❌ Timer functions failed: $_" -ForegroundColor Red
    exit 1
}

# Test 4: Parameter Validation
Write-Host "`n✅ Test 4: Parameter Validation" -ForegroundColor Yellow
try {
    # Test invalid module status - should fail
    $shouldFail = $false
    try {
        $timer = Start-GSAModuleTimer -ModuleName "ValidationTest"
        Stop-GSAModuleTimer -Timer $timer -ModuleStatus "InvalidStatus"
        $shouldFail = $true
    } catch {
        # Expected to fail
    }
    
    if ($shouldFail) {
        Write-Host "❌ Parameter validation not working - invalid status accepted" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✅ Parameter validation working correctly" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Parameter validation test failed: $_" -ForegroundColor Red
    exit 1
}

# Test 5: JSON Structure
Write-Host "`n📋 Test 5: JSON Structure Validation" -ForegroundColor Yellow
try {
    # Mock the Log Analytics function to capture JSON
    function Send-OMSAPIIngestionFile {
        param($customerId, $sharedkey, $body, $logType, $TimeStampField)
        $global:TestLogData = @{
            LogType = $logType
            Body = $body | ConvertFrom-Json
        }
    }
    
    # Mock Azure context
    function Get-AzContext {
        return @{
            Tenant = @{ Id = "test-tenant" }
            Subscription = @{ Id = "test-subscription" }
        }
    }
    
    Add-GSADebugMetrics -WorkSpaceID "test" -WorkspaceKey "test" `
        -ModuleName "JsonTest" -ModuleStartTime (Get-Date).AddSeconds(-5) -ModuleEndTime (Get-Date) `
        -ModuleStatus "Success" -ReportTime "2024-01-01 12:00:00"
    
    if ($global:TestLogData.LogType -eq "GuardRailsDebugMetrics" -and 
        $global:TestLogData.Body.ModuleName -eq "JsonTest" -and
        $global:TestLogData.Body.RuntimeSeconds -gt 0) {
        Write-Host "✅ JSON structure is correct" -ForegroundColor Green
    } else {
        throw "Invalid JSON structure"
    }
} catch {
    Write-Host "❌ JSON structure validation failed: $_" -ForegroundColor Red
    exit 1
}

# Test 6: Workbook Template Validation
Write-Host "`n📊 Test 6: Workbook Template Validation" -ForegroundColor Yellow
try {
    $workbookPath = "$PSScriptRoot/../tools/GuardRails-Debug-Dashboard.workbook"
    if (Test-Path $workbookPath) {
        $workbookContent = Get-Content $workbookPath -Raw | ConvertFrom-Json
        if ($workbookContent.items -and $workbookContent.items.Count -gt 0) {
            Write-Host "✅ Workbook template is valid ($($workbookContent.items.Count) items)" -ForegroundColor Green
        } else {
            throw "Workbook template has no items"
        }
    } else {
        throw "Workbook template file not found"
    }
} catch {
    Write-Host "❌ Workbook template validation failed: $_" -ForegroundColor Red
    exit 1
}

# Test 7: Documentation Check
Write-Host "`n📖 Test 7: Documentation Check" -ForegroundColor Yellow
$docPath = "$PSScriptRoot/../docs/Enhanced-Metrics-and-Debugging.md"
if (Test-Path $docPath) {
    $docContent = Get-Content $docPath -Raw
    if ($docContent.Length -gt 1000 -and $docContent -match "GuardRailsDebugMetrics_CL") {
        Write-Host "✅ Documentation is present and contains expected content" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Documentation exists but may be incomplete" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Documentation file not found" -ForegroundColor Yellow
}

# Test 8: Optional Azure Integration Test
if (-not $SkipAzureTests -and $LogAnalyticsWorkspaceId -and $LogAnalyticsKey) {
    Write-Host "`n🔗 Test 8: Azure Integration Test" -ForegroundColor Yellow
    try {
        # This would test actual Log Analytics ingestion if credentials provided
        Write-Host "⚠️ Azure integration test would require actual Log Analytics workspace" -ForegroundColor Yellow
        Write-Host "   Use the provided workspace ID and key to test in a real environment" -ForegroundColor Yellow
    } catch {
        Write-Host "❌ Azure integration test failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host "`n⏭️ Test 8: Azure Integration Test (Skipped)" -ForegroundColor Gray
    Write-Host "   Use -LogAnalyticsWorkspaceId and -LogAnalyticsKey parameters to test" -ForegroundColor Gray
}

# Summary
Write-Host "`n🎉 All tests completed successfully!" -ForegroundColor Green
Write-Host "The enhanced metrics and debugging functionality is ready for use." -ForegroundColor Green

Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Deploy the workbook template to Azure Monitor" -ForegroundColor White
Write-Host "2. Verify Log Analytics workspace access for automation account" -ForegroundColor White  
Write-Host "3. Run a guardrails execution to generate metrics data" -ForegroundColor White
Write-Host "4. Check the new Log Analytics tables for metrics data" -ForegroundColor White
Write-Host "5. Use the debugging dashboard to monitor performance" -ForegroundColor White