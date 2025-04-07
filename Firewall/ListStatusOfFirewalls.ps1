# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

Write-Output "Getting firewall information for Sophos Central..."
Write-Output ""
	
# SOPHOS API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization", "Bearer $Token")
$TenantHead.Add("X-Tenant-ID", "$TenantID")

if ($null -ne $DataRegion){
	# Post Request to Firewall API:
	$Result = (Invoke-RestMethod -Method Get -Uri $DataRegion"/firewall/v1/firewalls" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
}

#Output in table format
$Result.items | Format-Table -Property  @{label='Hostname';e={$_.hostname}},@{label='Firewall Name';e={$_.name}},  
                                        @{label='Serial Number';e={$_.serialNumber}}, @{label='Firmware Version';e={$_.firmwareVersion}}, 
                                        @{label='Firewall Model';e={$_.model}}, @{label='Cluster Mode';e={$_.cluster.mode}}, @{label='Cluster status';e={$_.cluster.status}}, 
                                        @{label='Central Connection';e={$_.status.connected}}
