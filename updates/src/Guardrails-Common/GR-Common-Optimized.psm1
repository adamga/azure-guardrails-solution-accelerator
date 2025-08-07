# Optimized Common Functions for Azure Guardrails
# This module provides optimized versions of common functions used across guardrails

<#
.SYNOPSIS
    Optimized common functions for Azure Guardrails Solution Accelerator

.DESCRIPTION
    This module provides performance-optimized versions of common functions,
    including efficient tag operations, blob operations, and other utilities.

.NOTES
    Version: 2.0 (Optimized)
    Author: Azure Guardrails Team
    
    Performance Improvements:
    - StringBuilder for tag string operations
    - Batch processing capabilities
    - Optimized memory usage
    - Efficient collection operations
    - Enhanced error handling
#>

# Import performance utilities
Import-Module "$PSScriptRoot\GR-Performance.psm1" -Force

#region Optimized Tag Operations

<#
.SYNOPSIS
    Efficiently gets tag value from an object using optimized string operations
#>
function Get-TagValueOptimized {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TagKey,
        
        [Parameter(Mandatory = $true)]
        [System.Object] $Object,
        
        [Parameter(Mandatory = $false)]
        [switch] $UseCache
    )
    
    $cacheKey = "TagValue_$($Object.GetHashCode())_$TagKey"
    
    if ($UseCache) {
        $cachedValue = Get-PerformanceCache -Key $cacheKey
        if ($null -ne $cachedValue) {
            return $cachedValue
        }
    }
    
    $tagString = Get-TagStringOptimized -Object $Object -UseCache:$UseCache
    
    if ($tagString -eq "None" -or [string]::IsNullOrEmpty($tagString)) {
        return ""
    }
    
    # Use optimized string operations for tag parsing
    $tagsList = $tagString.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    
    foreach ($tag in $tagsList) {
        $tagParts = $tag.Split('=', 2)
        if ($tagParts.Length -eq 2 -and $tagParts[0] -eq $TagKey) {
            $result = $tagParts[1]
            
            if ($UseCache) {
                Set-PerformanceCache -Key $cacheKey -Value $result -TimeoutSeconds 600
            }
            
            return $result
        }
    }
    
    if ($UseCache) {
        Set-PerformanceCache -Key $cacheKey -Value "" -TimeoutSeconds 600
    }
    
    return ""
}

<#
.SYNOPSIS
    Efficiently builds tag string using StringBuilder for better performance
#>
function Get-TagStringOptimized {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Object] $Object,
        
        [Parameter(Mandatory = $false)]
        [switch] $UseCache
    )
    
    $cacheKey = "TagString_$($Object.GetHashCode())"
    
    if ($UseCache) {
        $cachedValue = Get-PerformanceCache -Key $cacheKey
        if ($null -ne $cachedValue) {
            return $cachedValue
        }
    }
    
    if ($null -eq $Object.Tag -or $Object.Tag.Count -eq 0) {
        $result = "None"
    } else {
        # Use StringBuilder for efficient string concatenation
        $sb = New-OptimizedStringBuilder -InitialCapacity 512
        
        # Get keys and values efficiently
        $keys = $Object.Tag.Keys
        $values = $Object.Tag.Values
        
        $index = 0
        foreach ($key in $keys) {
            if ($index -gt 0) {
                [void]$sb.Append(';')
            }
            [void]$sb.Append($key)
            [void]$sb.Append('=')
            [void]$sb.Append($values[$index])
            $index++
        }
        
        $result = $sb.ToString()
    }
    
    if ($UseCache) {
        Set-PerformanceCache -Key $cacheKey -Value $result -TimeoutSeconds 600
    }
    
    return $result
}

<#
.SYNOPSIS
    Efficiently gets resource group tag string using optimized operations
#>
function Get-RGTagStringOptimized {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Object] $Object,
        
        [Parameter(Mandatory = $false)]
        [switch] $UseCache
    )
    
    $cacheKey = "RGTagString_$($Object.GetHashCode())"
    
    if ($UseCache) {
        $cachedValue = Get-PerformanceCache -Key $cacheKey
        if ($null -ne $cachedValue) {
            return $cachedValue
        }
    }
    
    if ($null -eq $Object.Tags -or $Object.Tags.Count -eq 0) {
        $result = "None"
    } else {
        # Use StringBuilder for efficient string concatenation
        $sb = New-OptimizedStringBuilder -InitialCapacity 512
        
        # Get keys and values efficiently
        $keys = $Object.Tags.Keys
        $values = $Object.Tags.Values
        
        $index = 0
        foreach ($key in $keys) {
            if ($index -gt 0) {
                [void]$sb.Append(';')
            }
            [void]$sb.Append($key)
            [void]$sb.Append('=')
            [void]$sb.Append($values[$index])
            $index++
        }
        
        $result = $sb.ToString()
    }
    
    if ($UseCache) {
        Set-PerformanceCache -Key $cacheKey -Value $result -TimeoutSeconds 600
    }
    
    return $result
}

