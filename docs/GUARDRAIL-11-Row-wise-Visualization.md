# GUARDRAIL 11 Row-wise Subscription Visualization

## Before (Issue)
The original implementation showed GUARDRAIL 11 results as a single aggregated entry across all subscriptions, making MCUP evaluation challenging.

**Original Query:** `gr_data("GUARDRAIL 11","{RunTime}", "{RequiredYesNo}")`
**Result:** One row per control type across all subscriptions

## After (Solution)
The updated implementation shows each subscription as a separate row, enabling individual subscription evaluation.

**New Query Structure:**
```kusto
let itsgcodes=GRITSGControls_CL | where TimeGenerated == toscalar(GRITSGControls_CL | summarize by TimeGenerated | top 2 by TimeGenerated desc | top 1 by TimeGenerated asc | project TimeGenerated);
let ctrlprefix="GUARDRAIL 11";
GuardrailsCompliance_CL
| where ControlName_s has ctrlprefix and ReportTime_s == "{RunTime}" and Required_s !=tostring("{RequiredYesNo}")
| where TimeGenerated > ago (24h)
|join kind=leftouter (itsgcodes) on itsgcode_s
| project SubscriptionName=SubscriptionName_s, Status=case(ComplianceStatus_b == true, "✔️", ComplianceStatus_b == false, "❌", "➖"), Comments=Comments_s,["ITSG Control"]=itsgcode_s, Mitigation=gr_geturl(replace_string(ctrlprefix," ",""),itsgcode_s), Profile=iff(isnotempty(column_ifexists('Profile_d', '')), tostring(toint(column_ifexists('Profile_d', ''))), '')
| sort by Status asc
```

**Expected Result Format:**
| SubscriptionName | Status | Comments | ITSG Control | Mitigation | Profile |
|------------------|---------|----------|--------------|------------|---------|
| Prod-Subscription-01 | ✔️ | Compliant | AC-2(1) | [Link] | 3 |
| Dev-Subscription-02 | ❌ | Security contact information is not configured | AC-2(1) | [Link] | 3 |
| Test-Subscription-03 | ❌ | Not all Defender plans enabled | AC-2(1) | [Link] | 2 |

## Implementation Changes

### PowerShell Module Changes
1. **Added SubscriptionName to output object** in `Get-SubscriptionDefenderConfig`:
   ```powershell
   return [PSCustomObject]@{
       ComplianceStatus = $isCompliant
       Comments = $comments
       ItemName = $MsgTable.defenderMonitoring
       itsgcode = $itsginfosecdefender
       ControlName = $ControlName
       ReportTime = $ReportTime
       SubscriptionName = $Subscription.Name  # NEW
       Errors = $errors
   }
   ```

2. **Updated function parameters** to pass required fields:
   ```powershell
   $result = Get-SubscriptionDefenderConfig -Subscription $sub -MsgTable $msgTable -ControlName $ControlName -ReportTime $ReportTime -itsginfosecdefender $itsginfosecdefender
   ```

### Workbook Changes
- **Replaced generic `gr_data` function** with custom subscription-specific query
- **Projects `SubscriptionName=SubscriptionName_s`** for row-wise display
- **Maintains all existing columns** (Status, Comments, ITSG Control, etc.)
- **Follows GUARDRAIL 8 pattern** for consistency

## Benefits
1. **Row-wise visualization** - Each subscription appears as a separate row
2. **MCUP evaluation enabled** - Easy to assess compliance per subscription
3. **Consistent with other guardrails** - Same pattern as GUARDRAIL 8
4. **Backward compatible** - No breaking changes to existing functionality
5. **Clear accountability** - Shows exactly which subscriptions need attention

This solution addresses the original issue by providing clear, subscription-level visibility for GUARDRAIL 11 Microsoft Defender for Cloud checks.