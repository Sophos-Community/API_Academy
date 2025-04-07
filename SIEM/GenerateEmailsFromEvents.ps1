param ([switch] $SaveCredentials)
<#
    Description: Generate Emails for specific events
    Parameters: -SaveCredentials -> will store then entered credentials locally on the PC, this is needed when
                                    running the script unattended
#>

Function SendMail {
    param([parameter(Mandatory)]$Subject, [parameter(Mandatory)]$Body)

    # Please note that you have to prepare your Gmail account accordingly. 
    # To be able to sent emails you namely have to activate MFA within your Gmail account and 
    # once this has been done create an application password, for more details see: 
    # https://support.google.com/accounts/answer/185833?hl=en.  

    $SmtpSrvr = "smtp.gmail.com"
    $SmtpPort = 587
    $SmtpUser = "your@gmail.com"
    $SmtpRcpt = "recipient@company.com"
    $SmtpPass = "apppassword"
    
    # Create MailMessage because it allows HTML content
    $Message = New-Object System.Net.Mail.MailMessage
    $Message.From = $SmtpUser
    $Message.To.Add($SmtpRcpt)
    $Message.Subject = $Subject
    $Message.IsBodyHtml = $true
    $Message.Body = $Body

    # Create the SmtpClient object and send the Email
    $Smtp = New-Object Net.Mail.SmtpClient($SmtpSrvr, $SmtpPort)
    $Smtp.EnableSsl = $true
    if ($SmtpPass -ne "") {
        $Smtp.Credentials = New-Object System.Net.NetworkCredential( $SmtpUser, $SmtpPass );
    }
    $Smtp.Send($Message)
}

# Sophos Logo for Embedding in Emails
$SophosLogo = '<img alt="Sophos Central" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAOEAAABRCAMAAAATpzE9AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEh
ZcwAADsMAAA7DAcdvqGQAAAL0UExURQAAAAD//wB//wCq/wB//wCZzAB/1ACR2gB/3wCNxgB/zACL0AB/1ACJ1wB/yACIzAB/zwCH0gB/xgCGyQB/zACFzgB/0ACFxwB/yQB6ywB/zQB6xgB/yAB7ygB/zAB7zQ
B/xwB7yAB/ygB7ywB/xgB8xwB/yQB8ygB/zAB8xwB/yAB8yQB/ygB8xgB/xwB8yAB6yQB8ygB6xgB9yAB6yQB9ygB6xgB9xwB6yAB9yQB7ygB9xgB7xwB9yAB7yQB9xgB7xwB9yAB7yAB9yQB7xgB9xwB7yAB6y
QB7xgB6xwB6yAB8yQB6xgB6yAB8yAB6xgB8xwB6xwB8yAB7xgB8xgB7xwB8xwB7yAB8xgB7xgB8xwB7yAB6xgB7xgB6xwB7xwB6yAB7xgB6xgB7xwB6yAB7xgB6xgB7xwB6xwB7yAB6xgB7xgB6xwB8xwB6xgB8
xgB7xwB8xwB7yAB6xgB7xgB6xwB6xgB7xgB6xwB7xwB6xwB7xgB6xgB7xwB6xwB7xgB6xgB7xgB6xwB7xwB6xgB7xgB6xwB7xwB6xgB6xgB6xgB6xwB7xwB6xgB7xgB6xwB7xwB6xgB7xgB6xgB7xwB6xwB7xgB
6xgB7xwB6xwB7xgB6xgB7xgB6xwB7xwB6xgB6xgB6xwB6xwB6xgB6xgB6xgB6xwB7xgB6xgB7xgB6xgB7xwB6xgB7xgB6xgB7xwB6xgB7xgB6xgB7xgB6xwB7xgB6xgB6xgB6xwB6xgB6xgB6xgB6xgB6xwB6xg
B6xgB6xgB6xwB6xgB6xgB6xgB7xwB6xgB7xgB6xgB7xwB6xgB7xgB6xgB6xgB6xwB6xgB6xgB6xgB6xgB6xgB6xgB6xgB6xgB6xwB6xgB6xgB6xgB6xgB6xgB6xgB6xgB6xgB7xwB6xgB7xgB6xgB6xgB6xgB6x
gB6xgB6xgB6xwB6xgB6xgB6xgB6xgB6xgB6xgB6xgB6xgB6xwB6xgB6xgB6xgB6xgB6xgB6xgB6xgB6xgB6xgcWjccAAAD7dFJOUwABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4fICEiIyQlJicoKSor
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" />'
$MailCount = 0

Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos - Generate Emails for specific events"
Write-Output "==============================================================================="

# Define the filename and path for the credential file
$CredentialFile = $PSScriptRoot + '\Sophos_Central_Admin_Credentials.json'

# Check if Central API Credentials have been stored, if not then prompt the user to enter the credentials
if (((Test-Path $CredentialFile) -eq $false) -or $SaveCredentials){
	# Prompt for Credentials
	$ClientId = Read-Host "Please Enter your Client ID"
	$ClientSecret = Read-Host "Please Enter your Client Secret" -AsSecureString 
} else { 
    # Read Credentials from JSON File
    $Credentials = Get-Content $CredentialFile | ConvertFrom-Json
    $ClientId = $Credentials[0]
    $ClientSecret = $Credentials[1] | ConvertTo-SecureString
}

# We are making use of the PSCredentials object to store the API credentials
# The Client Secret will be encrypted for the user excuting the script
# When scheduling execution of the script remember to use the same user context
$SecureCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList $ClientId , $ClientSecret

# SOPHOS OAuth URL
$AuthURI = "https://id.sophos.com/api/v2/oauth2/token"

