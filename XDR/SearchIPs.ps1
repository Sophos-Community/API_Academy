# add this code snippet to the auth code samples for Central (snippets 1)
# you will find a line that says INSERT CODE HERE
# NOTE: You must replace the two instances of UN#I#ON with UNION before you use this snippet.

Write-Output "[XDR] Search for devices that connected to specific IP addresses."
Write-Output "      You can search multiple addresses by separting them with a |."
Write-Output "      You can search partial addresses."
Write-Output ""

do {
    $IPAddress = [string](Read-Host -Prompt 'Enter you search text')
} while ($IPAddress.Length -lt 1)

# Calculate last 30 days for the query in UTC format
$currtime = Get-Date
$fromtime = $currtime.AddDays(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.FFFZ")
$tilltime = $currtime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.FFFZ")

# SOPHOS XDR API Headers:
$XDRHead = @{}
$XDRHead.Add("Authorization", "Bearer $Token")
$XDRHead.Add("X-Tenant-ID", "$TenantID")
$XDRHead.Add("Content-Type", "application/json")


$template = @"
    WITH addresses AS (

        SELECT meta_hostname AS Hostname, query_name AS QueryName, address AS Address , 0 AS Port, '' AS Name, '' AS CmdLine
        FROM xdr_data
        WHERE query_name = 'arp_cache'

        UN#I#ON ALL
        
        SELECT meta_hostname, query_name, destination_ip, destination_port, '', ''
        FROM xdr_data
        WHERE query_name = 'sophos_ips_windows'
    
        UN#I#ON ALL    

        SELECT meta_hostname, query_name, remote_address, remote_port, name, cmdline
        FROM xdr_data
        WHERE query_name = 'open_sockets' AND name <> 'Idle'
    )

    SELECT distinct Hostname, Address
    FROM addresses
    WHERE regexp_like(address, '($IPAddress)')
    ORDER BY Hostname
"@ -replace "(?m)^\s+"  -replace "`r","" -replace "`n","\n"

$body= '{ "adHocQuery": { "template": "' + $template + '" }, "from": "' + $fromtime + '" , "to": "' + $tilltime + '" }'

# Query Data Lake 
Write-Output ""
Write-Output "[XDR] Send Request to find occurrances of specified IP searchmask..."
if ($null -ne $DataRegion) {
    $XDR_Response = (Invoke-RestMethod -Method POST -Uri $DataRegion"/xdr-query/v1/queries/runs" -Headers $XDRHead -Body $Body)
    Write-Output "[XDR] Request sent wait for results..."

    While ($XDR_Response.status -ne "finished") {
        start-sleep -s 5
        $XDR_Response = (Invoke-RestMethod -Method Get -Uri $DataRegion"/xdr-query/v1/queries/runs/$($XDR_Response.id)" -Headers $XDRHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    }

    if ($XDR_Response.result -eq "succeeded") {
        Write-Output("[XDR] Query finished, retreiving results")
        $XDR_Response = (Invoke-RestMethod -Method Get -Uri $DataRegion"/xdr-query/v1/queries/runs/$($XDR_Response.id)/results?pageSize=2000" -Headers $XDRHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
        Write-Output ""

        if($XDR_Response.count -eq 0) {
            Write-Output "[XDR] Request completed, no entries were found!"
        } else {
            Write-Output("[XDR] Query details for IP search mask:")
            $XDR_Response.items | Format-Table -Property hostname, address
            Write-Output "[XDR] Request completed, $($XDR_Response.Items.Count) entries were found!"

            Write-Output("[XDR] Query summary:")
            $Hostnames = $XDR_Response.items | Select-Object 'hostname' -unique | Sort-Object 'hostname' 
            $Hostnames.hostname -join ', ' 
        }
    } else {
        Write-Output ("[XDR] Request failed!")
        Write-Output ($XDR_Response)
    }
}
