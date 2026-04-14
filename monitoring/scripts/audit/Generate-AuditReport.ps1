# Generate-AuditReport.ps1
# Script pour generer un audit des ressources Azure et creer le fichier audit.csv

param(
    [Parameter(Mandatory=$true)]
    [string]$ClientName,
    
    [Parameter(Mandatory=$true)]
    [string]$Environment
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "AUDIT DES RESSOURCES AZURE - $ClientName" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Chemins
$clientPath = "$PSScriptRoot/../../Clients/$ClientName"
$envConfigPath = "$clientPath/Config/$Environment/environment-config.json"
$auditOutputPath = "$clientPath/Config/$Environment/audit.csv"
$auditFullOutputPath = "$clientPath/Config/$Environment/audit-full.csv"

# Verifier que la configuration existe
if (-not (Test-Path $envConfigPath)) {
    Write-Host "ERROR: Configuration introuvable: $envConfigPath" -ForegroundColor Red
    exit 1
}

# Charger la configuration
Write-Host "`nChargement de la configuration..." -ForegroundColor Yellow
$envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json

# Recuperer les subscriptions a auditer
$subscriptions = $envConfig.subscriptions
if (-not $subscriptions -or $subscriptions.Count -eq 0) {
    Write-Host "`nERROR: Aucune subscription trouvee dans la configuration" -ForegroundColor Red
    Write-Host "`nPREREQUIS MANQUANT:" -ForegroundColor Yellow
    Write-Host "  Vous devez d'abord executer la Pipeline 2: Discover-Subscriptions" -ForegroundColor White
    Write-Host "  Cette pipeline decouvre les subscriptions et met a jour environment-config.json" -ForegroundColor White
    Write-Host "`nETAPES A SUIVRE:" -ForegroundColor Cyan
    Write-Host "  1. Executer Pipeline: Discover-Subscriptions" -ForegroundColor White
    Write-Host "     - clientName: $ClientName" -ForegroundColor Gray
    Write-Host "     - environment: $Environment" -ForegroundColor Gray
    Write-Host "  2. Verifier que subscriptions.csv est cree" -ForegroundColor White
    Write-Host "  3. Relancer cette pipeline (Audit)" -ForegroundColor White
    exit 1
}

Write-Host "OK Subscriptions a auditer: $($subscriptions.Count)" -ForegroundColor Green
foreach ($subId in $subscriptions) {
    Write-Host "  - $subId" -ForegroundColor Gray
}

# Initialiser les tableaux de resultats
$auditResults = @()  # Ressources filtrees par type
$auditFullResults = @()  # TOUTES les ressources sans filtre
$diagnosticSettingsResults = @()
$alertsResults = @()
$vmExtensionsResults = @()
$dcrResults = @()
$vmMonitoringResults = @()  # VMs pour vm-monitoring-matrix.csv

# Types de ressources a auditer (liste de base)
$resourceTypesToAudit = @(
    'Microsoft.Compute/virtualMachines',
    'Microsoft.Storage/storageAccounts',
    'Microsoft.Sql/servers',
    'Microsoft.Web/sites',
    'Microsoft.Network/virtualNetworks',
    'Microsoft.Network/networkInterfaces',
    'Microsoft.Network/publicIPAddresses',
    'Microsoft.Network/loadBalancers',
    'Microsoft.Network/applicationGateways',
    'Microsoft.KeyVault/vaults',
    'Microsoft.ContainerService/managedClusters',
    'Microsoft.DBforPostgreSQL/servers',
    'Microsoft.DBforMySQL/servers',
    'Microsoft.Cache/redis',
    'Microsoft.ServiceBus/namespaces',
    'Microsoft.EventHub/namespaces',
    'Microsoft.Logic/workflows',
    'Microsoft.Automation/automationAccounts'
)

Write-Host "`nDebut de l'audit des ressources..." -ForegroundColor Cyan

# Parcourir chaque subscription
foreach ($subId in $subscriptions) {
    Write-Host "`nSubscription: $subId" -ForegroundColor Yellow
    
    try {
        # Selectionner la subscription
        Set-AzContext -SubscriptionId $subId -ErrorAction Stop | Out-Null
        
        # Recuperer toutes les ressources
        Write-Host "  Recuperation des ressources..." -ForegroundColor Gray
        $resources = Get-AzResource -ErrorAction Stop
        
        Write-Host "  OK $($resources.Count) ressources trouvees" -ForegroundColor Green
        
        # Auditer TOUTES les ressources (sans filtre) et les ressources filtrees
        foreach ($resource in $resources) {
            # Creer l'entree d'audit complete (TOUTES les ressources)
            $auditFullEntry = [PSCustomObject]@{
                SubscriptionId = $subId
                ResourceGroup = $resource.ResourceGroupName
                ResourceName = $resource.Name
                ResourceType = $resource.ResourceType
                Location = $resource.Location
                Tags = ($resource.Tags | ConvertTo-Json -Compress -Depth 1)
                ResourceId = $resource.ResourceId
            }
            $auditFullResults += $auditFullEntry
            
            # Verifier si le type de ressource est dans notre liste (pour audit filtre)
            if ($resourceTypesToAudit -contains $resource.ResourceType) {
                $auditResults += $auditFullEntry
            }
        }
        
        Write-Host "  OK Ressources auditees (filtrees): $($auditResults.Count)" -ForegroundColor Green
        Write-Host "  OK Ressources auditees (toutes): $($auditFullResults.Count)" -ForegroundColor Cyan
        
        # Extraire les Diagnostic Settings
        Write-Host "  Extraction des Diagnostic Settings..." -ForegroundColor Gray
        foreach ($resource in $resources) {
            try {
                $diagSettings = Get-AzDiagnosticSetting -ResourceId $resource.ResourceId -ErrorAction SilentlyContinue
                if ($diagSettings) {
                    foreach ($diag in $diagSettings) {
                        $diagEntry = [PSCustomObject]@{
                            SubscriptionId = $subId
                            ResourceId = $resource.ResourceId
                            ResourceName = $resource.Name
                            DiagnosticSettingName = $diag.Name
                            WorkspaceId = $diag.WorkspaceId
                            StorageAccountId = $diag.StorageAccountId
                            EventHubAuthorizationRuleId = $diag.EventHubAuthorizationRuleId
                            Logs = ($diag.Logs | ConvertTo-Json -Compress -Depth 2)
                            Metrics = ($diag.Metrics | ConvertTo-Json -Compress -Depth 2)
                        }
                        $diagnosticSettingsResults += $diagEntry
                    }
                }
            } catch { }
        }
        Write-Host "  OK Diagnostic Settings: $($diagnosticSettingsResults.Count)" -ForegroundColor Green
        
        # Extraire les Alertes (Metric Alerts et Log Alerts)
        Write-Host "  Extraction des Alertes..." -ForegroundColor Gray
        try {
            $metricAlerts = Get-AzMetricAlertRuleV2 -ErrorAction SilentlyContinue
            foreach ($alert in $metricAlerts) {
                $alertEntry = [PSCustomObject]@{
                    SubscriptionId = $subId
                    AlertType = "MetricAlert"
                    AlertName = $alert.Name
                    ResourceGroup = $alert.ResourceGroupName
                    Enabled = $alert.Enabled
                    Severity = $alert.Severity
                    TargetResourceId = ($alert.Scopes -join ';')
                    Description = $alert.Description
                }
                $alertsResults += $alertEntry
            }
            
            $scheduledQueryRules = Get-AzScheduledQueryRule -ErrorAction SilentlyContinue
            foreach ($alert in $scheduledQueryRules) {
                $alertEntry = [PSCustomObject]@{
                    SubscriptionId = $subId
                    AlertType = "LogAlert"
                    AlertName = $alert.Name
                    ResourceGroup = $alert.ResourceGroupName
                    Enabled = $alert.Enabled
                    Severity = $alert.Severity
                    TargetResourceId = ($alert.Scopes -join ';')
                    Description = $alert.Description
                }
                $alertsResults += $alertEntry
            }
        } catch { }
        Write-Host "  OK Alertes: $($alertsResults.Count)" -ForegroundColor Green
        
        # Extraire les Extensions VM et preparer vm-monitoring-matrix
        Write-Host "  Extraction des Extensions VM et VMs pour monitoring..." -ForegroundColor Gray
        $vms = $resources | Where-Object { $_.ResourceType -eq 'Microsoft.Compute/virtualMachines' }
        foreach ($vm in $vms) {
            try {
                # Recuperer les details de la VM pour detecter l'OS
                $vmDetails = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -ErrorAction SilentlyContinue
                
                # Detecter l'OS type
                $osType = 'Windows'  # Par defaut
                if ($vmDetails -and $vmDetails.StorageProfile -and $vmDetails.StorageProfile.OsDisk) {
                    $osType = if ($vmDetails.StorageProfile.OsDisk.OsType -eq 'Linux') { 'Linux' } else { 'Windows' }
                }
                
                # Ajouter a vm-monitoring-matrix
                $vmMonitoringEntry = [PSCustomObject]@{
                    resourceId = $vm.ResourceId
                    resourceName = $vm.Name
                    resourceGroup = $vm.ResourceGroupName
                    subscriptionId = $subId
                    location = $vm.Location
                    osType = $osType
                    monitoring = 'yes'  # Par defaut yes, le consultant modifiera apres
                }
                $vmMonitoringResults += $vmMonitoringEntry
                
                # Extraire les extensions VM
                $vmExtensions = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name -ErrorAction SilentlyContinue
                foreach ($ext in $vmExtensions) {
                    $extEntry = [PSCustomObject]@{
                        SubscriptionId = $subId
                        VMName = $vm.Name
                        ResourceGroup = $vm.ResourceGroupName
                        ExtensionName = $ext.Name
                        ExtensionType = $ext.ExtensionType
                        Publisher = $ext.Publisher
                        TypeHandlerVersion = $ext.TypeHandlerVersion
                        ProvisioningState = $ext.ProvisioningState
                    }
                    $vmExtensionsResults += $extEntry
                }
            } catch { }
        }
        Write-Host "  OK Extensions VM: $($vmExtensionsResults.Count)" -ForegroundColor Green
        Write-Host "  OK VMs pour monitoring: $($vmMonitoringResults.Count)" -ForegroundColor Green
        
        # Extraire les Data Collection Rules (DCR)
        Write-Host "  Extraction des Data Collection Rules..." -ForegroundColor Gray
        try {
            $dcrs = Get-AzDataCollectionRule -ErrorAction SilentlyContinue
            foreach ($dcr in $dcrs) {
                $dcrEntry = [PSCustomObject]@{
                    SubscriptionId = $subId
                    DCRName = $dcr.Name
                    ResourceGroup = $dcr.ResourceGroupName
                    Location = $dcr.Location
                    DataFlows = ($dcr.DataFlows | ConvertTo-Json -Compress -Depth 2)
                    DataSources = ($dcr.DataSources | ConvertTo-Json -Compress -Depth 2)
                    Destinations = ($dcr.Destinations | ConvertTo-Json -Compress -Depth 2)
                    ProvisioningState = $dcr.ProvisioningState
                }
                $dcrResults += $dcrEntry
            }
        } catch { }
        Write-Host "  OK Data Collection Rules: $($dcrResults.Count)" -ForegroundColor Green
        
    } catch {
        Write-Host "  ERROR lors de l'audit de la subscription $subId : $_" -ForegroundColor Red
        continue
    }
}

# Exporter les resultats en CSV
Write-Host "`nExport des resultats..." -ForegroundColor Yellow

# Exporter audit-full.csv (TOUTES les ressources)
if ($auditFullResults.Count -eq 0) {
    Write-Host "WARNING: Aucune ressource trouvee" -ForegroundColor Yellow
    
    # Creer un fichier vide avec headers
    $emptyAudit = [PSCustomObject]@{
        SubscriptionId = ""
        ResourceGroup = ""
        ResourceName = ""
        ResourceType = ""
        Location = ""
        Tags = ""
        ResourceId = ""
    }
    $emptyAudit | Export-Csv -Path $auditFullOutputPath -NoTypeInformation -Encoding UTF8
    $emptyAudit | Export-Csv -Path $auditOutputPath -NoTypeInformation -Encoding UTF8
    
} else {
    # Exporter audit-full.csv (TOUTES les ressources sans filtre)
    $auditFullResults | Export-Csv -Path $auditFullOutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "OK Audit complet exporte: $auditFullOutputPath" -ForegroundColor Green
    Write-Host "  Total ressources (TOUTES): $($auditFullResults.Count)" -ForegroundColor Cyan
    
    # Exporter audit.csv (ressources filtrees par type)
    if ($auditResults.Count -gt 0) {
        $auditResults | Export-Csv -Path $auditOutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "OK Audit filtre exporte: $auditOutputPath" -ForegroundColor Green
        Write-Host "  Total ressources (filtrees): $($auditResults.Count)" -ForegroundColor White
    } else {
        # Creer fichier vide si aucune ressource filtree
        $emptyAudit = [PSCustomObject]@{
            SubscriptionId = ""
            ResourceGroup = ""
            ResourceName = ""
            ResourceType = ""
            Location = ""
            Tags = ""
            ResourceId = ""
        }
        $emptyAudit | Export-Csv -Path $auditOutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "OK Audit filtre exporte (vide): $auditOutputPath" -ForegroundColor Yellow
    }
    
    # Statistiques par type de ressource (audit complet)
    Write-Host "`nSTATISTIQUES PAR TYPE (TOUTES RESSOURCES):" -ForegroundColor Cyan
    $stats = $auditFullResults | Group-Object -Property ResourceType | Sort-Object Count -Descending
    foreach ($stat in $stats) {
        Write-Host "  $($stat.Name): $($stat.Count)" -ForegroundColor White
    }
    
    # Statistiques par subscription
    Write-Host "`nSTATISTIQUES PAR SUBSCRIPTION:" -ForegroundColor Cyan
    $subStats = $auditFullResults | Group-Object -Property SubscriptionId | Sort-Object Count -Descending
    foreach ($stat in $subStats) {
        Write-Host "  $($stat.Name): $($stat.Count) ressources" -ForegroundColor White
    }
}

# Exporter les Diagnostic Settings
$diagSettingsPath = "$clientPath/Config/$Environment/diagnostic-settings.csv"
if ($diagnosticSettingsResults.Count -gt 0) {
    $diagnosticSettingsResults | Export-Csv -Path $diagSettingsPath -NoTypeInformation -Encoding UTF8
    Write-Host "OK Diagnostic Settings exportes: $diagSettingsPath ($($diagnosticSettingsResults.Count))" -ForegroundColor Green
}

# Exporter les Alertes
$alertsPath = "$clientPath/Config/$Environment/alerts.csv"
if ($alertsResults.Count -gt 0) {
    $alertsResults | Export-Csv -Path $alertsPath -NoTypeInformation -Encoding UTF8
    Write-Host "OK Alertes exportees: $alertsPath ($($alertsResults.Count))" -ForegroundColor Green
}

# Exporter les Extensions VM
$vmExtensionsPath = "$clientPath/Config/$Environment/vm-extensions.csv"
if ($vmExtensionsResults.Count -gt 0) {
    $vmExtensionsResults | Export-Csv -Path $vmExtensionsPath -NoTypeInformation -Encoding UTF8
    Write-Host "OK Extensions VM exportees: $vmExtensionsPath ($($vmExtensionsResults.Count))" -ForegroundColor Green
}

# Exporter les Data Collection Rules
$dcrPath = "$clientPath/Config/$Environment/data-collection-rules.csv"
if ($dcrResults.Count -gt 0) {
    $dcrResults | Export-Csv -Path $dcrPath -NoTypeInformation -Encoding UTF8
    Write-Host "OK Data Collection Rules exportees: $dcrPath ($($dcrResults.Count))" -ForegroundColor Green
}

# Exporter le fichier vm-monitoring-matrix.csv directement dans Matrices/Dev
$matricesPath = "$clientPath/Matrices/$Environment"
if (-not (Test-Path $matricesPath)) {
    New-Item -ItemType Directory -Path $matricesPath -Force | Out-Null
}
$vmMonitoringPath = "$matricesPath/vm-monitoring-matrix_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
if ($vmMonitoringResults.Count -gt 0) {
    $vmMonitoringResults | Export-Csv -Path $vmMonitoringPath -NoTypeInformation -Encoding UTF8
    Write-Host "OK VM Monitoring Matrix exportee: $vmMonitoringPath ($($vmMonitoringResults.Count))" -ForegroundColor Green
} else {
    # Creer un fichier vide avec headers si aucune VM
    $emptyVmMonitoring = [PSCustomObject]@{
        resourceId = ""
        resourceName = ""
        resourceGroup = ""
        subscriptionId = ""
        location = ""
        osType = ""
        monitoring = ""
    }
    $emptyVmMonitoring | Export-Csv -Path $vmMonitoringPath -NoTypeInformation -Encoding UTF8
    Write-Host "OK VM Monitoring Matrix exportee (vide): $vmMonitoringPath" -ForegroundColor Yellow
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "AUDIT TERMINE AVEC SUCCES" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

Write-Host "`nFICHIERS CREES:" -ForegroundColor Green
Write-Host "  - Ressources (TOUTES): $auditFullOutputPath ($($auditFullResults.Count))" -ForegroundColor Cyan
Write-Host "  - Ressources (filtrees): $auditOutputPath ($($auditResults.Count))" -ForegroundColor White
Write-Host "  - Diagnostic Settings: $diagSettingsPath ($($diagnosticSettingsResults.Count))" -ForegroundColor White
Write-Host "  - Alertes: $alertsPath ($($alertsResults.Count))" -ForegroundColor White
Write-Host "  - Extensions VM: $vmExtensionsPath ($($vmExtensionsResults.Count))" -ForegroundColor White
Write-Host "  - Data Collection Rules: $dcrPath ($($dcrResults.Count))" -ForegroundColor White
Write-Host "  - VM Monitoring Matrix: $vmMonitoringPath ($($vmMonitoringResults.Count))" -ForegroundColor Cyan
