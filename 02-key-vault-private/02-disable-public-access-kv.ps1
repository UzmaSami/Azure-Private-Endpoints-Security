# ============================================
# Script: create-pe-keyvault.ps1
# Purpose: Disable public access to Key Vault
#          and route all traffic through a Private Endpoint
# Author: Uzma Shabbir
# Project: Zero-Trust Hub & Spoke Baseline 2026
# ============================================

Connect-AzAccount -ErrorAction SilentlyContinue

$rgName      = "rg-network-security"
$location    = "uksouth"
$kvName      = Get-Content ".\keyvault-name.txt"
$hubVnetName = "vnet-hub-uksouth"
$peSubnet    = "snet-privateendpoints"
$peName      = "pe-keyvault-uzmasami"

Write-Host "=== SECURING KEY VAULT WITH PRIVATE ENDPOINT ===" -ForegroundColor Cyan
Write-Host "Lead Engineer: Uzma Shabbir" -ForegroundColor White
Write-Host "Target Vault: $kvName" -ForegroundColor Gray

# Step 1: Disable public network access
Write-Host "`n[1/4] Disabling public internet access..." -ForegroundColor Yellow

Update-AzKeyVault `
    -VaultName $kvName `
    -ResourceGroupName $rgName `
    -PublicNetworkAccess "Disabled" -ErrorAction Stop | Out-Null

Write-Host "  ✅ Public access DISABLED! ❌🌐" -ForegroundColor Green

# Step 2: Get subnet for Private Endpoint
$hubVnet = Get-AzVirtualNetwork -Name $hubVnetName -ResourceGroupName $rgName
$subnet  = $hubVnet.Subnets | Where-Object {$_.Name -eq $peSubnet}

# Step 3: Get Key Vault resource ID
$kvResource = Get-AzResource -ResourceName $kvName -ResourceType "Microsoft.KeyVault/vaults"

# Step 4: Create Private Endpoint
Write-Host "`n[2/4] Creating Private Endpoint ($peName)..." -ForegroundColor Yellow

# Create PE connection
$peConnection = New-AzPrivateLinkServiceConnection `
    -Name "plsc-keyvault" `
    -PrivateLinkServiceId $kvResource.ResourceId `
    -GroupId "vault"

# Create Private Endpoint in the dedicated subnet
$privateEndpoint = New-AzPrivateEndpoint `
    -Name $peName `
    -ResourceGroupName $rgName `
    -Location $location `
    -Subnet $subnet `
    -PrivateLinkServiceConnection $peConnection `
    -Tag @{
        Purpose = "KeyVault-PrivateAccess"
        Service = "Key-Vault"
        Owner   = "Uzma Shabbir"
    } -ErrorAction Stop

Write-Host "  ✅ Private Endpoint provisioned!" -ForegroundColor Green

# Step 5: Configure Private DNS Zone Group
Write-Host "`n[3/4] Configuring DNS Zone Group integration..." -ForegroundColor Yellow

$dnsZone = Get-AzPrivateDnsZone -ResourceGroupName $rgName -Name "privatelink.vaultcore.azure.net"

$dnsConfig = New-AzPrivateDnsZoneConfig `
    -Name "privatelink-vaultcore-azure-net" `
    -PrivateDnsZoneId $dnsZone.ResourceId

New-AzPrivateDnsZoneGroup `
    -ResourceGroupName $rgName `
    -PrivateEndpointName $peName `
    -Name "dzg-keyvault" `
    -PrivateDnsZoneConfig $dnsConfig -ErrorAction SilentlyContinue | Out-Null

Write-Host "  ✅ DNS Zone Group successfully linked!" -ForegroundColor Green

# Step 6: Verify private IP assigned
Write-Host "`n[4/4] Verifying Private IP Assignment..." -ForegroundColor Yellow

# Allow a moment for DNS propagation
Start-Sleep -Seconds 5 

$pe = Get-AzPrivateEndpoint -Name $peName -ResourceGroupName $rgName
$privateIP = $pe.CustomDnsConfigs[0].IpAddresses[0]

# Fallback check if CustomDnsConfigs is slow to populate
if (-not $privateIP) {
    $nic = Get-AzNetworkInterface -ResourceId $pe.NetworkInterfaces[0].Id
    $privateIP = $nic.IpConfigurations[0].PrivateIpAddress
}

Write-Host "  ✅ Private IP Assigned: $privateIP" -ForegroundColor Green
Write-Host "  🔐 Key Vault is now ONLY accessible via the internal network!" -ForegroundColor Cyan

# Summary
Write-Host "`n=== KEY VAULT ZERO-TRUST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Key Vault:      $kvName" -ForegroundColor White
Write-Host "Public Access:  DISABLED ❌" -ForegroundColor Red
Write-Host "Private Access: ENABLED ✅" -ForegroundColor Green
Write-Host "Private IP:     $privateIP" -ForegroundColor Green
Write-Host "DNS Zone:       privatelink.vaultcore.azure.net" -ForegroundColor White
Write-Host "Subnet:         $peSubnet" -ForegroundColor White

