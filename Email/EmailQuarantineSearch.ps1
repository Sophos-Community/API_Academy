# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# Create table for storing quarantine data
$Quarantine = New-Object System.Data.Datatable
[void]$Quarantine.Columns.Add("When")
[void]$Quarantine.Columns.Add("From")
[void]$Quarantine.Columns.Add("To")
[void]$Quarantine.Columns.Add("Reason")
[void]$Quarantine.Columns.Add("Attachments")
[void]$Quarantine.Columns.Add("Subject")

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization", "Bearer $Token")
$TenantHead.Add("X-Tenant-ID", "$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Calc last 30 days for the query in UTC format
$currtime = Get-Date
$fromtime = $currtime.AddDays(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.FFFZ")
$tilltime = $currtime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.FFFZ")

try {
    $TenantBody = '{ "beginDate": "' + $fromtime + '", "endDate": "' + $tilltime + '" }'

    do {
        $Request = (Invoke-RestMethod -Method Post -Uri $DataRegion"/email/v1/quarantine/messages/search" -Headers $TenantHead -Body $TenantBody -ErrorAction SilentlyContinue -ErrorVariable ScriptError)   
        foreach ($Item in $Request.Items) {
            if ($Item.attachments.total -ne 0) {
                $QuarantinedAt = $Item.quarantinedAt
                $From = $Item.from.domainAddress
                $To = $Item.to.localaddress + '@' + $Item.to.domainAddress
                $Subject = $Item.subject
                $Reason = $Item.reason
                $Attachments = ""

                foreach ($AttItem in $Item.attachments.items) {
                    if ($Attachments -ne "") {
                        $Attachments += "`n"    
                    }
                    if ($AttItem.stripped) {
                        $Attachments += $AttItem.name + " (size: " + $AttItem.sizeInBytes + ") STRIPPED"
                    } else {
                        $Attachments += $AttItem.name + " (size: " + $AttItem.sizeInBytes + ")"
                    }
                }
                [void]$Quarantine.Rows.Add($QuarantinedAt, $From, $to, $Reason, $Attachments, $Subject)
            }
        }
        $TenantBody = '{ "beginDate": "' + $fromtime + '", "endDate": "' + $tilltime + '", "pageFromKey": "' + $Request.Pages.nextKey + '" }'
    } while ($null -ne $Request.Pages.nextKey)

} catch {
    # Something went wrong, get error details...
    Write-Host "   --> $($_)"
}

Write-Output "Attachments in the quarantine:"
Write-Output $Quarantine | Format-Table -wrap
