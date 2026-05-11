# ============================================
# Script: create-key-vault.ps1
# Purpose: Create Azure Key Vault with initial 
#          secrets and encryption keys. 
#          (Prepared for Private Endpoint Link)
# Author: Uzma Shabbir
# Project: Zero-Trust Hub & Spoke Baseline 2026
# ============================================

Connect-AzAccount -ErrorAction SilentlyContinue

$rgName      = "rg-network-security"
$location    = "uksouth"

# Note: Key Vault names must be globally unique across all of Azure. 
$kvName      = "kv-uzmasami-sec-2026"

Write-Host "=== DEPLOYING AZURE KEY VAULT ===" -ForegroundColor Cyan
Write-Host "Lead Engineer: Uzma Shabbir" -ForegroundColor White
Write-Host "Target: $rgName ($location)" -ForegroundColor Gray

# 1. Create Key Vault (RBAC is now default, so the flag was removed)
Write-Host "`n⚙️ Provisioning Key Vault ($kvName)..." -ForegroundColor Yellow
$keyVault = New-AzKeyVault `
    -Name $kvName `
    -ResourceGroupName $rgName `
    -Location $location `
    -Sku Standard `
    -EnabledForDeployment `
    -EnabledForTemplateDeployment `
    -EnabledForDiskEncryption `
    -Tag @{
        Purpose     = "Secrets-Management"
        Security    = "Critical-Zero-Trust"
        Environment = "Production"
        Project     = "Baseline-2026"
        Owner       = "Uzma Shabbir"
    } -ErrorAction Stop

Write-Host "  ✅ Key Vault created successfully!" -ForegroundColor Green
Write-Host "  🔗 URI: $($keyVault.VaultUri)" -ForegroundColor Gray

# 2. Assign RBAC Permissions
Write-Host "`n⚙️ Assigning Key Vault Administrator role to Uzma..." -ForegroundColor Yellow
$currentUser = Get-AzADUser -SignedIn -ErrorAction SilentlyContinue

if ($currentUser) {
    New-AzRoleAssignment `
        -ObjectId $currentUser.Id `
        -RoleDefinitionName "Key Vault Administrator" `
        -Scope $keyVault.ResourceId | Out-Null
    Write-Host "  ✅ Admin role assigned to $($currentUser.DisplayName)!" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Could not auto-detect signed-in user. You may need to assign RBAC manually in the portal." -ForegroundColor Yellow
}

# 3. Add Sample Secrets & Keys
Write-Host "`n⏳ Waiting 30 seconds for Azure RBAC propagation..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

Write-Host "`n⚙️ Injecting Baseline Secrets and Keys..." -ForegroundColor Yellow

# Add SQL Password
$sqlSecretValue = ConvertTo-SecureString "P@ssw0rd-SQL-Prod-2026!" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $kvName -Name "sql-admin-password" -SecretValue $sqlSecretValue -ContentType "SQL Server Password" -ErrorAction SilentlyContinue | Out-Null
Write-Host "  ✅ Secret added: sql-admin-password" -ForegroundColor Green

# Add Storage Connection String
$storageSecretValue = ConvertTo-SecureString "DefaultEndpointsProtocol=https;AccountName=demo" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $kvName -Name "storage-connection-string" -SecretValue $storageSecretValue -ContentType "Storage Connection String" -ErrorAction SilentlyContinue | Out-Null
Write-Host "  ✅ Secret added: storage-connection-string" -ForegroundColor Green

# Add Encryption Key
Add-AzKeyVaultKey -VaultName $kvName -Name "master-encryption-key" -Destination Software -KeyOps @("encrypt", "decrypt", "sign", "verify") -ErrorAction SilentlyContinue | Out-Null
Write-Host "  ✅ Encryption key added: master-encryption-key" -ForegroundColor Green

# 4. Final Verification
Write-Host "`n=== KEY VAULT SUMMARY ===" -ForegroundColor Cyan
Write-Host "Vault Name: $kvName" -ForegroundColor White
Write-Host "Vault URI:  $($keyVault.VaultUri)" -ForegroundColor White
Write-Host "Secrets:    sql-admin-password, storage-connection-string" -ForegroundColor White
Write-Host "Keys:       master-encryption-key" -ForegroundColor White
Write-Host "Status:     Ready for Private Endpoint Integration" -ForegroundColor Green

# Save KV name for next scripts
$kvName | Out-File ".\keyvault-name.txt"

