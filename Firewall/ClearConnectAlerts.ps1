# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

if ($null -ne $DataRegion){
	# Post Request to SOPHOS for Endpoint API:
	$AllAlertResult = (Invoke-RestMethod -Method Get -Uri $DataRegion"/common/v1/alerts?sort=raisedAt&product=firewall&category=connectivity&pageSize=1000" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
}

# Get the last date/time where the Firewall restored its connection:
$alertLastResolved = @{}
foreach ($alert in $AllAlertResult.items) {
	if (($alert.type -eq "Event::Firewall::FirewallGatewayUp") -or ($alert.type -eq "Event::Firewall::Reconnected")) {

        if (-not $alertLastResolved.Contains($alert.managedAgent.id)) {
            $alertLastResolved.Add(($alert.managedAgent.id),($alert.raisedAt))
        } else {
            $alertLastResolved[$alert.managedAgent.id] = $alert.raisedAt
        }
	}
}

# Clear all connection alerts for the firewall that are older then the last connection restored entry:
foreach ($alert in $AllAlertResult.items) {
	if ($alert.raisedAt -le $alertLastResolved[$alert.managedAgent.id]) {

        $Body = "{""action"":""acknowledge""}"
		$uri = $DataRegion+"/common/v1/alerts/"+$alert.id+"/actions"

		# Post Request to SOPHOS Details:
		$Result = (Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Headers $TenantHead -Body $Body -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
	}
}
