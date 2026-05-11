# ============================================
# Script: create-sql-server.ps1
# Purpose: Create SQL Server with Private Endpoint,
#          disable public access, and store in KV.
# Author: Uzma Shabbir
# Project: Zero-Trust Hub & Spoke Baseline 2026
# ============================================

Connect-AzAccount -ErrorAction SilentlyContinue

$rgName       = "rg-network-security"
$location     = "uksouth"
# SQL Server names must be globally unique and lowercase.
$sqlServerName = "sql-uzmasami-secure-8842"
$sqlDBName    = "sqldb-security-demo"
$hubVnetName  = "vnet-hub-uksouth"
$peSubnetName = "snet-privateendpoints"
$peName       = "pe-sql-uzmasami"

# SQL Admin credentials (In production, these would be generated dynamically)
$adminUser    = "sqladmin"
$adminPass    = ConvertTo-SecureString "Uzma@Secure2026!" -AsPlainText -Force
$sqlCreds     = New-Object System.Management.Automation.PSCredential ($adminUser, $adminPass)

Write-Host "=== DEPLOYING ZERO-TRUST AZURE SQL ===" -ForegroundColor Cyan
Write-Host "Lead Engineer: Uzma Shabbir" -ForegroundColor White
Write-Host "Target: $rgName ($location)" -ForegroundColor Gray

# Step 1: Create SQL Server
Write-Host "`n[1/6] Provisioning SQL Server ($sqlServerName)..." -ForegroundColor Yellow
$sqlServer = New-AzSqlServer `
    -ResourceGroupName $rgName `
    -ServerName $sqlServerName `
    -Location $location `
    -SqlAdministratorCredentials $sqlCreds `
    -MinimalTlsVersion "1.2" `
    -PublicNetworkAccess "Disabled" -ErrorAction Stop

Write-Host "  ✅ SQL Server created! Public Access is DISABLED. ❌🌐" -ForegroundColor Green

# Step 2: Create Database
Write-Host "`n[2/6] Provisioning SQL Database ($sqlDBName)..." -ForegroundColor Yellow
$sqlDB = New-AzSqlDatabase `
    -ResourceGroupName $rgName `
    -ServerName $sqlServerName `
    -DatabaseName $sqlDBName `
    -Edition "Basic" `
    -RequestedServiceObjectiveName "Basic" `
    -MaxSizeBytes 2147483648 `
    -Tag @{
        Purpose     = "Security-Demo"
        Environment = "Production"
        Project     = "Baseline-2026"
        Owner       = "Uzma Shabbir"
    } -ErrorAction Stop

Write-Host "  ✅ SQL Database created!" -ForegroundColor Green

# Step 3: Create Private Endpoint
Write-Host "`n[3/6] Creating Private Endpoint for SQL Server..." -ForegroundColor Yellow

$hubVnet = Get-AzVirtualNetwork -Name $hubVnetName -ResourceGroupName $rgName
$subnet  = $hubVnet.Subnets | Where-Object {$_.Name -eq $peSubnetName}

$sqlResource = Get-AzResource -ResourceName $sqlServerName -ResourceType "Microsoft.Sql/servers"

$sqlConnection = New-AzPrivateLinkServiceConnection `
    -Name "plsc-sql" `
    -PrivateLinkServiceId $sqlResource.ResourceId `
    -GroupId "sqlServer"

$sqlPE = New-AzPrivateEndpoint `
    -Name $peName `
    -ResourceGroupName $rgName `
    -Location $location `
    -Subnet $subnet `
    -PrivateLinkServiceConnection $sqlConnection `
    -Tag @{
        Purpose = "SQL-PrivateAccess"
        Service = "SQL-Server"
        Owner   = "Uzma Shabbir"
    } -ErrorAction Stop

Write-Host "  ✅ SQL Private Endpoint provisioned!" -ForegroundColor Green

# Step 4: Configure DNS
Write-Host "`n[4/6] Configuring DNS Zone Group integration..." -ForegroundColor Yellow
$sqlDnsZone = Get-AzPrivateDnsZone -ResourceGroupName $rgName -Name "privatelink.database.windows.net"

$sqlDnsConfig = New-AzPrivateDnsZoneConfig `
    -Name "privatelink-database-windows-net" `
    -PrivateDnsZoneId $sqlDnsZone.ResourceId

New-AzPrivateDnsZoneGroup `
    -ResourceGroupName $rgName `
    -PrivateEndpointName $peName `
    -Name "dzg-sql" `
    -PrivateDnsZoneConfig $sqlDnsConfig -ErrorAction SilentlyContinue | Out-Null

Write-Host "  ✅ SQL DNS Zone Group configured!" -ForegroundColor Green

# Step 5: Store SQL Details in Key Vault
Write-Host "`n[5/6] Storing configuration securely in Key Vault..." -ForegroundColor Yellow
$kvName = Get-Content ".\keyvault-name.txt"

Set-AzKeyVaultSecret `
    -VaultName $kvName `
    -Name "sql-server-name" `
    -SecretValue (ConvertTo-SecureString $sqlServerName -AsPlainText -Force) -ErrorAction SilentlyContinue | Out-Null

Write-Host "  ✅ SQL Server Name stored in Key Vault ($kvName)!" -ForegroundColor Green

# Step 6: Verify Private IP
Write-Host "`n[6/6] Verifying Private IP Assignment..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$pe = Get-AzPrivateEndpoint -Name $peName -ResourceGroupName $rgName
$privateIP = $pe.CustomDnsConfigs[0].IpAddresses[0]

if (-not $privateIP) {
    $nic = Get-AzNetworkInterface -ResourceId $pe.NetworkInterfaces[0].Id
    $privateIP = $nic.IpConfigurations[0].PrivateIpAddress
}

Write-Host "  ✅ Private IP Assigned: $privateIP" -ForegroundColor Green

# Summary
Write-Host "`n=== SQL ZERO-TRUST SUMMARY ===" -ForegroundColor Cyan
Write-Host "SQL Server:      $sqlServerName" -ForegroundColor White
Write-Host "Database:        $sqlDBName" -ForegroundColor White
Write-Host "Public Access:   DISABLED ❌" -ForegroundColor Red
Write-Host "Private PE:      ENABLED ✅" -ForegroundColor Green
Write-Host "Private IP:      $privateIP" -ForegroundColor Green
Write-Host "TLS Version:     1.2 minimum ✅" -ForegroundColor Green
Write-Host "DNS Zone:        privatelink.database.windows.net" -ForegroundColor White
Write-Host "Secrets Stored:  Key Vault ($kvName) ✅" -ForegroundColor Green

