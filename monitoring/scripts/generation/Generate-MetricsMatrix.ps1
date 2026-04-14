<#
.SYNOPSIS
    Génère la matrice de métriques avec fallback 3 niveaux (Client -> Global -> Discovery)

.DESCRIPTION
    Version améliorée du générateur de matrice de métriques avec:
    - Fallback 3 niveaux: Client -> Global -> Discovery PowerShell
    - Génération automatique de suggestions pour métriques non trouvées
    - Détection des changements par rapport à la matrice précédente
    - Logs détaillés et statistiques

.PARAMETER ClientName
    Nom du client

.PARAMETER Environment
    Environnement (dev, test, prod, etc.)

.EXAMPLE
    .\Generate-MetricsMatrix-DevOps-v2.ps1 -ClientName "Squadra" -Environment "Dev"
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
    $logFile = Join-Path $clientPath "Logs\metrics-generation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $matricesPath = Join-Path $clientPath "Matrices"
    $dictionariesPath = Join-Path $clientPath "Dictionaries"
    $suggestionsPath = Join-Path $clientPath "Dictionaries\suggestions-metrics.csv"
} else {
    $configPath = Join-Path $clientPath "Config\$Environment\environment-config.json"
    $logFile = Join-Path $clientPath "Logs\$Environment\metrics-generation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $matricesPath = Join-Path $clientPath "Matrices\$Environment"
    $dictionariesPath = Join-Path $clientPath "Dictionaries\$Environment"
    $suggestionsPath = Join-Path $clientPath "Dictionaries\$Environment\suggestions-metrics.csv"
}

# Chemins
$excludeResourcesPath = Join-Path $repoRoot "DevOps\Config\exclude-resources.json"
$excludeMetricsPath = Join-Path $repoRoot "DevOps\Config\exclude-metrics.json"

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

function Get-MetricConfiguration {
    param(
        [string]$ResourceType,
        [string]$MetricName,
        [string]$ResourceName = "",
        [hashtable]$ClientDict,
        [hashtable]$GlobalDict
    )
    
    # Clés de recherche : d'abord ressource spécifique, puis type générique
    $specificKey = "$ResourceType|$ResourceName|$MetricName"
    $genericKey = "$ResourceType|$MetricName"
    
    # Récupérer les configs du global (baseline)
    $globalConfigs = @()
    if ($GlobalDict.ContainsKey($genericKey)) {
        foreach ($entry in $GlobalDict[$genericKey]) {
            $config = $entry.PSObject.Copy()
            $config | Add-Member -MemberType NoteProperty -Name "_Source" -Value "Global" -Force
            $globalConfigs += $config
        }
    }
    
    # Chercher les overrides client : d'abord spécifique à la ressource, puis générique au type
    $clientOverrides = @()
    if ($ClientDict.ContainsKey($specificKey)) {
        $clientOverrides = $ClientDict[$specificKey]
        Write-Verbose "Override spécifique trouvé pour ressource $ResourceName"
    } elseif ($ClientDict.ContainsKey($genericKey)) {
        $clientOverrides = $ClientDict[$genericKey]
        Write-Verbose "Override générique trouvé pour type $ResourceType"
    }
    
    # Si pas de client overrides, retourner le global tel quel
    if ($clientOverrides.Count -eq 0) {
        if ($globalConfigs.Count -gt 0) {
            return $globalConfigs
        }
        return $null
    }
    
    # Merger client overrides avec global
    $finalConfigs = @()
    $overriddenSeverities = @{}
    
    # D'abord, traiter les overrides client
    foreach ($clientEntry in $clientOverrides) {
        $severity = $clientEntry.Severity
        $overriddenSeverities[$severity] = $true
        
        # Trouver la config global correspondante pour cette sévérité
        $globalMatch = $globalConfigs | Where-Object { $_.Severity -eq $severity } | Select-Object -First 1
        
        if ($globalMatch) {
            # Merger: prendre les valeurs du client, compléter avec le global
            $merged = $globalMatch.PSObject.Copy()
            
            # Remplacer uniquement les propriétés non-vides du client
            foreach ($prop in $clientEntry.PSObject.Properties) {
                if ($prop.Name -ne 'Severity' -and ![string]::IsNullOrWhiteSpace($prop.Value)) {
                    if ($merged.PSObject.Properties.Name -contains $prop.Name) {
                        $merged.$($prop.Name) = $prop.Value
                    } else {
                        $merged | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
                    }
                }
            }
            
            $merged._Source = "Client"
            $finalConfigs += $merged
        } else {
            # Pas de global pour cette sévérité, utiliser le client tel quel
            $config = $clientEntry.PSObject.Copy()
            $config | Add-Member -MemberType NoteProperty -Name "_Source" -Value "Client" -Force
            $finalConfigs += $config
        }
    }
    
    # Ajouter les sévérités du global qui n'ont PAS été overridées
    foreach ($globalEntry in $globalConfigs) {
        if (-not $overriddenSeverities.ContainsKey($globalEntry.Severity)) {
            $finalConfigs += $globalEntry
        }
    }
    
    return $finalConfigs
}

