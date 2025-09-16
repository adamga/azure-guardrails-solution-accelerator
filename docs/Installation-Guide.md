# Enhanced Metrics and Debugging - Installation Guide

This guide provides step-by-step instructions for deploying the enhanced metrics and debugging functionality for Azure Guardrails Solution Accelerator.

## Prerequisites

- Existing Azure Guardrails Solution Accelerator deployment
- Azure PowerShell module access in automation account
- Log Analytics workspace with write permissions
- Azure Monitor Workbooks permissions (for dashboard deployment)

## Installation Steps

### 1. Deploy Updated Code

The enhanced metrics functionality is integrated into the existing solution components:

- **Updated files:** `src/Guardrails-Common/GR-Common.psm1`, `setup/main.ps1`, `setup/backend.ps1`
- **New files:** `tools/GuardRails-Debug-Dashboard.workbook`, documentation, and tests

### 2. Validate Installation

Run the included test script to verify the installation:

```powershell
.\tools\Test-EnhancedMetrics.ps1 -SkipAzureTests
```

This validates:
- Module functions are available
- Timer functionality works
- Parameter validation is active  
- JSON structures are correct
- Workbook template is valid

### 3. Deploy Azure Workbook Dashboard

1. **Navigate to Azure Portal** → Azure Monitor → Workbooks
2. **Click "New"** to create a workbook
3. **Click the "Advanced Editor"** button (</> icon)
4. **Replace the template** with the content from `tools/GuardRails-Debug-Dashboard.workbook`
5. **Click "Apply"** to load the template
6. **Save the workbook** with a name like "Guardrails Debug Dashboard"
7. **Set the workspace resource** to your Log Analytics workspace

### 4. Verify Log Analytics Integration

Confirm the automation account has permissions to write to Log Analytics:

```powershell
# Check automation account managed identity has Log Analytics Contributor role
Get-AzRoleAssignment -Scope "/subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspace}"
```

### 5. Test Metrics Collection

After the next runbook execution, verify data in Log Analytics:

```kql
// Check for debug metrics
GuardRailsDebugMetrics_CL
| where TimeGenerated > ago(1h)
| take 10

// Check for runbook metrics  
GuardRailsRunbookMetrics_CL
| where TimeGenerated > ago(1h)
| take 5

// Check for permission info
GuardRailsPermissionInfo_CL
| where TimeGenerated > ago(1h)
| take 5
```

## Configuration

### Log Analytics Tables

The following new tables will be created automatically:

| Table Name | Purpose | Retention |
|------------|---------|-----------|
| `GuardRailsDebugMetrics_CL` | Individual module metrics | Same as workspace |
| `GuardRailsRunbookMetrics_CL` | Overall runbook performance | Same as workspace |
| `GuardRailsPermissionInfo_CL` | Automation account permissions | Same as workspace |

### Workbook Configuration

The workbook uses these parameters:
- **Time Range**: Adjustable time filter (default: 30 days)
- **Workspace**: Automatically set to your Log Analytics workspace

## Validation Checklist

- [ ] Test script runs successfully
- [ ] New functions available in PowerShell module
- [ ] Runbooks execute without errors
- [ ] Log Analytics tables are created after first execution
- [ ] Workbook dashboard displays data
- [ ] Metrics data appears in expected format

## Troubleshooting

### Common Issues

**No metrics data appearing:**
- Verify automation account permissions to Log Analytics workspace
- Check runbook execution logs for errors
- Confirm workspace ID and key are correct

**Workbook shows no data:**
- Verify time range includes recent runbook executions
- Check Log Analytics workspace is selected correctly
- Confirm metrics tables contain data

**Function not found errors:**
- Ensure GR-Common module is properly imported
- Check for PowerShell execution policy restrictions
- Verify module files are deployed correctly

### Debug Queries

```kql
// Recent runbook executions
GuardRailsRunbookMetrics_CL
| where TimeGenerated > ago(24h)
| project TimeGenerated, RunbookType_s, TotalRuntimeMinutes_s, SuccessRate_s
| order by TimeGenerated desc

// Failed modules
GuardRailsDebugMetrics_CL
| where TimeGenerated > ago(24h) and ModuleStatus_s == "Failed"
| project TimeGenerated, ModuleName_s, ErrorDetails_s
| order by TimeGenerated desc

// Performance issues
GuardRailsDebugMetrics_CL
| where TimeGenerated > ago(7d)
| summarize AvgRuntime = avg(todouble(RuntimeSeconds_s)) by ModuleName_s
| where AvgRuntime > 60  // Modules taking over 60 seconds
| order by AvgRuntime desc
```

## Next Steps

1. **Monitor Dashboard**: Use the workbook to monitor ongoing performance
2. **Set Alerts**: Create Log Analytics alerts for high failure rates or long runtimes
3. **Optimize Performance**: Use metrics to identify and optimize slow modules
4. **Capacity Planning**: Use historical data for resource planning

## Support

For issues with the enhanced metrics functionality:
1. Run the test script to identify specific problems
2. Check automation account execution logs
3. Verify Log Analytics workspace connectivity
4. Review the troubleshooting section in the main documentation

## Rollback

To disable metrics collection (if needed):
1. Comment out the metrics collection calls in `main.ps1` and `backend.ps1`
2. The core guardrails functionality will continue unchanged
3. Existing metrics data will remain in Log Analytics