# Original Post: https://community.sophos.com/sophos-central/f/recommended-reads/146644/building-multi-tenant-dashboards-with-sophos-central-api-s---part-2-health-check

param ([switch] $SaveCredentials, [switch] $Export, [string] $Path = "." )
<#
	Description: Gather health scores for all tenants
	Parameters: -SaveCredentials -> will store then entered credentials locally on the PC, this is needed once
				-Export -> Export the results to "healtscores.csv" 
				-Path -> Specify another directory to export to
#>

# Error Parser for Web Request
function ParseWebError($WebError) {
	if ($PSVersionTable.PSVersion.Major -lt 6) {
		$resultStream = New-Object System.IO.StreamReader($WebError.Exception.Response.GetResponseStream())
		$resultBody = $resultStream.readToEnd()  | ConvertFrom-Json
	} else {
		$resultBody = $WebError.ErrorDetails | ConvertFrom-Json
	}

	if ($null -ne $resultBody.message) {
		return $resultBody.message
	} else {
		return $WebError.Exception.Response.StatusCode
	}
}

# Function to extract the lowest score and linked snoozed status from an array
function ParseScores($Values) {

	$Score = 100
	$Snoozed = $False

	Foreach ($Value in $Values) {
		if ($null -ne $Value) {
			if ($Score -gt $Value.Score) {
				$Score = $Value.Score
				$Snoozed = $Value.Snoozed
			} elseif (($Score -eq $Value.Score) -and ($ture -eq $Value.Snoozed)) {
				$Snoozed = $true
			}
		}
	}
	return @{"Score" = $Score; "Snoozed" = $Snoozed}
}

# Setup datatable to store health scores
$HealthList = New-Object System.Data.Datatable
[void]$HealthList.Columns.Add("ID")
[void]$HealthList.Columns.Add("HOvSc",[int])
[void]$HealthList.Columns.Add("HOvSn",[boolean])
[void]$HealthList.Columns.Add("HPrSc",[int])
[void]$HealthList.Columns.Add("HPrSn",[boolean])
[void]$HealthList.Columns.Add("HTaSc",[int])
[void]$HealthList.Columns.Add("HTaSn",[boolean])
[void]$HealthList.Columns.Add("HPoSc",[int])
[void]$HealthList.Columns.Add("HPoSn",[boolean])
[void]$HealthList.Columns.Add("HExSc",[int])
[void]$HealthList.Columns.Add("HExSn",[boolean])
[void]$HealthList.Columns.Add("Name")
$HealthView = New-Object System.Data.DataView($HealthList)

Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos API - Get health scoures for all tenants"
Write-Output "==============================================================================="

# Define the filename and path for the credential file
$CredentialFile = (Get-Item $PSCommandPath ).DirectoryName+"\"+(Get-Item $PSCommandPath ).BaseName+".json"

# Check if Central API Credentials have been stored, if not then prompt the user to enter the credentials
if (((Test-Path $CredentialFile) -eq $false) -or $SaveCredentials){
	# Prompt for Credentials
	$clientId = Read-Host "Please Enter your Client ID"
	$clientSecret = Read-Host "Please Enter your Client Secret" -AsSecureString 
} else { 
	# Read Credentials from JSON File
	$credentials = Get-Content $CredentialFile | ConvertFrom-Json
	$clientId = $credentials[0]
	$clientSecret = $credentials[1] | ConvertTo-SecureString
}

# We are making use of the PSCredentials object to store the API credentials
# The Client Secret will be encrypted for the user excuting the script
# When scheduling execution of the script remember to use the same user context

$SecureCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList $clientId , $clientSecret

# SOPHOS OAuth URL
$TokenURI = "https://id.sophos.com/api/v2/oauth2/token"

# TokenRequestBody for oAuth2
$TokenRequestBody = @{
	"grant_type" = "client_credentials";
	"client_id" = $SecureCredentials.GetNetworkCredential().Username;
	"client_secret" = $SecureCredentials.GetNetworkCredential().Password;
	"scope" = "token";
}
$TokenRequestHeaders = @{
	"content-type" = "application/x-www-form-urlencoded";
}

