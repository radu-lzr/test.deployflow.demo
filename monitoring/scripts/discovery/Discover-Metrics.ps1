<#
.SYNOPSIS
    Découvre les métriques disponibles pour les ressources Azure avec fallback 3 niveaux

.DESCRIPTION
    Ce script implémente une logique de fallback à 3 niveaux pour découvrir les métriques:
    1. Dictionnaire client spécifique (overrides)
    2. Dictionnaire global (référence)
    3. Discovery PowerShell (Get-AzMetricDefinition)
    
    Les métriques découvertes via PowerShell sont ajoutées aux suggestions pour validation.

.PARAMETER ResourceId
    ID complet de la ressource Azure

.PARAMETER ResourceType
    Type de ressource (ex: microsoft.compute/virtualmachines)

.PARAMETER ClientName
    Nom du client

.PARAMETER Environment
    Environnement (dev, test, prod, etc.)

.EXAMPLE
    .\Discover-Metrics.ps1 -ResourceId "/subscriptions/.../resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1" -ResourceType "microsoft.compute/virtualmachines" -ClientName "Squadra" -Environment "Dev"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceType,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientName,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = ""
)

$ErrorActionPreference = "Continue"

# Déterminer le chemin de base du repo
$scriptPath = $PSScriptRoot
$repoRoot = Split-Path (Split-Path (Split-Path $scriptPath -Parent) -Parent) -Parent

# Chemins des dictionnaires
$globalDictPath = Join-Path $repoRoot "DevOps\Dictionaries\Global\metrics-dictionary.csv"

if ([string]::IsNullOrEmpty($Environment)) {
    $clientDictPath = Join-Path $repoRoot "DevOps\Clients\$ClientName\Dictionaries\metrics-overrides.csv"
    $suggestionsPath = Join-Path $repoRoot "DevOps\Clients\$ClientName\Dictionaries\suggestions-metrics.csv"
} else {
    $clientDictPath = Join-Path $repoRoot "DevOps\Clients\$ClientName\Dictionaries\$Environment\metrics-overrides.csv"
    $suggestionsPath = Join-Path $repoRoot "DevOps\Clients\$ClientName\Dictionaries\$Environment\suggestions-metrics.csv"
}

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

function Get-MetricConfiguration {
    param(
        [string]$ResourceType,
        [string]$MetricName,
        [hashtable]$ClientDict,
        [hashtable]$GlobalDict
    )
    
    # Niveau 1: Dictionnaire client
    $key = "$ResourceType|$MetricName"
    if ($ClientDict.ContainsKey($key)) {
        Write-Log "  ✓ Trouvé dans dictionnaire client: $MetricName" -Level Success
        $config = $ClientDict[$key]
        $config | Add-Member -MemberType NoteProperty -Name "_Source" -Value "Client" -Force
        return $config
    }
    
    # Niveau 2: Dictionnaire global
    if ($GlobalDict.ContainsKey($key)) {
        Write-Log "  ✓ Trouvé dans dictionnaire global: $MetricName" -Level Info
        $config = $GlobalDict[$key]
        $config | Add-Member -MemberType NoteProperty -Name "_Source" -Value "Global" -Force
        return $config
    }
    
    # Niveau 3: Pas trouvé
    Write-Log "  ⚠ Métrique non trouvée dans dictionnaires: $MetricName" -Level Warning
    return $null
}

function Add-ToSuggestions {
    param(
        [PSCustomObject]$MetricConfig
    )
    
    # Créer le dossier si nécessaire
    $suggestionsDir = Split-Path $suggestionsPath -Parent
    if (-not (Test-Path $suggestionsDir)) {
        New-Item -ItemType Directory -Path $suggestionsDir -Force | Out-Null
    }
    
    # Charger les suggestions existantes
    $existingSuggestions = @()
    if (Test-Path $suggestionsPath) {
        $existingSuggestions = Import-Csv -Path $suggestionsPath
    }
    
    # Vérifier si la suggestion existe déjà
    $key = "$($MetricConfig.ResourceType)|$($MetricConfig.AlertMetricName)"
    $exists = $existingSuggestions | Where-Object { 
        "$($_.ResourceType)|$($_.AlertMetricName)" -eq $key 
    }
    
    if (-not $exists) {
        # Ajouter la nouvelle suggestion
        $MetricConfig | Export-Csv -Path $suggestionsPath -NoTypeInformation -Encoding UTF8 -Append
        Write-Log "  ➕ Ajouté aux suggestions: $($MetricConfig.AlertMetricName)" -Level Success
    }
}

# ============================================================================
# MAIN
# ============================================================================

Write-Log "=== Découverte des métriques ===" -Level Info
Write-Log "ResourceType: $ResourceType" -Level Info
Write-Log "ResourceId: $ResourceId" -Level Info

