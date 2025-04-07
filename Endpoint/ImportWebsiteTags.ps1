# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Define URI for updating the local site list
$Uri = $DataRegion+"/endpoint/v1/settings/web-control/local-sites"


# Import data from CSV
Write-Output "Importing sites from CSV..."
Write-Output ""
$importFile = Import-Csv $PSScriptRoot\websites.csv

# Iterate through all sites from CSV
Write-Output "Creating local sites in Sophos Central..."
Write-Output ""

foreach ($Item in $ImportFile){

    # Split string in case of multiple tags
    $Tags = @($Item.tags.split("{;}"))

    # Change tags into an array
    $Item.PSobject.Properties.Remove('tags')
	$Item | Add-Member -NotePropertyName tags -NotePropertyValue $Tags
    
    # Create request body by converting to JSON
    $Body = $Item | ConvertTo-Json

    # Invoke Request
    $Result = (Invoke-RestMethod -Uri $Uri -Method Post -ContentType "application/json" -Headers $TenantHead -Body $Body -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    Write-Output "Created Site: $($Result.url) with ID $($Result.id)"
    
}
Write-Output ""
Write-Output "Successfully created local sites in Sophos Central..."
