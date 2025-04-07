# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

$EndpointList = @()
$NextKey = $null

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

do {
    $GetEndpoints = (Invoke-RestMethod -Method Get -Uri $DataRegion"/endpoint/v1/endpoints?pageTotal=true&pageFromKey=$NextKey&fields=hostname,tamperProtectionEnabled,health,os&view=summary&sort=healthStatus" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    $NextKey = $GetEndpoints.pages.nextKey

    $EndpointList += $GetEndpoints.items
} while ($null -ne $NextKey)      

Write-Output $EndpointList | Format-Table -Property @{label='Name';e={$_.Hostname}}, 
                                                    @{label='TP Status';align='right';e={$_.tamperProtectionEnabled}},
                                                    @{label='Health Overall';align='right';e={$_.health.overall}}, 
                                                    @{label='Health Threats';align='right';e={$_.health.threats.status}}, 
                                                    @{label='Health Services';align='right';e={$_.health.services.status}}, 
                                                    @{label='OS';e={$_.os.name}}
