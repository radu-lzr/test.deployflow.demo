<#
.SYNOPSIS
    Génère la matrice des Diagnostic Settings pour toutes les ressources Azure

.DESCRIPTION
    Ce script génère une matrice CSV des Diagnostic Settings à déployer pour chaque ressource.
    Utilise un système de fallback à 3 niveaux:
    1. Dictionnaire client (overrides par environnement)
    2. Dictionnaire global (bonnes pratiques)
    3. Discovery PowerShell (Get-AzDiagnosticSettingCategory)
    
    Génère également un fichier de suggestions pour les catégories découvertes non configurées.

.PARAMETER ClientName
    Nom du client (ex: Squadra)

.PARAMETER Environment
    Environnement (ex: Dev, Prod, PPRD)

.EXAMPLE
    .\Generate-DiagnosticSettingsMatrix-DevOps.ps1 -ClientName "Squadra" -Environment "Dev"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ClientName,
    
    [Parameter(Mandatory=$true)]
    [string]$Environment
)

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
    
    if (Test-Path $script:logFile) {
        Add-Content -Path $script:logFile -Value $logMessage
    }
}

# Chemins
$repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$clientPath = Join-Path $repoRoot "DevOps\Clients\$ClientName"
$configPath = Join-Path $clientPath "Config\$Environment"
$dictionariesPath = Join-Path $clientPath "Dictionaries\$Environment"
$matricesPath = Join-Path $clientPath "Matrices\$Environment"
$logsPath = Join-Path $clientPath "Logs\$Environment"
$excludeResourcesPath = Join-Path $repoRoot "DevOps\Config\exclude-resources.json"
$excludeDiagsettingsPath = Join-Path $repoRoot "DevOps\Config\exclude-diagsettings.json"

# Créer dossiers si nécessaire
@($dictionariesPath, $matricesPath, $logsPath) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

$script:logFile = Join-Path $logsPath "diagsettings-generation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:suggestionsPath = Join-Path $dictionariesPath "suggestions-diagsettings.csv"

Write-Log "=== Génération matrice Diagnostic Settings === $ClientName ===" -Level Info
Write-Log "Environnement: $Environment" -Level Info

# Charger les exclusions ressources
$excludedResources = @()
if (Test-Path $excludeResourcesPath) {
    $excludedResourcesJson = Get-Content -Path $excludeResourcesPath -Raw | ConvertFrom-Json
    $excludedResources = $excludedResourcesJson | ForEach-Object { $_.resource }
    Write-Log "Exclusions ressources chargées: $($excludedResources.Count) types" -Level Info
}

# Charger les exclusions diagnostic settings globales (catégories)
$excludedDiagsettings = @()
if (Test-Path $excludeDiagsettingsPath) {
    $excludedDiagsettingsJson = Get-Content -Path $excludeDiagsettingsPath -Raw | ConvertFrom-Json
    $excludedDiagsettings = $excludedDiagsettingsJson
    Write-Log "Exclusions diagnostic settings globales chargées: $($excludedDiagsettings.Count) règles" -Level Info
}

