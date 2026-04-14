<#
.SYNOPSIS
    Fusionne les dictionnaires global et client pour créer un dictionnaire effectif

.DESCRIPTION
    Ce script charge le dictionnaire global et applique les surcharges spécifiques au client.
    Permet de maintenir un dictionnaire de référence tout en personnalisant par client.

.PARAMETER DictionaryType
    Type de dictionnaire (metrics, diagnostic-settings, activity-logs, kql-queries)

.PARAMETER ClientName
    Nom du client

.PARAMETER Environment
    Environnement (dev, test, prod, etc.) - Optionnel pour rétrocompatibilité

.PARAMETER GlobalDictionaryPath
    Chemin vers le dictionnaire global

.PARAMETER ClientDictionaryPath
    Chemin vers le dictionnaire client (optionnel)

.EXAMPLE
    .\Merge-Dictionaries.ps1 -DictionaryType "metrics" -ClientName "ClientA" -Environment "prod"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('metrics', 'diagnostic-settings', 'activity-logs', 'kql-queries')]
    [string]$DictionaryType,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientName,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "",
    
    [Parameter(Mandatory=$false)]
    [string]$GlobalDictionaryPath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ClientDictionaryPath = ""
)

# Déterminer le chemin de base du repo
$scriptPath = $PSScriptRoot
$repoRoot = Split-Path (Split-Path (Split-Path $scriptPath -Parent) -Parent) -Parent

# Si GlobalDictionaryPath n'est pas fourni, utiliser le chemin par défaut
if ([string]::IsNullOrEmpty($GlobalDictionaryPath)) {
    $GlobalDictionaryPath = Join-Path $repoRoot "DevOps\Dictionaries\Global"
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info','Warning','Error','Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch($Level) {
        'Info' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $color
    
    $logFile = Join-Path $repoRoot "DevOps\Clients\$ClientName\Logs\dictionary-merge.log"
    if (Test-Path (Split-Path $logFile)) {
        Add-Content -Path $logFile -Value $logMessage
    }
}

Write-Log "=== Fusion des dictionnaires ===" -Level Info
Write-Log "Type: $DictionaryType" -Level Info
Write-Log "Client: $ClientName" -Level Info
if (-not [string]::IsNullOrEmpty($Environment)) {
    Write-Log "Environnement: $Environment" -Level Info
}

$globalDictFile = Join-Path $GlobalDictionaryPath "$DictionaryType-dictionary.csv"

if (-not (Test-Path $globalDictFile)) {
    Write-Log "Dictionnaire global introuvable: $globalDictFile" -Level Error
    exit 1
}

Write-Log "Chargement du dictionnaire global..." -Level Info
$globalDict = Import-Csv -Path $globalDictFile
Write-Log "  -> $($globalDict.Count) entrées chargées" -Level Success

if ([string]::IsNullOrEmpty($ClientDictionaryPath)) {
    if ([string]::IsNullOrEmpty($Environment)) {
        # Mode single-env (rétrocompatibilité)
        $ClientDictionaryPath = Join-Path $repoRoot "DevOps\Clients\$ClientName\Dictionaries"
    } else {
        # Mode multi-env
        $ClientDictionaryPath = Join-Path $repoRoot "DevOps\Clients\$ClientName\Dictionaries\$Environment"
    }
}

$clientDictFile = Join-Path $ClientDictionaryPath "$DictionaryType-overrides.csv"

if (Test-Path $clientDictFile) {
    Write-Log "Chargement des surcharges client..." -Level Info
    $clientOverrides = Import-Csv -Path $clientDictFile
    Write-Log "  -> $($clientOverrides.Count) surcharge(s) trouvée(s)" -Level Success
    
    $mergedDict = @()
    $overriddenKeys = @{}
    
    foreach ($override in $clientOverrides) {
        $key = ""
        
        switch ($DictionaryType) {
            'metrics' {
                $key = "$($override.ResourceType)|$($override.AlertMetricName)|$($override.Severity)"
            }
            'diagnostic-settings' {
                $key = "$($override.ResourceType)|$($override.CategoryName)"
            }
            'activity-logs' {
                $key = "$($override.Category)|$($override.OperationName)"
            }
            'kql-queries' {
                $key = "$($override.ResourceType)|$($override.QueryName)"
            }
        }
        
        $overriddenKeys[$key] = $true
        
        if ($override.Action -eq 'Delete') {
            Write-Log "  Suppression: $key" -Level Warning
            continue
        }
        
        Write-Log "  Surcharge: $key" -Level Info
        $mergedDict += $override
    }
    
    foreach ($globalEntry in $globalDict) {
        $key = ""
        
        switch ($DictionaryType) {
            'metrics' {
                $key = "$($globalEntry.ResourceType)|$($globalEntry.AlertMetricName)|$($globalEntry.Severity)"
            }
            'diagnostic-settings' {
                $key = "$($globalEntry.ResourceType)|$($globalEntry.CategoryName)"
            }
            'activity-logs' {
                $key = "$($globalEntry.Category)|$($globalEntry.OperationName)"
            }
            'kql-queries' {
                $key = "$($globalEntry.ResourceType)|$($globalEntry.QueryName)"
            }
        }
        
        if (-not $overriddenKeys.ContainsKey($key)) {
            $mergedDict += $globalEntry
        }
    }
    
    Write-Log "Dictionnaire fusionné: $($mergedDict.Count) entrées" -Level Success
    
} else {
    Write-Log "Aucune surcharge client trouvée, utilisation du dictionnaire global" -Level Info
    $mergedDict = $globalDict
}

if ([string]::IsNullOrEmpty($Environment)) {
    $outputPath = Join-Path $repoRoot "DevOps\Clients\$ClientName\Dictionaries\$DictionaryType-effective.csv"
} else {
    $outputPath = Join-Path $repoRoot "DevOps\Clients\$ClientName\Dictionaries\$Environment\$DictionaryType-effective.csv"
}

# Créer le dossier de sortie s'il n'existe pas
$outputDir = Split-Path $outputPath -Parent
if (-not (Test-Path $outputDir)) {
    Write-Log "Création du dossier de sortie: $outputDir" -Level Info
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$mergedDict | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

Write-Log "Dictionnaire effectif sauvegardé: $outputPath" -Level Success

return $outputPath
