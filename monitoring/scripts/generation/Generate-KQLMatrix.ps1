<#
.SYNOPSIS
    Génère la matrice des alertes KQL basées sur les logs

.DESCRIPTION
    Génère des alertes basées sur des requêtes KQL pour les ressources avec diagnostic settings configurés.
    Utilise le dictionnaire kql-queries-dictionary.csv pour définir les queries par resource type.

.PARAMETER ClientName
    Nom du client

.PARAMETER Environment
    Environnement (dev, test, prod, etc.)

.EXAMPLE
    .\Generate-KQLMatrix-DevOps.ps1 -ClientName "Squadra" -Environment "Dev"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ClientName,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = ""
)

$ErrorActionPreference = "Stop"

# Déterminer le chemin de base du repo
$scriptPath = $PSScriptRoot
$repoRoot = Split-Path (Split-Path (Split-Path $scriptPath -Parent) -Parent) -Parent

$clientPath = Join-Path $repoRoot "DevOps\Clients\$ClientName"

if ([string]::IsNullOrEmpty($Environment)) {
    $configPath = Join-Path $clientPath "Config\client-config.json"
    $logFile = Join-Path $clientPath "Logs\kql-generation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $matricesPath = Join-Path $clientPath "Matrices"
    $dictionariesPath = Join-Path $clientPath "Dictionaries"
} else {
    $configPath = Join-Path $clientPath "Config\$Environment\environment-config.json"
    $logFile = Join-Path $clientPath "Logs\$Environment\kql-generation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $matricesPath = Join-Path $clientPath "Matrices\$Environment"
    $dictionariesPath = Join-Path $clientPath "Dictionaries\$Environment"
}

$excludeResourcesPath = Join-Path $repoRoot "DevOps\Config\exclude-resources.json"

# Créer les dossiers si nécessaire
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
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
    Add-Content -Path $logFile -Value $logMessage
}

# ============================================================================
# MAIN
# ============================================================================

Write-Log "=== Génération matrice KQL Queries - $ClientName ===" -Level Info
Write-Log "Environnement: $Environment" -Level Info

# Charger les exclusions ressources
$excludedResources = @()
if (Test-Path $excludeResourcesPath) {
    $excludedResourcesJson = Get-Content -Path $excludeResourcesPath -Raw | ConvertFrom-Json
    $excludedResources = $excludedResourcesJson | ForEach-Object { $_.resource }
    Write-Log "Exclusions ressources chargées: $($excludedResources.Count) types de ressources" -Level Info
}

# Charger les exclusions KQL client (filtrer matrices)
$excludeKQLClientPath = Join-Path $dictionariesPath "exclude-kql-$($ClientName.ToLower())-$($Environment.ToLower()).csv"
$excludedKQLClient = @{}
if (Test-Path $excludeKQLClientPath) {
    $excludedKQLClientArray = Import-Csv -Path $excludeKQLClientPath
    foreach ($entry in $excludedKQLClientArray) {
        $key = "$($entry.ResourceType)|$($entry.QueryName)"
        $excludedKQLClient[$key] = $entry.Reason
    }
    Write-Log "Exclusions KQL client chargées: $($excludedKQLClientArray.Count) requêtes" -Level Info
}

# Charger les exclusions de noms de ressources client
$excludeResourceNamesPath = Join-Path $dictionariesPath "exclude-resourcenames-$($ClientName.ToLower())-$($Environment.ToLower()).csv"
$excludedResourceNames = @{}
if (Test-Path $excludeResourceNamesPath) {
    $excludedResourceNamesArray = Import-Csv -Path $excludeResourceNamesPath
    foreach ($entry in $excludedResourceNamesArray) {
        $excludedResourceNames[$entry.ResourceName] = $entry.Reason
    }
    Write-Log "Exclusions noms de ressources client chargées: $($excludedResourceNamesArray.Count) ressources" -Level Info
}

if (-not (Test-Path $configPath)) {
    Write-Log "Configuration introuvable: $configPath" -Level Error
    exit 1
}

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Charger le dictionnaire KQL
$globalDictPath = Join-Path $repoRoot "DevOps\Dictionaries\Global\kql-queries-dictionary.csv"
$clientDictPath = Join-Path $dictionariesPath "kql-queries-overrides.csv"

Write-Log "Chargement des dictionnaires KQL..." -Level Info

if (-not (Test-Path $globalDictPath)) {
    Write-Log "Dictionnaire KQL global introuvable: $globalDictPath" -Level Error
    exit 1
}

