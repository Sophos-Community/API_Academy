param ([switch] $SaveCredentials, $Month, $Year)
<#
    Description: MSP - Get Billing Report 
    Parameters: -SaveCredentials -> will store then entered credentials locally on the PC, this is needed when
                                    running the script unattended
                -Month -> will select the month for reporting
                -Year -> will select the reporing year
#>

Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos API - MSP - Get Billing Report"
Write-Output "==============================================================================="

# Define the filename and path for the credential file
$CredentialFile = $PSScriptRoot + '\Sophos-Central-Partner-Credentials.json'

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

# Check if we are using partner (Central Partner Dashboard) credentials
if ($Result.idType -ne "partner") {
    Write-Output "Aborting script - idType does not match partner!"
    Break
}

# Save Response details
$PartnerID = $Result.id

# SOPHOS Partner API Headers:
$PartnerHead = @{}
$PartnerHead.Add("Authorization", "Bearer $Token")
$PartnerHead.Add("X-Partner-ID", "$PartnerID")

if (($null -eq $Month) -or ($null -eq $Year)) {
    $Month = Get-Date -Format "MM";
    $Year = Get-Date -Format "yyyy";
}

# Post Request to Partner API:
try {
    $Uri = "https://api.central.sophos.com/partner/v1/billing/usage/" + $Year + "/" + "$Month"
    $Response = (Invoke-RestMethod -Method Get -Uri $Uri -Headers $PartnerHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    # Store result in CSV File
    $Response.items | Export-Csv -Path $PSScriptRoot"\monthlyusage.csv"
} catch {
    Write-Output $_.Exception.Message
}
