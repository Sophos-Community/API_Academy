# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Creating group for imported users
Write-Output "Creating new group for imported users"
Write-Output ""

# Define Object 
$Body = @{}
$Body.Add("name", "Imported Users")
$Body.Add("description", "Group for imported users")

# Convert Object to JSON Format
$Body = $Body | ConvertTo-Json

 # Set correct URI
$uri = $DataRegion+"/common/v1/directory/user-groups"

# Invoke Request
$Result = (Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Headers $TenantHead -Body $Body -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

# Store group result for next requests
$GroupID = @($Result.id)

Write-Output "Importing users from CSV..."
Write-Output ""

# Import data from CSV
$ImportFile = Import-Csv $PSScriptRoot\importUser.csv

Write-Output "Creating users in Sophos Central..."
Write-Output ""

# Iterate through all users
foreach ($Item in $ImportFile){
	
	# Add the groupID add the users to the imported users group
	$Item | Add-Member -NotePropertyName groupIds -NotePropertyValue $GroupID

	# Create request body by converting to JSON
	$Body = $Item | ConvertTo-Json

	 # Set correct URI
	$uri = $DataRegion+"/common/v1/directory/users"

	# Invoke Request
	$Result = (Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Headers $TenantHead -Body $Body -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

	Write-Output "Created User: $($Result.name) with ID $($Result.id)"

}
Write-Output ""
Write-Output "Successfully created users in Sophos Central..."
