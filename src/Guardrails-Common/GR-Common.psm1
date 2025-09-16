function get-tagValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $tagKey,
        [Parameter(Mandatory = $true)]
        [System.Object] $object
    )
    $tagString = get-tagstring($object)
    $tagslist = $tagString.split(";")
    foreach ($tag in $tagslist) {
        if ($tag.split("=")[0] -eq $tagKey) {
            return $tag.split("=")[1]
        }
    }
    return ""
}
function get-tagstring {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Object] $object
    )
    if ($object.Tag.Count -eq 0) {
        $tagstring = "None"
    }
    else {
        $tagstring = [System.Text.StringBuilder]::new()
        $tKeys = $object.tag | Select-Object -ExpandProperty keys
        $tValues = $object.Tag | Select-Object -ExpandProperty values
        $index = 0
        foreach ($tkey in $tKeys) {
            [void]$tagstring.Append("$tkey=$($tValues[$index]);")
            $index++
        }
        $tagstring = $tagstring.ToString().TrimEnd(';')
    }
    return $tagstring
}
function get-rgtagstring {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Object] $object
    )
    if ($object.Tags.Count -eq 0) {
        $tagstring = "None"
    }
    else {
        $tagstring = [System.Text.StringBuilder]::new()
        $tKeys = $object.tags | Select-Object -ExpandProperty keys
        $tValues = $object.Tags | Select-Object -ExpandProperty values
        $index = 0
        foreach ($tkey in $tKeys) {
            [void]$tagstring.Append("$tkey=$($tValues[$index]);")
            $index++
        }
        $tagstring = $tagstring.ToString().TrimEnd(';')
    }
    return $tagstring
}
function get-rgtagValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $tagKey,
        [Parameter(Mandatory = $true)]
        [System.Object] $object
    )
    $tagString = get-rgtagstring($object)
    $tagslist = $tagString.split(";")
    foreach ($tag in $tagslist) {
        if ($tag.split("=")[0] -eq $tagKey) {
            return $tag.split("=")[1]
        }
    }
    return ""
}
function copy-toBlob {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $FilePath,
        [Parameter(Mandatory = $true)]
        [string]
        $storageaccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $resourcegroup,
        [Parameter(Mandatory = $true)]
        [string]
        $containerName,
        [Parameter(Mandatory = $false)]
        [switch]
        $force
    )
    try {
        $saParams = @{
            ResourceGroupName = $resourcegroup
            Name              = $storageaccountName
        }
        $scParams = @{
            Container = $containerName
        }
        $bcParams = @{
            File = $FilePath
            Blob = ($FilePath | Split-Path -Leaf)
        }
        if ($force)
        { Get-AzStorageAccount @saParams | Get-AzStorageContainer @scParams | Set-AzStorageBlobContent @bcParams -Force | Out-Null }
        else { Get-AzStorageAccount @saParams | Get-AzStorageContainer @scParams | Set-AzStorageBlobContent @bcParams | Out-Null }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}
function get-blobs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $storageaccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $resourcegroup
    )
    $psModulesContainerName = "psmodules"
    try {
        $saParams = @{
            ResourceGroupName = $resourcegroup
            Name              = $storageaccountName
        }
        $scParams = @{
            Container = $psModulesContainerName
        }
        return (Get-AzStorageAccount @saParams | Get-AzStorageContainer @scParams | Get-AzStorageBlob)
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

function read-blob {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $FilePath,
        [Parameter(Mandatory = $true)]
        [string]
        $storageaccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $resourcegroup,
        [Parameter(Mandatory = $true)]
        [string]
        $containerName,
        [Parameter(Mandatory = $false)]
        [switch]
        $force
    )
    $Context = (Get-AzStorageAccount -ResourceGroupName $resourcegroup -Name $storageaccountName).Context
    $blobParams = @{
        Blob        = 'modules.json'
        Container   = $containerName
        Destination = $FilePath
        Context     = $Context
        Force       = $true
    }
    Get-AzStorageBlobContent @blobParams
}

Function Add-LogEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateSet("Critical", "Error", "Warning", "Information", "Debug")]
        [string]
        $severity,

        # message details (string)
        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $message,

        # module name
        [Parameter(Mandatory = $false)]
        [string]
        $moduleName = (Split-Path -Path $MyInvocation.ScriptName -Leaf),

        # additional values in hashtable
        [Parameter(Mandatory = $false)]
        [hashtable]
        $additionalValues = @{},

        # exception log type - this is the Log Analytics table name
        [Parameter(Mandatory = $false)]
        [string]
        $exceptionLogTable = "GuardrailsComplianceException",

        # guardrails exception workspace GUID
        [Parameter(Mandatory = $true)]
        [string]
        $workspaceGuid,

        # guardrails exception workspace shared key
        [Parameter(Mandatory = $true)]
        [string]
        $workspaceKey
    )

    # build log entry object, convert to json
    $entryHash = @{
        "message"    = $message
        "moduleName" = $moduleName
        "severity"   = $severity
    } + $additionalValues
    
    $entryJson = ConvertTo-Json -inputObject $entryHash -Depth 20

    # log event to Log Analytics workspace by REST API via the OMSIngestionAPI community PS module
    Send-OMSAPIIngestionFile  -customerId $workspaceGuid `
        -sharedkey $workspaceKey `
        -body $entryJson `
        -logType $exceptionLogTable `
        -TimeStampField Get-Date 

}

Function Add-TenantInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $WorkSpaceID,
        [Parameter(Mandatory = $true)]
        [string]
        $workspaceKey,
        [Parameter(Mandatory = $false)]
        [string]
        $LogType = "GR_TenantInfo",
        [Parameter(Mandatory = $true)]
        [string]
        $ReportTime,
        [Parameter(Mandatory = $true)]
        [string]
        $TenantId,
        [Parameter(Mandatory = $true)]
        [string]
        $DepartmentName,
        [Parameter(Mandatory = $true)]
        [string]
        $DepartmentNumber,
        [Parameter(Mandatory = $true)]
        [string]
        $cloudUsageProfiles,
        [Parameter(Mandatory = $true)]
        [string]
        $tenantName
    )
    $tenantInfo = Get-GSAAutomationVariable("tenantDomainUPN")

    $object = [PSCustomObject]@{ 
        TenantDomain       = $tenantInfo
        DepartmentTenantID = $TenantId
        DepartmentTenantName= $tenantName
        ReportTime         = $ReportTime
        DepartmentName     = $DepartmentName
        DepartmentNumber   = $DepartmentNumber
        cloudUsageProfiles = $cloudUsageProfiles
    }
    if ($debug) { Write-Output $tenantInfo }
    $JSON = ConvertTo-Json -inputObject $object

    Send-OMSAPIIngestionFile  -customerId $WorkSpaceID `
        -sharedkey $workspaceKey `
        -body $JSON `
        -logType $LogType `
        -TimeStampField Get-Date 
}

