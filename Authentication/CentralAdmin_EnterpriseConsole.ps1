param ([switch] $SaveCredentials)
<#
    Description: Authentication Script for Sophos Central using Organization Credentials
    Parameters: -SaveCredentials -> will store then entered credentials locally on the PC, this is needed when
                                    running the script unattended
#>

Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos API - Organization Authentication Example"
Write-Output "==============================================================================="

# Define the filename and path for the credential file
$CredentialFile = $PSScriptRoot + '\Sophos_Central_Organization_Credentials.json'

# Check if Central API Credentials have been stored, if not then prompt the user to enter the credentials
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

# Check if we are using organization (Central Enterprise Dashboard) credentials
if ($Result.idType -ne "organization") {
    Write-Output "Aborting script - idType does not match organization!"
    Break
}

# Save Response details
$OrganizationID = $Result.id

# SOPHOS Organization API Headers:
$OrganizationHead = @{}
$OrganizationHead.Add("Authorization", "Bearer $Token")
$OrganizationHead.Add("X-Organization-ID", "$OrganizationID")

# Get all Tenants
$TenantPage = 1
do {

    $TenantList = (Invoke-RestMethod -Method Get -Uri "https://api.central.sophos.com/organization/v1/tenants?pageTotal=true&pageSize=100&page=$TenantPage" -Headers $OrganizationHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    foreach ($Tenant in $TenantList.items) {

        $TenantID = $Tenant.id
        $DataRegion = $Tenant.apiHost

        Write-Output ""
        Write-Output "-------------------------------------------------------------------------------"
        Write-Output $Tenant.showAs
        Write-Output "-------------------------------------------------------------------------------"

        ################# INSERT CODE HERE ###############
    }
    $TenantPage++

} while ($TenantPage -le $TenantList.pages.total)
