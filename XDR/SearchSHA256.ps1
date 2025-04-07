# This will search PE and productivity documents
# add this code snippet to the auth code samples for Central (snippets 1)
# you will find a line that says INSERT CODE HERE
# NOTE: You must replace the two instances of UN#I#ON with UNION before you use this snippet.

Write-Output "[XDR] Search for SHA256 ocurrances within the Data Lake."
Write-Output "      You can search multiple SHA-values by separting them with a |."
Write-Output ""

do {
    $SHA256 = [string](Read-Host -Prompt 'Enter the SHA256 value to look for')
} while ($SHA256.Length -lt 1)

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
    WITH Connection_Info AS (

        SELECT DISTINCT meta_hostname, path, query_name, count(*)
        FROM xdr_data  
        WHERE query_name IN ('open_sockets') 
        GROUP BY meta_hostname, path, query_name
        
        UN#I#ON ALL
    
        SELECT DISTINCT meta_hostname, path, query_name, count(address)
        FROM xdr_data  
        WHERE query_name IN ('listening_ports') 
            AND address NOT IN ('::1', '0.0.0.0', '::')
            AND path <> ''
        GROUP BY meta_hostname, path, query_name
        
        UN#I#ON ALL
        
        SELECT DISTINCT x1.meta_hostname, x2.new_pid, x1.query_name, count(*)
        FROM xdr_data AS x1
        CROSS JOIN 
        UNNEST(SPLIT(x1.sophos_pids, ',')) AS x2(new_pid)
        WHERE x1.query_name IN ('sophos_ips_windows', 'sophos_urls_windows')
        GROUP BY meta_hostname, new_pid, query_name
    )
    
    SELECT DISTINCT sha256, meta_hostname AS hostname, query_name, path,
    CASE query_name
        WHEN 'access_productivity_documents' THEN 'N/A'
        ELSE IF((select count(*) from Connection_Info AS ci WHERE (ci.path = xd.path AND ci.meta_hostname = xd.meta_hostname) OR ci.path = xd.sophos_pid) > 0,'Yes','No')
    END AS used_network
    FROM xdr_data AS xd
    WHERE regexp_like(sha256, '($SHA256)')
    ORDER BY sha256
"@ -replace "(?m)^\s+"  -replace "`r","" -replace "`n","\n"

$body= '{ "adHocQuery": { "template": "' + $template + '" }, "from": "' + $fromtime + '" , "to": "' + $tilltime + '" }'


# Query Data Lake 
Write-Output "[XDR] Send Request to run Ad-Hoc Query for finding occurrances of specified SHA256 values..."
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

        Write-Output("[XDR] Query results:")
        $XDR_Response.items | Format-Table -Property sha256, hostname, path, query_name, used_network
        Write-Output "[XDR] Request completed, $($XDR_Response.Items.Count) entries were found!"
    } else {
        Write-Output ("[XDR] Request failed!")
        Write-Output ($XDR_Response)
    }
}