function Add-LogAnalyticsResults {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $WorkSpaceID,
        [Parameter(Mandatory = $true)]
        [string]
        $workspaceKey,
        [Parameter(Mandatory = $false)]
        [string]
        $LogType = "GR_Results",
        [Parameter(Mandatory = $false)]
        [array]
        $Results
    )

    $JSON = ConvertTo-Json -inputObject $Results

    Send-OMSAPIIngestionFile  -customerId $WorkSpaceID `
        -sharedkey $workspaceKey `
        -body $JSON `
        -logType $LogType `
        -TimeStampField Get-Date 
}

function Check-DocumentExistsInStorage {
    [Alias('Check-DocumentsExistInStorage')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $StorageAccountName,
        [Parameter(Mandatory = $true)]
        [string] $ContainerName, 
        [Parameter(Mandatory = $true)]
        [string] $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string] $SubscriptionID, 
        [Parameter(Mandatory = $true)]
        [string[]] $DocumentName, 
        [Parameter(Mandatory = $true)]
        [string] $ControlName, 
        [Parameter(Mandatory = $true)]
        [string]$ItemName,
        [Parameter(Mandatory = $true)]
        [hashtable] $msgTable, 
        [Parameter(Mandatory = $true)]
        [string]$itsgcode,
        [Parameter(Mandatory = $true)]
        [string]
        $ReportTime,
        [Parameter(Mandatory = $false)]
        [string] 
        $CloudUsageProfiles = "3",  # Passed as a string
        [Parameter(Mandatory = $false)]
        [string] $ModuleProfiles,  # Passed as a string
        [Parameter(Mandatory = $false)]
        [switch] $EnableMultiCloudProfiles # New feature flag, default to false    
    )
    [PSCustomObject] $ErrorList = New-Object System.Collections.ArrayList
    [bool] $IsCompliant = $false
    [string] $Comments = $null

    # Add possible file extensions
    $DocumentName_new = add-documentFileExtensions -DocumentName $DocumentName -ItemName $ItemName

    try {
        Select-AzSubscription -Subscription $SubscriptionID | out-null
    }
    catch {
        $ErrorList.Add("Failed to run 'Select-Azsubscription' with error: $_")
        #Add-LogEntry 'Error' 
        throw "Error: Failed to run 'Select-Azsubscription' with error: $_"
    }
    try {
        $StorageAccount = Get-Azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
    }
    catch {
        $ErrorList.Add("Could not find storage account '$storageAccountName' in resoruce group '$resourceGroupName' of `
        subscription '$subscriptionId'; verify that the storage account exists and that you have permissions to it. Error: $_")
        #Add-LogEntry 'Error' "Could not find storage account '$storageAccountName' in resoruce group '$resourceGroupName' of `
        #    subscription '$subscriptionId'; verify that the storage account exists and that you have permissions to it. Error: $_" `
        #    -workspaceKey $workspaceKey -workspaceGuid $WorkSpaceID
        Write-Error "Could not find storage account '$storageAccountName' in resoruce group '$resourceGroupName' of `
            subscription '$subscriptionId'; verify that the storage account exists and that you have permissions to it. Error: $_"
    }

    $docMissing = $false
    $commentsArray = @()
    $blobFound = $false
   
    ForEach ($docName in $DocumentName_new) {
        # check for procedure doc in blob storage account
        $blobs = Get-AzStorageBlob -Container $ContainerName -Context $StorageAccount.Context -Blob $docName -ErrorAction SilentlyContinue

        If ($blobs) {
            $blobFound = $true
            break
        }
    }

    if ($blobFound){
        # a blob with the name $attestationFileName was located in the specified storage account
        $commentsArray += $msgTable.procedureFileFound -f $docName
    }
    else {
        # no blob with the name $attestationFileName was found in the specified storage account
        $docMissing = $true
        $commentsArray += $msgTable.procedureFileNotFound -f $DocumentName[0], $ContainerName, $StorageAccountName
    }

    $Comments = $commentsArray -join ";"

    If ($docMissing) {
        $IsCompliant = $false
    }
    Else {
        $IsCompliant = $true
    }

    $PsObject = [PSCustomObject]@{
        ComplianceStatus = $IsCompliant
        ControlName      = $ControlName
        ItemName         = $ItemName
        DocumentName     = $DocumentName
        Comments         = $Comments
        ReportTime       = $ReportTime
        itsgcode         = $itsgcode
    }

    if ($EnableMultiCloudProfiles) {        
        $evalResult = Get-EvaluationProfile -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles -SubscriptionId $SubscriptionID
        if (!$evalResult.ShouldEvaluate) {
            if ($evalResult.Profile -gt 0) {
                $PsObject.ComplianceStatus = "Not Applicable"
                $PsObject | Add-Member -MemberType NoteProperty -Name "Profile" -Value $evalResult.Profile
                $PsObject.Comments = "Not evaluated - Profile $($evalResult.Profile) not present in CloudUsageProfiles"
                
                $moduleOutput = [PSCustomObject]@{ 
                    ComplianceResults = $PsObject
                    Errors            = $ErrorList
                    AdditionalResults = $AdditionalResults
                }
                return $moduleOutput
            } else {
                $ErrorList.Add("Error occurred while evaluating profile configuration")
            }
        } else {
            
            $PsObject | Add-Member -MemberType NoteProperty -Name "Profile" -Value $evalResult.Profile
        }
    }

    $moduleOutput = [PSCustomObject]@{ 
        ComplianceResults = $PsObject
        Errors            = $ErrorList
        AdditionalResults = $AdditionalResults
    }
    return $moduleOutput

}

