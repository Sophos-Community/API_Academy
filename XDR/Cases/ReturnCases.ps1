# add this code snippet to the auth code samples for Central (snippets 1)
# you will find a line that says INSERT CODE HERE

$Cases_Total = 0
$Cases_Critical = 0
$Cases_High = 0
$Cases_Medium = 0
$Cases_Low = 0
$Cases_Info = 0
$Cases_Unknown = 0

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization", "Bearer $Token")
$TenantHead.Add("X-Tenant-ID", "$TenantID")
$TenantHead.Add("Content-Type", "application/json")

try {
    Write-Output("[Cases] Retreive cases created in the last 30 days...")
    $Cases = (Invoke-RestMethod -Method get -Uri $DataRegion"/cases/v1/cases?createdAfter=-P30D&pageSize=5000" -Headers $TenantHead  -ErrorAction SilentlyContinue -ErrorVariable ScriptError)   

    foreach ($Case in $Cases.items) {
        $Cases_Total += 1

        switch ($Case.severity) {
            "Informational" {$Cases_Info += 1}
            "low"           {$Cases_Low += 1}
            "medium"        {$Cases_Medium += 1}
            "high"          {$Cases_Higg += 1}
            "critical"      {$Cases_Critical += 1}
            Default         {$Cases_Unknown += 1}
        }
    }

    Write-Output("")
    Write-Output("[Cases] Details:")
    $Cases.items | Format-Table -Property `
        @{label='Severity';e={$_.severity}},
        @{label='Case ID';e={$_.id}}, 
        @{label='Status';e={$_.status}}, 
        @{label='Assignee';e={$_.assignee.name}}, 
        @{label='Name';e={$_.name}}, 
        @{label='Managed By';e={$_.managedBy}},
        @{label='Case type';e={$_.type}}

    Write-Output("[Cases] Summary:")
    Write-Output("$($Cases_Critical) (Critical) + $($Cases_High) (High) + $($Cases_Medium) (Medium) + $($Cases_Low) (Low) + $($Cases_Info) (Info) + $($Cases_Unknown) (Not classified yet)")
    Write-Output("$($Cases_Total) Cases total")

} catch {
    # Something went wrong, get error details...
    Write-Host "   --> $($_)"
}
