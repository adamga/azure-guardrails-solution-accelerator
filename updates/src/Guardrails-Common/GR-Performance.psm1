# Performance Utilities Module for Azure Guardrails
# This module provides performance optimization utilities and patterns

<#
.SYNOPSIS
    Performance utilities for Azure Guardrails Solution Accelerator

.DESCRIPTION
    This module provides optimized functions for common operations used across guardrails,
    including caching, batch processing, parallel execution, and efficient data handling.

.NOTES
    Version: 2.0 (Optimized)
    Author: Azure Guardrails Team
    
    Performance Improvements:
    - Batch API processing
    - Intelligent caching
    - Parallel execution support
    - Memory optimization
    - Efficient string operations
#>

# Global cache storage
$script:CacheStorage = @{}
$script:CacheExpiry = @{}
$script:DefaultCacheTimeout = 300 # 5 minutes

#region Caching Functions

<#
.SYNOPSIS
    Sets a value in the performance cache
#>
function Set-PerformanceCache {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Key,
        
        [Parameter(Mandatory = $true)]
        [object] $Value,
        
        [Parameter(Mandatory = $false)]
        [int] $TimeoutSeconds = $script:DefaultCacheTimeout
    )
    
    $expiryTime = (Get-Date).AddSeconds($TimeoutSeconds)
    $script:CacheStorage[$Key] = $Value
    $script:CacheExpiry[$Key] = $expiryTime
    
    Write-Verbose "Cached '$Key' with expiry: $expiryTime"
}

<#
.SYNOPSIS
    Gets a value from the performance cache
#>
function Get-PerformanceCache {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Key
    )
    
    if ($script:CacheStorage.ContainsKey($Key)) {
        $expiryTime = $script:CacheExpiry[$Key]
        
        if ((Get-Date) -lt $expiryTime) {
            Write-Verbose "Cache hit for '$Key'"
            return $script:CacheStorage[$Key]
        } else {
            # Cache expired, remove it
            $script:CacheStorage.Remove($Key)
            $script:CacheExpiry.Remove($Key)
            Write-Verbose "Cache expired for '$Key'"
        }
    }
    
    Write-Verbose "Cache miss for '$Key'"
    return $null
}

<#
.SYNOPSIS
    Clears the performance cache
#>
function Clear-PerformanceCache {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string] $KeyPattern = "*"
    )
    
    if ($KeyPattern -eq "*") {
        $script:CacheStorage.Clear()
        $script:CacheExpiry.Clear()
        Write-Verbose "Cleared entire cache"
    } else {
        $keysToRemove = $script:CacheStorage.Keys | Where-Object { $_ -like $KeyPattern }
        foreach ($key in $keysToRemove) {
            $script:CacheStorage.Remove($key)
            $script:CacheExpiry.Remove($key)
        }
        Write-Verbose "Cleared cache entries matching '$KeyPattern'"
    }
}

#endregion

#region Batch Processing Functions

<#
.SYNOPSIS
    Executes operations in batches to improve performance
#>
function Invoke-BatchOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array] $Items,
        
        [Parameter(Mandatory = $true)]
        [scriptblock] $Operation,
        
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20,
        
        [Parameter(Mandatory = $false)]
        [int] $DelayBetweenBatches = 100
    )
    
    $results = @()
    $totalItems = $Items.Count
    $processedItems = 0
    
    Write-Verbose "Processing $totalItems items in batches of $BatchSize"
    
    for ($i = 0; $i -lt $totalItems; $i += $BatchSize) {
        $endIndex = [Math]::Min($i + $BatchSize - 1, $totalItems - 1)
        $batch = $Items[$i..$endIndex]
        
        Write-Verbose "Processing batch $([Math]::Floor($i / $BatchSize) + 1): items $($i + 1) to $($endIndex + 1)"
        
        try {
            $batchResults = & $Operation $batch
            $results += $batchResults
            $processedItems += $batch.Count
            
            # Add delay between batches to avoid throttling
            if ($i + $BatchSize -lt $totalItems -and $DelayBetweenBatches -gt 0) {
                Start-Sleep -Milliseconds $DelayBetweenBatches
            }
        }
        catch {
            Write-Warning "Error processing batch starting at index $i: $_"
            # Continue with next batch
        }
    }
    
    Write-Verbose "Completed batch processing. Processed $processedItems of $totalItems items"
    return $results
}