$globalDict = Import-Csv -Path $globalDictPath
$globalDictHash = @{}
foreach ($entry in $globalDict) {
    $key = "$($entry.ResourceType)|$($entry.QueryName)"
    $globalDictHash[$key] = $entry
}
Write-Log "  -> Dictionnaire global: $($globalDict.Count) queries" -Level Success

# Dictionnaire client (overrides)
$clientDictHash = @{}
if (Test-Path $clientDictPath) {
    $clientDict = Import-Csv -Path $clientDictPath
    foreach ($entry in $clientDict) {
        # Supporter les overrides par ressource spécifique (colonne ResourceName optionnelle)
        if ($entry.PSObject.Properties.Name -contains 'ResourceName' -and ![string]::IsNullOrWhiteSpace($entry.ResourceName)) {
            # Override spécifique à une ressource
            $key = "$($entry.ResourceType)|$($entry.ResourceName)|$($entry.QueryName)"
        } else {
            # Override générique pour tout le type de ressource
            $key = "$($entry.ResourceType)|$($entry.QueryName)"
        }
        $clientDictHash[$key] = $entry
    }
    Write-Log "  -> Dictionnaire client: $($clientDict.Count) surcharges" -Level Success
}

# Récupérer TOUTES les ressources (pas seulement celles avec diagnostic settings)
Write-Log "Récupération des ressources Azure..." -Level Info
Set-AzContext -TenantId $config.tenantId | Out-Null

$allResources = @()

foreach ($subId in $config.subscriptions) {
    Write-Log "  Subscription: $subId" -Level Info
    Set-AzContext -SubscriptionId $subId | Out-Null
    
    $resources = Get-AzResource
    
    # Filtrer les ressources exclues (par type ET par nom)
    $filteredResources = $resources | Where-Object { 
        $resourceType = $_.ResourceType.ToLower()
        $resourceName = $_.Name
        ($resourceType -notin $excludedResources) -and (-not $excludedResourceNames.ContainsKey($resourceName))
    }
    
    $allResources += $filteredResources
    Write-Log "    -> $($resources.Count) ressources trouvées, $($filteredResources.Count) après exclusions" -Level Info
}

Write-Log "Total ressources: $($allResources.Count)" -Level Success

# Générer la matrice KQL
Write-Log "Génération de la matrice KQL..." -Level Info

$matrix = @()
$stats = @{
    FromClient = 0
    FromGlobal = 0
    ResourcesWithQueries = 0
}
$processedTypes = @{}

