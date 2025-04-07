# add this code snippet to the auth code samples for Central (snippets 1)
# you will find a line that says INSERT CODE HERE

##### Device Isolation Start #####

$EndpointList = @()
$NextKey = $null

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Retrieve list of endpoints that match our search string
do {
    $GetEndpoints = (Invoke-RestMethod -Method Get -Uri $DataRegion"/endpoint/v1/endpoints?pageTotal=true&isolationStatus=notIsolated&fields=hostname,type,os,isolation&pageFromKey=$NextKey" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    $NextKey = $GetEndpoints.pages.nextKey

    $EndpointList += $GetEndpoints.items
} while ($null -ne $NextKey)      

# Display results
Write-Output "Total number of devices found: $($EndpointList.Count)"
Write-Output ""
Write-Output "Which devices do you want to isolate?"
do {
    $Hostname = [string](Read-Host -Prompt 'Enter the hostname search string (wildcard allowed)')
} while ($Hostname.Length -lt 1)

$SelectList = @()
$SelectList += $EndpointList | Where-Object -Property "Hostname" -Like "*$($Hostname)*"

if ($SelectList.Count -gt 50) {
    Write-Output "This script support isolating up to 50 devices at once."
    Write-Output "We however found $($SelectList.Count) devices that match."
    Write-Output "Script aborted"
} elseif ($SelectList.Count -gt 0) {
    Write-Output "Number of Endpoints to isolate: $($SelectList.Count)"
    write-output ""
    write-output "Hostname(s) of devices to be isolated:"
    Write-Output ($SelectList.hostname -join ', ')
    write-output ""

    # Get confirmation that these devices should be isolated
    do {
        $Isolate = Read-Host 'Isolate selected devices (Y/N)'
    } while (-not (($Isolate -eq "y") -or ($Isolate -eq "n")))

    if ($Isolate -eq "y") {
        # EndpointList must be an array even when it only contains one object
        if ($SelectList.Count -eq 1) {
            $Body = '{ "enabled": true, "comment": "Isolating endpoints using API","ids": [' + ($SelectList.id | ConvertTo-Json) + '] }' 
        } else {
            $Body = '{ "enabled": true, "comment": "Isolating endpoints using API","ids": ' + ($SelectList.id | ConvertTo-Json) + ' }' 
        }
    
        try {
            $Result = (Invoke-RestMethod -Method Post -Uri $DataRegion"/endpoint/v1/endpoints/isolation" -Body $Body -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
            Write-Output  "Device isolation triggered!"
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
