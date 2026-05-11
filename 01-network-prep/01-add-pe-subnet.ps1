# ============================================
# Script: add-pe-subnet.ps1
# Purpose: Add dedicated Private Endpoint subnet 
#          to existing Hub VNet for secure PaaS access
# Author: Uzma Shabbir
# Project: Secure Baseline 2026
# ============================================

# Variables
$rgName      = "rg-network-security"
$location    = "uksouth"
$hubVnetName = "vnet-hub-uksouth"
$peSubnet    = "10.0.5.0/24"
$peSubnetName= "snet-privateendpoints"

Write-Host "=== ADDING PRIVATE ENDPOINT SUBNET ===" -ForegroundColor Cyan
Write-Host "Target VNet: $hubVnetName" -ForegroundColor White

# 1. Get existing Hub VNet
$hubVnet = Get-AzVirtualNetwork -Name $hubVnetName -ResourceGroupName $rgName

if (-not $hubVnet) {
    Write-Host "❌ Error: Hub VNet not found. Check resource group and name." -ForegroundColor Red
    exit
}

Write-Host "✅ Hub VNet retrieved successfully." -ForegroundColor Green
Write-Host "Current subnets count: $($hubVnet.Subnets.Count)" -ForegroundColor Gray

# 2. Configure Private Endpoint subnet
# ⭐ CRITICAL: Disabling network policies is required for Private Endpoints to route correctly
Write-Host "Configuring Subnet: $peSubnetName ($peSubnet)..." -ForegroundColor Yellow

$peSubnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $peSubnetName `
    -AddressPrefix $peSubnet `
    -PrivateEndpointNetworkPoliciesFlag "Disabled"

# 3. Add subnet to the VNet object in memory
$hubVnet.Subnets.Add($peSubnetConfig)

# 4. Commit changes to Azure
Write-Host "Committing changes to Azure (this takes a moment)..." -ForegroundColor Yellow
$hubVnet | Set-AzVirtualNetwork | Out-Null

Write-Host "✅ Private Endpoint subnet successfully provisioned!" -ForegroundColor Green

# 5. Final Verification
$updatedVnet = Get-AzVirtualNetwork -Name $hubVnetName -ResourceGroupName $rgName

Write-Host "`n=== UPDATED HUB VNET SUBNETS: UZMA SHABBIR ===" -ForegroundColor Cyan
$updatedVnet.Subnets |
    Select-Object Name, 
    @{N="AddressPrefix";E={$_.AddressPrefix}},
    @{N="PE_Policies";E={$_.PrivateEndpointNetworkPolicies}} |
    Format-Table -AutoSize