foreach ($resource in $allResources) {
    $resourceType = $resource.ResourceType.ToLower()
    
    if (-not $processedTypes.ContainsKey($resourceType)) {
        $processedTypes[$resourceType] = $true
        Write-Log "  Type: $resourceType" -Level Info
    }
    
    # Chercher les queries pour ce type de ressource dans dictionnaires
    # Priorité 1: Override spécifique à la ressource
    $specificClientQueries = $clientDictHash.Keys | Where-Object { $_ -like "$resourceType|$($resource.Name)|*" }
    # Priorité 2: Override générique au type
    $genericClientQueries = $clientDictHash.Keys | Where-Object { $_ -like "$resourceType|*" -and $_ -notlike "$resourceType|$($resource.Name)|*" -and ($_.Split('|').Count -eq 2) }
    # Priorité 3: Global
    $globalQueries = $globalDictHash.Keys | Where-Object { $_ -like "$resourceType|*" }
    
    $hasClientOverrides = $false
    
    # Niveau 1: Client overrides spécifiques à la ressource (priorité maximale)
    if ($specificClientQueries) {
        $hasClientOverrides = $true
        $stats.ResourcesWithQueries++
        foreach ($queryKey in $specificClientQueries) {
            $config = $clientDictHash[$queryKey]
            
            # Vérifier si requête exclue par le client
            $kqlKey = "$resourceType|$($config.QueryName)"
            if ($excludedKQLClient.ContainsKey($kqlKey)) {
                Write-Log "    -> Requête KQL exclue par client: $($config.QueryName) - Raison: $($excludedKQLClient[$kqlKey])" -Level Info
                continue
            }
            
            $stats.FromClient++
            
            $alertName = "$($resource.Name)-$($config.QueryName)"
            
            $matrixEntry = [PSCustomObject]@{
                resourceId = $resource.ResourceId
                resourceName = $resource.Name
                resourceType = $resourceType
                resourceGroup = $resource.ResourceGroupName
                subscriptionId = $resource.SubscriptionId
                location = $resource.Location
                alertName = $alertName
                queryName = $config.QueryName
                query = $config.Query
                description = $config.Description
                severity = $config.Severity
                threshold = $config.Threshold
                evaluationFrequency = $config.EvaluationFrequency
                windowSize = $config.WindowSize
                friendlyName = $config.FriendlyName
                _Source = "Client-Specific"
            }
            
            $matrix += $matrixEntry
        }
    }
    
    # Niveau 2: Client overrides génériques au type
    if ($genericClientQueries) {
        if (-not $hasClientOverrides) {
            $stats.ResourcesWithQueries++
            $hasClientOverrides = $true
        }
        foreach ($queryKey in $genericClientQueries) {
            $config = $clientDictHash[$queryKey]
            
            # Vérifier si requête exclue par le client
            $kqlKey = "$resourceType|$($config.QueryName)"
            if ($excludedKQLClient.ContainsKey($kqlKey)) {
                Write-Log "    -> Requête KQL exclue par client: $($config.QueryName) - Raison: $($excludedKQLClient[$kqlKey])" -Level Info
                continue
            }
            
            $stats.FromClient++
            
            $alertName = "$($resource.Name)-$($config.QueryName)"
            
            $matrixEntry = [PSCustomObject]@{
                resourceId = $resource.ResourceId
                resourceName = $resource.Name
                resourceType = $resourceType
                resourceGroup = $resource.ResourceGroupName
                subscriptionId = $resource.SubscriptionId
                location = $resource.Location
                alertName = $alertName
                queryName = $config.QueryName
                query = $config.Query
                description = $config.Description
                severity = $config.Severity
                threshold = $config.Threshold
                evaluationFrequency = $config.EvaluationFrequency
                windowSize = $config.WindowSize
                friendlyName = $config.FriendlyName
                _Source = "Client"
            }
            
            $matrix += $matrixEntry
        }
    }
    
    # Niveau 3: Global (seulement si aucun override client n'existe)
    if ($globalQueries -and -not $hasClientOverrides) {
        $stats.ResourcesWithQueries++
        foreach ($queryKey in $globalQueries) {
            $config = $globalDictHash[$queryKey]
            
            # Vérifier si requête exclue par le client
            $kqlKey = "$resourceType|$($config.QueryName)"
            if ($excludedKQLClient.ContainsKey($kqlKey)) {
                Write-Log "    -> Requête KQL exclue par client: $($config.QueryName) - Raison: $($excludedKQLClient[$kqlKey])" -Level Info
                continue
            }
            
            $stats.FromGlobal++
            
            $alertName = "$($resource.Name)-$($config.QueryName)"
            
            $matrixEntry = [PSCustomObject]@{
                resourceId = $resource.ResourceId
                resourceName = $resource.Name
                resourceType = $resourceType
                resourceGroup = $resource.ResourceGroupName
                subscriptionId = $resource.SubscriptionId
                location = $resource.Location
                alertName = $alertName
                queryName = $config.QueryName
                query = $config.Query
                description = $config.Description
                severity = $config.Severity
                threshold = $config.Threshold
                evaluationFrequency = $config.EvaluationFrequency
                windowSize = $config.WindowSize
                friendlyName = $config.FriendlyName
                _Source = "Global"
            }
            
            $matrix += $matrixEntry
        }
    }
}

# Sauvegarder la matrice
$matrixFile = Join-Path $matricesPath "kql-matrix_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$matrixDir = Split-Path $matrixFile -Parent
if (-not (Test-Path $matrixDir)) {
    New-Item -ItemType Directory -Path $matrixDir -Force | Out-Null
}

$matrix | Export-Csv -Path $matrixFile -NoTypeInformation -Encoding UTF8
Write-Log "Matrice KQL sauvegardée: $matrixFile" -Level Success

# Résumé
Write-Log "`n=== RÉSUMÉ ===" -Level Info
Write-Log "Ressources traitées: $($allResources.Count)" -Level Info
Write-Log "Types de ressources: $($processedTypes.Count)" -Level Info
Write-Log "Ressources avec queries KQL: $($stats.ResourcesWithQueries)" -Level Info
Write-Log "Alertes KQL générées: $($matrix.Count)" -Level Success
Write-Log "  - Depuis dictionnaire client: $($stats.FromClient)" -Level Info
Write-Log "  - Depuis dictionnaire global: $($stats.FromGlobal)" -Level Info

Write-Log "`n⚠️  NOTE: Les alertes KQL nécessitent Diagnostic Settings configurés" -Level Warning
Write-Log "Utilisez Generate-DiagnosticSettingsMatrix-DevOps.ps1 pour générer la matrice des Diagnostic Settings" -Level Info

Write-Log "`n✅ Génération terminée avec succès" -Level Success
