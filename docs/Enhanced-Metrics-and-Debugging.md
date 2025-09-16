# Enhanced Metrics and Debugging Support for Azure CaC

This document describes the enhanced metrics and debugging functionality added to the Azure Guardrails Solution Accelerator to support operational monitoring and troubleshooting.

## Overview

The enhanced metrics and debugging support provides comprehensive monitoring and diagnostic capabilities for the Azure Compliance as Code (CaC) solution. This functionality addresses the need for:

- Runtime tracking for individual modules and overall runbooks
- Success/failure analysis per guardrail and control type  
- Error collection and troubleshooting information
- Automation account permissions monitoring
- Resource usage and performance metrics

## New Log Analytics Tables

The enhancement creates new Log Analytics tables to store metrics data:

### GuardRailsDebugMetrics_CL
Stores individual module execution metrics including:
- Module name and execution times
- Runtime duration in seconds
- Success/failure status
- Result counts
- Error details
- Guardrail number and control type (M/R)

### GuardRailsRunbookMetrics_CL  
Stores overall runbook performance metrics including:
- Total execution time
- Module counts (total, successful, failed, warnings)
- Success rates
- System information (PowerShell version, execution policy)

### GuardRailsPermissionInfo_CL
Stores automation account permission information including:
- Role assignments and scopes
- Resource group permissions
- Permission check timestamps

## New Functions

### Module Timer Functions

#### Start-GSAModuleTimer
```powershell
$timer = Start-GSAModuleTimer -ModuleName "Check-AdminAccess"
```

Creates a timer object for tracking module execution time.

#### Stop-GSAModuleTimer
```powershell
$metrics = Stop-GSAModuleTimer -Timer $timer -ModuleStatus "Success" -ResultCount 10
```

Completes timing and optionally logs metrics to Log Analytics.

### Metrics Collection Functions

#### Add-GSADebugMetrics
```powershell
Add-GSADebugMetrics -WorkSpaceID $workspaceId -WorkspaceKey $key `
    -ModuleName "Check-AdminAccess" -ModuleStartTime $startTime -ModuleEndTime $endTime `
    -ModuleStatus "Success" -ResultCount 15 -GuardrailNumber "1" -ControlType "M" `
    -ReportTime $reportTime
```

Logs detailed module execution metrics to Log Analytics.

#### Add-GSARunbookPerformanceMetrics
```powershell
Add-GSARunbookPerformanceMetrics -WorkSpaceID $workspaceId -WorkspaceKey $key `
    -RunbookType "Main" -TotalStartTime $startTime -TotalEndTime $endTime `
    -TotalModulesExecuted 25 -SuccessfulModules 23 -FailedModules 1 `
    -WarningModules 1 -ReportTime $reportTime
```

Logs overall runbook performance metrics.

#### Get-GSAAutomationAccountPermissions
```powershell
Get-GSAAutomationAccountPermissions -WorkSpaceID $workspaceId -WorkspaceKey $key -ReportTime $reportTime
```

Collects and logs automation account permissions for debugging.

## Integration with Existing Runbooks

### Main Runbook (main.ps1) Changes
- Added runbook-level performance tracking
- Module-level timing around each guardrail module execution
- Enhanced error collection and status tracking
- Automatic metrics logging for each module

### Backend Runbook (backend.ps1) Changes
- Added backend runbook performance metrics
- Permission information collection for debugging

## Debugging Dashboard

The solution includes an Azure Workbook template (`tools/GuardRails-Debug-Dashboard.workbook`) that provides:

### Performance Overview
- Runbook execution summary with average runtimes
- Module performance analysis with success rates
- Runtime trend visualization over time

### Error Analysis
- Failed and warning modules with error details
- Most common failure patterns
- Troubleshooting insights

### Compliance Metrics
- Results summary by guardrail number
- Mandatory vs recommended control breakdown
- Average results per execution

### Operational Insights
- Slowest performing modules
- Most frequently failing modules
- Highest result count modules
- Automation account permission status

## Installation

The metrics functionality is automatically integrated into the existing solution. To deploy:

1. The enhanced `GR-Common.psm1` module will be automatically loaded
2. Deploy the workbook template to Azure Monitor
3. Metrics collection begins automatically on next runbook execution

## Configuration

No additional configuration is required. The metrics use the same Log Analytics workspace as the existing guardrails compliance data.

## Monitoring Queries

### Top Slowest Modules
```kql
GuardRailsDebugMetrics_CL
| where TimeGenerated > ago(30d)
| summarize AvgRuntime = avg(todouble(RuntimeSeconds_s)) by ModuleName_s
| top 10 by AvgRuntime desc
```

### Success Rate by Guardrail
```kql
GuardRailsDebugMetrics_CL
| where TimeGenerated > ago(7d) and isnotempty(GuardrailNumber_s)
| summarize 
    Total = count(),
    Success = countif(ModuleStatus_s == "Success")
    by GuardrailNumber_s
| extend SuccessRate = round((todouble(Success) / todouble(Total)) * 100.0, 1)
| sort by GuardrailNumber_s asc
```

### Module Execution Trends
```kql
GuardRailsRunbookMetrics_CL
| where TimeGenerated > ago(30d)
| project TimeGenerated, RunbookType_s, TotalRuntimeMinutes_s = todouble(TotalRuntimeMinutes_s)
| render timechart
```

## Benefits

1. **Proactive Monitoring**: Early identification of performance issues and failures
2. **Troubleshooting**: Detailed error information and runtime metrics for diagnosis
3. **Capacity Planning**: Historical performance data for resource planning
4. **Compliance Tracking**: Success rates and result counts per guardrail
5. **Operational Visibility**: Dashboard views for operations teams

## Troubleshooting

### Common Issues

**High module runtimes**: Check GuardRailsDebugMetrics_CL for modules with consistently high RuntimeSeconds_s values.

**Low success rates**: Query GuardRailsDebugMetrics_CL for modules with ModuleStatus_s = "Failed" and review ErrorDetails_s.

**Permission issues**: Check GuardRailsPermissionInfo_CL for role assignment problems.

### Debug Queries

**Recent failures**:
```kql
GuardRailsDebugMetrics_CL
| where TimeGenerated > ago(1d) and ModuleStatus_s == "Failed"
| project TimeGenerated, ModuleName_s, ErrorDetails_s
| order by TimeGenerated desc
```

**Automation account permissions**:
```kql
GuardRailsPermissionInfo_CL
| where TimeGenerated > ago(1d)
| summarize arg_max(TimeGenerated, *) by RoleDefinitionName_s, Scope_s
```

## Support

For issues related to the metrics and debugging functionality, check:
1. Log Analytics workspace for metric data availability
2. Automation account permissions for Log Analytics access
3. Workbook deployment in Azure Monitor
4. Module import warnings in runbook execution logs