function Add-ToSuggestions {
    param(
        [PSCustomObject]$MetricConfig,
        [hashtable]$ExcludedMetrics
    )
    
    # Vérifier si la métrique est dans la blacklist
    $key = "$($MetricConfig.ResourceType)|$($MetricConfig.AlertMetricName)"
    if ($ExcludedMetrics.ContainsKey($key)) {
        Write-Log "    -> Métrique exclue (blacklist): $($MetricConfig.AlertMetricName) - Raison: $($ExcludedMetrics[$key])" -Level Info
        return
    }
    
    # Ajouter au tableau global de suggestions
    $script:allSuggestions += $MetricConfig
    return $true
}

# ============================================================================
# MAIN
# ============================================================================

Write-Log "=== Génération matrice de métriques - $ClientName ===" -Level Info

if (-not (Test-Path $configPath)) {
    Write-Log "Configuration introuvable: $configPath" -Level Error
    exit 1
}

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

Write-Log "Connexion à Azure..." -Level Info
Set-AzContext -TenantId $config.tenantId | Out-Null

# Charger les dictionnaires
$globalDictPath = Join-Path $repoRoot "DevOps\Dictionaries\Global\metrics-dictionary.csv"
$clientDictPath = Join-Path $dictionariesPath "metrics-overrides.csv"

Write-Log "Chargement des dictionnaires..." -Level Info

# Dictionnaire global
if (-not (Test-Path $globalDictPath)) {
    Write-Log "Dictionnaire global introuvable: $globalDictPath" -Level Error
    exit 1
}

$globalDictArray = Import-Csv -Path $globalDictPath
$globalDict = @{}
foreach ($entry in $globalDictArray) {
    $key = "$($entry.ResourceType)|$($entry.AlertMetricName)"
    if (-not $globalDict.ContainsKey($key)) {
        $globalDict[$key] = @()
    }
    $globalDict[$key] += $entry  # Ajouter TOUTES les sévérités
}
Write-Log "  -> Dictionnaire global: $($globalDictArray.Count) entrées ($(($globalDict.Keys).Count) métriques uniques)" -Level Success

# Dictionnaire client
$clientDict = @{}
if (Test-Path $clientDictPath) {
    $clientDictArray = Import-Csv -Path $clientDictPath
    foreach ($entry in $clientDictArray) {
        # Supporter les overrides par ressource spécifique (colonne ResourceName optionnelle)
        if ($entry.PSObject.Properties.Name -contains 'ResourceName' -and ![string]::IsNullOrWhiteSpace($entry.ResourceName)) {
            # Override spécifique à une ressource
            $key = "$($entry.ResourceType)|$($entry.ResourceName)|$($entry.AlertMetricName)"
        } else {
            # Override générique pour tout le type de ressource
            $key = "$($entry.ResourceType)|$($entry.AlertMetricName)"
        }
        
        if (-not $clientDict.ContainsKey($key)) {
            $clientDict[$key] = @()
        }
        $clientDict[$key] += $entry  # Ajouter TOUTES les sévérités
    }
    Write-Log "  -> Dictionnaire client: $($clientDictArray.Count) surcharges" -Level Success
} else {
    Write-Log "  -> Aucun dictionnaire client (utilisation global uniquement)" -Level Info
}

# Charger les exclusions de ressources
$excludedResources = @()
if (Test-Path $excludeResourcesPath) {
    $excludedResourcesJson = Get-Content -Path $excludeResourcesPath -Raw | ConvertFrom-Json
    $excludedResources = $excludedResourcesJson | ForEach-Object { $_.resource }
    Write-Log "  -> $($excludedResources.Count) types de ressources exclus" -Level Info
} else {
    Write-Log "  -> Aucune exclusion de ressource configurée" -Level Info
}

