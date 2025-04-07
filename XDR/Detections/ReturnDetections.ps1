# add this code snippet to the auth code samples for Central (snippets 1)
# you will find a line that says INSERT CODE HERE

$Detections_Total = 0
$Detections_Critical = 0
$Detections_High = 0
$Detections_Medium = 0
$Detections_Low = 0
$Detections_Info = 0

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization", "Bearer $Token")
$TenantHead.Add("X-Tenant-ID", "$TenantID")
$TenantHead.Add("Content-Type", "application/json")

#Calc last 30 days for the query in UTC format
$currtime = Get-Date
$fromtime = $currtime.AddDays(-7).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.FFFZ")
$tilltime = $currtime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.FFFZ")

$TenantBody = '{ "from": "' + $fromtime + '", "to": "' + $tilltime + '"}'

try {
    Write-Output("[Detections] Send Request to retreive the detections from the last 7 days...")
    $Request = (Invoke-RestMethod -Method Post -Uri $DataRegion"/detections/v1/queries/detections" -Headers $TenantHead -Body $TenantBody -ErrorAction SilentlyContinue -ErrorVariable ScriptError)   
    Write-Output "[Detections] Request sent, wait for results..."

    do {
        Start-Sleep -Milliseconds 500
        $Request = (Invoke-RestMethod -Method Get -Uri $DataRegion"/detections/v1/queries/detections/$($Request.id)" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)   
    } while ($Request.Result -eq "notAvailable")
    Write-Output("[Detections] Request ready, retreiving results")

    $uri = "$($DataRegion)/detections/v1/queries/detections/$($Request.id)/results?pageSize=2000"
    $Detections =  (Invoke-RestMethod -Method Get -Uri $uri -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    foreach ($Detection in $Detections.items) {
        $Detections_Total += 1
        
        switch ($Detection.severity) {
            0 {$Detections_info += 0}
            1 {$Detections_Low += 1}
            2 {$Detections_Low += 1}
            3 {$Detections_Low += 1}
            4 {$Detections_Medium += 1}
            5 {$Detections_Medium += 1}
            6 {$Detections_Medium += 1}
            7 {$Detections_High += 1}
            8 {$Detections_High += 1}
            9 {$Detections_Critical += 1}
            10 {$Detections_Critical += 1}
        }
    }

    Write-Output("")
    Write-Output("[Detections] Details:")
    $Detections.items | Format-Table -Property `
        @{label='Severity';e={ if ($_.severity -eq 0) { "Info" } elseif ($_.severity -le 3) { "Low" } elseif ($_.severity -le 6) { "Medium" } elseif ($_.severity -le 8) { "High" } elseif ($_.severity -le 10) { "Critical" }}},
        @{label='Detection';e={$_.detectionRule}}, 
        @{label='time';e={$_.sensorGeneratedAt}}, 
        @{label='Host';e={$_.device.entity}}, 
        @{label='Sensor Type';e={$_.sensor.type}}, 
        @{label='MITRE Attack';e={$_.mitreAttacks.tactic.name}}

    Write-Output("[Detections] Summary:")
    Write-Output("$($Detections_Critical) (Critical) + $($Detections_High) (High) + $($Detections_Medium) (Medium) + $($Detections_Low) (Low) + $($Detections_Info) (Info)")
    Write-Output("$($Detections_Total) detections total")

} catch {
    # Something went wrong, get error details...
    Write-Host "   --> $($_)"
}
