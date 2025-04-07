# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# SOPHOS API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization", "Bearer $Token")
$TenantHead.Add("X-Tenant-ID", "$TenantID")
$TenantHead.Add("Content-Type", "application/json")

if ($null -ne $DataRegion){
        
    ###################################################################################################################################
    # Runs an adHoc query against the Sophos Data Lake via the XDR API
    ###################################################################################################################################
    Write-Host("`n===============================================================================")
    Write-Host("[Data Lake] Running adHoc query...")
    Write-Host("===============================================================================")
    
    # Define Query in easily readable form and then format it for XDR
    $Template = @" 
        # INSERT YOUR QUERY HERE 
"@ -replace "(?m)^\s+"  -replace "`r","" -replace "`n","\n"

    # If your query uses variables then define them here, for example:
    # $variables = '[{"name": "device_name","dataType": "text","value": "%"}]'
    $Variables = ''

    # Specify desired time range for the query
    $Currtime = Get-Date
    $Fromtime = $Currtime.AddDays(-7).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.FFFZ")
    $Tilltime = $Currtime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.FFFZ")

    # Construct body
    if ($Variables -eq '') {
        $Body = '{"adHocQuery": { "template": "' + $Template + '" },"from": "'+$Fromtime+'","to": "'+$Tilltime+'"}'
    } else {
        $Body = '{"adHocQuery": { "template": "' + $Template + '" },"from": "'+$Fromtime+'","to": "'+$Tilltime+'","variables": '+$Variables+'}'
    }

    $Response = (Invoke-RestMethod -Method POST -Uri $DataRegion"/xdr-query/v1/queries/runs" -Headers $TenantHead -Body $Body)              

    While ($Response.status -ne "finished") {
        start-sleep -s 1
        $Response = (Invoke-RestMethod -Method Get -Uri $DataRegion"/xdr-query/v1/queries/runs/$($Response.id)" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)   
    }

    if ($Response.result -eq "succeeded") {
        $Response = (Invoke-RestMethod -Method Get -Uri $DataRegion"/xdr-query/v1/queries/runs/$($Response.id)/results?maxSize=1000" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
        
        # plain output of the response, if you need the results formatted then use | format-table
        $Response.items 
    } else {
        Write-Output ("Request failed!")
        Write-Output ($Response)
    }
}