function Check-UpdateAvailable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $WorkSpaceID,
        [Parameter(Mandatory = $true)]
        [string]
        $workspaceKey,
        [Parameter(Mandatory = $false)]
        [string]
        $LogType = "GR_VersionInfo",
        [Parameter(Mandatory = $true)]
        [string]
        $ReportTime,
        [Parameter(Mandatory = $false)]
        [string]
        $ResourceGroupName
    )
    #fetches current public version (from repo...maybe should download the zip...)
    $latestRelease = Invoke-RestMethod 'https://api.github.com/repos/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator/releases/latest' -Verbose:$false
    $tagsFileURI = "https://github.com/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator/raw/{0}/setup/tags.json" -f $latestRelease.name
    $tags = Invoke-RestMethod $tagsFileURI -Verbose:$false

    if ([string]::IsNullOrEmpty($ResourceGroupName)) {
        $ResourceGroupName = Get-AutomationVariable -Name "ResourceGroupName"
    }
    $rg=Get-AzResourceGroup -Name $ResourceGroupName 

    $deployedVersion=$rg.Tags["ReleaseVersion"]
    $currentVersion = $tags.ReleaseVersion

    try {
        # script version numbers of surrounding characters and then converted to a version object
        $deployedVersionVersion = [version]::Parse(($deployedVersion -replace '[\w-]+?(\d+?\.\d+?\.\d+?(\.\d+?)?)[\w-]*$','$1'))
        $currentVersionVersion = [version]::Parse(($currentVersion -replace '[\w-]+?(\d+?\.\d+?\.\d+?(\.\d+?)?)[\w-]*$','$1'))
    }
    catch {
        Write-Error "Error: Failed to convert version numbers to version objects. Error: $_"
    }

    if ($debug) { Write-Output "Resource Group Tag (deployed version): $deployedVersion; $deployedVersionVersion"}
    if ($debug) { Write-Output "Latest available version from GitHub: $currentVersion; $currentVersionVersion"}
    
    if ($deployedVersionVersion -lt $currentVersionVersion)
    {
        $updateNeeded=$true
    }
    else {
        $updateNeeded = $false
    }
    $object = [PSCustomObject]@{ 
        DeployedVersion = $deployedVersion
        AvailableVersion = $currentVersion
        UpdateNeeded= $updateNeeded
        ReportTime = $ReportTime
    }
    $JSON = ConvertTo-Json -inputObject $object

    Send-OMSAPIIngestionFile  -customerId $WorkSpaceID `
        -sharedkey $workspaceKey `
        -body $JSON `
        -logType $LogType `
        -TimeStampField Get-Date 
}

function get-itsgdata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $URL,
        [Parameter(Mandatory = $true)]
        [string] $WorkSpaceID,
        [Parameter(Mandatory = $true)]
        [string] $workspaceKey,
        [Parameter(Mandatory = $false)]
        [string] $LogType = "GRITSGControls",
        [Parameter(Mandatory = $false)]
        [switch] $DebugCode
    )
    (Invoke-WebRequest -UseBasicParsing $URL).Content | out-file tempitsg.csv
    $Header = "Family", "Control ID", "Enhancement", "Name", "Class", "Definition", "Supplemental Guidance,References"
    $itsgtempinfo = Import-Csv ./tempitsg.csv -Header $Header
    $itsginfo = $itsgtempinfo | Select-Object Name, Definition, @{Name = "itsgcode"; Expression = { ($_.Family + $_."Control ID" + $_.Enhancement).replace("`t", "") } }
    $JSONcontrols = ConvertTo-Json -inputObject $itsginfo
    
    if ($DebugCode) {
        $JSONcontrols
    }

    Send-OMSAPIIngestionFile  -customerId $WorkSpaceID `
        -sharedkey $workspaceKey `
        -body $JSONcontrols `
        -logType $LogType `
        -TimeStampField Get-Date
}
function New-LogAnalyticsData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array] 
        $Data,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkSpaceID,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkSpaceKey,
        [Parameter(Mandatory = $true)]
        [string]
        $LogType
    )
    $JsonObject = convertTo-Json -inputObject $Data -Depth 3

    Send-OMSAPIIngestionFile  -customerId $WorkSpaceID `
        -sharedkey $workspaceKey `
        -body $JsonObject `
        -logType $LogType `
        -TimeStampField Get-Date  
}

function Hide-Email {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$email
    )

    $parts = $email -split '@'
    if ($parts.Length -eq 2) {
        $username = $parts[0]
        $domain = $parts[1]

        $hiddenUsername = $username[0] + ($username.Substring(1, $username.Length - 2) -replace '.', '#') + $username[-1]
        $hiddenDomain = $domain[0] + ($domain.Substring(1, $domain.Length - 5) -replace '.', '#') + $domain[-4] + $domain[-3] + $domain[-2] + $domain[-1]

        $hiddenEmail = "$hiddenUsername@$hiddenDomain"
        return $hiddenEmail
    } else {
        return "Invalid email format"
    }
}