<#
.SYNOPSIS
    Efficiently gets resource group tag value using optimized string operations
#>
function Get-RGTagValueOptimized {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TagKey,
        
        [Parameter(Mandatory = $true)]
        [System.Object] $Object,
        
        [Parameter(Mandatory = $false)]
        [switch] $UseCache
    )
    
    $cacheKey = "RGTagValue_$($Object.GetHashCode())_$TagKey"
    
    if ($UseCache) {
        $cachedValue = Get-PerformanceCache -Key $cacheKey
        if ($null -ne $cachedValue) {
            return $cachedValue
        }
    }
    
    $tagString = Get-RGTagStringOptimized -Object $Object -UseCache:$UseCache
    
    if ($tagString -eq "None" -or [string]::IsNullOrEmpty($tagString)) {
        return ""
    }
    
    # Use optimized string operations for tag parsing
    $tagsList = $tagString.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    
    foreach ($tag in $tagsList) {
        $tagParts = $tag.Split('=', 2)
        if ($tagParts.Length -eq 2 -and $tagParts[0] -eq $TagKey) {
            $result = $tagParts[1]
            
            if ($UseCache) {
                Set-PerformanceCache -Key $cacheKey -Value $result -TimeoutSeconds 600
            }
            
            return $result
        }
    }
    
    if ($UseCache) {
        Set-PerformanceCache -Key $cacheKey -Value "" -TimeoutSeconds 600
    }
    
    return ""
}

#endregion

#region Optimized Blob Operations

<#
.SYNOPSIS
    Optimized blob copy operation with retry logic and performance monitoring
#>
function Copy-ToBlobOptimized {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $FilePath,
        
        [Parameter(Mandatory = $true)]
        [string] $StorageAccountName,
        
        [Parameter(Mandatory = $true)]
        [string] $ResourceGroup,
        
        [Parameter(Mandatory = $true)]
        [string] $ContainerName,
        
        [Parameter(Mandatory = $false)]
        [switch] $Force,
        
        [Parameter(Mandatory = $false)]
        [int] $MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [switch] $UseOptimizedUpload
    )
    
    $performanceResult = Measure-OperationPerformance -OperationName "Blob Upload" -Operation {
        
        $attempt = 0
        do {
            $attempt++
            try {
                Write-Verbose "Blob upload attempt $attempt for file: $FilePath"
                
                # Get storage account context with caching
                $storageAccount = Get-StorageAccountOptimized -ResourceGroupName $ResourceGroup -StorageAccountName $StorageAccountName
                $ctx = $storageAccount.Context
                
                # Optimize upload based on file size
                $fileInfo = Get-Item -Path $FilePath
                $fileName = $fileInfo.Name
                
                if ($UseOptimizedUpload -and $fileInfo.Length -gt 64MB) {
                    # Use optimized upload for large files
                    Write-Verbose "Using optimized upload for large file ($($fileInfo.Length) bytes)"
                    $blob = Set-AzStorageBlobContent -File $FilePath -Container $ContainerName -Blob $fileName -Context $ctx -Force:$Force -BlobType Block -StandardBlobTier Hot
                } else {
                    # Standard upload for smaller files
                    $blob = Set-AzStorageBlobContent -File $FilePath -Container $ContainerName -Blob $fileName -Context $ctx -Force:$Force
                }
                
                Write-Verbose "Successfully uploaded file to blob: $($blob.Name)"
                return $blob
            }
            catch {
                if ($attempt -ge $MaxRetries) {
                    Write-Error "Blob upload failed after $MaxRetries attempts: $_"
                    throw
                } else {
                    Write-Warning "Blob upload attempt $attempt failed, retrying: $_"
                    Start-Sleep -Seconds (2 * $attempt) # Exponential backoff
                }
            }
        } while ($attempt -lt $MaxRetries)
    }
    
    Write-Verbose "Blob upload completed in $($performanceResult.ElapsedMilliseconds)ms"
    return $performanceResult.Result
}

