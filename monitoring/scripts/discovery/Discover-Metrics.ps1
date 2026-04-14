<#
.SYNOPSIS
    Discovers available Azure metrics for resources found in an audit CSV.

.DESCRIPTION
    Reads audit.csv, groups resources by type, discovers metrics via
    Get-AzMetricDefinition, and cross-references a metrics dictionary to
    classify each metric as known or new (suggestion).

.PARAMETER AuditCsvPath
    Path to the audit.csv file produced by Generate-AuditReport.ps1

.PARAMETER DictionaryPath
    Path to the metrics-dictionary.csv reference file

.PARAMETER ExcludeMetrics
    Array of metric names to exclude from results

.PARAMETER OutputDir
    Directory where output files will be written
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$AuditCsvPath,

    [Parameter(Mandatory=$true)]
    [string]$DictionaryPath,

    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeMetrics = @(),

    [Parameter(Mandatory=$true)]
    [string]$OutputDir
)

$ErrorActionPreference = "Continue"

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$suggestionsPath = "$OutputDir/suggestions-metrics.csv"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )
    $color = switch($Level) {
        'Info' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
        default { 'White' }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

# ============================================================================
# MAIN
# ============================================================================

Write-Log "=== Metric Discovery ===" -Level Info

# Load audit CSV
if (-not (Test-Path $AuditCsvPath)) {
    Write-Log "Audit CSV not found: $AuditCsvPath" -Level Error
    exit 1
}

$auditResources = Import-Csv -Path $AuditCsvPath
Write-Log "Loaded $($auditResources.Count) resources from audit" -Level Success

# Load dictionary
$globalDict = @{}
if (Test-Path $DictionaryPath) {
    $dictEntries = Import-Csv -Path $DictionaryPath
    foreach ($entry in $dictEntries) {
        $key = "$($entry.ResourceType)|$($entry.AlertMetricName)"
        if (-not $globalDict.ContainsKey($key)) {
            $globalDict[$key] = $entry
        }
    }
    Write-Log "Loaded $($globalDict.Count) dictionary entries" -Level Success
} else {
    Write-Log "Dictionary not found: $DictionaryPath (will discover all)" -Level Warning
}

# Group audit resources by type and pick one sample per type for metric discovery
$resourcesByType = $auditResources | Group-Object -Property ResourceType

$configuredMetrics = @()
$discoveredMetrics = @()

foreach ($group in $resourcesByType) {
    $resType = $group.Name
    # Take first resource as sample for metric definitions
    $sampleResource = $group.Group | Select-Object -First 1
    $resourceId = $sampleResource.ResourceId

    if ([string]::IsNullOrWhiteSpace($resourceId)) { continue }

    Write-Log "`nResource type: $resType ($($group.Count) resources)" -Level Info

    try {
        $availableMetrics = Get-AzMetricDefinition -ResourceId $resourceId -ErrorAction Stop
        Write-Log "  -> $($availableMetrics.Count) metrics available" -Level Success
    } catch {
        Write-Log "  Error discovering metrics for $resType : $_" -Level Error
        continue
    }

    foreach ($metric in $availableMetrics) {
        $metricName = $metric.Name.Value

        # Skip excluded metrics
        if ($ExcludeMetrics -contains $metricName) { continue }

        $key = "$($resType.ToLower())|$metricName"

        if ($globalDict.ContainsKey($key)) {
            Write-Log "  Found in dictionary: $metricName" -Level Success
            $config = $globalDict[$key]
            $config | Add-Member -MemberType NoteProperty -Name "_Source" -Value "Dictionary" -Force
            $configuredMetrics += $config
        } else {
            Write-Log "  New metric: $metricName" -Level Warning
            $aggregation = if ($metric.PrimaryAggregationType) { $metric.PrimaryAggregationType } else { "Average" }
            $suggestion = [PSCustomObject]@{
                ResourceType        = $resType.ToLower()
                AlertMetricName     = $metricName
                Count               = $group.Count
                AlertOperator       = "GreaterThanOrEqual"
                Aggregation         = $aggregation
                Dimensions          = ""
                EvaluationFrequency = "PT5M"
                WindowSize          = "PT5M"
                DSExport            = "Yes"
                Severity            = "2"
                Threshold           = "XX"
                FriendlyName        = ""
                Unit                = $metric.Unit
                _Source             = "Discovery"
                _DateDiscovered     = (Get-Date -Format "yyyy-MM-dd")
            }
            $discoveredMetrics += $suggestion
        }
    }
}

# Export suggestions
if ($discoveredMetrics.Count -gt 0) {
    $discoveredMetrics | Export-Csv -Path $suggestionsPath -NoTypeInformation -Encoding UTF8
    Write-Log "`nSuggestions exported: $suggestionsPath ($($discoveredMetrics.Count))" -Level Success
}

# Summary
Write-Log "`n=== SUMMARY ===" -Level Info
Write-Log "Configured metrics (from dictionary): $($configuredMetrics.Count)" -Level Success
Write-Log "Discovered metrics (suggestions): $($discoveredMetrics.Count)" -Level Warning

if ($discoveredMetrics.Count -gt 0) {
    Write-Log "`nATTENTION: $($discoveredMetrics.Count) discovered metrics need validation" -Level Warning
    Write-Log "Review $suggestionsPath and define thresholds (replace 'XX')" -Level Info
}

# Retourner les résultats
return @{
    ConfiguredMetrics = $configuredMetrics
    DiscoveredMetrics = $discoveredMetrics
    TotalMetrics = $availableMetrics.Count
}
