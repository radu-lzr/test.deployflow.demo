<#
.SYNOPSIS
    Generates diagnostic settings matrix from audit CSV and dictionary.
.PARAMETER AuditCsvPath
    Path to audit.csv.
.PARAMETER DictionaryPath
    Path to the merged diagnostic-settings dictionary CSV.
.PARAMETER ExcludeDiagSettings
    Array of exclusion rules to skip.
.PARAMETER OutputPath
    Path for the output diagsettings-matrix.csv.
.PARAMETER SuggestionsPath
    Path for the output suggestions CSV (optional).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AuditCsvPath,
    [Parameter(Mandatory=$true)][string]$DictionaryPath,
    [Parameter(Mandatory=$false)][string[]]$ExcludeDiagSettings = @(),
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

Write-Log "=== Diagnostic Settings Matrix Generation ==="

if (-not (Test-Path $AuditCsvPath)) { Write-Log "Audit CSV not found: $AuditCsvPath" -Level Error; exit 1 }
$auditResources = Import-Csv -Path $AuditCsvPath
Write-Log "Loaded $($auditResources.Count) resources from audit" -Level Success

if (-not (Test-Path $DictionaryPath)) { Write-Log "Dictionary not found: $DictionaryPath" -Level Error; exit 1 }
$dictEntries = Import-Csv -Path $DictionaryPath
$globalDict = @{}
foreach ($entry in $dictEntries) {
    $key = "$($entry.ResourceType)|$($entry.LogCategory)|$($entry.MetricCategory)"
    if (-not $globalDict.ContainsKey($key)) { $globalDict[$key] = @() }
    $globalDict[$key] += $entry
}
Write-Log "Loaded $($dictEntries.Count) diagnostic settings entries" -Level Success

# Build exclusion set from JSON array items
$excludeSet = @{}
foreach ($item in $ExcludeDiagSettings) {
    # Items may be strings like "resourceType|category" or objects
    $excludeSet[$item] = $true
}

$matrix = @()
$suggestions = @()
$stats = @{ FromDict = 0; Suggested = 0 }
$processedTypes = @{}

foreach ($resource in $auditResources) {
    $resourceType = $resource.ResourceType.ToLower()
    $resourceName = $resource.ResourceName
    $resourceId = $resource.ResourceId
    if ([string]::IsNullOrWhiteSpace($resourceId)) { continue }

    # Find dictionary configs for this resource type
    $typeConfigs = $globalDict.Keys | Where-Object { $_ -like "$resourceType|*" }

    if ($typeConfigs) {
        foreach ($configKey in $typeConfigs) {
            foreach ($config in $globalDict[$configKey]) {
                $matrixEntry = [PSCustomObject]@{
                    resourceId      = $resourceId
                    resourceName    = $resourceName
                    resourceType    = $resourceType
                    resourceGroup   = $resource.ResourceGroup
                    subscriptionId  = $resource.SubscriptionId
                    location        = $resource.Location
                    logCategory     = $config.LogCategory
                    metricCategory  = $config.MetricCategory
                    enabled         = $config.Enabled
                    retentionDays   = if ($config.PSObject.Properties['RetentionDays']) { $config.RetentionDays } else { "30" }
                    friendlyName    = if ($config.PSObject.Properties['FriendlyName']) { $config.FriendlyName } else { $resourceType.Split('/')[-1] }
                }
                $matrix += $matrixEntry
                $stats.FromDict++
            }
        }
    } elseif (-not $processedTypes.ContainsKey($resourceType)) {
        # Not in dictionary — suggest
        $stats.Suggested++
        $suggestions += [PSCustomObject]@{
            ResourceType    = $resourceType
            LogCategory     = "(needs configuration)"
            MetricCategory  = ""
            Enabled         = "Yes"
            RetentionDays   = "30"
            FriendlyName    = $resourceType.Split('/')[-1]
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
    Write-Log "Matrix exported: $OutputPath ($($matrix.Count) entries)" -Level Success
} else {
    [PSCustomObject]@{ resourceId = ""; logCategory = "" } | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
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
Write-Log "Diagnostic settings entries: $($stats.FromDict)" -Level Success
Write-Log "Suggestions: $($stats.Suggested)" -Level Warning
