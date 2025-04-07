# Requires central admin rights
# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# List all Installers sorted by PLatform and Platform Type
$Getinstallers = (Invoke-RestMethod -Method Get -Uri $DataRegion"/endpoint/v1/downloads" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
Write-Output $GetInstallers.Installers | Format-Table @{label='Product Name';e={$_.productName}},
                                                      @{label='Platform';e={$_.platform}},
                                                      @{label='Type';e={$_.type}},
                                                      @{label='Link';e={$_.downloadUrl}}
