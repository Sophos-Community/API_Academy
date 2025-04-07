param ([switch] $SaveCredentials, [switch] $IP, [switch] $IPfile, [Switch] $SHA, [Switch] $SHAfile, [switch] $URL, [switch] $URLfile, [string] $LookupValue)
<#
    Description: Perform an SophosLabs Intelix Lookup for a URL, IP, SHA256
    Parameters: -SaveCredentials -> will store the entered credentials locally on the PC
                -IP, -IPfile -SHA, -SHAfile, -URL, -URLfile -> define which lookup to perform 
                -LookupValue -> what to lookup
#>

Clear-Host
Write-Output "=============================================================================="
Write-Output "SophosLabs Intelix Lookup Request"
Write-Output "=============================================================================="

# Intelix Region to be used, must be "de", "us" or "au", please adjust this based on your location 
$Region = "de"  

# Define the filename and path for the credential file
$CredentialFile = $PSScriptRoot + '\Sophos-Intelix-Credentials.json'

# Check if Intelix Credentials have been stored, if not then prompt the user to enter the credentials
if (((Test-Path $CredentialFile) -eq $false) -or $SaveCredentials){
	# Prompt for Credentials
	$ClientId = Read-Host "Please Enter your Client ID"
    if ($ClientID -eq "") {Break}
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
$SecureCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList $clientId , $clientSecret
$BasicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(($SecureCredentials.GetNetworkCredential().Username, $SecureCredentials.GetNetworkCredential().Password -join ":")))

# SophosLabs Intelix OAuth URL
$AuthURI = "https://api.labs.sophos.com/oauth2/token"

# Header and Body for oAuth2 authetication request
$AuthBody = @{}
$AuthBody.Add("grant_type", "client_credentials")
$AuthHead = @{}
$AuthHead.Add("content-type", "application/x-www-form-urlencoded")
$AuthHead.Add("authorization", "Basic $($BasicAuth)")

