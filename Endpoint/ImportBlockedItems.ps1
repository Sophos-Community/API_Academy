# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Define URI for updating the local site list
$Uri = $DataRegion+"/endpoint/v1/settings/blocked-items"

# Import data from CSV
Write-Output "Importing SHA256 values from CSV..."
Write-Output ""
$importFile = Import-Csv $PSScriptRoot\SHA256_hashes.csv

# Iterate through all sites from CSV
Write-Output "Creating blocked items in Sophos Central..."
Write-Output ""

foreach ($Item in $ImportFile){
    $Body = '{ "type": "sha256", "properties": { "sha256": "' + $Item.SHA256 + '" }, "comment": "' + $Item.Comment + '" }'

    # Invoke Request
    try {
        $Result = (Invoke-RestMethod -Uri $Uri -Method Post -ContentType "application/json" -Headers $TenantHead -Body $Body -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
        Write-Output "Created blocked item for '$($Result.comment)' with ID $($Result.id)"
    } catch {
        $WebError = ($_.ErrorDetails.Message | ConvertFrom-Json).message
        Write-Output "Blocked item '$($Item.comment)' --> $($WebError)"
    }
    
}
Write-Output ""
Write-Output "Successfully created local sites in Sophos Central..."