function Get-EvaluationProfile {
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $CloudUsageProfiles,
        [Parameter(Mandatory = $true)]
        [string] $ModuleProfiles,
        [Parameter(Mandatory = $false)]
        [string] $SubscriptionId
    )

    try {
        # Convert input strings to integer arrays  
        $cloudUsageProfileArray = ConvertTo-IntArray $CloudUsageProfiles
        $moduleProfileArray = ConvertTo-IntArray $ModuleProfiles

        if (-not $SubscriptionId) {
            $matchedProfile = Get-HighestMatchingProfile $cloudUsageProfileArray $moduleProfileArray
            return [PSCustomObject]@{
                Profile = $matchedProfile
                ShouldEvaluate = ($matchedProfile -in $cloudUsageProfileArray)
            }
        }

        $subscriptionTags = Get-AzTag -ResourceId "subscriptions/$SubscriptionId" -ErrorAction Stop
        $profileTagValues = if ($subscriptionTags.Properties -and 
                              $subscriptionTags.Properties.TagsProperty -and 
                              $subscriptionTags.Properties.TagsProperty['profile']) {
            $subscriptionTags.Properties.TagsProperty['profile']
        } else {
            $null
        }

        if ($null -eq $profileTagValues) {
            $matchedProfile = Get-HighestMatchingProfile $cloudUsageProfileArray $moduleProfileArray
            return [PSCustomObject]@{
                Profile = $matchedProfile
                ShouldEvaluate = ($matchedProfile -in $cloudUsageProfileArray)
            }
        }

        $profileTagValuesArray = ConvertTo-IntArray $profileTagValues

        # Get the highest profile from all sources
        $highestCloudUsageProfile = ($cloudUsageProfileArray | Measure-Object -Maximum).Maximum
        $highestModuleProfile = ($moduleProfileArray | Measure-Object -Maximum).Maximum
        $highestTagProfile = ($profileTagValuesArray | Measure-Object -Maximum).Maximum

        # Use the highest profile if it's present in the module profiles
        if ($highestTagProfile -in $moduleProfileArray) {
            return [PSCustomObject]@{
                Profile = $highestTagProfile
                ShouldEvaluate = ($highestTagProfile -in $cloudUsageProfileArray)
            }
        }

        # Otherwise, use the highest matching profile that doesn't exceed the module profile
        $highestMatchingProfile = Get-HighestMatchingProfile $cloudUsageProfileArray $moduleProfileArray
        return [PSCustomObject]@{
            Profile = $highestMatchingProfile
            ShouldEvaluate = ($highestMatchingProfile -in $cloudUsageProfileArray)
        }
    }
    catch {
        Write-Error "Error in Get-EvaluationProfile: $_"
        return [PSCustomObject]@{
            Profile = 0
            ShouldEvaluate = $false
        }
    }
}

# Helper function to get the highest matching profile
function Get-HighestMatchingProfile {
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true)]
        [int[]]$profile1,
        [Parameter(Mandatory = $true)]
        [int[]]$profile2
    )
    $matchingProfiles = $profile1 | Where-Object { $profile2 -contains $_ }
    if ($matchingProfiles.Count -eq 0) {
        return 0
    }
    return ($matchingProfiles | Measure-Object -Maximum).Maximum
}

function ConvertTo-IntArray {
    [OutputType([int[]])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$inputString
    )
    if ($inputString -match '^\[.*\]$') {
        return $inputString.Trim('[]').Split(',') | ForEach-Object { [int]$_.Trim() }
    }
    if ($inputString -match ',') {
        return $inputString.Split(',') | ForEach-Object { [int]$_.Trim() }
    }
    return @([int]$inputString)
}

function Parse-BlobContent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$blobContent
    )

    # Check if blob content is retrieved
    if (-not $blobContent) {
        throw "Failed to retrieve blob content or blob is empty."
    }

    # Split content into lines
    $lines = $blobContent -split "`r`n|`n|,|;|,\s|;\s"

    $filteredLines = $lines | Where-Object { $_ -match '\S' -and $_ -like "*@*" } | ForEach-Object { $_ -replace '\s' }

    # Initialize an empty array
    $globalAdminUPNs = @()

    # Check each line, remove the hyphen (if any), and add to array
    foreach ($line in $filteredLines) {
        if ($line.StartsWith("-")) {
            # Remove the leading hyphen and any potential whitespace after it
            $trimmedLine = $line.Substring(1)
        } 
        else{
            $trimmedLine = $line
        }
        $trimmedLine = $trimmedLine.Trim()
        $globalAdminUPNs += $trimmedLine
    }

    $result = New-Object PSObject -Property @{
        GlobalAdminUPNs = $globalAdminUPNs
    }

    return $result
}

function Invoke-GraphQuery {
    [CmdletBinding()]
    param(
        # URL path (ex: /users)
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^(?!https://graph.microsoft.com/(v1|beta)/)')]
        [string]
        $urlPath
    )

    try {
        $uri = "https://graph.microsoft.com/v1.0$urlPath" -as [uri]
        
        $response = Invoke-AzRestMethod -Uri $uri -Method GET -ErrorAction Stop

    }
    catch {
        Write-Error "An error occured constructing the URI or while calling Graph query for URI GET '$uri': $($_.Exception.Message)"
    }
    
    @{
        Content    = $response.Content | ConvertFrom-Json
        StatusCode = $response.StatusCode
    }
}



# Function to add other possible file extension(s) to the module file names
function add-documentFileExtensions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]] $DocumentName,
        [Parameter(Mandatory = $true)]
        [string]$ItemName

    )

    if ($ItemName.ToLower() -eq 'network architecture diagram' -or 
        $ItemName.ToLower() -eq 'high level design documentation' -or
        $ItemName.ToLower() -eq "diagramme d'architecture réseau" -or 
        $ItemName.ToLower() -eq 'documentation de Conception de haut niveau'){

            $fileExtensions = @(".pdf", ".png", ".jpeg", ".vsdx")
    }
    elseif ($ItemName.ToLower() -eq 'dedicated user accounts for administration' -or 
            $ItemName.ToLower() -eq "Comptes d'utilisateurs dédiés pour l'administration") {
                
            $fileExtensions = @(".csv")
    }
    elseif ($ItemName.ToLower() -eq 'application gateway certificate validity' -or 
            $ItemName.ToLower() -eq "validité du certificat : passerelle d'application") {
        
            $fileExtensions = @(".txt")
    }
    else {
        $fileExtensions = @(".txt",".docx", ".doc", ".pdf")
    }
    
    $DocumentName_new = New-Object System.Collections.Generic.List[System.Object]
    ForEach ($fileExt in $fileExtensions) {
        $DocumentName_new.Add($DocumentName[0] + $fileExt)
    }

    return $DocumentName_new
}



