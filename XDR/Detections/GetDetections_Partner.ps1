/* Original Post: https://community.sophos.com/sophos-central/f/recommended-reads/146483/building-multi-tenant-dashboards-with-sophos-central-api-s---part-1-detections */

param ([switch] $SaveCredentials, [switch] $Export, [switch] $Fallback, [string] $Path = "." )
<#
	Description: Gather detection counts for all tenants
	Parameters: -SaveCredentials -> will store then entered credentials locally on the PC, this is needed once
				-Export -> Export the results to "detections.csv" 
				-Fallback -> fallback to detecions API instead of the detections/counts API call
				-Path -> Specify another directory to export to
#>

# Error Parser for Web Request
function ParseWebError($WebError) {
	if ($PSVersionTable.PSVersion.Major -lt 6) {
		$resultStream = New-Object System.IO.StreamReader($WebError.Exception.Response.GetResponseStream())
		$resultBody = $resultStream.readToEnd()  | ConvertFrom-Json
		return $resultBody.message
	} else {
		$resultBody = $WebError.ErrorDetails | ConvertFrom-Json
		return $resultBody.message
	}
}

# Setup datatable to store detection counts
$DetectionsList = New-Object System.Data.Datatable
[void]$DetectionsList.Columns.Add("ID")
[void]$DetectionsList.Columns.Add("Detections_Critical")
[void]$DetectionsList.Columns.Add("Detections_High")
[void]$DetectionsList.Columns.Add("Detections_Medium")
[void]$DetectionsList.Columns.Add("Detections_Low")
[void]$DetectionsList.Columns.Add("Detections_Info")
[void]$DetectionsList.Columns.Add("Detections_Total")
[void]$DetectionsList.Columns.Add("Name")
$DetectionsView = New-Object System.Data.DataView($DetectionsList)

Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos API - Get XDR Detection Counts for the last 24 hours"
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

		$Detections_Total = 0
		$Detections_Critical = 0
		$Detections_High = 0
		$Detections_Medium = 0
		$Detections_Low = 0
		$Detections_Info = 0

		# Check Protection Status using the Health Check API
		if (-not $null -eq $TenantDataRegion) {
			if (-not $Fallback) {
				try {
					$DetectionsCounts = (Invoke-RestMethod -Method Get -Uri $TenantDataRegion"/detections/v1/queries/detections/counts?resolution=hour" -Headers $TenantHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)   

					foreach ($DetectionsCount in $DetectionsCounts.resolutionDetectionCounts) {
						$Detections_Total += $DetectionsCount.totalCount
						$Detections_Critical += $DetectionsCount.countBySeverity.critical
						$Detections_High += $DetectionsCount.countBySeverity.high
						$Detections_Medium += $DetectionsCount.countBySeverity.medium
						$Detections_Low += $DetectionsCount.countBySeverity.low
						$Detections_Info += $DetectionsCount.countBySeverity.info
					}

					[void]$DetectionsList.Rows.Add($Tenant.id, $Detections_Critical, $Detections_High, $Detections_Medium, $Detections_Low, $Detections_Info, $Detections_Total, $ShowAs)
					Write-Host ("   --> Total Detections: $($Detections_Total)")
				} catch {
					# Something went wrong, get error details...
					$WebError = ParseWebError($_)
					Write-Host "   --> $($WebError)"
				}
			} else {
				try {
					$Request = (Invoke-RestMethod -Method Post -Uri $TenantDataRegion"/detections/v1/queries/detections" -Headers $TenantHeaders -Body "{}" -ErrorAction SilentlyContinue -ErrorVariable ScriptError)   
					do {
						Start-Sleep -Milliseconds 500
						$Request = (Invoke-RestMethod -Method Get -Uri $TenantDataRegion"/detections/v1/queries/detections/$($Request.id)" -Headers $TenantHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)   
					} while ($Request.Result -eq "notAvailable")
	
					$uri = "$($TenantDataRegion)/detections/v1/queries/detections/$($Request.id)/results?pageSize=2000"
					$Detections =  (Invoke-RestMethod -Method Get -Uri $uri -Headers $TenantHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
					foreach ($Detection in $Detections.items) {
						$Detections_Total += 1
						
						switch ($Detection.severity) {
							0 {$Detections_info += 1}
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
	
					[void]$DetectionsList.Rows.Add($Tenant.id, $Detections_Critical, $Detections_High, $Detections_Medium, $Detections_Low, $Detections_Info, $Detections_Total, $ShowAs)
					Write-Host ("   --> Total Detections: $($Detections_Total)")
				} catch {
					# Something went wrong, get error details...
					$WebError = ParseWebError($_)
					Write-Host "   --> $($WebError)"
				}
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
	Write-Host "The detections were save to the following file:"
	Write-Host "$($Path)\detections.csv"
	$detectionsList.Select("", "Detections_critical DESC, Detections_High DESC, Detections_Medium DESC, Detections_Low DESC, Detections_Info DESC, Name ASC") | Export-Csv $path"\detections.csv" -Encoding UTF8 -NoTypeInformation
} else {
	Write-Host "Results:"    
	$detectionsList.Select("", "Detections_critical DESC, Detections_High DESC, Detections_Medium DESC, Detections_Low DESC, Detections_Info DESC, Name ASC") | Format-Table
}