# Set TLS Version
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Post Request to SOPHOS for OAuth2 token
try {
	$APIAuthResult = (Invoke-RestMethod -Method Post -Uri $TokenURI -Body $TokenRequestBody -Headers $TokenRequestHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
	if ($SaveCredentials) {
		$clientSecret = $clientSecret | ConvertFrom-SecureString
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
$Token = $APIAuthResult.access_token

# SOPHOS Whoami URI:
$WhoamiURI = "https://api.central.sophos.com/whoami/v1"

# SOPHOS Whoami Headers:
$WhoamiRequestHeaders = @{
	"Content-Type" = "application/json";
	"Authorization" = "Bearer $Token";
}

# Post Request to SOPHOS for Whoami Details:
$WhoamiResult = (Invoke-RestMethod -Method Get -Uri $WhoamiURI -Headers $WhoamiRequestHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

# Save Response details
$WhoamiID = $WhoamiResult.id
$WhoamiType = $WhoamiResult.idType	

# Check if we are using partner/organization credentials
if (-not (($WhoamiType -eq "partner") -or ($WhoamiType -eq "organization"))) {
	Write-Output "Aborting script - idType does not match partner or organization!"
	Break
}

# SOPHOS Partner/Organization API Headers:
if ($WhoamiType -eq "partner") {
	$GetTenantsHeaders = @{
		"Authorization" = "Bearer $Token";
		"X-Partner-ID" = "$WhoamiID";
	}
} else {
	$GetTenantsHeaders = @{
		"Authorization" = "Bearer $Token";
		"X-Organization-ID" = "$WhoamiID";
	}
}

# Get all Tenants
Write-Host ("Checking:")
$GetTenantsPage = 1
do {

	if ($WhoamiType -eq "partner") {
		$GetTenants = (Invoke-RestMethod -Method Get -Uri "https://api.central.sophos.com/partner/v1/tenants?pageTotal=true&pageSize=100&page=$GetTenantsPage" -Headers $GetTenantsHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
	} else {
		$GetTenants = (Invoke-RestMethod -Method Get -Uri "https://api.central.sophos.com/organization/v1/tenants?pageTotal=true&pageSize=100&page=$GetTenantsPage" -Headers $GetTenantsHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
	}

	foreach ($Tenant in $GetTenants.items) {

		# Codepage stuff to ensure that powershell displays those nasty Umlauts and other special characters correctly
		$ShowAs = $Tenant.showAs
		$ShowAs = [System.Text.Encoding]::GetEncoding(28591).GetBytes($ShowAs)
		$ShowAs = [System.Text.Encoding]::UTF8.GetString($ShowAs)

		Write-Host ("+- $($ShowAs)... $(" " * 75)".Substring(0,75)) 

		$TenantID = $Tenant.id
		$TenantDataRegion = $Tenant.apiHost

		# SOPHOS Endpoint API Headers:
		$TenantHeaders = @{
			"Authorization" = "Bearer $Token";
			"X-Tenant-ID" = "$TenantID";
			"Content-Type" = "application/json";
		}

		# Check Protection Status using the Health Check API
		if (-not $null -eq $TenantDataRegion) {
		try {
			$HealthCheck = (Invoke-RestMethod -Method Get -Uri $TenantDataRegion"/account-health-check/v1/health-check" -Headers $TenantHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)   
			$HPR = ParseScores ($HealthCheck.Endpoint.Protection.Computer,$HealthCheck.Endpoint.Protection.Server)
			$HTA = ParseScores ($HealthCheck.Endpoint.TamperProtection.Computer, $HealthCheck.Endpoint.TamperProtection.Server, $HealthCheck.Endpoint.TamperProtection.GlobalDetail)
			$HPO = ParseScores ($HealthCheck.Endpoint.Policy.Computer."threat-protection", $HealthCheck.Endpoint.Policy.Server."server-threat-protection")
			$HEX = ParseScores ($HealthCheck.Endpoint.Exclusions.Global, $HealthCheck.Endpoint.Exclusions.Policy.Computer, $HealthCheck.Endpoint.Exclusions.Policy.Server)
			$HOV = ParseScores ($HPR, $HTA, $HPO, $HEX)
			[void]$HealthList.Rows.Add($Tenant.id, $HOV.Score, $HOV.Snoozed, $HPR.Score, $HPR.Snoozed, $HTA.Score, $HTA.Snoozed, $HPO.Score, $HPO.Snoozed, $HEX.Score, $HEX.Snoozed, $ShowAs)
			Write-Host ("   --> Health Score: $($HOV.Score) - Snoozed: $($HOV.Snoozed)")
		} catch {
			# Something went wrong, get error details...
			$WebError = ParseWebError($_)
			Write-Host "   --> $($WebError)"
		}
	} else {
		Write-Host ("   --> Account not activated")
	}
		Start-Sleep -Milliseconds 50 # Slow down processing to prevent hitting the API rate limit
	}
	$GetTenantsPage++

} while ($GetTenantsPage -le $GetTenants.pages.total)

Write-Output "==============================================================================="
Write-Output "Check completed!"
Write-Output "==============================================================================="

if ($Export) {
	Write-Host ""
	Write-Host "The health scores were saved to the following file:"
	Write-Host "$($Path)\healthscores.csv"
	$HealthList.Select("", "HOvSc ASC, Name ASC") | Export-Csv $Path"\healthscores.csv" -Encoding UTF8 -NoTypeInformation
} else {
	Write-Host "Results:"    
	$HealthList.Select("", "HOvSc ASC, Name ASC") | Format-Table Name,HOvSc,HOvSn,HPrSc,HTaSc,HPoSc,HExSc
}
