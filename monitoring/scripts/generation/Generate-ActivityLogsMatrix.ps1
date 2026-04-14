<#
.SYNOPSIS
    Génère la matrice des alertes Activity Logs

.DESCRIPTION
    Génère des alertes basées sur les opérations Activity Logs pour toutes les ressources.
    Utilise le dictionnaire activity-logs-dictionary.csv pour définir les opérations à surveiller.

.PARAMETER ClientName
    Nom du client

.PARAMETER Environment
    Environnement (dev, test, prod, etc.)

.EXAMPLE
    .\Generate-ActivityLogsMatrix-DevOps.ps1 -ClientName "Squadra" -Environment "Dev"
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
    $logFile = Join-Path $clientPath "Logs\activitylogs-generation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $matricesPath = Join-Path $clientPath "Matrices"
    $dictionariesPath = Join-Path $clientPath "Dictionaries"
} else {
    $configPath = Join-Path $clientPath "Config\$Environment\environment-config.json"
    $logFile = Join-Path $clientPath "Logs\$Environment\activitylogs-generation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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

Write-Log "=== Génération matrice Activity Logs - $ClientName ===" -Level Info
Write-Log "Environnement: $Environment" -Level Info

# Charger les exclusions ressources
$excludedResources = @()
if (Test-Path $excludeResourcesPath) {
    $excludedResourcesJson = Get-Content -Path $excludeResourcesPath -Raw | ConvertFrom-Json
    $excludedResources = $excludedResourcesJson | ForEach-Object { $_.resource }
    Write-Log "Exclusions ressources chargées: $($excludedResources.Count) types de ressources" -Level Info
}

# Charger les exclusions activity logs client (filtrer matrices ET suggestions)
$excludeActivityLogsClientPath = Join-Path $dictionariesPath "exclude-activitylogs-$($ClientName.ToLower())-$($Environment.ToLower()).csv"
$excludedActivityLogsClient = @{}
if (Test-Path $excludeActivityLogsClientPath) {
    $excludedActivityLogsClientArray = Import-Csv -Path $excludeActivityLogsClientPath
    foreach ($entry in $excludedActivityLogsClientArray) {
        $key = "$($entry.ResourceType)|$($entry.OperationName)"
        $excludedActivityLogsClient[$key] = $entry.Reason
    }
    Write-Log "Exclusions activity logs client chargées: $($excludedActivityLogsClientArray.Count) opérations" -Level Info
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

# Charger le dictionnaire Activity Logs
$globalDictPath = Join-Path $repoRoot "DevOps\Dictionaries\Global\activity-logs-dictionary.csv"
$clientDictPath = Join-Path $dictionariesPath "activity-logs-overrides.csv"

Write-Log "Chargement des dictionnaires Activity Logs..." -Level Info

if (-not (Test-Path $globalDictPath)) {
    Write-Log "Dictionnaire Activity Logs global introuvable: $globalDictPath" -Level Error
    exit 1
}

$globalDict = Import-Csv -Path $globalDictPath
$globalDictHash = @{}
foreach ($entry in $globalDict) {
    $key = "$($entry.ResourceType)|$($entry.OperationName)"
    $globalDictHash[$key] = $entry
}
Write-Log "  -> Dictionnaire global: $($globalDict.Count) opérations" -Level Success

# Dictionnaire client (overrides)
$clientDictHash = @{}
if (Test-Path $clientDictPath) {
    $clientDict = Import-Csv -Path $clientDictPath
    foreach ($entry in $clientDict) {
        $key = "$($entry.ResourceType)|$($entry.OperationName)"
        $clientDictHash[$key] = $entry
    }
    Write-Log "  -> Dictionnaire client: $($clientDict.Count) surcharges" -Level Success
}

# Récupérer toutes les ressources
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

# Générer la matrice Activity Logs
Write-Log "Génération de la matrice Activity Logs..." -Level Info

$matrix = @()
$suggestions = @()
$stats = @{
    FromClient = 0
    FromGlobal = 0
    Total = 0
    Suggested = 0
}
$processedResourceTypes = @{}

foreach ($resource in $allResources) {
    $resourceType = $resource.ResourceType.ToLower()
    
    # Ignorer les bases master SQL
    if ($resource.ResourceType -eq "microsoft.sql/servers/databases" -and $resource.Name -like "*/master") {
        continue
    }
    
    # Chercher les opérations pour ce type de ressource
    $operations = $globalDict | Where-Object { $_.ResourceType -eq $resourceType }
    
    if ($operations.Count -eq 0) {
        # Type non répertorié - créer suggestion une seule fois par type
        if (-not $processedResourceTypes.ContainsKey($resourceType)) {
            Write-Log "  ⚠ Type non répertorié: $resourceType - Ajout aux suggestions" -Level Warning
            
            # Créer suggestions pour opérations administratives courantes
            $commonOperations = @(
                @{
                    OperationName = "$resourceType/write"
                    Description = "Resource created or updated"
                    Category = "Administrative"
                    Severity = "2"
                    AlertOnSuccess = "No"
                    AlertOnFailure = "Yes"
                },
                @{
                    OperationName = "$resourceType/delete"
                    Description = "Resource deleted"
                    Category = "Administrative"
                    Severity = "1"
                    AlertOnSuccess = "Yes"
                    AlertOnFailure = "Yes"
                }
            )
            
            foreach ($op in $commonOperations) {
                $suggestion = [PSCustomObject]@{
                    ResourceType = $resourceType
                    Category = $op.Category
                    OperationName = $op.OperationName
                    Severity = $op.Severity
                    Description = $op.Description
                    AlertOnSuccess = $op.AlertOnSuccess
                    AlertOnFailure = $op.AlertOnFailure
                    FriendlyName = $resourceType.Split('/')[-1]
                    _DateDiscovered = (Get-Date -Format 'yyyy-MM-dd')
                    _SampleResource = $resource.Name
                }
                
                # Vérifier si pas dans exclusions client
                $suggestionKey = "$resourceType|$($op.OperationName)"
                if (-not $excludedActivityLogsClient.ContainsKey($suggestionKey)) {
                    $suggestions += $suggestion
                    $stats.Suggested++
                }
            }
            
            $processedResourceTypes[$resourceType] = $true
        }
        continue
    }
    
    foreach ($operation in $operations) {
        $key = "$resourceType|$($operation.OperationName)"
        
        # Vérifier si opération exclue par le client
        if ($excludedActivityLogsClient.ContainsKey($key)) {
            Write-Log "    -> Opération exclue par client: $($operation.OperationName) - Raison: $($excludedActivityLogsClient[$key])" -Level Info
            continue
        }
        
        # Vérifier si override client existe
        $config = if ($clientDictHash.ContainsKey($key)) {
            $stats.FromClient++
            $clientDictHash[$key]
        } else {
            $stats.FromGlobal++
            $operation
        }
        
        # Créer une alerte pour Success si configuré
        if ($config.AlertOnSuccess -eq "Yes") {
            $alertName = "$($resource.Name)-$($config.OperationName.Split('/')[-1])-Success"
            
            $matrixEntry = [PSCustomObject]@{
                alertName = $alertName
                alertDescription = "$($config.Description) - Success"
                severity = $config.Severity
                enabled = "true"
                category = $config.Category
                operationName = $config.OperationName
                status = "Succeeded"
                targetResourceType = $resourceType
                targetResourceName = $resource.Name
                resourceGroup = $resource.ResourceGroupName
                resourceId = $resource.ResourceId
                subscriptionId = $resource.SubscriptionId
                friendlyName = $config.FriendlyName
            }
            
            $matrix += $matrixEntry
            $stats.Total++
        }
        
        # Créer une alerte pour Failure si configuré
        if ($config.AlertOnFailure -eq "Yes") {
            $alertName = "$($resource.Name)-$($config.OperationName.Split('/')[-1])-Failure"
            
            $matrixEntry = [PSCustomObject]@{
                alertName = $alertName
                alertDescription = "$($config.Description) - Failure"
                severity = "0"  # Toujours critique pour les échecs
                enabled = "true"
                category = $config.Category
                operationName = $config.OperationName
                status = "Failed"
                targetResourceType = $resourceType
                targetResourceName = $resource.Name
                resourceGroup = $resource.ResourceGroupName
                resourceId = $resource.ResourceId
                subscriptionId = $resource.SubscriptionId
                friendlyName = $config.FriendlyName
            }
            
            $matrix += $matrixEntry
            $stats.Total++
        }
    }
}

# Sauvegarder la matrice
$matrixFile = Join-Path $matricesPath "activitylogs-matrix_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$matrixDir = Split-Path $matrixFile -Parent
if (-not (Test-Path $matrixDir)) {
    New-Item -ItemType Directory -Path $matrixDir -Force | Out-Null
}

$matrix | Export-Csv -Path $matrixFile -NoTypeInformation -Encoding UTF8
Write-Log "Matrice Activity Logs sauvegardée: $matrixFile" -Level Success

# Sauvegarder les suggestions
if ($suggestions.Count -gt 0) {
    $suggestionsFile = Join-Path $dictionariesPath "suggestions-activitylogs.csv"
    $suggestions | Export-Csv -Path $suggestionsFile -NoTypeInformation -Encoding UTF8
    Write-Log "Suggestions Activity Logs sauvegardées: $suggestionsFile" -Level Success
    Write-Log "  -> $($suggestions.Count) suggestions pour $($processedResourceTypes.Count) types de ressources" -Level Info
} else {
    Write-Log "Aucune suggestion Activity Logs à sauvegarder" -Level Info
}

# Résumé
Write-Log "`n=== RÉSUMÉ ===" -Level Info
Write-Log "Ressources traitées: $($allResources.Count)" -Level Info
Write-Log "Types de ressources configurés: $(($globalDict | Select-Object -Property ResourceType -Unique).Count)" -Level Info
Write-Log "Alertes Activity Logs générées: $($stats.Total)" -Level Success
Write-Log "  - Depuis dictionnaire client: $($stats.FromClient)" -Level Info
Write-Log "  - Depuis dictionnaire global: $($stats.FromGlobal)" -Level Info
Write-Log "Suggestions générées: $($stats.Suggested)" -Level Info

Write-Log "`n✅ Génération terminée avec succès" -Level Success