# Body and Header for oAuth2 Authentication
$AuthBody = @{}
$AuthBody.Add("grant_type", "client_credentials")
$AuthBody.Add("client_id", $SecureCredentials.GetNetworkCredential().Username)
$AuthBody.Add("client_secret", $SecureCredentials.GetNetworkCredential().Password)
$AuthBody.Add("scope", "token")
$AuthHead = @{}
$AuthHead.Add("content-type", "application/x-www-form-urlencoded")

# Set TLS Version
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Post Request to SOPHOS for OAuth2 token
try {
    $Result = (Invoke-RestMethod -Method Post -Uri $AuthURI -Body $AuthBody -Headers $AuthHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    if ($SaveCredentials) {
	    $ClientSecret = $ClientSecret | ConvertFrom-SecureString
	    ConvertTo-Json $ClientID, $ClientSecret | Out-File $CredentialFile -Force
    }
} catch {
    # If there's an error requesting the token, say so, display the error, and break:
    Write-Output "" 
	Write-Output "AUTHENTICATION FAILED - Unable to retreive SOPHOS API Authentication Token"
    Write-Output "Please verify the credentials used!" 
    Write-Output "" 
    Write-Output "If you are working with saved credentials then you can reset them by calling"
    Write-Output "this script with the -SaveCredentials parameter"
    Write-Output "" 
    Read-Host -Prompt "Press ENTER to continue..."
    Break
}

# Set the Token for use later on:
$Token = $Result.access_token

# SOPHOS Whoami URI:
$WhoamiURI = "https://api.central.sophos.com/whoami/v1"

# SOPHOS Whoami Headers:
$WhoamiHead = @{}
$WhoamiHead.Add("Content-Type", "application/json")
$WhoamiHead.Add("Authorization", "Bearer $Token")

# Post Request to SOPHOS for Whoami Details:
$Result = (Invoke-RestMethod -Method Get -Uri $WhoamiURI -Headers $WhoamiHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

# Check if we are using tenant (Central Admin) credentials
if ($Result.idType -ne "tenant") {
    Write-Output "Aborting script - idType does not match tenant!"
    Break
}

# Save Response details
$TenantID = $Result.id
$DataRegion = $Result.ApiHosts.dataRegion

# SOPHOS Endpoint API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Load previously saved cursor so that we only process the latest events
try {
    $Cursor = Get-Content -Path "$($PSScriptRoot)\SIEM_Events_cursor.txt" -ErrorAction Stop
} catch {
    $Cursor = ""
}

# Event filter, only process events listed below
# Use https://support.sophos.com/support/s/article/KBA-000006285 for more event types
$ProcessEvents = @()
$ProcessEvents += "Event::Firewall::FirewallGatewayDown"
$ProcessEvents += "Event::Firewall::FirewallGatewayUp"
$ProcessEvents += "Event::Firewall::FirewallHAStateDegraded"
$ProcessEvents += "Event::Firewall::FirewallHAStateRestored"
$ProcessEvents += "Event::Endpoint::CorePuaDetection"
$ProcessEvents += "Event::Endpoint::HmpaPuaDetected"
$ProcessEvents += "Event::Endpoint::Threat::PuaDetected"

# Device filter, only process events for the following devices, use .* to include all devices 
# or enter multiple entries separated by |
$EndpointFilter = ".*"
$FirewallFilter = "C010012334568|C010019468345"

do {
    $GetEvents = (Invoke-RestMethod -Method Get -Uri $DataRegion"/siem/v1/events"$Cursor -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    $Cursor = "?limit=200&cursor=" + $GetEvents.next_cursor

    foreach ($Event in $GetEvents.items) {

        if ( $ProcessEvents -contains $Event.type) {

            if (($Event.endpoint_type -match 'server|computer') -And ($Event.location -match $EndpointFilter)) {
                $Subject = "[$($Event.severity)] Event for Sophos Central of type: $($Event.type)"
                $Body = "<p style=`"color:#808080`">This email was generated programatically. Please do not reply to this email</p>" + 
                "$($SophosLogo)<BR><BR><B>Sophos Central Event Details</B><BR><BR>" +
                "<B>What happened: </B>$($Event.name)<BR>" +
                "<B>Where it happened: </B>$($Event.location)<BR>" +
                "<B>When did it happen: </B>$($Event.when)<BR>" +
                "<B>User associated with device: </B>$($Event.source)<BR>" +
                "<B>How severe is it: </B>$($Event.severity)<BR><BR>"

                SendMail -Subject $Subject -Body $Body
                $MailCount++ 

            } elseif (-Not ($Event.endpoint_type -match 'server|computer') -And ($Event.location -match $FirewallFilter)) {
                $Subject = "[$($Event.severity)] Event for Sophos Central of type: $($Event.type)"
                $Body = "<p style=`"color:#808080`">This email was generated programatically. Please do not reply to this email</p>" + 
                "$($SophosLogo)<BR><BR><B>Sophos Central Event Details</B><BR><BR>" +
                "<B>What happened: </B>$($Event.name)<BR>" +
                "<B>Where it happened: </B>$($Event.location)<BR>" +
                "<B>When did it happen: </B>$($Event.when)<BR>" +
                "<B>How severe is it: </B>$($Event.severity)<BR><BR>"

                SendMail -Subject $Subject -Body $Body
                $MailCount++ 
            } 
        } 
    }
    
} while ($null -ne $NextKey)     

# Save cursor to ensure that we do process the same event multiple times
Set-Content -Path "$($PSScriptRoot)\CentralAdmin-EmailEvents.txt" -Value $Cursor

Write-Output "Number of Emails sent: $($MailCount)" 