function Get-AllUserAuthInformation{
    [CmdletBinding()]
    param (      
        [Parameter(Mandatory = $true)]
        [array]$allUserList
    )
    [PSCustomObject] $ErrorList = New-Object System.Collections.ArrayList
    $userValidMFACounter = 0
    $userUPNsValidMFA = @()
    $userUPNsBadMFA = @()

    ForEach ($user in $allUserList) {
        $userAccount = $user.userPrincipalName
            
        if($userAccount -like "*#EXT#*"){
            # for guest accounts
            $userEmail = $user.mail
            if(!$null -eq  $userEmail){
                $urlPath = '/users/' + $userEmail + '/authentication/methods'
            }else{
                Write-Host "userEmail is null for $userAccount"
                $extractedEmail = (($userAccount -split '#')[0]) -replace '_', '@'
                $urlPath = '/users/' + $extractedEmail + '/authentication/methods'
            }
            
        }else{
            # for member accounts
            $urlPath = '/users/' + $userAccount + '/authentication/methods'
        }
        
        try {
            $response = Invoke-GraphQuery -urlPath $urlPath -ErrorAction Stop

        }
        catch {
            $errorMsg = "Failed to call Microsoft Graph REST API at URL '$urlPath'; returned error message: $_"                
            $ErrorList.Add($errorMsg)
            Write-Error "Error: $errorMsg"
        }

        # # To check if MFA is setup for a user, we're checking various authentication methods:
        # # 1. #microsoft.graph.microsoftAuthenticatorAuthenticationMethod
        # # 2. #microsoft.graph.phoneAuthenticationMethod
        # # 3. #microsoft.graph.passwordAuthenticationMethod - not considered for MFA
        # # 4. #microsoft.graph.emailAuthenticationMethod - not considered for MFA
        # # 5. #microsoft.graph.fido2AuthenticationMethod
        # # 6. #microsoft.graph.softwareOathAuthenticationMethod
        # # 7. #microsoft.graph.temporaryAccessPassAuthenticationMethod
        # # 8. #microsoft.graph.windowsHelloForBusinessAuthenticationMethod

        if ($null -ne $response) {
            # portal
            $data = $response.Content
            # # localExecution
            # $data = $response
            if ($null -ne $data -and $null -ne $data.value) {
                $authenticationmethods = $data.value
                
                $authFound = $false
                foreach ($authmeth in $authenticationmethods) {    
                  
                    switch ($authmeth.'@odata.type') {
                        "#microsoft.graph.phoneAuthenticationMethod" { $authFound = $true; break }
                        "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" { $authFound = $true; break }
                        "#microsoft.graph.fido2AuthenticationMethod" { $authFound = $true; break }
                        "#microsoft.graph.temporaryAccessPassAuthenticationMethod" { $authFound = $true; break }
                        "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" { $authFound = $true; break }
                        "#microsoft.graph.softwareOathAuthenticationMethod" { $authFound = $true; break }
                    }
                }
                if($authFound){
                    #need to keep track of user account mfa in a counter and compare it with the total user count   
                    $userValidMFACounter += 1
                    Write-Host "Auth method found for $userAccount"
                    # Create an instance of valid MFA inner list object
                    $userValidUPNtemplate = [PSCustomObject]@{
                        UPN  = $userAccount
                        MFAStatus   = $true
                    }
                    $userUPNsValidMFA +=  $userValidUPNtemplate
                }
                else{
                    # This message is being used for debugging
                    Write-Host "$userAccount does not have MFA enabled"

                    # Create an instance of inner list object
                    $userUPNtemplate = [PSCustomObject]@{
                        UPN  = $userAccount
                        MFAStatus   = $false
                    }
                    # Add the list to user accounts MFA list
                    $userUPNsBadMFA += $userUPNtemplate
                }
            }
            else {
                $errorMsg = "No authentication methods data found for $userAccount"                
                $ErrorList.Add($errorMsg)
                # Write-Error "Error: $errorMsg"
                
                # Create an instance of inner list object
                $userUPNtemplate = [PSCustomObject]@{
                    UPN  = $userAccount
                    MFAStatus   = $false
                }
                # Add the list to user accounts MFA list
                $userUPNsBadMFA += $userUPNtemplate
            }
        }
        else {
            $errorMsg = "Failed to get response from Graph API for $userAccount"                
            $ErrorList.Add($errorMsg)
            Write-Error "Error: $errorMsg"
        }    
    }

    $PsObject = [PSCustomObject]@{
        userUPNsBadMFA = $userUPNsBadMFA
        ErrorList      = $ErrorList
        userValidMFACounter = $userValidMFACounter
        userUPNsValidMFA = $userUPNsValidMFA
    }

    return $PsObject

}

function CompareKQLQueries{
    param (
        [string] $query,
        [string] $targetQuery
        )

    #Fix the formatting of KQL query
    $normalizedTargetQuery = $targetQuery -replace '\s+', ' ' -replace '\|', ' | ' 
    $removeSpacesQuery = $query -replace '\s', ''
    $removeSpacesTargetQuery = $normalizedTargetQuery -replace '\s', ''

    return $removeSpacesQuery -eq $removeSpacesTargetQuery
}

# Function used for V2.0 GR2V7(M) andV1.0  GR3(R) cloud console access
function Get-allowedLocationCAPCompliance {
    param (
        [array]$ErrorList,
        [string] $IsCompliant
    )

    # get named locations
    $locationsBaseAPIUrl = '/identity/conditionalAccess/namedLocations'
    try {
        $response = Invoke-GraphQuery -urlPath $locationsBaseAPIUrl -ErrorAction Stop
        $data = $response.Content
        $locations = $data.value
    }
    catch {
        $Errorlist.Add("Failed to call Microsoft Graph REST API at URL '$locationsBaseAPIUrl'; returned error message: $_") 
        Write-Warning "Error: Failed to call Microsoft Graph REST API at URL '$locationsBaseAPIUrl'; returned error message: $_"
    }

    # get conditional access policies
    $CABaseAPIUrl = '/identity/conditionalAccess/policies'
    try {
        $response = Invoke-GraphQuery -urlPath $CABaseAPIUrl -ErrorAction Stop

        $caps = $response.Content.value
    }
    catch {
        $Errorlist.Add("Failed to call Microsoft Graph REST API at URL '$CABaseAPIUrl'; returned error message: $_")
        Write-Warning "Error: Failed to call Microsoft Graph REST API at URL '$CABaseAPIUrl'; returned error message: $_"
    }
    
    # check that a named location for Canada exists and that a policy exists that uses it
    $validLocations = @()

    foreach ($location in $locations) {
        #Determine location conditions
        #get all valid locations: needs to have Canada Only
        if ($location.countriesAndRegions.Count -eq 1 -and $location.countriesAndRegions[0] -eq "CA") {
            $validLocations += $location
        }
    }

    $locationBasedPolicies = $caps | Where-Object { $_.conditions.locations.includeLocations -in $validLocations.ID -and $_.state -eq 'enabled' }

    if ($validLocations.count -ne 0) {
        #if there is at least one location with Canada only, we are good. If no Canada Only policy, not compliant.
        # Conditional access Policies
        # Need a location based policy, for admins (owners, contributors) that uses one of the valid locations above.
        # If there is no policy or the policy doesn't use one of the locations above, not compliant.

        if (!$locationBasedPolicies) {
            #failed. No policies have valid locations.
            $Comments = $msgTable.noCompliantPoliciesfound
            $IsCompliant = $false
        }
        else {
            #"Compliant Policies."
            $IsCompliant = $true
            $Comments = $msgTable.allPoliciesAreCompliant
        }      
    }
    else {
        # Failed. Reason: No locations have only Canada.
        $Comments = $msgTable.noLocationsCompliant
        $IsCompliant = $false
    }
    
    $PsObject = [PSCustomObject]@{
        ComplianceStatus = $IsCompliant
        ControlName      = $ControlName
        Comments         = $Comments
        ItemName         = $ItemName
        ReportTime       = $ReportTime
        itsgcode         = $itsgcode
        Errors           = $ErrorList
    }
    return  $PsObject

}

