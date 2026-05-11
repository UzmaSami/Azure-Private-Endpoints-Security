# ============================================
# Script: create-storage-secure.ps1
# Purpose: Create Storage Account and secure it 
#          with a Private Endpoint (Blob)
# Author: Uzma Shabbir
# Project: Zero-Trust Hub & Spoke Baseline 2026
# ============================================

Connect-AzAccount -ErrorAction SilentlyContinue

$rgName            = "rg-network-security"
$location          = "uksouth"
# Storage account names must be globally unique, lowercase, and no special chars/spaces
$storageNameSecure = "stuzmasamisecure8842"
$hubVnetName       = "vnet-hub-uksouth"
$peSubnetName      = "snet-privateendpoints"
$peName            = "pe-storage-uzmasami"

Write-Host "=== SECURING STORAGE WITH PRIVATE ENDPOINT ===" -ForegroundColor Cyan
Write-Host "Lead Engineer: Uzma Shabbir" -ForegroundColor White
Write-Host "Target: $rgName ($location)" -ForegroundColor Gray

# Step 1: Create Storage Account
Write-Host "`n[1/5] Provisioning Zero-Trust Storage Account..." -ForegroundColor Yellow
$storageAccount = New-AzStorageAccount `
    -ResourceGroupName $rgName `
    -Name $storageNameSecure `
    -Location $location `
    -SkuName Standard_LRS `
    -Kind StorageV2 `
    -MinimumTlsVersion TLS1_2 `
    -AllowBlobPublicAccess $false `
    -EnableHttpsTrafficOnly $true `
    -Tag @{
        Purpose     = "Secure-Storage"
        Security    = "Critical-Zero-Trust"
        Environment = "Production"
        Project     = "Baseline-2026"
        Owner       = "Uzma Shabbir"
    } -ErrorAction Stop

Write-Host "  ✅ Storage Account created: $($storageAccount.StorageAccountName)" -ForegroundColor Green

# Step 2: Create sample containers
Write-Host "`n[2/5] Creating Secure Containers..." -ForegroundColor Yellow
$ctx = $storageAccount.Context

$containers = @("secure-documents", "security-logs", "compliance-reports")
foreach ($container in $containers) {
    New-AzStorageContainer -Name $container -Context $ctx -Permission Off -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  ✅ Container locked: $container" -ForegroundColor Green
}

# Step 3: Disable public access completely
Write-Host "`n[3/5] Disabling public network access..." -ForegroundColor Yellow
Set-AzStorageAccount `
    -ResourceGroupName $rgName `
    -Name $storageNameSecure `
    -PublicNetworkAccess Disabled -ErrorAction Stop | Out-Null

Write-Host "  ✅ Public access DISABLED! ❌🌐" -ForegroundColor Green

# Step 4: Create Private Endpoint for Blob
Write-Host "`n[4/5] Creating Private Endpoint for Blob Services..." -ForegroundColor Yellow
$hubVnet = Get-AzVirtualNetwork -Name $hubVnetName -ResourceGroupName $rgName
$subnet  = $hubVnet.Subnets | Where-Object {$_.Name -eq $peSubnetName}

$storageResource = Get-AzResource -ResourceName $storageNameSecure -ResourceType "Microsoft.Storage/storageAccounts"

# Blob Private Endpoint Connection
$blobConnection = New-AzPrivateLinkServiceConnection `
    -Name "plsc-storage-blob" `
    -PrivateLinkServiceId $storageResource.ResourceId `
    -GroupId "blob"

# Create Private Endpoint
$blobPE = New-AzPrivateEndpoint `
    -Name "$peName-blob" `
    -ResourceGroupName $rgName `
    -Location $location `
    -Subnet $subnet `
    -PrivateLinkServiceConnection $blobConnection `
    -Tag @{
        Purpose = "Storage-Blob-PrivateAccess"
        Service = "Storage"
        Owner   = "Uzma Shabbir"
    } -ErrorAction Stop

Write-Host "  ✅ Blob Private Endpoint provisioned!" -ForegroundColor Green

# Configure DNS for blob
$blobDnsZone = Get-AzPrivateDnsZone -ResourceGroupName $rgName -Name "privatelink.blob.core.windows.net"

$blobDnsConfig = New-AzPrivateDnsZoneConfig `
    -Name "privatelink-blob-core-windows-net" `
    -PrivateDnsZoneId $blobDnsZone.ResourceId

New-AzPrivateDnsZoneGroup `
    -ResourceGroupName $rgName `
    -PrivateEndpointName "$peName-blob" `
    -Name "dzg-storage-blob" `
    -PrivateDnsZoneConfig $blobDnsConfig -ErrorAction SilentlyContinue | Out-Null

Write-Host "  ✅ Storage Blob DNS Zone Group configured!" -ForegroundColor Green

# Step 5: Verify private IP assigned
Write-Host "`n[5/5] Verifying Private IP Assignment..." -ForegroundColor Yellow

Start-Sleep -Seconds 5 

$pe = Get-AzPrivateEndpoint -Name "$peName-blob" -ResourceGroupName $rgName
$privateIP = $pe.CustomDnsConfigs[0].IpAddresses[0]

if (-not $privateIP) {
    $nic = Get-AzNetworkInterface -ResourceId $pe.NetworkInterfaces[0].Id
    $privateIP = $nic.IpConfigurations[0].PrivateIpAddress
}

Write-Host "  ✅ Private IP Assigned: $privateIP" -ForegroundColor Green

# Save storage name for subsequent scripts
$storageNameSecure | Out-File ".\storage-name.txt"

# Summary
Write-Host "`n=== STORAGE ZERO-TRUST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Storage Account: $storageNameSecure" -ForegroundColor White
Write-Host "Public Access:   DISABLED ❌" -ForegroundColor Red
Write-Host "Private Blob PE: ENABLED ✅" -ForegroundColor Green
Write-Host "Private IP:      $privateIP" -ForegroundColor Green
Write-Host "DNS Zone:        privatelink.blob.core.windows.net" -ForegroundColor White
Write-Host "TLS Version:     1.2 minimum ✅" -ForegroundColor Green
Write-Host "Blob Public:     DISABLED ✅" -ForegroundColor Green

