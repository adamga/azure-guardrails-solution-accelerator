# Migration Guide: Original to Optimized Azure Guardrails

## Overview

This guide provides step-by-step instructions for migrating from the original Azure Guardrails Solution Accelerator scripts to the performance-optimized versions. The optimized scripts maintain backward compatibility while providing significant performance improvements.

## Pre-Migration Checklist

### 1. Environment Assessment
- [ ] Document current execution times for baseline comparison
- [ ] Identify high-usage guardrail checks in your environment
- [ ] Review current resource limitations (CPU, memory, network)
- [ ] Check PowerShell version compatibility (requires PowerShell 5.1 or later)

### 2. Backup and Testing
- [ ] Create backup of current implementation
- [ ] Set up isolated test environment
- [ ] Prepare test datasets representative of production
- [ ] Document current configuration settings

### 3. Prerequisites
- [ ] Ensure required PowerShell modules are available
- [ ] Verify Azure permissions for all operations
- [ ] Check network connectivity and firewall rules
- [ ] Review API rate limiting configurations

## Migration Phases

### Phase 1: Foundation Setup (Low Risk)

#### Step 1: Deploy Common Optimization Modules

1. **Copy optimization modules** to your environment:
   ```powershell
   # Copy the optimized common modules
   Copy-Item "updates/src/Guardrails-Common/*" -Destination "src/Guardrails-Common/" -Recurse -Force
   ```

2. **Import performance utilities**:
   ```powershell
   Import-Module "src/Guardrails-Common/GR-Performance.psm1" -Force
   Import-Module "src/Guardrails-Common/GR-Common-Optimized.psm1" -Force
   ```

3. **Test basic functionality**:
   ```powershell
   # Test caching functionality
   Set-PerformanceCache -Key "test" -Value "data" -TimeoutSeconds 60
   $cached = Get-PerformanceCache -Key "test"
   Write-Host "Cache test result: $cached"
   
   # Test batch operations
   $testItems = 1..10
   $results = Invoke-BatchOperation -Items $testItems -BatchSize 3 -Operation {
       param($batch)
       return $batch | ForEach-Object { $_ * 2 }
   }
   Write-Host "Batch test completed with $($results.Count) results"
   ```

#### Step 2: Configure Optimization Settings

1. **Create configuration file** (`optimization-config.json`):
   ```json
   {
       "caching": {
           "enabled": true,
           "defaultTimeoutSeconds": 300,
           "maxCacheSize": 1000
       },
       "parallelProcessing": {
           "enabled": true,
           "maxConcurrentJobs": 5,
           "timeoutMinutes": 30
       },
       "batchProcessing": {
           "enabled": true,
           "defaultBatchSize": 20,
           "delayBetweenBatches": 100
       },
       "apiOptimization": {
           "maxRetries": 3,
           "retryDelaySeconds": 2,
           "useSpecificFields": true
       }
   }
   ```

2. **Load configuration in scripts**:
   ```powershell
   $optimizationConfig = Get-Content "optimization-config.json" | ConvertFrom-Json
   ```

### Phase 2: Low-Risk Module Migration

#### Step 3: Migrate Common Functions

1. **Replace tag operations** with optimized versions:
   ```powershell
   # Update function calls to use optimized versions
   # Original: get-tagValue -tagKey "Environment" -object $resource
   # Optimized: Get-TagValueOptimized -TagKey "Environment" -Object $resource -UseCache
   ```

2. **Update blob operations**:
   ```powershell
   # Original: copy-toBlob -FilePath $file -storageaccountName $sa -resourcegroup $rg -containerName $container
   # Optimized: Copy-ToBlobOptimized -FilePath $file -StorageAccountName $sa -ResourceGroup $rg -ContainerName $container -UseOptimizedUpload
   ```

3. **Test common function replacements**:
   ```powershell
   # Run test to ensure compatibility
   $testResource = Get-AzResource | Select-Object -First 1
   $tagValue = Get-TagValueOptimized -TagKey "Environment" -Object $testResource -UseCache
   Write-Host "Tag test successful: $tagValue"
   ```

#### Step 4: Migrate User MFA Checks (Guardrail 1)

1. **Backup original module**:
   ```powershell
   Copy-Item "src/GUARDRAIL 1 PROTECT USER ACCOUNTS AND IDENTITIES/Audit/Check-AllUserMFARequired.psm1" `
            "src/GUARDRAIL 1 PROTECT USER ACCOUNTS AND IDENTITIES/Audit/Check-AllUserMFARequired.psm1.backup"
   ```

2. **Deploy optimized version**:
   ```powershell
   Copy-Item "updates/src/GUARDRAIL 1 PROTECT USER ACCOUNTS AND IDENTITIES/Audit/Check-AllUserMFARequired-Optimized.psm1" `
            "src/GUARDRAIL 1 PROTECT USER ACCOUNTS AND IDENTITIES/Audit/Check-AllUserMFARequired.psm1"
   ```