<#
.SYNOPSIS
    Gets storage account with caching for performance optimization
#>
function Get-StorageAccountOptimized {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string] $StorageAccountName
    )
    
    $cacheKey = "StorageAccount_$ResourceGroupName_$StorageAccountName"
    $cachedAccount = Get-PerformanceCache -Key $cacheKey
    
    if ($null -ne $cachedAccount) {
        return $cachedAccount
    }
    
    try {
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
        
        # Cache for 10 minutes
        Set-PerformanceCache -Key $cacheKey -Value $storageAccount -TimeoutSeconds 600
        
        return $storageAccount
    }
    catch {
        Write-Error "Failed to get storage account '$StorageAccountName' in resource group '$ResourceGroupName': $_"
        throw
    }
}

#endregion

#region Batch Processing Functions

<#
.SYNOPSIS
    Processes multiple objects in batches for tag operations
#>
function Get-TagValuesBatch {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array] $Objects,
        
        [Parameter(Mandatory = $true)]
        [string] $TagKey,
        
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 50,
        
        [Parameter(Mandatory = $false)]
        [switch] $UseCache
    )
    
    $results = New-OptimizedList -InitialCapacity $Objects.Count
    
    $batchOperation = {
        param($batch)
        $batchResults = New-OptimizedList -InitialCapacity $batch.Count
        
        foreach ($obj in $batch) {
            $tagValue = Get-TagValueOptimized -TagKey $TagKey -Object $obj -UseCache:$UseCache
            [void]$batchResults.Add(@{
                Object = $obj
                TagKey = $TagKey
                TagValue = $tagValue
            })
        }
        
        return $batchResults.ToArray()
    }
    
    $batchResults = Invoke-BatchOperation -Items $Objects -Operation $batchOperation -BatchSize $BatchSize
    
    foreach ($result in $batchResults) {
        [void]$results.Add($result)
    }
    
    return $results.ToArray()
}

#endregion

#region Enhanced Error Handling

<#
.SYNOPSIS
    Centralized error handling with consistent patterns
#>
function Invoke-GuardrailOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock] $Operation,
        
        [Parameter(Mandatory = $true)]
        [string] $OperationName,
        
        [Parameter(Mandatory = $false)]
        [hashtable] $ErrorList = @{},
        
        [Parameter(Mandatory = $false)]
        [int] $MaxRetries = 1,
        
        [Parameter(Mandatory = $false)]
        [switch] $ContinueOnError
    )
    
    $attempt = 0
    do {
        $attempt++
        try {
            Write-Verbose "Executing $OperationName (attempt $attempt)"
            $result = & $Operation
            return $result
        }
        catch {
            $errorMessage = "Failed to execute '$OperationName' (attempt $attempt): $_"
            
            if ($attempt -ge $MaxRetries) {
                $ErrorList[$OperationName] = $errorMessage
                
                if ($ContinueOnError) {
                    Write-Warning $errorMessage
                    return $null
                } else {
                    Write-Error $errorMessage
                    throw
                }
            } else {
                Write-Warning "$errorMessage. Retrying..."
                Start-Sleep -Seconds $attempt
            }
        }
    } while ($attempt -lt $MaxRetries)
}

#endregion

# Export optimized functions
Export-ModuleMember -Function @(
    'Get-TagValueOptimized',
    'Get-TagStringOptimized',
    'Get-RGTagStringOptimized', 
    'Get-RGTagValueOptimized',
    'Copy-ToBlobOptimized',
    'Get-StorageAccountOptimized',
    'Get-TagValuesBatch',
    'Invoke-GuardrailOperation'
)

# Maintain backward compatibility by aliasing to original function names
Set-Alias -Name 'get-tagValue' -Value 'Get-TagValueOptimized'
Set-Alias -Name 'get-tagstring' -Value 'Get-TagStringOptimized'
Set-Alias -Name 'get-rgtagstring' -Value 'Get-RGTagStringOptimized'
Set-Alias -Name 'get-rgtagValue' -Value 'Get-RGTagValueOptimized'
Set-Alias -Name 'copy-toBlob' -Value 'Copy-ToBlobOptimized'

Export-ModuleMember -Alias @(
    'get-tagValue',
    'get-tagstring',
    'get-rgtagstring',
    'get-rgtagValue',
    'copy-toBlob'
)