# Charger le dictionnaire global
if (-not (Test-Path $globalDictPath)) {
    Write-Log "Dictionnaire global introuvable: $globalDictPath" -Level Error
    exit 1
}

Write-Log "Chargement du dictionnaire global..." -Level Info
$globalDictArray = Import-Csv -Path $globalDictPath
$globalDict = @{}
foreach ($entry in $globalDictArray) {
    $key = "$($entry.ResourceType)|$($entry.AlertMetricName)"
    if (-not $globalDict.ContainsKey($key)) {
        $globalDict[$key] = $entry
    }
}
Write-Log "  -> $($globalDict.Count) entrées chargées" -Level Success

# Charger le dictionnaire client (si existe)
$clientDict = @{}
if (Test-Path $clientDictPath) {
    Write-Log "Chargement du dictionnaire client..." -Level Info
    $clientDictArray = Import-Csv -Path $clientDictPath
    foreach ($entry in $clientDictArray) {
        $key = "$($entry.ResourceType)|$($entry.AlertMetricName)"
        $clientDict[$key] = $entry
    }
    Write-Log "  -> $($clientDict.Count) surcharge(s) chargée(s)" -Level Success
}

# Découvrir les métriques disponibles via PowerShell
Write-Log "Découverte des métriques disponibles via Azure..." -Level Info

try {
    $availableMetrics = Get-AzMetricDefinition -ResourceId $ResourceId -ErrorAction Stop
    Write-Log "  -> $($availableMetrics.Count) métriques disponibles" -Level Success
} catch {
    Write-Log "Erreur lors de la découverte des métriques: $_" -Level Error
    exit 1
}

# Résultats
$configuredMetrics = @()
$discoveredMetrics = @()

foreach ($metric in $availableMetrics) {
    $metricName = $metric.Name.Value
    
    # Chercher dans dictionnaires (Niveau 1 et 2)
    $config = Get-MetricConfiguration -ResourceType $ResourceType -MetricName $metricName -ClientDict $clientDict -GlobalDict $globalDict
    
    if ($config) {
        $configuredMetrics += $config
    } else {
        # Niveau 3: Créer suggestion
        Write-Log "  🔍 Découverte PowerShell: $metricName" -Level Info
        
        # Déterminer l'agrégation par défaut
        $aggregation = if ($metric.PrimaryAggregationType) { 
            $metric.PrimaryAggregationType 
        } else { 
            "Average" 
        }
        
        # Créer configuration par défaut
        $suggestion = [PSCustomObject]@{
            ResourceType = $ResourceType.ToLower()
            AlertMetricName = $metricName
            Count = ""
            AlertOperator = "GreaterThanOrEqual"
            Aggregation = $aggregation
            Dimensions = ""
            EvaluationFrequency = "PT5M"
            WindowSize = "PT5M"
            DSExport = "Yes"
            Severity = "2"  # Warning par défaut
            Threshold = "XX"  # À définir par consultant
            FriendlyName = ""
            Unit = $metric.Unit
            MetricAvailabilities = ($metric.MetricAvailabilities | ForEach-Object { "$($_.TimeGrain)" }) -join ";"
            _Source = "Discovery"
            _DateDiscovered = (Get-Date -Format "yyyy-MM-dd")
        }
        
        Add-ToSuggestions -MetricConfig $suggestion
        $discoveredMetrics += $suggestion
    }
}

# Résumé
Write-Log "`n=== RÉSUMÉ ===" -Level Info
Write-Log "Métriques configurées (dictionnaires): $($configuredMetrics.Count)" -Level Success
Write-Log "  - Depuis dictionnaire client: $(($configuredMetrics | Where-Object { $_._Source -eq 'Client' }).Count)" -Level Info
Write-Log "  - Depuis dictionnaire global: $(($configuredMetrics | Where-Object { $_._Source -eq 'Global' }).Count)" -Level Info
Write-Log "Métriques découvertes (suggestions): $($discoveredMetrics.Count)" -Level Warning

if ($discoveredMetrics.Count -gt 0) {
    Write-Log "`n⚠️  ATTENTION: $($discoveredMetrics.Count) métriques découvertes nécessitent validation" -Level Warning
    Write-Log "Fichier de suggestions: $suggestionsPath" -Level Info
    Write-Log "`nActions recommandées:" -Level Info
    Write-Log "1. Consulter le fichier suggestions-metrics.csv" -Level Info
    Write-Log "2. Définir les thresholds appropriés (remplacer 'XX')" -Level Info
    Write-Log "3. Choisir:" -Level Info
    Write-Log "   - Ajouter à metrics-overrides.csv (client) pour usage spécifique" -Level Info
    Write-Log "   - Proposer à metrics-dictionary.csv (global) pour bonne pratique" -Level Info
}

# Retourner les résultats
return @{
    ConfiguredMetrics = $configuredMetrics
    DiscoveredMetrics = $discoveredMetrics
    TotalMetrics = $availableMetrics.Count
}
