<#
.SYNOPSIS
    Generates activity logs alert matrix from audit CSV and activity-logs dictionary.
.PARAMETER AuditCsvPath
    Path to audit.csv.
.PARAMETER DictionaryPath
    Path to the merged activity-logs dictionary CSV.
.PARAMETER OutputPath
    Path for the output activitylogs-matrix.csv.
.PARAMETER SuggestionsPath
    Path for the output suggestions CSV (optional).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AuditCsvPath,
    [Parameter(Mandatory=$true)][string]$DictionaryPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$false)][string]$SuggestionsPath = ""
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = 'Info')
    $color = switch($Level) {
        'Info' { 'Cyan' } 'Warning' { 'Yellow' } 'Error' { 'Red' } 'Success' { 'Green' } default { 'White' }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

Write-Log "=== Activity Logs Matrix Generation ==="

if (-not (Test-Path $AuditCsvPath)) { Write-Log "Audit CSV not found: $AuditCsvPath" -Level Error; exit 1 }
$auditResources = Import-Csv -Path $AuditCsvPath
Write-Log "Loaded $($auditResources.Count) resources from audit" -Level Success

if (-not (Test-Path $DictionaryPath)) { Write-Log "Dictionary not found: $DictionaryPath" -Level Error; exit 1 }
$dictEntries = Import-Csv -Path $DictionaryPath
$globalDict = @{}
foreach ($entry in $dictEntries) {
    $key = "$($entry.ResourceType)|$($entry.OperationName)"
    $globalDict[$key] = $entry
}
Write-Log "Loaded $($dictEntries.Count) activity log operations" -Level Success

$matrix = @()
$suggestions = @()
$stats = @{ Total = 0; Suggested = 0 }
$processedTypes = @{}

foreach ($resource in $auditResources) {
    $resourceType = $resource.ResourceType.ToLower()
    $resourceName = $resource.ResourceName
    $resourceId = $resource.ResourceId
    if ([string]::IsNullOrWhiteSpace($resourceId)) { continue }

    # Find operations for this resource type
    $typeOps = $globalDict.Keys | Where-Object { $_ -like "$resourceType|*" }

    if ($typeOps) {
        foreach ($opKey in $typeOps) {
            $config = $globalDict[$opKey]

            # Success alert
            if ($config.PSObject.Properties['AlertOnSuccess'] -and $config.AlertOnSuccess -eq "Yes") {
                $matrix += [PSCustomObject]@{
                    alertName          = "$resourceName-$($config.OperationName.Split('/')[-1])-Success"
                    alertDescription   = "$($config.Description) - Success"
                    severity           = $config.Severity
                    enabled            = "true"
                    category           = $config.Category
                    operationName      = $config.OperationName
                    status             = "Succeeded"
                    targetResourceType = $resourceType
                    targetResourceName = $resourceName
                    resourceGroup      = $resource.ResourceGroup
                    resourceId         = $resourceId
                    subscriptionId     = $resource.SubscriptionId
                    friendlyName       = if ($config.PSObject.Properties['FriendlyName']) { $config.FriendlyName } else { "" }
                }
                $stats.Total++
            }

            # Failure alert
            if ($config.PSObject.Properties['AlertOnFailure'] -and $config.AlertOnFailure -eq "Yes") {
                $matrix += [PSCustomObject]@{
                    alertName          = "$resourceName-$($config.OperationName.Split('/')[-1])-Failure"
                    alertDescription   = "$($config.Description) - Failure"
                    severity           = "0"
                    enabled            = "true"
                    category           = $config.Category
                    operationName      = $config.OperationName
                    status             = "Failed"
                    targetResourceType = $resourceType
                    targetResourceName = $resourceName
                    resourceGroup      = $resource.ResourceGroup
                    resourceId         = $resourceId
                    subscriptionId     = $resource.SubscriptionId
                    friendlyName       = if ($config.PSObject.Properties['FriendlyName']) { $config.FriendlyName } else { "" }
                }
                $stats.Total++
            }
        }
    } elseif (-not $processedTypes.ContainsKey($resourceType)) {
        # Suggest common ops for uncovered types
        $stats.Suggested++
        $suggestions += [PSCustomObject]@{
            ResourceType = $resourceType
            OperationName = "$resourceType/write"
            Description = "Resource created or updated"
            Category = "Administrative"
            Severity = "2"
            AlertOnSuccess = "No"
            AlertOnFailure = "Yes"
            _SampleResource = $resourceName
            _DateDiscovered = (Get-Date -Format "yyyy-MM-dd")
        }
        $suggestions += [PSCustomObject]@{
            ResourceType = $resourceType
            OperationName = "$resourceType/delete"
            Description = "Resource deleted"
            Category = "Administrative"
            Severity = "1"
            AlertOnSuccess = "Yes"
            AlertOnFailure = "Yes"
            _SampleResource = $resourceName
            _DateDiscovered = (Get-Date -Format "yyyy-MM-dd")
        }
    }
    $processedTypes[$resourceType] = $true
}

$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }

if ($matrix.Count -gt 0) {
    $matrix | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Log "Matrix exported: $OutputPath ($($matrix.Count) alerts)" -Level Success
} else {
    [PSCustomObject]@{ alertName = ""; resourceId = "" } | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Log "Matrix exported (empty): $OutputPath" -Level Warning
}

if ($SuggestionsPath -and $suggestions.Count -gt 0) {
    $sugDir = Split-Path $SuggestionsPath -Parent
    if ($sugDir -and -not (Test-Path $sugDir)) { New-Item -ItemType Directory -Path $sugDir -Force | Out-Null }
    $suggestions | Export-Csv -Path $SuggestionsPath -NoTypeInformation -Encoding UTF8
    Write-Log "Suggestions exported: $SuggestionsPath ($($suggestions.Count))" -Level Warning
}

Write-Log "`n=== SUMMARY ==="
Write-Log "Resources: $($auditResources.Count), Types: $($processedTypes.Count)" -Level Info
Write-Log "Activity log alerts generated: $($stats.Total)" -Level Success
Write-Log "Suggestions: $($stats.Suggested)" -Level Warning