3. **Test with small user set**:
   ```powershell
   # Test with limited scope first
   $testResult = Check-AllUserMFARequiredOptimized -ControlName "Test" -ItemName "MFA Check" `
                -itsgcode "GR1" -msgTable $msgTable -ReportTime (Get-Date) `
                -FirstBreakGlassUPN "break1@domain.com" -SecondBreakGlassUPN "break2@domain.com" `
                -UseCache -UseParallelProcessing:$false
   ```

### Phase 3: Medium-Risk Module Migration

#### Step 5: Migrate Conditional Access Policies (Guardrail 1)

1. **Deploy optimized CloudAccountsMFA**:
   ```powershell
   Copy-Item "updates/src/GUARDRAIL 1 PROTECT USER ACCOUNTS AND IDENTITIES/Audit/Check-CloudAccountsMFA-Optimized.psm1" `
            "src/GUARDRAIL 1 PROTECT USER ACCOUNTS AND IDENTITIES/Audit/Check-CloudAccountsMFA.psm1"
   ```

2. **Test policy evaluation**:
   ```powershell
   $testResult = Check-CloudAccountsMFAOptimized -ControlName "Test" -ItemName "CA Policy Check" `
                -itsgcode "GR1" -msgTable $msgTable -ReportTime (Get-Date) `
                -UseCache
   ```

#### Step 6: Migrate Location Policies (Guardrail 5)

1. **Deploy optimized location policy check**:
   ```powershell
   Copy-Item "updates/src/GUARDRAIL 5 DATA LOCATION/Audit/Check-AllowedLocationPolicy-Optimized.psm1" `
            "src/GUARDRAIL 5 DATA LOCATION/Audit/Check-AllowedLocationPolicy.psm1"
   ```

2. **Test with limited scope**:
   ```powershell
   $testResult = Verify-AllowedLocationPolicyOptimized -ControlName "Test" -ItemName "Location Check" `
                -PolicyID $policyId -InitiativeID $initiativeId -itsgcode "GR5" `
                -AllowedLocationsString "canadacentral,canadaeast" -msgTable $msgTable `
                -ReportTime (Get-Date) -UseParallelProcessing:$false
   ```

### Phase 4: Full Migration and Optimization

#### Step 7: Enable Full Optimizations

1. **Update configuration for production**:
   ```json
   {
       "caching": {
           "enabled": true,
           "defaultTimeoutSeconds": 600,
           "maxCacheSize": 5000
       },
       "parallelProcessing": {
           "enabled": true,
           "maxConcurrentJobs": 10,
           "timeoutMinutes": 60
       },
       "batchProcessing": {
           "enabled": true,
           "defaultBatchSize": 50,
           "delayBetweenBatches": 50
       }
   }
   ```

2. **Enable all optimization features**:
   ```powershell
   # Update function calls to use all optimizations
   $result = Check-AllUserMFARequiredOptimized `
            -UseCache `
            -UseParallelProcessing `
            -UseOptimizations `
            # ... other parameters
   ```

#### Step 8: Performance Validation

1. **Run performance benchmarks**:
   ```powershell
   Import-Module "updates/performance-benchmarks/performance-benchmark.ps1"
   $benchmarkResults = Start-PerformanceBenchmark -Iterations 5
   ```

2. **Compare with baseline**:
   ```powershell
   # Compare execution times with original baseline
   New-PerformanceReport -BenchmarkResultsPath "benchmark-results.json"
   ```

## Configuration Parameters

### Caching Configuration

| Parameter | Default | Description | Tuning Guidance |
|-----------|---------|-------------|-----------------|
| `defaultTimeoutSeconds` | 300 | Default cache expiration | Increase for stable environments |
| `maxCacheSize` | 1000 | Maximum cached items | Adjust based on memory availability |

### Parallel Processing Configuration

| Parameter | Default | Description | Tuning Guidance |
|-----------|---------|-------------|-----------------|
| `maxConcurrentJobs` | 5 | Maximum parallel operations | Increase for powerful systems, decrease if hitting API limits |
| `timeoutMinutes` | 30 | Job timeout | Adjust based on expected operation duration |

### Batch Processing Configuration

| Parameter | Default | Description | Tuning Guidance |
|-----------|---------|-------------|-----------------|
| `defaultBatchSize` | 20 | Items per batch | Increase for higher throughput, decrease if hitting API limits |
| `delayBetweenBatches` | 100ms | Delay between batches | Adjust based on API throttling requirements |