# Charger les exclusions métriques globales
$excludeMetricsPath = Join-Path $repoRoot "DevOps\Config\exclude-metrics.json"
$excludedMetrics = @{}
if (Test-Path $excludeMetricsPath) {
    $excludeMetricsJson = Get-Content -Path $excludeMetricsPath -Raw | ConvertFrom-Json
    foreach ($entry in $excludeMetricsJson) {
        $key = "$($entry.resourceType)|$($entry.metricName)"
        $excludedMetrics[$key] = $entry.reason
    }
    Write-Log "Exclusions métriques globales chargées: $($excludedMetrics.Count) métriques" -Level Info
}

# Charger les exclusions métriques client (filtrer matrices ET suggestions)
$excludeMetricsClientPath = Join-Path $dictionariesPath "exclude-metrics-$($ClientName.ToLower())-$($Environment.ToLower()).csv"
$excludedMetricsClient = @{}
if (Test-Path $excludeMetricsClientPath) {
    $excludedMetricsClientArray = Import-Csv -Path $excludeMetricsClientPath
    foreach ($entry in $excludedMetricsClientArray) {
        # Supporter exclusions spécifiques (avec ResourceName) ET génériques (sans ResourceName)
        if (![string]::IsNullOrWhiteSpace($entry.ResourceName)) {
            # Exclusion spécifique à une ressource
            $key = "$($entry.ResourceType)|$($entry.ResourceName)|$($entry.MetricName)"
        } else {
            # Exclusion générique pour tout le type de ressource
            $key = "$($entry.ResourceType)||$($entry.MetricName)"
        }
        $excludedMetricsClient[$key] = $entry.Reason
    }
    Write-Log "Exclusions métriques client chargées: $($excludedMetricsClientArray.Count) métriques" -Level Info
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

# Générer la matrice
Write-Log "Génération de la matrice..." -Level Info

$matrix = @()
$stats = @{
    FromClient = 0
    FromGlobal = 0
    Discovered = 0
    Skipped = 0
}
$processedResourceTypes = @{}  # Pour tracker les suggestions (une fois par type)
$metricsCache = @{}  # Cache des métriques disponibles par type
$newSuggestions = 0
$allSuggestions = @()

$resourceCount = 0
foreach ($resource in $allResources) {
    $resourceCount++
    $resourceType = $resource.ResourceType.ToLower()
    
    # Ignorer les bases master SQL
    if ($resource.ResourceType -eq "microsoft.sql/servers/databases" -and $resource.Name -like "*/master") {
        $stats.Skipped++
        continue
    }
    
    Write-Log "  [$resourceCount/$($allResources.Count)] Ressource: $($resource.Name) ($resourceType)" -Level Info
    
    # Récupérer les métriques disponibles (avec cache par type)
    if (-not $metricsCache.ContainsKey($resourceType)) {
        try {
            $availableMetrics = Get-AzMetricDefinition -ResourceId $resource.ResourceId -ErrorAction Stop -WarningAction SilentlyContinue
            
            if (-not $availableMetrics -or $availableMetrics.Count -eq 0) {
                Write-Log "    -> Aucune métrique disponible pour ce type" -Level Warning
                $metricsCache[$resourceType] = @()
                $stats.Skipped++
                continue
            }
            
            $metricsCache[$resourceType] = $availableMetrics
            Write-Log "    -> $($availableMetrics.Count) métriques disponibles pour ce type" -Level Info
        } catch {
            Write-Log "    -> Erreur récupération métriques: $_" -Level Warning
            $metricsCache[$resourceType] = @()
            $stats.Skipped++
            continue
        }
    } else {
        $availableMetrics = $metricsCache[$resourceType]
        if ($availableMetrics.Count -eq 0) {
            $stats.Skipped++
            continue
        }
    }
    
    # Générer les alertes pour CETTE ressource
    $alertsForResource = 0
    
    # Détecter le SKU pour Service Bus (pour filtrer les métriques Premium uniquement)
    $serviceBusSku = $null
    if ($resourceType -eq "microsoft.servicebus/namespaces") {
        try {
            # Méthode 1: Get-AzServiceBusNamespace
            $serviceBusNamespace = Get-AzServiceBusNamespace -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name -ErrorAction SilentlyContinue
            if ($serviceBusNamespace -and $serviceBusNamespace.Sku -and $serviceBusNamespace.Sku.Name) {
                $serviceBusSku = $serviceBusNamespace.Sku.Name
                Write-Log "    -> Service Bus SKU détecté (Get-AzServiceBusNamespace): $serviceBusSku" -Level Info
            } else {
                # Méthode 2: Get-AzResource (fallback)
                $serviceBusResource = Get-AzResource -ResourceId $resource.ResourceId -ErrorAction SilentlyContinue
                if ($serviceBusResource -and $serviceBusResource.Sku -and $serviceBusResource.Sku.Name) {
                    $serviceBusSku = $serviceBusResource.Sku.Name
                    Write-Log "    -> Service Bus SKU détecté (Get-AzResource): $serviceBusSku" -Level Info
                } else {
                    Write-Log "    -> Impossible de détecter le SKU Service Bus pour $($resource.Name)" -Level Warning
                }
            }
        } catch {
            Write-Log "    -> Erreur lors de la récupération du SKU Service Bus: $_" -Level Warning
        }
    }
    
    # Créer une liste de toutes les métriques à traiter
    # 1. Métriques découvertes via API
    $metricsToProcess = @{}
    foreach ($metric in $availableMetrics) {
        $metricsToProcess[$metric.Name.Value] = $true
    }
    
    # 2. Ajouter les métriques du dictionnaire global qui ne sont pas dans l'API
    #    Cela permet de supporter les métriques spéciales (ex: NamespaceCpuUsage avec dimension Replica)
    $globalMetricsForType = $globalDict.Keys | Where-Object { $_ -like "$resourceType|*" }
    foreach ($key in $globalMetricsForType) {
        $metricName = $key.Split('|')[1]
        
        # Filtrer les métriques Premium pour Service Bus Standard/Basic
        if ($resourceType -eq "microsoft.servicebus/namespaces" -and 
            ($metricName -eq "NamespaceCpuUsage" -or $metricName -eq "NamespaceMemoryUsage") -and 
            ($serviceBusSku -eq "Standard" -or $serviceBusSku -eq "Basic")) {
            Write-Log "    -> Métrique $metricName ignorée (disponible uniquement sur Service Bus Premium, SKU actuel: $serviceBusSku)" -Level Info
            continue
        }
        
        if (-not $metricsToProcess.ContainsKey($metricName)) {
            $metricsToProcess[$metricName] = $true
            Write-Log "    -> Métrique du dictionnaire global ajoutée: $metricName (non découverte via API)" -Level Info
        }
    }
    
    # Traiter toutes les métriques (API + dictionnaire global)
    foreach ($metricName in $metricsToProcess.Keys) {
        # Chercher dans dictionnaires (retourne array de configs pour toutes sévérités)
        $configs = Get-MetricConfiguration -ResourceType $resourceType -MetricName $metricName -ResourceName $resource.Name -ClientDict $clientDict -GlobalDict $globalDict
        
        if ($configs) {
            # Métriques configurées - générer une alerte par sévérité pour CETTE ressource
            foreach ($config in $configs) {
                # Vérifier si métrique exclue par le client (spécifique OU générique)
                $specificKey = "$resourceType|$($resource.Name)|$metricName"
                $genericKey = "$resourceType||$metricName"
                
                if ($excludedMetricsClient.ContainsKey($specificKey)) {
                    Write-Log "    -> Métrique exclue par client: $metricName - Raison: $($excludedMetricsClient[$specificKey])" -Level Info
                    continue
                }
                
                if ($excludedMetricsClient.ContainsKey($genericKey)) {
                    Write-Log "    -> Métrique exclue par client: $metricName - Raison: $($excludedMetricsClient[$genericKey])" -Level Info
                    continue
                }
                
                if ($config._Source -eq "Client") {
                    $stats.FromClient++
                } else {
                    $stats.FromGlobal++
                }
                
                # Ajouter à la matrice pour cette ressource
                $alertName = "$($resource.Name)-$($config.AlertMetricName)-$($config.Severity)"
                
                $matrixEntry = [PSCustomObject]@{
                    metricNamespace = $config.ResourceType
                    targetResourceName = $resource.Name
                    targetResourceTypeFriendlyName = $config.FriendlyName
                    resourceRG = $resource.ResourceGroupName
                    targetResourceType = $config.ResourceType
                    alertDescription = "BySquadra"
                    alertMetricNamespace = $config.ResourceType
                    alertMetricName = $config.AlertMetricName
                    alertSev = $config.Severity
                    alertDimensions = $config.Dimensions
                    alertOperator = $config.AlertOperator
                    alertTimeAggregation = $config.Aggregation
                    evaluationFreq = $config.EvaluationFrequency
                    windowsSize = $config.WindowSize
                    alertThreshold = $config.Threshold
                    alertAutoMitigate = "true"
                    alertState = "true"
                    alertName = $alertName
                    resourceId = $resource.ResourceId
                    subscriptionId = $resource.SubscriptionId
                    location = $resource.Location
                    _Source = $config._Source
                }
                
                $matrix += $matrixEntry
                $alertsForResource++
            }
            
        } elseif (-not $processedResourceTypes.ContainsKey($resourceType)) {
            # Créer suggestion uniquement la première fois qu'on voit ce type
            $stats.Discovered++
            
            $aggregation = if ($metric.PrimaryAggregationType) { 
                $metric.PrimaryAggregationType 
            } else { 
                "Average" 
            }
            
            $suggestionConfig = [PSCustomObject]@{
                ResourceType = $resourceType
                AlertMetricName = $metricName
                Unit = $metric.Unit
                AlertOperator = "GreaterThanOrEqual"
                Aggregation = $aggregation
                Dimensions = ""
                EvaluationFrequency = "PT5M"
                WindowSize = "PT5M"
                AutoMitigate = "Yes"
                Severity = "2"
                Threshold = "80"
                FriendlyName = $resourceType.Split('/')[-1]
                _DateDiscovered = (Get-Date -Format 'yyyy-MM-dd')
            }
            
            # Vérifier exclusions globales ET exclusions client
            if (-not $excludedMetrics.ContainsKey("$($resourceType)|$($metricName)") -and 
                -not $excludedMetricsClient.ContainsKey("$($resourceType)|$($metricName)")) {
                $allSuggestions += $suggestionConfig
                $newSuggestions++
            }
        }
    }
    
    # Marquer ce type comme traité pour les suggestions
    if (-not $processedResourceTypes.ContainsKey($resourceType)) {
        $processedResourceTypes[$resourceType] = $true
    }
    
    Write-Log "    -> $alertsForResource alertes générées pour cette ressource" -Level Success
}

# Sauvegarder la matrice
$matrixFile = Join-Path $matricesPath "metrics-matrix_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$matrixDir = Split-Path $matrixFile -Parent
if (-not (Test-Path $matrixDir)) {
    New-Item -ItemType Directory -Path $matrixDir -Force | Out-Null
}

$matrix | Export-Csv -Path $matrixFile -NoTypeInformation -Encoding UTF8
Write-Log "Matrice sauvegardée: $matrixFile" -Level Success

# Sauvegarder les suggestions (écraser le fichier)
if ($allSuggestions.Count -gt 0) {
    $suggestionsDir = Split-Path $suggestionsPath -Parent
    if (-not (Test-Path $suggestionsDir)) {
        New-Item -ItemType Directory -Path $suggestionsDir -Force | Out-Null
    }
    $allSuggestions | Export-Csv -Path $suggestionsPath -NoTypeInformation -Encoding UTF8
    Write-Log "Suggestions sauvegardées: $suggestionsPath ($($allSuggestions.Count) suggestions)" -Level Warning
} elseif (Test-Path $suggestionsPath) {
    # Supprimer le fichier s'il n'y a plus de suggestions
    Remove-Item -Path $suggestionsPath -Force
    Write-Log "Fichier suggestions supprimé (aucune nouvelle suggestion)" -Level Info
}

# Résumé
Write-Log "`n=== RÉSUMÉ ===" -Level Info
Write-Log "Ressources traitées: $($allResources.Count)" -Level Info
Write-Log "Types de ressources: $($processedResourceTypes.Count)" -Level Info
Write-Log "Alertes générées: $($matrix.Count)" -Level Success
Write-Log "  - Depuis dictionnaire client: $($stats.FromClient)" -Level Info
Write-Log "  - Depuis dictionnaire global: $($stats.FromGlobal)" -Level Info
Write-Log "Métriques découvertes: $($stats.Discovered)" -Level Warning
Write-Log "  - Nouvelles suggestions: $newSuggestions" -Level Warning

if ($newSuggestions -gt 0) {
    Write-Log "`n⚠️  ATTENTION: $newSuggestions nouvelles suggestions créées" -Level Warning
    Write-Log "Fichier: $suggestionsPath" -Level Info
    Write-Log "`nActions recommandées:" -Level Info
    Write-Log "1. Consulter suggestions-metrics.csv" -Level Info
    Write-Log "2. Définir les thresholds (remplacer 'XX')" -Level Info
    Write-Log "3. Ajouter à metrics-overrides.csv (client) ou metrics-dictionary.csv (global)" -Level Info
}

Write-Log "`n✅ Génération terminée avec succès" -Level Success