# endregion

#region Enhanced Metrics and Debugging Functions

function Add-GSADebugMetrics {
    <#
    .SYNOPSIS
    Collects and logs enhanced debugging metrics and performance data to Log Analytics
    
    .DESCRIPTION
    This function collects various debugging and performance metrics for Azure Guardrails
    Solution Accelerator, including module runtime, error information, resource usage,
    and other diagnostic data useful for troubleshooting and operational monitoring.
    
    .PARAMETER WorkSpaceID
    Log Analytics workspace GUID where metrics will be stored
    
    .PARAMETER WorkspaceKey
    Shared key for Log Analytics workspace authentication
    
    .PARAMETER ModuleName
    Name of the guardrail module being measured
    
    .PARAMETER ModuleStartTime
    DateTime when the module execution started
    
    .PARAMETER ModuleEndTime
    DateTime when the module execution completed
    
    .PARAMETER ModuleStatus
    Status of module execution ('Success', 'Failed', 'Warning')
    
    .PARAMETER ErrorDetails
    Details of any errors encountered during module execution
    
    .PARAMETER ResultCount
    Number of compliance result rows generated by the module
    
    .PARAMETER GuardrailNumber
    Guardrail number (e.g., "1", "2", etc.)
    
    .PARAMETER ControlType
    Type of control being measured ('M' for Mandatory, 'R' for Recommended)
    
    .PARAMETER ReportTime
    Time when the overall report was generated
    
    .PARAMETER AdditionalMetrics
    Hash table of additional custom metrics to include
    
    .PARAMETER LogType
    Log Analytics table name (default: 'GuardRailsDebugMetrics')
    
    .EXAMPLE
    Add-GSADebugMetrics -WorkSpaceID $workspaceId -WorkspaceKey $key -ModuleName "Check-AdminAccess" -ModuleStartTime $startTime -ModuleEndTime $endTime -ModuleStatus "Success" -ResultCount 15 -GuardrailNumber "1" -ControlType "M" -ReportTime $reportTime
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $WorkSpaceID,
        
        [Parameter(Mandatory = $true)]
        [string] $WorkspaceKey,
        
        [Parameter(Mandatory = $true)]
        [string] $ModuleName,
        
        [Parameter(Mandatory = $true)]
        [datetime] $ModuleStartTime,
        
        [Parameter(Mandatory = $true)]
        [datetime] $ModuleEndTime,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Failed', 'Warning')]
        [string] $ModuleStatus,
        
        [Parameter(Mandatory = $false)]
        [string] $ErrorDetails = '',
        
        [Parameter(Mandatory = $false)]
        [int] $ResultCount = 0,
        
        [Parameter(Mandatory = $false)]
        [string] $GuardrailNumber = '',
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('M', 'R', '')]
        [string] $ControlType = '',
        
        [Parameter(Mandatory = $true)]
        [string] $ReportTime,
        
        [Parameter(Mandatory = $false)]
        [hashtable] $AdditionalMetrics = @{},
        
        [Parameter(Mandatory = $false)]
        [string] $LogType = 'GuardRailsDebugMetrics'
    )
    
    try {
        $runtimeSeconds = ($ModuleEndTime - $ModuleStartTime).TotalSeconds
        
        # Create metrics object
        $metricsObject = [PSCustomObject]@{
            ReportTime = $ReportTime
            ModuleName = $ModuleName
            GuardrailNumber = $GuardrailNumber
            ControlType = $ControlType
            ModuleStatus = $ModuleStatus
            ModuleStartTime = $ModuleStartTime.ToString('yyyy-MM-dd HH:mm:ss')
            ModuleEndTime = $ModuleEndTime.ToString('yyyy-MM-dd HH:mm:ss')
            RuntimeSeconds = [math]::Round($runtimeSeconds, 2)
            ResultCount = $ResultCount
            ErrorDetails = $ErrorDetails
            TenantId = (Get-AzContext)?.Tenant?.Id ?? 'Unknown'
            SubscriptionId = (Get-AzContext)?.Subscription?.Id ?? 'Unknown'
            Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
        
        # Add any additional metrics
        foreach ($key in $AdditionalMetrics.Keys) {
            $metricsObject | Add-Member -NotePropertyName $key -NotePropertyValue $AdditionalMetrics[$key]
        }
        
        $json = ConvertTo-Json -InputObject $metricsObject -Depth 3
        
        Send-OMSAPIIngestionFile -customerId $WorkSpaceID `
            -sharedkey $WorkspaceKey `
            -body $json `
            -logType $LogType `
            -TimeStampField Get-Date
            
        Write-Debug "Debug metrics logged successfully for module: $ModuleName"
    }
    catch {
        Write-Warning "Failed to log debug metrics for module $ModuleName`: $_"
    }
}

