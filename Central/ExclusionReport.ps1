# This will return global and exclusions set in policies

# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# SOPHOS  API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

Write-Output "==============================================================================="
Write-Output "Global Exclusions"
Write-Output "==============================================================================="

if ($null -ne $DataRegion){
	# Post Request to Central API:
	$Result = (Invoke-RestMethod -Method Get -Uri $DataRegion"/endpoint/v1/settings/exclusions/scanning" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
}

$Result.items | Format-Table -Property @{label='Type';e={$_.type}},@{label='Scan Mode';e={$_.scanMode}}, @{label='Description';e={$_.description}}, @{label='Value';e={$_.value}}

Write-Output "==============================================================================="
Write-Output "Endpoint Policy Exclusions"
Write-Output "==============================================================================="

if ($null -ne $DataRegion){
	# Post Request to Central API:
	$Result = (Invoke-RestMethod -Method Get -Uri $DataRegion"/endpoint/v1/policies?policyType=threat-protection&pageSize=100" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
}

foreach ($Item in $Result.items) {
    if($Item.settings.'endpoint.threat-protection.exclusions.scanning'.value.Count -gt 0){
        Write-Output "`n---------------------------------"
        Write-Output $Item.name
        Write-Output "---------------------------------"
        $Item.settings.'endpoint.threat-protection.exclusions.scanning'.value | Format-Table -Property @{label='Type';e={$_.type}},@{label='Scan Mode';e={$_.scanMode}}, @{label='Value';e={$_.value}}
    }  
}

Write-Output "==============================================================================="
Write-Output "Server Policy Exclusions"
Write-Output "==============================================================================="

if ($null -ne $DataRegion){
	# Post Request to Central API:
	$Result = (Invoke-RestMethod -Method Get -Uri $DataRegion"/endpoint/v1/policies?policyType=server-threat-protection&pageSize=100" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
}

foreach ($Item in $Result.items) {
    if($Item.settings.'endpoint.threat-protection.exclusions.scanning'.value.Count -gt 0){
        Write-Output "`n---------------------------------"
        Write-Output $Item.name
        Write-Output "---------------------------------"
        $Item.settings.'endpoint.threat-protection.exclusions.scanning'.value | Format-Table -Property @{label='Type';e={$_.type}},@{label='Scan Mode';e={$_.scanMode}}, @{label='Value';e={$_.value}}
    }
}
