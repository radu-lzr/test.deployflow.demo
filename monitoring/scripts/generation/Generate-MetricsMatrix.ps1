<#
.SYNOPSIS
    Generates a metrics alert matrix from audit CSV and metrics dictionary.
.PARAMETER AuditCsvPath
    Path to audit.csv produced by the discovery workflow.
.PARAMETER DictionaryPath
    Path to the merged metrics dictionary CSV.
.PARAMETER ExcludeMetrics
    Array of metric names to exclude.
.PARAMETER OutputPath
    Path for the output metrics-matrix.csv.
.PARAMETER SuggestionsPath
    Path for the output suggestions CSV (optional).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AuditCsvPath,
    [Parameter(Mandatory=$true)][string]$DictionaryPath,
    [Parameter(Mandatory=$false)][string[]]$ExcludeMetrics = @(),
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

Write-Log "=== Metrics Matrix Generation ==="

if (-not (Test-Path $AuditCsvPath)) { Write-Log "Audit CSV not found: $AuditCsvPath" -Level Error; exit 1 }
$auditResources = Import-Csv -Path $AuditCsvPath
Write-Log "Loaded $($auditResources.Count) resources from audit" -Level Success

if (-not (Test-Path $DictionaryPath)) { Write-Log "Dictionary not found: $DictionaryPath" -Level Error; exit 1 }
$dictEntries = Import-Csv -Path $DictionaryPath
$globalDict = @{}
foreach ($entry in $dictEntries) {
    $key = "$($entry.ResourceType)|$($entry.AlertMetricName)"
    if (-not $globalDict.ContainsKey($key)) { $globalDict[$key] = @() }
    $globalDict[$key] += $entry
}
Write-Log "Loaded $($dictEntries.Count) dictionary entries ($($globalDict.Count) unique metrics)" -Level Success

$excludeSet = @{}
foreach ($m in $ExcludeMetrics) { $excludeSet[$m] = $true }

$matrix = @()
$suggestions = @()
$stats = @{ FromDict = 0; Suggested = 0 }
$processedTypes = @{}

foreach ($resource in $auditResources) {
    $resourceType = $resource.ResourceType.ToLower()
    $resourceName = $resource.ResourceName
    $resourceId = $resource.ResourceId
    if ([string]::IsNullOrWhiteSpace($resourceId)) { continue }

    $typeMetrics = $globalDict.Keys | Where-Object { $_ -like "$resourceType|*" }

    if ($typeMetrics) {
        foreach ($key in $typeMetrics) {
            $metricName = $key.Split('|')[1]
            if ($excludeSet.ContainsKey($metricName)) { continue }

            foreach ($config in $globalDict[$key]) {
                $alertName = "$resourceName-$($config.AlertMetricName)-$($config.Severity)"
                $matrixEntry = [PSCustomObject]@{
                    metricNamespace       = $config.ResourceType
                    targetResourceName    = $resourceName
                    targetResourceTypeFriendlyName = if ($config.PSObject.Properties['FriendlyName']) { $config.FriendlyName } else { $resourceType.Split('/')[-1] }
                    resourceRG            = $resource.ResourceGroup
                    targetResourceType    = $config.ResourceType
                    alertDescription      = "Managed by DeployFlow"
                    alertMetricNamespace  = $config.ResourceType
                    alertMetricName       = $config.AlertMetricName
                    alertSev              = $config.Severity
                    alertDimensions       = if ($config.PSObject.Properties['Dimensions']) { $config.Dimensions } else { "" }
                    alertOperator         = $config.AlertOperator
                    alertTimeAggregation  = $config.Aggregation
                    evaluationFreq        = $config.EvaluationFrequency
                    windowsSize           = $config.WindowSize
                    alertThreshold        = $config.Threshold
                    alertAutoMitigate     = "true"
                    alertState            = "true"
                    alertName             = $alertName
                    resourceId            = $resourceId
                    subscriptionId        = $resource.SubscriptionId
                    location              = $resource.Location
                }
                $matrix += $matrixEntry
                $stats.FromDict++
            }
        }
    } elseif (-not $processedTypes.ContainsKey($resourceType)) {
        $stats.Suggested++
        $suggestions += [PSCustomObject]@{
            ResourceType = $resourceType; AlertMetricName = "(needs configuration)"
            Severity = "2"; Threshold = "XX"; _SampleResource = $resourceName
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
Write-Log "Alerts generated: $($stats.FromDict)" -Level Success
Write-Log "Suggestions: $($stats.Suggested)" -Level Warning