function Add-GSARunbookPerformanceMetrics {
    <#
    .SYNOPSIS
    Collects and logs overall runbook performance metrics
    
    .DESCRIPTION
    Logs high-level performance and operational metrics for the entire runbook execution,
    including total runtime, module counts, overall success rate, and system resource information.
    
    .PARAMETER WorkSpaceID
    Log Analytics workspace GUID where metrics will be stored
    
    .PARAMETER WorkspaceKey
    Shared key for Log Analytics workspace authentication
    
    .PARAMETER RunbookType
    Type of runbook ('Main', 'Backend')
    
    .PARAMETER TotalStartTime
    DateTime when the runbook execution started
    
    .PARAMETER TotalEndTime
    DateTime when the runbook execution completed
    
    .PARAMETER TotalModulesExecuted
    Total number of modules that were executed
    
    .PARAMETER SuccessfulModules
    Number of modules that completed successfully
    
    .PARAMETER FailedModules
    Number of modules that failed
    
    .PARAMETER WarningModules
    Number of modules that completed with warnings
    
    .PARAMETER ReportTime
    Time when the report was generated
    
    .PARAMETER LogType
    Log Analytics table name (default: 'GuardRailsRunbookMetrics')
    
    .EXAMPLE
    Add-GSARunbookPerformanceMetrics -WorkSpaceID $workspaceId -WorkspaceKey $key -RunbookType "Main" -TotalStartTime $startTime -TotalEndTime $endTime -TotalModulesExecuted 25 -SuccessfulModules 23 -FailedModules 1 -WarningModules 1 -ReportTime $reportTime
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $WorkSpaceID,
        
        [Parameter(Mandatory = $true)]
        [string] $WorkspaceKey,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Main', 'Backend')]
        [string] $RunbookType,
        
        [Parameter(Mandatory = $true)]
        [datetime] $TotalStartTime,
        
        [Parameter(Mandatory = $true)]
        [datetime] $TotalEndTime,
        
        [Parameter(Mandatory = $true)]
        [int] $TotalModulesExecuted,
        
        [Parameter(Mandatory = $true)]
        [int] $SuccessfulModules,
        
        [Parameter(Mandatory = $true)]
        [int] $FailedModules,
        
        [Parameter(Mandatory = $true)]
        [int] $WarningModules,
        
        [Parameter(Mandatory = $true)]
        [string] $ReportTime,
        
        [Parameter(Mandatory = $false)]
        [string] $LogType = 'GuardRailsRunbookMetrics'
    )
    
    try {
        $totalRuntimeSeconds = ($TotalEndTime - $TotalStartTime).TotalSeconds
        $successRate = if ($TotalModulesExecuted -gt 0) { [math]::Round(($SuccessfulModules / $TotalModulesExecuted) * 100, 2) } else { 0 }
        
        # Get automation account and system information
        $automationAccountName = Get-GSAAutomationVariable -Name "AutomationAccountName" -ErrorAction SilentlyContinue
        $resourceGroupName = Get-GSAAutomationVariable -Name "ResourceGroupName" -ErrorAction SilentlyContinue
        
        $runbookMetrics = [PSCustomObject]@{
            ReportTime = $ReportTime
            RunbookType = $RunbookType
            AutomationAccountName = $automationAccountName ?? 'Unknown'
            ResourceGroupName = $resourceGroupName ?? 'Unknown'
            TotalStartTime = $TotalStartTime.ToString('yyyy-MM-dd HH:mm:ss')
            TotalEndTime = $TotalEndTime.ToString('yyyy-MM-dd HH:mm:ss')
            TotalRuntimeSeconds = [math]::Round($totalRuntimeSeconds, 2)
            TotalRuntimeMinutes = [math]::Round($totalRuntimeSeconds / 60, 2)
            TotalModulesExecuted = $TotalModulesExecuted
            SuccessfulModules = $SuccessfulModules
            FailedModules = $FailedModules
            WarningModules = $WarningModules
            SuccessRate = $successRate
            TenantId = (Get-AzContext)?.Tenant?.Id ?? 'Unknown'
            SubscriptionId = (Get-AzContext)?.Subscription?.Id ?? 'Unknown'
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            PSExecutionPolicyUsed = (Get-ExecutionPolicy).ToString()
            Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
        
        $json = ConvertTo-Json -InputObject $runbookMetrics -Depth 3
        
        Send-OMSAPIIngestionFile -customerId $WorkSpaceID `
            -sharedkey $WorkspaceKey `
            -body $json `
            -logType $LogType `
            -TimeStampField Get-Date
            
        Write-Debug "Runbook performance metrics logged successfully for $RunbookType runbook"
    }
    catch {
        Write-Warning "Failed to log runbook performance metrics for $RunbookType runbook: $_"
    }
}

