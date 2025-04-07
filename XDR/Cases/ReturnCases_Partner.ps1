#Original Post: https://community.sophos.com/sophos-central/f/recommended-reads/146643/building-multi-tenant-dashboards-with-sophos-central-api-s---part-3-cases

param ([switch] $SaveCredentials, [switch] $Export, [string] $Path = "." )
<#
	Description: Gather case counts for all tenants
	Parameters: -SaveCredentials -> will store then entered credentials locally on the PC, this is needed once
				-Export -> Export the results to "cases.csv" 
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

# Setup datatable to store case counters
$CasesList = New-Object System.Data.Datatable
[void]$CasesList.Columns.Add("ID")
[void]$CasesList.Columns.Add("Cases_OCR")
[void]$CasesList.Columns.Add("Cases_OHI")
[void]$CasesList.Columns.Add("Cases_OME")
[void]$CasesList.Columns.Add("Cases_OLO")
[void]$CasesList.Columns.Add("Cases_OIN")
[void]$CasesList.Columns.Add("Cases_ONA")
[void]$CasesList.Columns.Add("Cases_CLO")
[void]$CasesList.Columns.Add("Cases_TOT")
[void]$CasesList.Columns.Add("Name")
$CasesView = New-Object System.Data.DataView($CasesList)

Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos API - Count cases created in the last 30 days"
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

		$Cases_TOT = 0
		$Cases_OCR = 0
		$Cases_OHI = 0
		$Cases_OME = 0
		$Cases_OLO = 0
		$Cases_OIN = 0
		$Cases_ONA = 0
		$Cases_CLO = 0
		$Cases_TOT = 0
		
		# Check Protection Status using the Health Check API
		if (-not $null -eq $TenantDataRegion) {
			try {

				$Page = 1
				do {
					$Cases = (Invoke-RestMethod -Method Get -Uri $TenantDataRegion"/cases/v1/cases?page=$($page)&createdAfter=-P30D&pageSize=5000" -Headers $TenantHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
					foreach ($Case in $Cases.items) {

						$Cases_TOT += 1
						if ($Case.status -eq "closed") {
							$Cases_CLO += 1
						} else {
							switch ($Case.severity) {
								"Informational" {$Cases_OIN += 1}
								"low"           {$Cases_OLO += 1}
								"medium"        {$Cases_OME += 1}
								"high"          {$Cases_OHI += 1}
								"critical"      {$Cases_OCR += 1}
								Default         {$Cases_ONA += 1}
							}
						}
					}
					$Page += 1
				} while ($Page -le $Cases.pages.total)
				[void]$CasesList.Rows.Add($Tenant.id, $Cases_OCR, $Cases_OHI, $Cases_OME, $Cases_OLO, $Cases_OIN, $Cases_ONA, $Cases_CLO, $Cases_TOT, $Tenant.name)
				Write-Host ("   --> Total Cases: $($Cases_TOT)    Open Cases: $($Cases_OIN + $Cases_OLO+ $Cases_OME + $Cases_OHI + $Cases_OCR + $Cases_ONA)    Closed Cases: $($Cases_CLO)")
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
	Write-Host "The case counters were save to the following file:"
	Write-Host "$($Path.TrimEnd('\'))\cases.csv"
	$CasesList.Select("", "Cases_OCR DESC, Cases_OHI DESC, Cases_OME DESC, Cases_OLO DESC, Cases_OIN DESC, Cases_ONA DESC, Name ASC") | Export-Csv $path"\cases.csv" -Encoding UTF8 -NoTypeInformation
} else {
	Write-Host "Results:"    
	$CasesList.Select("","Cases_OCR DESC, Cases_OHI DESC, Cases_OME DESC, Cases_OLO DESC, Cases_OIN DESC, Cases_ONA DESC, Name ASC") | select Name, Cases_OCR, Cases_OHI, Cases_OME, Cases_OLO, Cases_OIN, Cases_ONA, Cases_CLO | Format-Table
}
