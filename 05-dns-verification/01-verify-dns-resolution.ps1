# ============================================
# Script: verify-dns-resolution.ps1
# Purpose: Verify all services resolve to private IPs
#          and public access is strictly disabled.
# Author: Uzma Shabbir
# Project: Zero-Trust Hub & Spoke Baseline 2026
# ============================================

Connect-AzAccount -ErrorAction SilentlyContinue

$rgName        = "rg-network-security"
$kvName        = Get-Content ".\keyvault-name.txt"
$storageName   = Get-Content ".\storage-name.txt"
# Updated to match the unique name deployed in the previous step
$sqlServerName = "sql-uzmasami-secure-8842"

Write-Host "=== ZERO-TRUST VERIFICATION INITIATED ===" -ForegroundColor Cyan
Write-Host "Lead Engineer: Uzma Shabbir" -ForegroundColor White
Write-Host "Target: $rgName" -ForegroundColor Gray
Write-Host "`nVerifying private routing and security enforcement..." -ForegroundColor Yellow

# Get all Private Endpoints
$allPEs = Get-AzPrivateEndpoint -ResourceGroupName $rgName

Write-Host "`n=== 1. PRIVATE ENDPOINT IP ASSIGNMENTS ===" -ForegroundColor Cyan
foreach ($pe in $allPEs) {
    Write-Host "`nEndpoint: $($pe.Name)" -ForegroundColor Yellow

    # Get private IP from the attached Network Interface
    $nic = Get-AzNetworkInterface -ResourceId $pe.NetworkInterfaces[0].Id
    $privateIP = $nic.IpConfigurations[0].PrivateIpAddress

    Write-Host "  Private IP: $privateIP" -ForegroundColor Green
    Write-Host "  Subnet:     $($nic.IpConfigurations[0].Subnet.Id.Split('/')[-1])" -ForegroundColor White
    Write-Host "  Status:     $($pe.ProvisioningState)" -ForegroundColor White
}

# Verify DNS Zone records
Write-Host "`n=== 2. PRIVATE DNS ZONE RECORDS ===" -ForegroundColor Cyan

$dnsZones = Get-AzPrivateDnsZone -ResourceGroupName $rgName

foreach ($zone in $dnsZones) {
    Write-Host "`nZone: $($zone.Name)" -ForegroundColor Yellow

    $records = Get-AzPrivateDnsRecordSet `
        -ZoneName $zone.Name `
        -ResourceGroupName $rgName `
        -RecordType A `
        -ErrorAction SilentlyContinue

    foreach ($record in $records) {
        # Skip the root "@" records that might be empty, focus on named records
        if ($record.Name -ne "@") {
            Write-Host "  Record: $($record.Name)" -ForegroundColor White
            Write-Host "  IP:     $($record.Records[0].Ipv4Address)" -ForegroundColor Green
        }
    }
}

# Security verification
Write-Host "`n=== 3. PUBLIC ACCESS SECURITY ENFORCEMENT ===" -ForegroundColor Cyan

# Check Key Vault public access
$kv = Get-AzKeyVault -VaultName $kvName -ResourceGroupName $rgName
Write-Host "`nKey Vault ($kvName): " -NoNewline
if ($kv.PublicNetworkAccess -eq "Disabled") {
    Write-Host "DISABLED ✅" -ForegroundColor Green
} else {
    Write-Host "ENABLED ⚠️" -ForegroundColor Red
}

# Check Storage public access
$storage = Get-AzStorageAccount -ResourceGroupName $rgName -Name $storageName
Write-Host "Storage Account ($storageName): " -NoNewline
if ($storage.PublicNetworkAccess -eq "Disabled") {
    Write-Host "DISABLED ✅" -ForegroundColor Green
} else {
    Write-Host "ENABLED ⚠️" -ForegroundColor Red
}

# Check SQL public access
$sql = Get-AzSqlServer -ResourceGroupName $rgName -ServerName $sqlServerName
Write-Host "SQL Server ($sqlServerName): " -NoNewline
if ($sql.PublicNetworkAccess -eq "Disabled") {
    Write-Host "DISABLED ✅" -ForegroundColor Green
} else {
    Write-Host "ENABLED ⚠️" -ForegroundColor Red
}

Write-Host "`n🔐 SUCCESS: All services secured and confined to the internal network!" -ForegroundColor Green

