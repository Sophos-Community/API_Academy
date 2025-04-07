# Uses tags from ImportWebsiteTag.ps1

# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Define URI for updating the local site list
$Uri = $DataRegion+"/endpoint/v1/policies?pageTotal=true&policyType=web-control"


# Get all Web Control Policies
$Policies = (Invoke-RestMethod -Method Get -Uri $Uri -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

# Define what happens when the "Warnen", "Erlauben" und "Blockieren" custom tags are used
$Body = '{ "settings": { "endpoint.web-control.tags.settings": { "value": [  
                { "tag": "Warn", "action": "warn" }, 
                { "tag": "Allow", "action": "allow" }, 
                { "tag": "Block", "action": "block" }
            ]}}}'

# Find the base policy which has oriority 0
Write-Output "Scanning policies for the Web Control Base Policy..."
foreach ($Policy in $Policies.items) {
    if ($Policy.priority -eq 0) {

        $PolicyID = $Policy.id
        $Uri = $DataRegion + "/endpoint/v1/policies/" + $PolicyID

        Write-Output "Adding tags to the base policy for Web Control..."
        $Result = (Invoke-RestMethod -Method Patch -Uri $Uri -Body $Body -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
        Write-Output "Base Policy Updated"
    }
}
