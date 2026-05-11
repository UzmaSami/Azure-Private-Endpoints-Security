# ============================================
# Script: enable-pe-diagnostics.ps1
# Purpose: Send all Zero-Trust resource diagnostics
#          to your existing Log Analytics Workspace (Modern Syntax)
# Author: Uzma Shabbir
# Project: Zero-Trust Hub & Spoke Baseline 2026
# ============================================

Connect-AzAccount -ErrorAction SilentlyContinue

$rgName        = "rg-network-security"
$workspaceName = "law-UzmaSami-hybrid-security-2026"
$kvName        = Get-Content ".\keyvault-name.txt"
$storageName   = Get-Content ".\storage-name.txt"
$sqlServerName = "sql-uzmasami-secure-8842" 
$sqlDBName     = "sqldb-security-demo"

Write-Host "=== ENABLING ZERO-TRUST DIAGNOSTICS ===" -ForegroundColor Cyan
Write-Host "Lead Engineer: Uzma Shabbir" -ForegroundColor White
Write-Host "Target Workspace: $workspaceName" -ForegroundColor Gray

# Get existing Log Analytics Workspace
$workspace = Get-AzOperationalInsightsWorkspace `
    -ResourceGroupName $rgName `
    -Name $workspaceName -ErrorAction Stop

Write-Host "`n  ✅ Target workspace validated!" -ForegroundColor Green

# ---------------------------------------------------------
# [1/3] Enable Key Vault Diagnostics
# ---------------------------------------------------------
Write-Host "`n[1/3] Enabling Key Vault Audit logging..." -ForegroundColor Yellow

$kvResource = Get-AzResource -ResourceName $kvName -ResourceType "Microsoft.KeyVault/vaults"

$kvLogs = @(
    (New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "AuditEvent"),
    (New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "AzurePolicyEvaluationDetails")
)
$kvMetrics = @(New-AzDiagnosticSettingMetricSettingsObject -Enabled $true -Category "AllMetrics")

New-AzDiagnosticSetting `
    -Name "diag-keyvault-to-law" `
    -ResourceId $kvResource.ResourceId `
    -WorkspaceId $workspace.ResourceId `
    -Log $kvLogs `
    -Metric $kvMetrics | Out-Null

Write-Host "  ✅ Key Vault diagnostics enabled!" -ForegroundColor Green

# ---------------------------------------------------------
# [2/3] Enable Storage Diagnostics
# ---------------------------------------------------------
Write-Host "`n[2/3] Enabling Storage Blob telemetry..." -ForegroundColor Yellow

$storageResource = Get-AzResource -ResourceName $storageName -ResourceType "Microsoft.Storage/storageAccounts"

$storageLogs = @(
    (New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "StorageRead"),
    (New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "StorageWrite"),
    (New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "StorageDelete")
)
$storageMetrics = @(New-AzDiagnosticSettingMetricSettingsObject -Enabled $true -Category "Transaction")

New-AzDiagnosticSetting `
    -Name "diag-storage-to-law" `
    -ResourceId "$($storageResource.ResourceId)/blobServices/default" `
    -WorkspaceId $workspace.ResourceId `
    -Log $storageLogs `
    -Metric $storageMetrics | Out-Null

Write-Host "  ✅ Storage diagnostics enabled!" -ForegroundColor Green

# ---------------------------------------------------------
# [3/3] Enable SQL Diagnostics
# ---------------------------------------------------------
Write-Host "`n[3/3] Enabling SQL Database security audits..." -ForegroundColor Yellow

$sqlDBResource = Get-AzResource -ResourceGroupName $rgName -ResourceName "$sqlServerName/$sqlDBName" -ResourceType "Microsoft.Sql/servers/databases"

$sqlLogs = @(
    (New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "SQLSecurityAuditEvents"),
    (New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "Errors"),
    (New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "DatabaseWaitStatistics")
)
$sqlMetrics = @(New-AzDiagnosticSettingMetricSettingsObject -Enabled $true -Category "Basic")

New-AzDiagnosticSetting `
    -Name "diag-sql-to-law" `
    -ResourceId $sqlDBResource.ResourceId `
    -WorkspaceId $workspace.ResourceId `
    -Log $sqlLogs `
    -Metric $sqlMetrics | Out-Null

Write-Host "  ✅ SQL diagnostics enabled!" -ForegroundColor Green

# Summary
Write-Host "`n=== DIAGNOSTIC SETTINGS SUMMARY ===" -ForegroundColor Cyan
Write-Host "All Zero-Trust services are now routing logs to:" -ForegroundColor White
Write-Host "Workspace: $workspaceName" -ForegroundColor Green
Write-Host "`nTelemetry Data Flow (Modern Syntax):" -ForegroundColor White
Write-Host "  ✅ Key Vault ➡️ AuditEvent logs" -ForegroundColor Green
Write-Host "  ✅ Storage   ➡️ Read/Write/Delete logs" -ForegroundColor Green
Write-Host "  ✅ SQL DB    ➡️ Security audit logs" -ForegroundColor Green

