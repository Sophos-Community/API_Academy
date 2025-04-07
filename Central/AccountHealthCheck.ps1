# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# Tenant Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

if ($null -ne $DataRegion){
	# Post Request to Firewall API:
	$Result = (Invoke-RestMethod -Method Get -Uri $DataRegion"/account-health-check/v1/health-check" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
}

Write-Host "Account Health Check"

### Output Protected Endpoints
Write-Host ("`nProtection Status")
Write-Host ("-------------------------------")
Write-Host ("Unprotected Computers: " + $Result.endpoint.protection.computer.notFullyProtected + " out of " + $Result.endpoint.protection.computer.total)
Write-Host ("Unprotected Servers: " + $Result.endpoint.protection.server.notFullyProtected + " out of " + $Result.endpoint.protection.server.total)

### Output Policy Status
Write-Host ("`nPolicy Status")
Write-Host ("-------------------------------")
Write-Host ("Computer policies not on recommended settings: " + $Result.endpoint.policy.computer.'threat-protection'.notOnRecommended + " out of " + $Result.endpoint.policy.computer.'threat-protection'.total)
Write-Host ("Server policies not on recommended settings : " + $Result.endpoint.policy.server.'server-threat-protection'.notOnRecommended + " out of " + $Result.endpoint.policy.server.'server-threat-protection'.total)

### Output Exclusions
Write-Host ("`nExclusion Status")
Write-Host ("-------------------------------")
Write-Host ("Risky exclusions for computers: " + $Result.endpoint.exclusions.policy.computer.numberOfSecurityRisks)
Write-Host ("Risky exclusions for servers: " + $Result.endpoint.exclusions.policy.server.numberOfSecurityRisks)
Write-Host ("Risky global exclusions: " + $Result.endpoint.exclusions.global.numberOfSecurityRisks)

### Output Tamper Protection
Write-Host ("`nTamper Protection")
Write-Host ("-------------------------------")
Write-Host ("Tamper Protection enabled for account: " + $Result.endpoint.tamperProtection.global)
Write-Host ("Computers with disabled Tamper Protection: " + $Result.endpoint.tamperProtection.computer.disabled + " out of " + $Result.endpoint.tamperProtection.computer.total )
Write-Host ("Servers  with disabled Tamper Protection: " + $Result.endpoint.tamperProtection.server.disabled + " out of " + $Result.endpoint.tamperProtection.server.total)
