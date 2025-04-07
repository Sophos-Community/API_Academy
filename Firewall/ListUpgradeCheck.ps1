# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# Create table for storing results
$FirewallTable = New-Object System.Data.Datatable
[void]$FirewallTable.Columns.Add("Serial")
[void]$FirewallTable.Columns.Add("Hostname")
[void]$FirewallTable.Columns.Add("Label")
[void]$FirewallTable.Columns.Add("Current Firmware")
[void]$FirewallTable.Columns.Add("Upgrade to")

# SOPHOS API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization", "Bearer $Token")
$TenantHead.Add("X-Tenant-ID", "$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Post Request to Firewall API:
$FWList = (Invoke-RestMethod -Method Get -Uri $DataRegion"/firewall/v1/firewalls" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

foreach ($FW in $FWList.items) {

    # Only check firewall with Firewall Management active
    if ($null -ne $FW.status.managingStatus) {

        $Body = '{ "firewalls": ["'+$FW.id+'"]}'

        try {
            $FWCheck = (Invoke-RestMethod -Method POST -Uri $DataRegion"/firewall/v1/firewalls/actions/firmware-upgrade-check" -Headers $TenantHead -Body $Body)

            $UpgradeTo = ""
            Foreach ($FWVersion in $FWCheck.firmwareVersions ){	
                if ($UpgradeTo -ne "") {
                    $UpgradeTo = $UpgradeTo + "`n"    
                }
                $UpgradeTo = $UpgradeTo + $FWVersion.version + " (size: " + $FWVersion.size + ")" + " "+ $FWVersion.news[0]
            }

            [void]$FirewallTable.Rows.Add($FW.serialNumber,$FW.hostname, $FW.name, $FW.firmwareVersion, $UpgradeTo)

        } catch {
            # No result found --> Central Firewall Management not active!
        }
    }
}

# Display the results 
Write-Output $FirewallTable | Format-Table -wrap
