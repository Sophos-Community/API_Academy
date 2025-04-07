# add this code snippet to the auth code samples for Central (snippets 1)
# you will find a line that says INSERT CODE HERE

##### Device Isolation Stop #####

$EndpointList = @()
$NextKey = $null

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Retrieve list of endpoints that are isolated
do {
    $GetEndpoints = (Invoke-RestMethod -Method Get -Uri $DataRegion"/endpoint/v1/endpoints?pageTotal=true&isolationStatus=isolated&fields=hostname,type,os,isolation&pageFromKey=$NextKey" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    $NextKey = $GetEndpoints.pages.nextKey

    $EndpointList += $GetEndpoints.items
} while ($null -ne $NextKey)      

# Display results
Write-Output "Number of isolated devices found: $($EndpointList.Count)"

if ($EndpointList.Count -eq 0) {
    Write-Output "No isolated devices found, aborting script..."
    Exit
}

write-output "Hostname(s) of isolated devices:"
Write-Output ($EndpointList.hostname -join ', ')
write-output ""

# Define pattern to search for
Write-Output "Select devices do you want to remove from isolation?"
do {
    $Hostname = [string](Read-Host -Prompt 'Enter the search string (wildcard allowed)')
} while (($Hostname.Length -lt 1) -or ($Hostname.Length -gt 10))

$SelectList = @()
$SelectList += $EndpointList | Where-Object -Property "Hostname" -Like "*$($Hostname)*"
write-output ""

if ($SelectList.Count -gt 50) {
    Write-Output "This script supports removing up to 50 devices from isolation at once."
    Write-Output "We however found $($SelectList.Count) devices that match."
    Write-Output "Script aborted"
} elseif ($SelectList.Count -gt 0) {
    Write-Output "Number of devices selected: $($SelectList.Count)"
    write-output "Hostname(s) of devices to be removed from isolation:"
    Write-Output ($SelectList.hostname -join ', ')
    write-output ""

    # Get confirmation that these devices should be removed from isolation
    do {
        $Isolate = Read-Host 'Remove selected devices from isolation (y/n)'
    } while (-not (($Isolate -eq "y") -or ($Isolate -eq "n")))

    if ($Isolate -eq "y") {
        # EndpointList must be an array even when it only contains one object
        if ($EndpointList.Count -eq 1) {
            $Body = '{ "enabled": false, "comment": "Isolating endpoints using API","ids": [' + ($EndpointList.id | ConvertTo-Json) + '] }' 
        } else {
            $Body = '{ "enabled": false, "comment": "Isolating endpoints using API","ids": ' + ($EndpointList.id | ConvertTo-Json) + ' }' 
        }

        # Remove devices from isolation
        try {
            $Result = (Invoke-RestMethod -Method Post -Uri $DataRegion"/endpoint/v1/endpoints/isolation" -Body $Body -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
            Write-Output  "Device removal from isolation triggered!"
        } catch {
            Write-Output  "Something went wrong, status code: $($_.Exception.Response.StatusCode.value__)"
            break
        }
    } else {
        Write-Output "Process aborted..."
    }
} else {
    Write-Output "No devices found that match the search string"
}
