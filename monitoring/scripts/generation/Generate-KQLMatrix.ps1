<#
.SYNOPSIS
    Generates KQL alert matrix from audit CSV and KQL queries dictionary.
.PARAMETER AuditCsvPath
    Path to audit.csv.
.PARAMETER DictionaryPath
    Path to the merged kql-queries dictionary CSV.
.PARAMETER OutputPath
    Path for the output kql-matrix.csv.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AuditCsvPath,
    [Parameter(Mandatory=$true)][string]$DictionaryPath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = 'Info')
    $color = switch($Level) {
        'Info' { 'Cyan' } 'Warning' { 'Yellow' } 'Error' { 'Red' } 'Success' { 'Green' } default { 'White' }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

Write-Log "=== KQL Matrix Generation ==="

if (-not (Test-Path $AuditCsvPath)) { Write-Log "Audit CSV not found: $AuditCsvPath" -Level Error; exit 1 }
$auditResources = Import-Csv -Path $AuditCsvPath
Write-Log "Loaded $($auditResources.Count) resources from audit" -Level Success

if (-not (Test-Path $DictionaryPath)) { Write-Log "Dictionary not found: $DictionaryPath" -Level Error; exit 1 }
$dictEntries = Import-Csv -Path $DictionaryPath
$globalDict = @{}
foreach ($entry in $dictEntries) {
    $key = "$($entry.ResourceType)|$($entry.QueryName)"
    $globalDict[$key] = $entry
}
Write-Log "Loaded $($dictEntries.Count) KQL queries" -Level Success

$matrix = @()
$stats = @{ FromDict = 0 }
$processedTypes = @{}

foreach ($resource in $auditResources) {
    $resourceType = $resource.ResourceType.ToLower()
    $resourceName = $resource.ResourceName
    $resourceId = $resource.ResourceId
    if ([string]::IsNullOrWhiteSpace($resourceId)) { continue }

    $typeQueries = $globalDict.Keys | Where-Object { $_ -like "$resourceType|*" }

    if ($typeQueries) {
        foreach ($queryKey in $typeQueries) {
            $config = $globalDict[$queryKey]
            $alertName = "$resourceName-$($config.QueryName)"

            $matrixEntry = [PSCustomObject]@{
                resourceId          = $resourceId
                resourceName        = $resourceName
                resourceType        = $resourceType
                resourceGroup       = $resource.ResourceGroup
                subscriptionId      = $resource.SubscriptionId
                location            = $resource.Location
                alertName           = $alertName
                queryName           = $config.QueryName
                query               = $config.Query
                description         = $config.Description
                severity            = $config.Severity
                threshold           = $config.Threshold
                evaluationFrequency = $config.EvaluationFrequency
                windowSize          = $config.WindowSize
                friendlyName        = if ($config.PSObject.Properties['FriendlyName']) { $config.FriendlyName } else { "" }
            }
            $matrix += $matrixEntry
            $stats.FromDict++
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

Write-Log "`n=== SUMMARY ==="
Write-Log "Resources: $($auditResources.Count), Types: $($processedTypes.Count)" -Level Info
Write-Log "KQL alerts generated: $($stats.FromDict)" -Level Success