## Monitoring and Validation

### Performance Metrics to Track

1. **Execution Time**:
   ```powershell
   $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
   # ... run operation
   $stopwatch.Stop()
   Write-Host "Execution time: $($stopwatch.ElapsedMilliseconds)ms"
   ```

2. **Memory Usage**:
   ```powershell
   $memoryBefore = [System.GC]::GetTotalMemory($false)
   # ... run operation
   $memoryAfter = [System.GC]::GetTotalMemory($false)
   Write-Host "Memory used: $([Math]::Round(($memoryAfter - $memoryBefore) / 1MB, 2))MB"
   ```

3. **Cache Effectiveness**:
   ```powershell
   # Monitor cache hit ratios
   $cacheStats = Get-CacheStatistics
   Write-Host "Cache hit ratio: $($cacheStats.HitRatio)%"
   ```

### Validation Checklist

- [ ] All original functionality preserved
- [ ] Performance improvements measured and documented
- [ ] Error handling working correctly
- [ ] Caching operating as expected
- [ ] Parallel processing stable
- [ ] API throttling handled appropriately
- [ ] Memory usage optimized
- [ ] Results identical to original implementation

## Rollback Procedures

### Emergency Rollback

If issues are encountered, you can quickly rollback:

1. **Restore original modules**:
   ```powershell
   # Restore from backup
   Copy-Item "src/GUARDRAIL 1 PROTECT USER ACCOUNTS AND IDENTITIES/Audit/Check-AllUserMFARequired.psm1.backup" `
            "src/GUARDRAIL 1 PROTECT USER ACCOUNTS AND IDENTITIES/Audit/Check-AllUserMFARequired.psm1"
   ```

2. **Disable optimizations**:
   ```powershell
   # Update configuration to disable optimizations
   $config.caching.enabled = $false
   $config.parallelProcessing.enabled = $false
   ```

3. **Clear cache**:
   ```powershell
   Clear-PerformanceCache
   ```

### Gradual Rollback

For specific issues, you can selectively disable optimizations:

1. **Disable caching only**:
   ```powershell
   $result = Check-AllUserMFARequiredOptimized -UseCache:$false
   ```

2. **Disable parallel processing**:
   ```powershell
   $result = Check-AllUserMFARequiredOptimized -UseParallelProcessing:$false
   ```

## Troubleshooting Common Issues

### Issue: Cache Returning Stale Data

**Symptoms**: Results don't reflect recent changes
**Solution**: 
```powershell
# Reduce cache timeout or clear specific cache entries
Clear-PerformanceCache -KeyPattern "Users_*"
```

### Issue: API Throttling with Parallel Processing

**Symptoms**: HTTP 429 errors, degraded performance
**Solution**:
```powershell
# Reduce concurrency and add delays
$result = Invoke-ParallelOperation -MaxConcurrent 3 -Items $items
```

### Issue: High Memory Usage

**Symptoms**: System becomes unresponsive, OutOfMemory errors
**Solution**:
```powershell
# Force garbage collection and reduce batch sizes
[System.GC]::Collect()
$result = Invoke-BatchOperation -BatchSize 10 -Items $items
```

### Issue: Inconsistent Results

**Symptoms**: Results differ between original and optimized versions
**Solution**:
```powershell
# Disable caching and run comparison
$original = Check-AllUserMFARequired -UseCache:$false
$optimized = Check-AllUserMFARequiredOptimized -UseCache:$false
Compare-Object $original $optimized
```

## Support and Resources

### Documentation
- [Optimization Guide](optimization-guide.md) - Detailed technical documentation
- [Performance Benchmarks](../performance-benchmarks/) - Benchmark scripts and results

### Monitoring Scripts
- `performance-benchmark.ps1` - Automated performance testing
- `cache-monitor.ps1` - Cache effectiveness monitoring
- `memory-monitor.ps1` - Memory usage tracking

### Contact Information
For issues or questions regarding the optimizations:
- Review the troubleshooting section above
- Check the GitHub issues for similar problems
- Create a new issue with detailed logs and environment information

## Best Practices for Production

1. **Start Small**: Begin migration with least critical guardrails
2. **Monitor Closely**: Watch performance metrics during initial deployment
3. **Gradual Rollout**: Migrate guardrails one at a time
4. **Test Thoroughly**: Validate results match original implementation
5. **Document Changes**: Keep detailed records of configuration changes
6. **Plan Rollback**: Always have a rollback plan ready
7. **Train Team**: Ensure team understands new optimization features

Remember: The goal is to maintain the same compliance checking functionality while significantly improving performance. Take time to validate that both aspects are achieved in your specific environment.