function Get-GSAAutomationAccountPermissions {
    <#
    .SYNOPSIS
    Retrieves and formats automation account permissions for debugging
    
    .DESCRIPTION
    Collects information about the automation account's managed identity permissions,
    role assignments, and access to various Azure resources for troubleshooting purposes.
    
    .PARAMETER WorkSpaceID
    Log Analytics workspace GUID where permission info will be stored
    
    .PARAMETER WorkspaceKey
    Shared key for Log Analytics workspace authentication
    
    .PARAMETER ReportTime
    Time when the report was generated
    
    .PARAMETER LogType
    Log Analytics table name (default: 'GuardRailsPermissionInfo')
    
    .EXAMPLE
    Get-GSAAutomationAccountPermissions -WorkSpaceID $workspaceId -WorkspaceKey $key -ReportTime $reportTime
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $WorkSpaceID,
        
        [Parameter(Mandatory = $true)]
        [string] $WorkspaceKey,
        
        [Parameter(Mandatory = $true)]
        [string] $ReportTime,
        
        [Parameter(Mandatory = $false)]
        [string] $LogType = 'GuardRailsPermissionInfo'
    )
    
    try {
        $permissionInfo = @()
        $context = Get-AzContext
        
        if ($context) {
            # Get current subscription and tenant info
            $subscriptionId = $context.Subscription.Id
            $tenantId = $context.Tenant.Id
            $accountName = $context.Account.Id
            
            # Try to get role assignments for the managed identity
            try {
                $roleAssignments = Get-AzRoleAssignment -SignInName $accountName -ErrorAction SilentlyContinue
                if (-not $roleAssignments) {
                    # Try with object ID if available
                    $roleAssignments = Get-AzRoleAssignment -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $accountName -or $_.SignInName -eq $accountName }
                }
                
                foreach ($assignment in $roleAssignments) {
                    $permissionInfo += [PSCustomObject]@{
                        ReportTime = $ReportTime
                        TenantId = $tenantId
                        SubscriptionId = $subscriptionId
                        AccountName = $accountName
                        RoleDefinitionName = $assignment.RoleDefinitionName ?? 'Unknown'
                        Scope = $assignment.Scope ?? 'Unknown'
                        ResourceGroupName = if ($assignment.Scope -match '/resourceGroups/([^/]+)') { $matches[1] } else { 'Subscription Level' }
                        PrincipalType = $assignment.ObjectType ?? 'Unknown'
                        AssignmentType = 'Role Assignment'
                        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                    }
                }
            }
            catch {
                Write-Warning "Could not retrieve role assignments: $_"
                $permissionInfo += [PSCustomObject]@{
                    ReportTime = $ReportTime
                    TenantId = $tenantId
                    SubscriptionId = $subscriptionId
                    AccountName = $accountName
                    RoleDefinitionName = 'Error retrieving permissions'
                    Scope = 'Unknown'
                    ResourceGroupName = 'Unknown'
                    PrincipalType = 'Unknown'
                    AssignmentType = 'Error'
                    ErrorDetails = $_.Exception.Message
                    Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
        }
        else {
            $permissionInfo += [PSCustomObject]@{
                ReportTime = $ReportTime
                TenantId = 'No Context'
                SubscriptionId = 'No Context'
                AccountName = 'No Context'
                RoleDefinitionName = 'No Azure Context Available'
                Scope = 'Unknown'
                ResourceGroupName = 'Unknown'
                PrincipalType = 'Unknown'
                AssignmentType = 'No Context'
                Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
        
        if ($permissionInfo.Count -gt 0) {
            $json = ConvertTo-Json -InputObject $permissionInfo -Depth 3
            
            Send-OMSAPIIngestionFile -customerId $WorkSpaceID `
                -sharedkey $WorkspaceKey `
                -body $json `
                -logType $LogType `
                -TimeStampField Get-Date
                
            Write-Debug "Automation account permission information logged successfully"
        }
    }
    catch {
        Write-Warning "Failed to log automation account permission information: $_"
    }
}

function Start-GSAModuleTimer {
    <#
    .SYNOPSIS
    Creates a timer object for measuring module execution time
    
    .DESCRIPTION
    Utility function that returns a hashtable containing start time and module name
    for tracking module performance metrics.
    
    .PARAMETER ModuleName
    Name of the module being timed
    
    .EXAMPLE
    $timer = Start-GSAModuleTimer -ModuleName "Check-AdminAccess"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ModuleName
    )
    
    return @{
        ModuleName = $ModuleName
        StartTime = Get-Date
    }
}

function Stop-GSAModuleTimer {
    <#
    .SYNOPSIS
    Completes module timing and optionally logs metrics
    
    .DESCRIPTION
    Takes a timer object from Start-GSAModuleTimer and calculates execution time.
    Optionally logs the metrics to Log Analytics if workspace parameters are provided.
    
    .PARAMETER Timer
    Timer object returned from Start-GSAModuleTimer
    
    .PARAMETER ModuleStatus
    Status of module execution ('Success', 'Failed', 'Warning')
    
    .PARAMETER WorkSpaceID
    Optional: Log Analytics workspace GUID for automatic logging
    
    .PARAMETER WorkspaceKey
    Optional: Shared key for Log Analytics workspace
    
    .PARAMETER ReportTime
    Optional: Report time for metrics logging
    
    .PARAMETER ResultCount
    Optional: Number of results produced by the module
    
    .PARAMETER ErrorDetails
    Optional: Details of any errors encountered
    
    .PARAMETER GuardrailNumber
    Optional: Guardrail number for categorization
    
    .PARAMETER ControlType
    Optional: Control type ('M', 'R')
    
    .EXAMPLE
    $metrics = Stop-GSAModuleTimer -Timer $timer -ModuleStatus "Success" -ResultCount 10
    
    .EXAMPLE
    Stop-GSAModuleTimer -Timer $timer -ModuleStatus "Success" -WorkSpaceID $wsId -WorkspaceKey $wsKey -ReportTime $reportTime
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $Timer,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Failed', 'Warning')]
        [string] $ModuleStatus,
        
        [Parameter(Mandatory = $false)]
        [string] $WorkSpaceID,
        
        [Parameter(Mandatory = $false)]
        [string] $WorkspaceKey,
        
        [Parameter(Mandatory = $false)]
        [string] $ReportTime,
        
        [Parameter(Mandatory = $false)]
        [int] $ResultCount = 0,
        
        [Parameter(Mandatory = $false)]
        [string] $ErrorDetails = '',
        
        [Parameter(Mandatory = $false)]
        [string] $GuardrailNumber = '',
        
        [Parameter(Mandatory = $false)]
        [string] $ControlType = ''
    )
    
    $endTime = Get-Date
    $runtimeSeconds = ($endTime - $Timer.StartTime).TotalSeconds
    
    $metrics = @{
        ModuleName = $Timer.ModuleName
        StartTime = $Timer.StartTime
        EndTime = $endTime
        RuntimeSeconds = [math]::Round($runtimeSeconds, 2)
        ModuleStatus = $ModuleStatus
        ResultCount = $ResultCount
        ErrorDetails = $ErrorDetails
    }
    
    # If workspace parameters provided, automatically log metrics
    if ($WorkSpaceID -and $WorkspaceKey -and $ReportTime) {
        try {
            Add-GSADebugMetrics -WorkSpaceID $WorkSpaceID -WorkspaceKey $WorkspaceKey `
                -ModuleName $Timer.ModuleName -ModuleStartTime $Timer.StartTime -ModuleEndTime $endTime `
                -ModuleStatus $ModuleStatus -ErrorDetails $ErrorDetails -ResultCount $ResultCount `
                -GuardrailNumber $GuardrailNumber -ControlType $ControlType -ReportTime $ReportTime
        }
        catch {
            Write-Warning "Failed to auto-log metrics for module $($Timer.ModuleName): $_"
        }
    }
    
    return $metrics
}

# endregion



