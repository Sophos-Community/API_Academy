# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Define URI for setting Global exclusions
$Uri = $DataRegion+"/endpoint/v1/settings/exclusions/scanning"

# Import data from CSV
Write-Output "Importing global exclusions from CSV..."
Write-Output ""
$ImportFile = Import-Csv $PSScriptRoot\exclusions.csv

# Iterate through all exclusions from CSV
Write-Output "Creating global exclusions in Sophos Central..."
Write-Output ""

foreach ($Item in $ImportFile){
    # Create request body by converting to JSON
    $Body = $Item | ConvertTo-Json

    # Invoke Request
    $Result = (Invoke-RestMethod -Uri $Uri -Method Post -ContentType "application/json" -Headers $TenantHead -Body $body -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    Write-Output "Created global exclusion: $($Result.value) with ID $($Result.id)"
}

Write-Output ""
Write-Output "Successfully created global exclusions in Sophos Central..."
