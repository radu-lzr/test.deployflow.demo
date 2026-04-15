<#
.SYNOPSIS
    Merges a global dictionary with optional client overrides.
.PARAMETER GlobalDictionaryPath
    Path to the global dictionary CSV file.
.PARAMETER OutputPath
    Path for the merged output CSV.
.PARAMETER OverridePath
    Path to the client overrides CSV (optional).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$GlobalDictionaryPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$false)][string]$OverridePath = ""
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = 'Info')
    $color = switch($Level) {
        'Info' { 'Cyan' } 'Warning' { 'Yellow' } 'Error' { 'Red' } 'Success' { 'Green' } default { 'White' }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

Write-Log "=== Dictionary Merge ==="

if (-not (Test-Path $GlobalDictionaryPath)) {
    Write-Log "Global dictionary not found: $GlobalDictionaryPath" -Level Error
    exit 1
}

$globalDict = Import-Csv -Path $GlobalDictionaryPath
Write-Log "Global dictionary: $($globalDict.Count) entries" -Level Success

if ($OverridePath -and (Test-Path $OverridePath)) {
    Write-Log "Loading overrides from $OverridePath..." -Level Info
    $overrides = Import-Csv -Path $OverridePath
    Write-Log "Overrides: $($overrides.Count) entries" -Level Success

    # Detect key columns from the CSV headers
    $headers = $globalDict[0].PSObject.Properties.Name

    # Build override lookup — use all columns except value-like ones as composite key
    $overrideLookup = @{}
    foreach ($entry in $overrides) {
        # Build a key from ResourceType + the second column (varies by dict type)
        $props = $entry.PSObject.Properties.Name
        $keyParts = @()
        foreach ($p in $props) {
            # Use the first 2-3 identifying columns
            if ($p -match 'ResourceType|AlertMetricName|Severity|OperationName|QueryName|LogCategory|MetricCategory|CategoryName') {
                $keyParts += $entry.$p
            }
        }
        $key = $keyParts -join '|'
        $overrideLookup[$key] = $entry
    }

    # Merge: override wins, then add remaining globals
    $mergedDict = @()
    $overriddenKeys = @{}

    foreach ($globalEntry in $globalDict) {
        $keyParts = @()
        foreach ($p in $globalEntry.PSObject.Properties.Name) {
            if ($p -match 'ResourceType|AlertMetricName|Severity|OperationName|QueryName|LogCategory|MetricCategory|CategoryName') {
                $keyParts += $globalEntry.$p
            }
        }
        $key = $keyParts -join '|'

        if ($overrideLookup.ContainsKey($key)) {
            $override = $overrideLookup[$key]
            # Check for delete action
            if ($override.PSObject.Properties['Action'] -and $override.Action -eq 'Delete') {
                Write-Log "  Deleted: $key" -Level Warning
            } else {
                $mergedDict += $override
                Write-Log "  Overridden: $key" -Level Info
            }
            $overriddenKeys[$key] = $true
        } else {
            $mergedDict += $globalEntry
        }
    }

    # Add overrides that are net-new (not in global)
    foreach ($entry in $overrides) {
        $keyParts = @()
        foreach ($p in $entry.PSObject.Properties.Name) {
            if ($p -match 'ResourceType|AlertMetricName|Severity|OperationName|QueryName|LogCategory|MetricCategory|CategoryName') {
                $keyParts += $entry.$p
            }
        }
        $key = $keyParts -join '|'

        if (-not $overriddenKeys.ContainsKey($key) -and
            (-not $entry.PSObject.Properties['Action'] -or $entry.Action -ne 'Delete')) {
            $mergedDict += $entry
            Write-Log "  Added new: $key" -Level Success
        }
    }

    Write-Log "Merged dictionary: $($mergedDict.Count) entries" -Level Success
} else {
    Write-Log "No overrides found, using global dictionary as-is" -Level Info
    $mergedDict = $globalDict
}

# Ensure output dir exists
$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$mergedDict | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Log "Output: $OutputPath ($($mergedDict.Count) entries)" -Level Success