#endregion

#region Parallel Processing Functions

<#
.SYNOPSIS
    Executes operations in parallel using PowerShell jobs
#>
function Invoke-ParallelOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array] $Items,
        
        [Parameter(Mandatory = $true)]
        [scriptblock] $Operation,
        
        [Parameter(Mandatory = $false)]
        [int] $MaxConcurrent = 5,
        
        [Parameter(Mandatory = $false)]
        [int] $TimeoutMinutes = 30
    )
    
    $jobs = @()
    $results = @()
    $totalItems = $Items.Count
    
    Write-Verbose "Starting parallel processing of $totalItems items with max $MaxConcurrent concurrent jobs"
    
    try {
        # Start jobs in batches
        for ($i = 0; $i -lt $totalItems; $i += $MaxConcurrent) {
            $endIndex = [Math]::Min($i + $MaxConcurrent - 1, $totalItems - 1)
            $currentBatch = $Items[$i..$endIndex]
            
            foreach ($item in $currentBatch) {
                $job = Start-Job -ScriptBlock $Operation -ArgumentList $item
                $jobs += $job
                Write-Verbose "Started job $($job.Id) for item: $($item.ToString().Substring(0, [Math]::Min(50, $item.ToString().Length)))"
            }
            
            # Wait for current batch to complete before starting next
            if ($i + $MaxConcurrent -lt $totalItems) {
                $batchJobs = $jobs | Where-Object { $_.State -eq 'Running' }
                Wait-Job -Job $batchJobs -Timeout (60 * $TimeoutMinutes) | Out-Null
                
                # Collect results from completed jobs
                foreach ($job in $batchJobs) {
                    if ($job.State -eq 'Completed') {
                        $jobResult = Receive-Job -Job $job
                        $results += $jobResult
                        Remove-Job -Job $job
                    } elseif ($job.State -eq 'Failed') {
                        Write-Warning "Job $($job.Id) failed: $($job.ChildJobs[0].JobStateInfo.Reason)"
                        Remove-Job -Job $job
                    }
                }
                
                # Update jobs list to only include remaining jobs
                $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
            }
        }
        
        # Wait for final batch
        if ($jobs.Count -gt 0) {
            Wait-Job -Job $jobs -Timeout (60 * $TimeoutMinutes) | Out-Null
            
            foreach ($job in $jobs) {
                if ($job.State -eq 'Completed') {
                    $jobResult = Receive-Job -Job $job
                    $results += $jobResult
                } elseif ($job.State -eq 'Failed') {
                    Write-Warning "Job $($job.Id) failed: $($job.ChildJobs[0].JobStateInfo.Reason)"
                }
                Remove-Job -Job $job
            }
        }
    }
    finally {
        # Cleanup any remaining jobs
        $jobs | Where-Object { $_.State -ne 'Completed' -and $_.State -ne 'Failed' } | Remove-Job -Force
    }
    
    Write-Verbose "Completed parallel processing. Collected $($results.Count) results"
    return $results
}

#endregion

#region Efficient String Operations

<#
.SYNOPSIS
    Efficiently builds strings for large outputs
#>
function New-OptimizedStringBuilder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [int] $InitialCapacity = 1024
    )
    
    return [System.Text.StringBuilder]::new($InitialCapacity)
}

<#
.SYNOPSIS
    Efficiently joins arrays with separators
#>
function Join-ArrayOptimized {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array] $Array,
        
        [Parameter(Mandatory = $false)]
        [string] $Separator = ", "
    )
    
    if ($Array.Count -eq 0) {
        return ""
    }
    
    if ($Array.Count -eq 1) {
        return $Array[0].ToString()
    }
    
    # Use StringBuilder for large arrays
    if ($Array.Count -gt 10) {
        $sb = [System.Text.StringBuilder]::new()
        for ($i = 0; $i -lt $Array.Count; $i++) {
            if ($i -gt 0) {
                [void]$sb.Append($Separator)
            }
            [void]$sb.Append($Array[$i].ToString())
        }
        return $sb.ToString()
    } else {
        # Use simple join for small arrays
        return $Array -join $Separator
    }
}