# Charger les exclusions diagnostic settings client (filtrer matrices ET suggestions)
$excludeDiagsettingsClientPath = Join-Path $dictionariesPath "exclude-diagsettings-$($ClientName.ToLower())-$($Environment.ToLower()).csv"
$excludedDiagsettingsClient = @{}
if (Test-Path $excludeDiagsettingsClientPath) {
    $excludedDiagsettingsClientArray = Import-Csv -Path $excludeDiagsettingsClientPath
    foreach ($entry in $excludedDiagsettingsClientArray) {
        $key = "$($entry.ResourceType)|$($entry.LogCategory)|$($entry.MetricCategory)"
        $excludedDiagsettingsClient[$key] = $entry.Reason
    }
    Write-Log "Exclusions diagnostic settings client chargées: $($excludedDiagsettingsClientArray.Count) catégories" -Level Info
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

# Charger la configuration
$configFile = Join-Path $configPath "environment-config.json"
if (-not (Test-Path $configFile)) {
    Write-Log "Fichier de configuration introuvable: $configFile" -Level Error
    Write-Log "Veuillez exécuter la Pipeline 2 (Discover Subscriptions) d'abord." -Level Error
    exit 1
}

$config = Get-Content $configFile | ConvertFrom-Json

if ($config.subscriptions.Count -eq 0) {
    Write-Log "Aucune subscription configurée dans $configFile" -Level Error
    Write-Log "Veuillez exécuter la Pipeline 2 (Discover Subscriptions) d'abord." -Level Error
    exit 1
}

# Connexion Azure
Write-Log "Connexion à Azure..." -Level Info
Set-AzContext -TenantId $config.tenantId | Out-Null

# Charger les dictionnaires
$globalDictPath = Join-Path $repoRoot "DevOps\Dictionaries\Global\diagnostic-settings-dictionary.csv"
$clientDictPath = Join-Path $dictionariesPath "diagnostic-settings-overrides.csv"

Write-Log "Chargement des dictionnaires..." -Level Info

# Dictionnaire global
if (-not (Test-Path $globalDictPath)) {
    Write-Log "Dictionnaire global introuvable: $globalDictPath" -Level Error
    exit 1
}

$globalDictArray = Import-Csv -Path $globalDictPath
$globalDict = @{}
foreach ($entry in $globalDictArray) {
    $key = "$($entry.ResourceType)|$($entry.LogCategory)|$($entry.MetricCategory)"
    if (-not $globalDict.ContainsKey($key)) {
        $globalDict[$key] = @()
    }
    $globalDict[$key] += $entry
}
Write-Log "  -> Dictionnaire global: $($globalDictArray.Count) catégories" -Level Success

# Dictionnaire client
$clientDict = @{}
if (Test-Path $clientDictPath) {
    $clientDictArray = Import-Csv -Path $clientDictPath
    foreach ($entry in $clientDictArray) {
        # Supporter les overrides par ressource spécifique (colonne ResourceName optionnelle)
        if ($entry.PSObject.Properties.Name -contains 'ResourceName' -and ![string]::IsNullOrWhiteSpace($entry.ResourceName)) {
            # Override spécifique à une ressource
            $key = "$($entry.ResourceType)|$($entry.ResourceName)|$($entry.LogCategory)|$($entry.MetricCategory)"
        } else {
            # Override générique pour tout le type de ressource
            $key = "$($entry.ResourceType)|$($entry.LogCategory)|$($entry.MetricCategory)"
        }
        
        if (-not $clientDict.ContainsKey($key)) {
            $clientDict[$key] = @()
        }
        $clientDict[$key] += $entry
    }
    Write-Log "  -> Dictionnaire client: $($clientDictArray.Count) surcharges" -Level Success
} else {
    Write-Log "  -> Aucun dictionnaire client (utilisation global uniquement)" -Level Info
}

# Récupérer toutes les ressources
Write-Log "Récupération des ressources Azure..." -Level Info
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

# Statistiques
$stats = @{
    FromClient = 0
    FromGlobal = 0
    Discovered = 0
}

$matrix = @()
$suggestions = @()
$processedResourceTypes = @{}

# Générer la matrice
Write-Log "`nGénération de la matrice Diagnostic Settings..." -Level Info

foreach ($resource in $allResources) {
    $resourceType = $resource.ResourceType.ToLower()
    $resourceName = $resource.Name
    
    if (-not $processedResourceTypes.ContainsKey($resourceType)) {
        $processedResourceTypes[$resourceType] = $true
        Write-Log "  Type: $resourceType" -Level Info
    }
    
    # Vérifier si le type de ressource entier est exclu (exclusion globale avec catégories vides)
    $resourceTypeExclusionKey = "$resourceType||"
    if ($excludedDiagsettingsClient.ContainsKey($resourceTypeExclusionKey)) {
        Write-Log "    -> Type de ressource entièrement exclu: $resourceType - Raison: $($excludedDiagsettingsClient[$resourceTypeExclusionKey])" -Level Info
        $stats.Skipped++
        continue
    }
    
    # Chercher les configurations pour CETTE ressource spécifique
    # Priorité 1: Override spécifique à la ressource
    $specificClientConfigs = $clientDict.Keys | Where-Object { $_ -like "$resourceType|$resourceName|*" }
    # Priorité 2: Override générique au type
    $genericClientConfigs = $clientDict.Keys | Where-Object { $_ -like "$resourceType|*" -and $_ -notlike "$resourceType|$resourceName|*" -and ($_.Split('|').Count -eq 3) }
    # Priorité 3: Global
    $globalConfigs = $globalDict.Keys | Where-Object { $_ -like "$resourceType|*" }
    
    $configsFound = $false
    
    # Niveau 1: Client overrides spécifiques à la ressource (priorité maximale)
    if ($specificClientConfigs) {
        foreach ($key in $specificClientConfigs) {
            foreach ($config in $clientDict[$key]) {
                # Les overrides spécifiques à une ressource ont la priorité absolue
                # et ne sont PAS filtrés par les exclusions globales
                
                $stats.FromClient++
                $configsFound = $true
                
                $matrixEntry = [PSCustomObject]@{
                    resourceId = $resource.ResourceId
                    resourceName = $resource.Name
                    resourceType = $resourceType
                    resourceGroup = $resource.ResourceGroupName
                    subscriptionId = $resource.SubscriptionId
                    location = $resource.Location
                    logCategory = $config.LogCategory
                    metricCategory = $config.MetricCategory
                    enabled = $config.Enabled
                    retentionDays = $config.RetentionDays
                    friendlyName = $config.FriendlyName
                    _Source = "Client-Specific"
                }
                $matrix += $matrixEntry
            }
        }
    }
    # Niveau 2: Client overrides génériques au type
    elseif ($genericClientConfigs) {
        foreach ($key in $genericClientConfigs) {
            foreach ($config in $clientDict[$key]) {
                # Vérifier si catégorie exclue par le client
                $categoryKey = "$resourceType|$($config.LogCategory)|$($config.MetricCategory)"
                if ($excludedDiagsettingsClient.ContainsKey($categoryKey)) {
                    Write-Log "    -> Catégorie exclue par client: $($config.LogCategory)$($config.MetricCategory) - Raison: $($excludedDiagsettingsClient[$categoryKey])" -Level Info
                    continue
                }
                
                $stats.FromClient++
                $configsFound = $true
                
                $matrixEntry = [PSCustomObject]@{
                    resourceId = $resource.ResourceId
                    resourceName = $resource.Name
                    resourceType = $resourceType
                    resourceGroup = $resource.ResourceGroupName
                    subscriptionId = $resource.SubscriptionId
                    location = $resource.Location
                    logCategory = $config.LogCategory
                    metricCategory = $config.MetricCategory
                    enabled = $config.Enabled
                    retentionDays = $config.RetentionDays
                    friendlyName = $config.FriendlyName
                    _Source = "Client"
                }
                $matrix += $matrixEntry
            }
        }
    }
    # Niveau 3: Global (si pas trouvé dans client)
    else {
        if ($globalConfigs) {
            foreach ($key in $globalConfigs) {
                foreach ($config in $globalDict[$key]) {
                    # Vérifier si catégorie exclue par le client
                    $categoryKey = "$resourceType|$($config.LogCategory)|$($config.MetricCategory)"
                    if ($excludedDiagsettingsClient.ContainsKey($categoryKey)) {
                        Write-Log "    -> Catégorie exclue par client: $($config.LogCategory)$($config.MetricCategory) - Raison: $($excludedDiagsettingsClient[$categoryKey])" -Level Info
                        continue
                    }
                    
                    $stats.FromGlobal++
                    $configsFound = $true
                    
                    $matrixEntry = [PSCustomObject]@{
                        resourceId = $resource.ResourceId
                        resourceName = $resource.Name
                        resourceType = $resourceType
                        resourceGroup = $resource.ResourceGroupName
                        subscriptionId = $resource.SubscriptionId
                        location = $resource.Location
                        logCategory = $config.LogCategory
                        metricCategory = $config.MetricCategory
                        enabled = $config.Enabled
                        retentionDays = $config.RetentionDays
                        friendlyName = $config.FriendlyName
                        _Source = "Global"
                    }
                    $matrix += $matrixEntry
                }
            }
        }
    }
    
    # Niveau 4: Discovery (si pas trouvé dans dictionnaires)
    if (-not $configsFound) {
        Write-Log "    -> Non configuré, discovery des catégories..." -Level Warning
        
        # Prendre la première ressource de ce type pour discovery
        $sampleResource = $allResources | Where-Object { $_.ResourceType.ToLower() -eq $resourceType } | Select-Object -First 1
        
        if ($sampleResource) {
            try {
                $categories = Get-AzDiagnosticSettingCategory -ResourceId $sampleResource.ResourceId -ErrorAction Stop -WarningAction SilentlyContinue
                
                if ($categories) {
                    Write-Log "    -> $($categories.Count) catégories découvertes" -Level Info
                    
                    foreach ($category in $categories) {
                        $stats.Discovered++
                        
                        # Vérifier si catégorie est exclue
                        $isExcluded = $false
                        foreach ($exclusion in $excludedDiagsettings) {
                            $matchResourceType = ($exclusion.resourceType -eq "*") -or ($exclusion.resourceType -eq $resourceType)
                            $matchCategory = ($exclusion.category -eq $category.Name)
                            
                            if ($matchResourceType -and $matchCategory) {
                                Write-Log "      -> Catégorie exclue: $($category.Name) (raison: $($exclusion.reason))" -Level Info
                                $isExcluded = $true
                                break
                            }
                        }
                        
                        if (-not $isExcluded) {
                            # Créer suggestion
                            $suggestion = [PSCustomObject]@{
                                ResourceType = $resourceType
                                LogCategory = if ($category.CategoryType -eq "Logs") { $category.Name } else { "" }
                                MetricCategory = if ($category.CategoryType -eq "Metrics") { $category.Name } else { "" }
                                Enabled = "Yes"
                                RetentionDays = "30"
                                FriendlyName = $resourceType.Split('/')[-1]
                                _DateDiscovered = (Get-Date -Format 'yyyy-MM-dd')
                            }
                        
                            # Vérifier si déjà dans suggestions ET si pas dans exclusions client
                            $existingKey = "$($suggestion.ResourceType)|$($suggestion.LogCategory)|$($suggestion.MetricCategory)"
                            if (-not ($suggestions | Where-Object { "$($_.ResourceType)|$($_.LogCategory)|$($_.MetricCategory)" -eq $existingKey }) -and
                                -not $excludedDiagsettingsClient.ContainsKey($existingKey)) {
                                $suggestions += $suggestion
                            }
                        }
                    }
                }
            } catch {
                Write-Log "    ⚠ Impossible de récupérer les catégories: $_" -Level Warning
            }
        }
    }
}

# Sauvegarder la matrice
$matrixFile = Join-Path $matricesPath "diagsettings-matrix_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$matrix | Export-Csv -Path $matrixFile -NoTypeInformation -Encoding UTF8
Write-Log "Matrice sauvegardée: $matrixFile" -Level Success

# Sauvegarder les suggestions (écraser le fichier)
if ($suggestions.Count -gt 0) {
    $suggestionsDir = Split-Path $script:suggestionsPath -Parent
    if (-not (Test-Path $suggestionsDir)) {
        New-Item -ItemType Directory -Path $suggestionsDir -Force | Out-Null
    }
    $suggestions | Export-Csv -Path $script:suggestionsPath -NoTypeInformation -Encoding UTF8
    Write-Log "Suggestions sauvegardées: $script:suggestionsPath ($($suggestions.Count) suggestions)" -Level Warning
} elseif (Test-Path $script:suggestionsPath) {
    # Supprimer le fichier s'il n'y a plus de suggestions
    Remove-Item -Path $script:suggestionsPath -Force
    Write-Log "Fichier suggestions supprimé (aucune nouvelle suggestion)" -Level Info
}

# Résumé
Write-Log "`n=== RÉSUMÉ ===" -Level Info
Write-Log "Ressources traitées: $($allResources.Count)" -Level Info
Write-Log "Types de ressources: $($processedResourceTypes.Count)" -Level Info
Write-Log "Configurations Diagnostic Settings générées: $($matrix.Count)" -Level Success
Write-Log "  - Depuis dictionnaire client: $($stats.FromClient)" -Level Info
Write-Log "  - Depuis dictionnaire global: $($stats.FromGlobal)" -Level Info
Write-Log "Catégories découvertes: $($stats.Discovered)" -Level Warning
Write-Log "  - Nouvelles suggestions: $($suggestions.Count)" -Level Warning

if ($suggestions.Count -gt 0) {
    Write-Log "`n⚠️  ATTENTION: $($suggestions.Count) nouvelles suggestions créées" -Level Warning
    Write-Log "Fichier: $script:suggestionsPath" -Level Info
    Write-Log "`nActions recommandées:" -Level Info
    Write-Log "1. Consulter suggestions-diagsettings.csv" -Level Info
    Write-Log "2. Valider les catégories à activer" -Level Info
    Write-Log "3. Ajouter à diagnostic-settings-overrides.csv (client) ou diagnostic-settings-dictionary.csv (global)" -Level Info
}

Write-Log "`n✅ Génération terminée avec succès" -Level Success
