#!/usr/bin/env pwsh
# Simple validation script to test the function structure

param(
    [string]$ModulePath = "../../../src/GUARDRAIL 11 LOGGING AND MONITORING/Audit/Check-DefenderForCloudConfig.psm1"
)

Write-Host "Testing GUARDRAIL 11 DefenderForCloudConfig module changes..."

try {
    # Test 1: Check if module can be parsed without errors
    Write-Host "Test 1: Module syntax validation..."
    $moduleContent = Get-Content -Path $ModulePath -Raw
    [System.Management.Automation.PSParser]::Tokenize($moduleContent, [ref]$null) | Out-Null
    Write-Host "✓ Module syntax is valid" -ForegroundColor Green

    # Test 2: Check if functions are properly defined
    Write-Host "Test 2: Function definition validation..."
    $scriptBlock = [scriptblock]::Create($moduleContent)
    $ast = $scriptBlock.Ast
    $functions = $ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]}, $true)
    
    $expectedFunctions = @("Get-DefenderForCloudConfig", "Get-SubscriptionDefenderConfig", "Get-SecurityContactInfo", "Add-ProfileToResult")
    foreach ($expectedFunc in $expectedFunctions) {
        if ($functions.Name -contains $expectedFunc) {
            Write-Host "✓ Function '$expectedFunc' found" -ForegroundColor Green
        } else {
            Write-Host "✗ Function '$expectedFunc' not found" -ForegroundColor Red
        }
    }

    # Test 3: Check if Get-SubscriptionDefenderConfig has the correct parameters
    Write-Host "Test 3: Parameter validation for Get-SubscriptionDefenderConfig..."
    $subDefenderFunc = $functions | Where-Object { $_.Name -eq "Get-SubscriptionDefenderConfig" }
    if ($subDefenderFunc) {
        $paramNames = $subDefenderFunc.Parameters.Name.VariablePath.UserPath
        $expectedParams = @("Subscription", "MsgTable", "ControlName", "ReportTime", "itsginfosecdefender")
        
        foreach ($expectedParam in $expectedParams) {
            if ($paramNames -contains $expectedParam) {
                Write-Host "✓ Parameter '$expectedParam' found" -ForegroundColor Green
            } else {
                Write-Host "✗ Parameter '$expectedParam' missing" -ForegroundColor Red
            }
        }
    }

    # Test 4: Check if output object includes SubscriptionName
    Write-Host "Test 4: Checking for SubscriptionName in output object..."
    if ($moduleContent -match "SubscriptionName\s*=\s*\$Subscription\.Name") {
        Write-Host "✓ SubscriptionName property found in output object" -ForegroundColor Green
    } else {
        Write-Host "✗ SubscriptionName property not found in output object" -ForegroundColor Red
    }

    Write-Host "`nModule validation completed!" -ForegroundColor Cyan

} catch {
    Write-Host "Error during validation: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}