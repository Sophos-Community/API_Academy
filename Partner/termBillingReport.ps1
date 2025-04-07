# Original Post: https://community.sophos.com/sophos-central/f/recommended-reads/146953/sophos-central-licensing-api

param ([switch] $SaveCredentials, [switch] $Mail, [switch] $Export, [int] $Days = 90 )
<#
	Description: Retrieve overview of customers/tenants with licences that will expire soon
	Parameters: -SaveCredentials -> will store then entered credentials locally on the PC, this is needed once
				-Mail -> mail the results, make sure to specify sender and recipient details below
				-Days -> include licenses expiring in n days (default is 90 days)
				-Export -> Export the results to "Sophos-licenses-<datestamp>.csv" 
#>

# Email Settings, please note that we are using an Gmail account for sending the email.
# For Gmail ensure that you generate an app password and activate MFA for the account! 
$SmtpSrvr = "smtp.gmail.com"
$SmtpPort = 587
$SmtpUser = "myaccount@gmail.com"
$SmtpPass = "mypassword"
$SmtpRcpt = "recipient@domain.com"

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

# HTML blocks for the HTML based email
$Header = @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"> 
<html xmlns="http://www.w3.org/1999/xhtml"> 
<head> 
<style>
table {border-width: 1px; border-style: solid; border-color: #FFFFFF; border-collapse: collapse; }
th {border-width: 1px; padding: 1px 5px 1px 5px; border-style: solid; border-color: #E0E0E0; background-color: #6495ED; color:#FFFFFF; text-align: left;}
td {border-width: 1px; padding: 1px 5px 1px 5px; border-style: solid; border-color: #E0E0E0; text-align: left;}
td.tenant {border-width: 1px; padding: 1px 5px 1px 5px; border-style: solid; border-color: #E0E0E0; background-color: #E0E0E0; text-align: left; }
td.expired {border-width: 1px; padding: 1px 5px 1px 5px; border-style: solid; border-color: #E0E0E0; color:#FF0000; text-align: left;}
td.expiring {border-width: 1px; padding: 1px 5px 1px 5px; border-style: solid; border-color: #E0E0E0; color:#FDA809; text-align: left;}

</style> 
</head>
<body>
Below you will find an overview of customers with licenses that recenly expired or will expire within the next <b>$($Days) days</b>.<br>
The overview contains all licenses of said customers, which will help to identify those customers that already renewed their licenses.<br><br>
<table><colgroup><col/><col/><col/><col/><col/><col/></colgroup> 
<tr><th>LicenseID</th><th>StartDate</th><th>EndDate</th><th>ProductCode</th><th>Type</th><th>Days</th></tr>
"@

$Footer = @"
</table>
<br>When <b>enterprise</b> is listed in the <b>Type</b> column then the customer is using Master Licening.</body></html>
"@

# Setup datatable to license details
$LicenseList = New-Object System.Data.Datatable
[void]$LicenseList.Columns.Add("TenantName")
[void]$LicenseList.Columns.Add("TenantID")
[void]$LicenseList.Columns.Add("LicenseID")
[void]$LicenseList.Columns.Add("StartDate")
[void]$LicenseList.Columns.Add("EndDate")
[void]$LicenseList.Columns.Add("ProductCode")
[void]$LicenseList.Columns.Add("Type")
[void]$LicenseList.Columns.Add("DaysRemaining", "System.Int32") 
$LicenseView = New-Object System.Data.DataView($LicenseList)

# Setup hashtable for tenants with expiring lisences
$TenantList = @{}


Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos API - Get details of expiring licenses"
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

		Write-Output ("+- $($ShowAs)... $(" " * 75)".Substring(0,75)) 

		$TenantID = $Tenant.id
		$TenantDataRegion = $Tenant.apiHost

		# SOPHOS Endpoint API Headers:
		$TenantHeaders = @{
			"Authorization" = "Bearer $Token";
			"X-Tenant-ID" = "$TenantID";
			"Content-Type" = "application/json";
		}

		# Get License Details
		if (-not $null -eq $TenantDataRegion) {
			try {

				$Licenses = (Invoke-RestMethod -Method Get -Uri "https://api.central.sophos.com/licenses/v1/licenses" -Headers $TenantHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
				foreach ($License in $Licenses.licenses) {
					if ($null -ne $License.EndDate) {
						$EndDate = [datetime]::parseexact($License.EndDate, 'yyyy-MM-dd', $null)
						$DaysRemaining = ($EndDate - ((Get-Date).Date)).Days
						[void]$LicenseList.Rows.Add($ShowAs, $Tenant.id, $License.licenseIdentifier, $License.startDate, $License.EndDate, $License.product.code, $License.type, $DaysRemaining)
						
						if ($TenantList.ContainsKey($Tenant.id)) {
							if($TenantList[$Tenant.id] -gt $DaysRemaining) {
								$TenantList[$Tenant.id] = $DaysRemaining
							}
						} else {
							$TenantList.add($Tenant.id, $DaysRemaining)
						}
					}
				}
			} catch {
				# Something went wrong, get error details...
				$WebError = ParseWebError($_)
				Write-Output "   --> $($WebError)"
			}
		} else {
			Write-Output ("   --> Account not activated")
		}
		Start-Sleep -Milliseconds 250 # Slow down processing to prevent hitting the API rate limit
	}
	$GetTenantsPage++

} while ($GetTenantsPage -le $GetTenants.pages.total)

Write-Output ""
Write-Output "-------------------------------------------------------------------------------"

$LicenseView.RowFilter = "DaysRemaining <= '$($Days)'"

if ($LicenseView.Count -gt 0) {

	if ($Export) {
		# Delete old export present --> delete it
		$FileName = (Get-Item $PSCommandPath ).DirectoryName + "\Sophos-Licenses-" + ((Get-Date).ToString("yyyyMMdd")) + ".csv"
		if (Test-Path -Path $FileName) {
			Remove-Item $FileName
		}

		# Export all relavant data
		$TenantList = $TenantList.GetEnumerator() | Sort-Object -property:Value
		foreach ($Tenant in $TenantList) {
			if ($Tenant.Value -le $Days) {
				$LicenseView.RowFilter = "TenantID = '$($Tenant.Key)'"
				$LicenseView | Export-Csv $FileName -Encoding UTF8 -NoTypeInformation -Append
			}
		}

		Write-Output ""
		Write-Output "The results were save to the following file:"
		Write-Output $FileName
	} 
	
	if ($Mail) {
		# Prepare Table Contents
		$TableBody = ""
		$TenantList = $TenantList.GetEnumerator() | Sort-Object -property:Value
		foreach ($Tenant in $TenantList) {
			if ($Tenant.Value -le $Days) {
				$LicenseView.RowFilter = "TenantID = '$($Tenant.Key)'"
				$LicenseView.Sort = "DaysRemaining ASC"
				$TableBody += '<tr><td colspan="6" class="tenant"><b>' + $LicenseView[0].TenantName + '</b></td></tr>'
				if($LicenseView.Count -ne 0) {
					foreach ($Row in $LicenseView) {

						# Change text color based on end date
						if ($Row.DaysRemaining -lt 0) { 
							$Class = "expired"
						} elseif ($Row.DaysRemaining -le $Days) {
							$Class = "expiring"
						} else {
							$Class = ""
						}

						$TableBody += '<tr>'
						$TableBody += '<td class="' + $($Class) + '">' + $Row.LicenseID + '</td>'
						$TableBody += '<td class="' + $($Class) + '">' + $Row.StartDate + '</td>'
						$TableBody += '<td class="' + $($Class) + '">' + $Row.EndDate + '</td>'
						$TableBody += '<td class="' + $($Class) + '">' + $Row.ProductCode + '</td>'
						$TableBody += '<td class="' + $($Class) + '">' + $Row.Type + '</td>'
						$TableBody += '<td class="' + $($Class) + '">' + $Row.DaysRemaining + '</td>'
						$TableBody += '</tr>'
					}
				}
				$TableBody += '<tr><td colspan="6"></td></tr>'
			}
		}

		# Prepare Email
		$Message = New-Object System.Net.Mail.MailMessage
		$Message.From = $SmtpUser
		$Message.To.Add($SmtpRcpt)
		$Message.Subject = "Sophos Licenses expiring soon!"
		$Message.IsBodyHtml = $true
		$Message.Body = $Header + $TableBody + $Footer

		# Create the SmtpClient object and send the Email
		$Smtp = New-Object Net.Mail.SmtpClient($SmtpSrvr, $SmtpPort)
		$Smtp.EnableSsl = $true
		if ($SmtpPass -ne "") {
			$Smtp.Credentials = New-Object System.Net.NetworkCredential( $SmtpUser , $SmtpPass );
		}
		$Smtp.Send($Message)

		Write-Output ""
		Write-Output "The results were sent by email to $($SmtpRcpt)"

	} 
	
	if ((-Not $Mail) -And (-Not $Export)) {
		Write-Output "Licenses that already expired or are expiring within the next $($Days) days:"    
		$LicenseList.Select("DaysRemaining <= '$($Days)'","DaysRemaining ASC, TenantName ASC") | Select-Object TenantName, LicenseID, StartDate, EndDate, ProductCode, Type, DaysRemaining | Format-Table
	}

} else {
	Write-Output ""
	Write-Output "No licenses are expiring within the next $($Days) days!"    
}

Write-Output "==============================================================================="
