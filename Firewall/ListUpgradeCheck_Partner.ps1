param ([switch] $SaveCredentials)
<#
    Description: Scan for managed Sophos Firewalls with pending Upgrades
    Parameters: -SaveCredentials -> will store then entered credentials locally on the PC, this is needed when
                                    running the script unattended
#>

Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos API - Scan tenants for firewalls with pending updates..."
Write-Output "==============================================================================="

# Define the filename and path for the credential file
$CredentialFile = $PSScriptRoot + '\Sophos_Central_Partner_Credentials.json'

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

# Create table for storing results
$FirewallTable = New-Object System.Data.Datatable
[void]$FirewallTable.Columns.Add("Tenant Name")
[void]$FirewallTable.Columns.Add("Serial")
[void]$FirewallTable.Columns.Add("Hostname")
[void]$FirewallTable.Columns.Add("Label")
[void]$FirewallTable.Columns.Add("Current Firmware")
[void]$FirewallTable.Columns.Add("Upgrade to")

# Process all Tenants
Write-Output "Scanning tenants..."
$TenantPage = 1
$TenantCurr = 0

do {
    $TenantList = (Invoke-RestMethod -Method Get -Uri "https://api.central.sophos.com/partner/v1/tenants?pageTotal=true&pageSize=100&page=$TenantPage" -Headers $PartnerHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    foreach ($Tenant in $TenantList.items) {

        $TenantCurr = $TenantCurr + 1
        $TenantComp = ($TenantCurr/($TenantList.pages.items)*100)
        Write-Progress -Activity "Scanning tenants..." -Status "Progress:" -PercentComplete $TenantComp

        $TenantID = $Tenant.id
        $DataRegion = $Tenant.apiHost

        # SOPHOS API Headers:
        $TenantHead = @{}
        $TenantHead.Add("Authorization", "Bearer $Token")
        $TenantHead.Add("X-Tenant-ID", "$TenantID")
        $TenantHead.Add("Content-Type", "application/json")

        # If DataRegion is not set then the account was not activated properly (e.g. the Central datacenter was not yet selected)
        if ($null -ne $DataRegion) {
        
            # Post Request to Firewall API:
            try {
                $FWList = (Invoke-RestMethod -Method Get -Uri $DataRegion"/firewall/v1/firewalls" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
            } catch {
                # No Access to Tenant - If needed ask the customer to enable Partner Assistance
            }
        
            foreach ($FW in $FWList.items) {

                # Only check firewall with Firewall Management active
                if ($null -ne $FW.status.managingStatus) {

                    $Body = '{ "firewalls": ["'+$FW.id+'"]}'

                    try {
                        $FWCheck = (Invoke-RestMethod -Method POST -Uri $DataRegion"/firewall/v1/firewalls/actions/firmware-upgrade-check" -Headers $TenantHead -Body $Body)

                        $UpgradeTo = ""
                        Foreach ($FWVersion in $FWCheck.firmwareVersions ){	
                            if ($UpgradeTo -ne "") {
                                $UpgradeTo = $UpgradeTo + "`n"    
                            }
                            $UpgradeTo = $UpgradeTo + $FWVersion.version + " (size: " + $FWVersion.size + ")" + " "+ $FWVersion.news[0]
                        }

                        [void]$FirewallTable.Rows.Add($Tenant.showAs,$FW.serialNumber,$FW.hostname, $FW.name, $FWCheck.firewalls[0].firmwareVersion, $UpgradeTo)

                    } catch {
                        # No result found --> Central Firewall Management not active!
                    }
                }
            }
        }
    }
    $TenantPage++

} while ($TenantPage -le $TenantList.pages.total)

# Stop displaing the progress bar
Write-Progress -Activity "Scanning tenants..." -Completed

# Display the results 
Write-Output $FirewallTable | Format-Table -wrap
