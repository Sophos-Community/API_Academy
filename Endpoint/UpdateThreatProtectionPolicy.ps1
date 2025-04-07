# Enables SSL/TLS decryption and QUIC blocking in all Threat Protection policies

# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Define URI for updating the local site list
$Uri = $DataRegion+"/endpoint/v1/policies?pageTotal=true&pageSize=200&policyType=threat-protection"

# Get all Threat Endpoint Protection Policies
$Policies = (Invoke-RestMethod -Method Get -Uri $Uri -Headers $tenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

# Define action to enable Deep Learning
$Body = '{ "settings": { "endpoint.threat-protection.web-control.tls-decryption.enabled": { "value": true },"endpoint.threat-protection.web-control.tls-decryption.quic.enabled": {	"value": true }}}'

Write-Output "Scanning for Threat Protection policies with SSL/TLS Inspection & QUIC Blocking deactivated..."
foreach ($Policy in $Policies.items) {

    $ModifyPolicy = $false

    if ($false -eq $Policy.settings.'endpoint.threat-protection.web-control.tls-decryption.enabled'.value) {
        Write-Output "+ SSL/TLS Inspection is not active in the $($PolicyType) '$($Policy.name)' policy --> activating..."
        $ModifyPolicy = $True
    }
    
    if ($false -eq $Policy.settings.'endpoint.threat-protection.web-control.tls-decryption.quic.enabled'.value) {
        Write-Output "+ QUIC Blocking is not active in the $($PolicyType) '$($Policy.name)' policy --> activating..."
        $ModifyPolicy = $True
    }

    if ($ModifyPolicy) {
        $PolicyID = $Policy.id
        $Uri = $DataRegion + "/endpoint/v1/policies/" + $PolicyID
        $Result = (Invoke-RestMethod -Method Patch -Uri $Uri -Body $Body -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
        Write-Output "+-> Policy updated!"
    } else {
        Write-Output "+ Policy '$($Policy.name)' matches required settings --> no action needed..."
    }
}

Write-Output "" "Policy Scan completed"