#endregion

#region Memory Optimization

<#
.SYNOPSIS
    Creates an optimized array list for better memory performance
#>
function New-OptimizedList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [int] $InitialCapacity = 100
    )
    
    $list = [System.Collections.Generic.List[object]]::new($InitialCapacity)
    return $list
}

<#
.SYNOPSIS
    Disposes of large objects to free memory
#>
function Clear-LargeObjects {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object[]] $Objects
    )
    
    foreach ($obj in $Objects) {
        if ($obj -is [System.IDisposable]) {
            $obj.Dispose()
        }
    }
    
    # Force garbage collection for large memory cleanup
    if ($Objects.Count -gt 1000) {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        Write-Verbose "Performed garbage collection for $($Objects.Count) objects"
    }
}

#endregion

#region API Optimization

<#
.SYNOPSIS
    Optimized Graph API query with caching and retry logic
#>
function Invoke-OptimizedGraphQuery {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $UrlPath,
        
        [Parameter(Mandatory = $false)]
        [hashtable] $Headers = @{},
        
        [Parameter(Mandatory = $false)]
        [string] $Method = "GET",
        
        [Parameter(Mandatory = $false)]
        [object] $Body = $null,
        
        [Parameter(Mandatory = $false)]
        [switch] $UseCache,
        
        [Parameter(Mandatory = $false)]
        [int] $CacheTimeoutSeconds = 300,
        
        [Parameter(Mandatory = $false)]
        [int] $MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int] $RetryDelaySeconds = 2
    )
    
    $cacheKey = "GraphQuery_$($Method)_$($UrlPath)_$($Body | ConvertTo-Json -Compress -Depth 2)"
    
    # Check cache first
    if ($UseCache) {
        $cachedResult = Get-PerformanceCache -Key $cacheKey
        if ($null -ne $cachedResult) {
            return $cachedResult
        }
    }
    
    $attempt = 0
    do {
        $attempt++
        try {
            Write-Verbose "Graph API call attempt $attempt to: $UrlPath"
            
            $result = Invoke-GraphQuery -urlPath $UrlPath -Headers $Headers -Method $Method -Body $Body -ErrorAction Stop
            
            # Cache successful result
            if ($UseCache) {
                Set-PerformanceCache -Key $cacheKey -Value $result -TimeoutSeconds $CacheTimeoutSeconds
            }
            
            return $result
        }
        catch {
            if ($attempt -ge $MaxRetries) {
                Write-Error "Graph API call failed after $MaxRetries attempts: $_"
                throw
            } else {
                Write-Warning "Graph API call attempt $attempt failed, retrying in $RetryDelaySeconds seconds: $_"
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    } while ($attempt -lt $MaxRetries)
}

#endregion

#region Performance Measurement

<#
.SYNOPSIS
    Measures execution time of operations
#>
function Measure-OperationPerformance {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock] $Operation,
        
        [Parameter(Mandatory = $false)]
        [string] $OperationName = "Operation"
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $result = & $Operation
        $stopwatch.Stop()
        
        Write-Verbose "$OperationName completed in $($stopwatch.ElapsedMilliseconds)ms"
        
        return @{
            Result = $result
            ElapsedMilliseconds = $stopwatch.ElapsedMilliseconds
            ElapsedSeconds = $stopwatch.Elapsed.TotalSeconds
        }
    }
    catch {
        $stopwatch.Stop()
        Write-Error "$OperationName failed after $($stopwatch.ElapsedMilliseconds)ms: $_"
        throw
    }
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'Set-PerformanceCache',
    'Get-PerformanceCache', 
    'Clear-PerformanceCache',
    'Invoke-BatchOperation',
    'Invoke-ParallelOperation',
    'New-OptimizedStringBuilder',
    'Join-ArrayOptimized',
    'New-OptimizedList',
    'Clear-LargeObjects',
    'Invoke-OptimizedGraphQuery',
    'Measure-OperationPerformance'
)