# Set TLS Version
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Post Request to SOPHOS for OAuth2 token
try {
    $Result = (Invoke-RestMethod -Method Post -Uri $AuthURI -Body $AuthBody -Headers $AuthHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    if ($SaveCredentials) {
	    $clientSecret = $clientSecret | ConvertFrom-SecureString
	    ConvertTo-Json $ClientID, $ClientSecret | Out-File $CredentialFile -Force
    }
} catch {
    # If there's an error requesting the token, say so, display the error, and break:
    Write-Output "" 
	Write-Output "AUTHENTICATION FAILED - Unable to retreive SophosLabs Intelix Access Token"
    Write-Output "Please verify the credentials used!" 
    Write-Output "" 
    Write-Output "If you are working with saved credentials then you can reset them by calling"
    Write-Output "this script with the -SaveCredentials parameter"
    Write-Output "" 
    Read-Host -Prompt "Press ENTER to continue..."
    Break
}

# Set the Token for use later on:
$ReqHead=@{}
$ReqHead.Add("Authorization", "$($Result.access_token)")

if ((1 -ne $IP.IsPresent + $IPfile.IsPresent + $SHA.IsPresent + $SHAfile.IsPresent + $URL.IsPresent + $URLfile.IsPresent) -Or ($LookupValue -eq "")) {
    Write-Output "You have to call this script with one of the following parameters:"
    Write-Output "-IP <IP Address to check>"
    Write-Output "-IPfile <CSV-file containing IP-addresses>"
    Write-Output "-SHA <SHA-256 value to check>"
    Write-Output "-SHAfile <CSV-file containing SHA256 hashes>"
    Write-Output "-URL <URL to check>"
    Write-Output "-URLfile <CSV-file containing URL's>"
    Break
} 


# Lookup an IP address to see if its known malicious
if($IP) {
    try {
        $Result = (Invoke-RestMethod -Method GET -Uri "https://$($Region).api.labs.sophos.com/lookup/ips/v1/$($LookupValue)" -Headers $ReqHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
        Write-Output "Results for IP Address: $($LookupValue)..."
        Write-Output "------------------------------------------------------------------------------"
        Write-Output "Productivity Category: $($Result.category)"
    } catch {
        Write-Output "[ERROR] $($_.Exception.Message)"
        Write-Output "        --> verify that '$($LookupValue)' is a valid IP address`n"
    }
}


# Filter list of IP addresses from a file for know malicious entries
if($IPfile) {

    # Define table to hold 'known bad' entries
    $KnownBad = New-Object System.Data.Datatable
    [void]$KnownBad.Columns.Add("IPAddress")
    [void]$KnownBad.Columns.Add("Categories")

    $FileName = Get-ChildItem $LookupValue
    $ExportFile = "$($FileName.Directory)\$($FileName.BaseName) (Intelix Checked)$($FileName.Extension)"

    $ImportFile = Import-Csv $LookupValue
    if ((($importFile | Get-Member -MemberType NoteProperty).Name) -notcontains "IPaddress") {
        Write-Output "'IPaddress' column does not exist in the CSV file, aborting script!"
        break
    }

    foreach ($Item in $ImportFile) {
        try {
            $Result = (Invoke-RestMethod -Method GET -Uri "https://$($Region).api.labs.sophos.com/lookup/ips/v1/$($Item.ipAddress)" -Headers $ReqHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
            if (($Result.category -match "malware") -or ($Result.category -match "botnet") -or ($Result.category -match "spam_mta") -or ($Result.category -match "illegal")) {
                [void]$KnownBad.Rows.Add($Item.ipAddress, "$($Result.category -join ', ')" )
            } else {
                $Item | Export-Csv $ExportFile -Encoding UTF8 -NoTypeInformation -Append
            }
        } catch {
            Write-Output "[ERROR] $($_.Exception.Message)"
            Write-Output "        --> verify that '$($Item.ipAddress)' is a valid IP address`n"
        }
    }

    Write-Output "The following entries are classified as 'Known Bad':"
    Write-Output $KnownBad | Format-Table
    Write-Output "The remaining entries have been saved in:"
    Write-Output "$($Exportfile)"
}


# Lookup a SHA256 to see if its known malicious
if ($SHA) {
    try {
        $Result = (Invoke-RestMethod -Method GET -Uri "https://$($Region).api.labs.sophos.com/lookup/files/v1/$($LookupValue)" -Headers $ReqHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
        Write-Output "Results for SHA256: $($LookupValue)..."
        Write-Output "------------------------------------------------------------------------------"
        Write-Output "Reputation Score: $($Result.reputationScore)"
        Write-Output "  Detection Name: $($Result.detectionName)"
    } catch {
        Write-Output "[ERROR] $($_.Exception.Message)"
        Write-Output "        --> verify that '$($LookupValue)' is a valid SHA256`n"
    }
}


# Filter a list of SHA256 values from an CSV file for know malicious entries
if ($SHAFile) {

    # Define table to hold 'known bad' entries
    $KnownBad = New-Object System.Data.Datatable
    [void]$KnownBad.Columns.Add("SHA256")
    [void]$KnownBad.Columns.Add("Reputation Score")
    [void]$KnownBad.Columns.Add("Detection Name")

    $FileName = Get-ChildItem $LookupValue
    $ExportFile = "$($FileName.Directory)\$($FileName.BaseName) (Intelix Checked)$($FileName.Extension)"

    $ImportFile = Import-Csv $LookupValue
    if ((($importFile | Get-Member -MemberType NoteProperty).Name) -notcontains "SHA256") {
        Write-Output "'SHA256' column does not exist in the CSV file, aborting script!"
        break
    }

    foreach ($Item in $ImportFile) { 
        try {
            $Result = (Invoke-RestMethod -Method GET -Uri "https://$($Region).api.labs.sophos.com/lookup/files/v1/$($Item.sha256)" -Headers $ReqHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

            if ($Result.reputationScore -lt 30) {
                [void]$KnownBad.Rows.Add($Item.SHA256, $Result.reputationScore, $Result.detectionName)
            } else {
                $Item | Export-Csv $ExportFile -Encoding UTF8 -NoTypeInformation -Append
            }
            Start-Sleep -m 100
        } catch {
            Write-Output "[ERROR] $($_.Exception.Message)"
            Write-Output "        --> verify that '$($Item.sha256)' is a valid SHA256`n"
        }
    }

    Write-Output "The following entries are classified as 'Known Bad':"
    Write-Output $KnownBad | Format-Table
    Write-Output "The remaining entries have been saved in:"
    Write-Output "$($Exportfile)"
}


# Lookup a URL to see if its known malicious
if ($URL) {
    try {
        $Result = (Invoke-RestMethod -Method GET -Uri "https://$($Region).api.labs.sophos.com/lookup/urls/v1/$($LookupValue)" -Headers $ReqHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
        Write-Output "Results for URL: $($LookupValue)..."
        Write-Output "------------------------------------------------------------------------------"
        Write-Output "Productivity Category: $($Result.productivityCategory)"
        Write-Output "                Score: $($Result.productivityScore)"
        Write-Output "    Security Category: $($Result.securityCategory)"
        Write-Output "                Score: $($Result.securityScore)"
        Write-Output "           Risk level: $($Result.riskLevel)"
    } catch {
        Write-Output "[ERROR] $($_.Exception.Message)"
        Write-Output "        --> verify that '$($LookupValue)' is a valid URL`n"
    }
}


# Filter list of URLs from a file for known malicious entries
if ($URLfile) {

    # Define table to hold 'known bad' entries
    $KnownBad = New-Object System.Data.Datatable
    [void]$KnownBad.Columns.Add("URL")
    [void]$KnownBad.Columns.Add("Productivity Category")
    [void]$KnownBad.Columns.Add("Security Category")
    [void]$KnownBad.Columns.Add("Score")
    [void]$KnownBad.Columns.Add("Risk Level")

    $FileName = Get-ChildItem $LookupValue
    $ExportFile = "$($FileName.Directory)\$($FileName.BaseName) (Intelix Checked)$($FileName.Extension)"

    $ImportFile = Import-Csv $LookupValue
    if ((($importFile | Get-Member -MemberType NoteProperty).Name) -notcontains "URL") {
        Write-Output "'URL' column does not exist in the CSV file, aborting script!"
        break
    }

    foreach ($Item in $ImportFile) { 

        try {
            $Result = (Invoke-RestMethod -Method GET -Uri "https://$($Region).api.labs.sophos.com/lookup/urls/v1/$($Item.URL)" -Headers $ReqHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
            if ($Result.securityScore -lt 20) {
                [void]$KnownBad.Rows.Add($Item.URL, $Result.productivityCategory, $Result.securityCategory, $Result.securityScore, $Result.riskLevel)
            } else {
                $Item | Export-Csv $ExportFile -Encoding UTF8 -NoTypeInformation -Append
            }
            Start-Sleep -m 100
        } catch {
            Write-Output "[ERROR] $($_.Exception.Message)"
            Write-Output "        --> verify that '$($Item.URL)' is a valid URL`n"
        }
    }

    Write-Output "The following entries are classified as 'Known Bad':"
    Write-Output $KnownBad | Format-Table
    Write-Output "The remaining entries have been saved in:"
    Write-Output "$($Exportfile)"
}

Write-Output "=============================================================================="
