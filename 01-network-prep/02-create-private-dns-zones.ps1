# ============================================
# Script: create-private-dns-zones.ps1
# Purpose: Create Private DNS Zones for PaaS 
#          (Key Vault, Storage, SQL) and link to VNets
# Author: Uzma Shabbir
# Project: Zero-Trust Hub & Spoke Baseline 2026
# ============================================

$rgName      = "rg-network-security"
$hubVnetName = "vnet-hub-uksouth"
$spoke1Name  = "vnet-spoke1-workloads"
$spoke2Name  = "vnet-spoke2-management"

Write-Host "=== CREATING PRIVATE DNS ZONES ===" -ForegroundColor Cyan
Write-Host "Lead Engineer: Uzma Shabbir" -ForegroundColor White

# 1. Get VNets for DNS zone linking
$hubVnet = Get-AzVirtualNetwork -Name $hubVnetName -ResourceGroupName $rgName
$spoke1  = Get-AzVirtualNetwork -Name $spoke1Name -ResourceGroupName $rgName
$spoke2  = Get-AzVirtualNetwork -Name $spoke2Name -ResourceGroupName $rgName

if (-not $hubVnet -or -not $spoke1 -or -not $spoke2) {
    Write-Host "❌ Error: One or more VNets not found. Please verify inventory." -ForegroundColor Red
    exit
}

# 2. DNS Zones needed for the Zero Trust PaaS Baseline
$dnsZones = @(
    "privatelink.vaultcore.azure.net",       # Key Vault
    "privatelink.blob.core.windows.net",     # Storage Blob
    "privatelink.file.core.windows.net",     # Storage File
    "privatelink.database.windows.net"       # SQL Database
)

foreach ($zoneName in $dnsZones) {
    Write-Host "`n⚙️ Processing DNS Zone: $zoneName" -ForegroundColor Yellow

    # Create Private DNS Zone
    $zone = New-AzPrivateDnsZone -Name $zoneName -ResourceGroupName $rgName -ErrorAction SilentlyContinue
    Write-Host "  ✅ DNS Zone ready." -ForegroundColor Green

    # Base name for the links
    $baseLinkName = $zoneName.Replace(".", "-").Replace("privatelink-", "link-")

    # Link to Hub VNet (Removed the EnableRegistration switch)
    New-AzPrivateDnsVirtualNetworkLink -ZoneName $zoneName -ResourceGroupName $rgName `
        -Name "$baseLinkName-hub" -VirtualNetworkId $hubVnet.Id -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  🔗 Linked to Hub VNet" -ForegroundColor Gray

    # Link to Spoke 1 (Removed the EnableRegistration switch)
    New-AzPrivateDnsVirtualNetworkLink -ZoneName $zoneName -ResourceGroupName $rgName `
        -Name "$baseLinkName-spoke1" -VirtualNetworkId $spoke1.Id -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  🔗 Linked to Spoke 1" -ForegroundColor Gray

    # Link to Spoke 2 (Removed the EnableRegistration switch)
    New-AzPrivateDnsVirtualNetworkLink -ZoneName $zoneName -ResourceGroupName $rgName `
        -Name "$baseLinkName-spoke2" -VirtualNetworkId $spoke2.Id -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  🔗 Linked to Spoke 2" -ForegroundColor Gray
    
    Write-Host "  ✅ Zone linking complete!" -ForegroundColor Green
}

# 3. Final Verification
Write-Host "`n=== DNS ZONES OVERVIEW ===" -ForegroundColor Cyan
Get-AzPrivateDnsZone -ResourceGroupName $rgName | Select-Object Name, NumberOfRecordSets, ProvisioningState | Format-Table -AutoSize

Write-Host "`n=== DNS ZONE VNET LINKS VERIFICATION ===" -ForegroundColor Cyan
foreach ($zoneName in $dnsZones) {
    Write-Host "-> $zoneName" -ForegroundColor Yellow
    Get-AzPrivateDnsVirtualNetworkLink -ZoneName $zoneName -ResourceGroupName $rgName | Select-Object Name, VirtualNetworkLinkState | Format-Table -AutoSize
}

Write-Host "✅ DNS Configuration for Project 4 complete!" -ForegroundColor Green

