# This will block devices based on their MAC-address on the Sophos switch and AP access points

param ([string[]] $macAddresses, [switch] $add, [switch] $del, [switch] $wifi, [switch] $switch, [switch] $saveCredentials)
<#
    Description: Sophos ATR MAC Filter
    Parameters: -SaveCredentials -> will store then entered credentials locally on the PC.
                -macAddresses -> comma separated list of MAC addresses to be added / deletec
                -add or -del -> initiate add or delete action
                -switch and/or -wifi -> targets for the action
#>

function IsMACAddressValid {
    param ([string]$macAddress)
    $RegEx = "^([0-9A-Fa-f]{2}[-:]){5}([0-9A-Fa-f]{2})$"
    if ($macAddress -match $RegEx) {
        return $true
    } else {
        return $false
    }
}

Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos API - Wi-Fi / Switch ATR MAC Filter --- START"
Write-Output "==============================================================================="

# Define the filename and path for the credential file
$credentialFile = $PSScriptRoot + '\Sophos_Central_Admin_Credentials.json'

# Check if Central API Credentials have been stored, if not then prompt the user to enter the credentials
if (((Test-Path $credentialFile) -eq $false) -or $saveCredentials){
	# Prompt for Credentials
	$clientId = Read-Host "Please Enter your Client ID"
	$clientSecret = Read-Host "Please Enter your Client Secret" -AsSecureString 
} else { 
    # Read Credentials from JSON File
    $credentials = Get-Content $credentialFile | ConvertFrom-Json
    $clientId = $credentials[0]
    $clientSecret = $credentials[1] | ConvertTo-SecureString
}

# We are making use of the PSCredentials object to store the API credentials
# The Client Secret will be encrypted for the user excuting the script
# When scheduling execution of the script remember to use the same user context

$secureCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList $clientId , $clientSecret

# SOPHOS OAuth URL
$tokenURI = "https://id.sophos.com/api/v2/oauth2/token"

# TokenRequestBody for oAuth2
$tokenRequestBody = @{
	"grant_type" = "client_credentials";
	"client_id" = $secureCredentials.GetNetworkCredential().Username;
	"client_secret" = $secureCredentials.GetNetworkCredential().Password;
	"scope" = "token";
}
$tokenRequestHeaders = @{
	"content-type" = "application/x-www-form-urlencoded";
}

# Set TLS Version
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Post Request to SOPHOS for OAuth2 token
try {
    $APIAuthResult = (Invoke-RestMethod -Method Post -Uri $tokenURI -Body $tokenRequestBody -Headers $tokenRequestHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    if ($saveCredentials) {
	    $clientSecret = $clientSecret | ConvertFrom-SecureString
	    ConvertTo-Json $clientID, $clientSecret | Out-File $credentialFile -Force
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
$token = $APIAuthResult.access_token

# SOPHOS Whoami URI:
$whoamiURI = "https://api.central.sophos.com/whoami/v1"

# SOPHOS Whoami Headers:
$whoamiRequestHeaders = @{
	"Content-Type" = "application/json";
	"Authorization" = "Bearer $token";
}

# Post Request to SOPHOS for Whoami Details:
$APIWhoamiResult = (Invoke-RestMethod -Method Get -Uri $whoamiURI -Headers $whoamiRequestHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

# Save Response details
$APIidTenant = $APIWhoamiResult.id
$APIdataRegion = $APIWhoamiResult.ApiHosts.dataRegion
if ($APIWhoamiResult.idType -ne "tenant") {
    Write-Output "This script can only be used with tenant credentials. Aborting..."
    exit
}	

# SOPHOS Endpoint API Headers:
$tentantAPIHeaders = @{
	"Authorization" = "Bearer $token";
	"X-Tenant-ID" = "$APIidTenant";
}

# Ensure that the MAC Address is valid for add/del actions and normalize it
if ($add -or $del -or $switch -or $wifi) {
    if (-not $PSBoundParameters.ContainsKey('macAddresses')) {
        Write-Output "MAC Address(es) not specified, aborting..." 
        exit
    }

    if (-not ($del -or $add)) {
        Write-Output "The ATR targets -wifi and/or -switch need to be combined with an action."
        Write-Output "You can use -add or -del as action. Aborting..."
        exit
    }
    
    if (-not ($switch -or $wifi)) {
        Write-Output "The actions -add or -del need to be combined with a target ATR list. "
        Write-Output "You can use -wifi and/or -switch as targets. Aborting..."
        exit
    }
    
    if ($del -and $add) {
        Write-Output "The actions -add and -del cannot be combined. Aborting..."
        exit
    }
}

# Create object to hold MAC-Address List
$macList = New-Object System.Data.Datatable
[void]$macList.Columns.Add("macAddress")
[void]$macList.Columns.Add("WiFi")
[void]$macList.Columns.Add("Switch")
$macView = New-Object System.Data.DataView($macList)
$macView.Sort = "macAddress ASC"

# Get current ATR MAC-Filter Lists
$getATRSwitch = (Invoke-RestMethod -Method Get -Uri $APIdataRegion"/switch/v1/settings/mac-filtering" -Headers $tentantAPIHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
foreach ($address in $getATRSwitch.macAddresses) {
    $address = ($address.ToUpper()) -replace '-',':'
    $macView.RowFilter = "macAddress = '$($address)'"
    if ($macView.Count -ne 0) {
        $macView  | ForEach-Object { $_.Switch = $true }
    } else {
        [void]$macList.Rows.Add($address, $false, $true)
    }
}

$getATRWiFi = (Invoke-RestMethod -Method Get -Uri $APIdataRegion"/wifi/v1/settings/mac-filtering" -Headers $tentantAPIHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
foreach ($address in $GetATRWiFi.macAddresses) {
    $address = ($address.ToUpper()) -replace '-',':'
    $macView.RowFilter = "macAddress = '$($address)'"
    if ($macView.Count -ne 0) {
        $macView  | ForEach-Object { $_.WiFi = $true }
    } else {
        [void]$macList.Rows.Add($address, $true, $false)
    }
}

Write-Output "" 
Write-Output "Current ATR MAC Filter List:" 
$macView.RowFilter = "WiFi = $true or Switch = $true"
$macView | Format-Table

# Modify table based on parameters specified...
foreach ($macAddress in $macAddresses) {
    if (IsMACAddressValid $macAddress) {
        $macAddress = ($macAddress.ToUpper()) -replace '-',':'
    } else {
        Write-Output "MAC Address invalid $($macAddress), aborting..."
        exit
    }

    if ($add) {
        if ($switch) {
            $macView.RowFilter = "macAddress = '$($macAddress)'"
            if ($macView.Count -ne 0) {
                $macView  | ForEach-Object { $_.Switch = $true }
            } else {
                [void]$macList.Rows.Add($macAddress, $false, $true)
            }
        }
        if ($wifi) {
            $macView.RowFilter = "macAddress = '$($macAddress)'"
            if ($macView.Count -ne 0) {
                $macView  | ForEach-Object { $_.WiFi = $true }
            } else {
                [void]$macList.Rows.Add($macAddress, $true, $false)
            }
        }
    }

    if ($del) {
        if ($switch) {
            $macView.RowFilter = "macAddress = '$($macAddress)'"
            if ($macView.Count -ne 0) {
                $macView  | ForEach-Object { $_.Switch = $false }
            }
        }
        if ($wifi) {
            $macView.RowFilter = "macAddress = '$($macAddress)'"
            if ($macView.Count -ne 0) {
                $macView  | ForEach-Object { $_.WiFi = $false }
            }
        }
    }
}

# time to update the ATR lists in Sophos Central
if ($add -or $del) {

    if ($switch) {
        $macView.RowFilter = "Switch = $true"

        if ($macView.Count -eq 0) {
            $Body = '{ "macAddresses": [ ] }'
        } elseif ($macView.Count -eq 1) {
            $Body = '{ "macAddresses": [ ' + ($macView.macAddress | ConvertTo-Json) + '] }'
        } else { 
            $Body = '{ "macAddresses": ' + ($macView.macAddress | ConvertTo-Json) + ' }'
        }

        try {
            $response = Invoke-WebRequest -Uri $APIdataRegion"/switch/v1/settings/mac-filtering" -Method PUT -Headers $tentantAPIHeaders -ContentType 'application/json' -Body $Body
        } catch {
            Write-Output "Oops, something went wrong. Aborting..."

            $resultStream = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $resultBody = $resultStream.readToEnd()
            $resultBody
            exit
        }
    }

    if ($wifi) {
        $macView.RowFilter = "WiFi = $true"

        if ($macView.Count -eq 0) {
            $Body = '{ "macAddresses": [ ] }'
        } elseif ($macView.Count -eq 1) {
            $Body = '{ "macAddresses": [ ' + ($macView.macAddress | ConvertTo-Json) + '] }'
        } else { 
            $Body = '{ "macAddresses": ' + ($macView.macAddress | ConvertTo-Json) + ' }'
        }

        try {
            $response = Invoke-WebRequest -Uri $APIdataRegion"/wifi/v1/settings/mac-filtering" -Method PUT -Headers $tentantAPIHeaders -ContentType 'application/json' -Body $Body
        } catch {
            Write-Output "Oops, something went wrong. Aborting..."
            $resultStream = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $resultBody = $resultStream.readToEnd()
            $resultBody
            exit
        }
    }
 
    Write-Output "New ATR MAC Filter List:" 
    $macView.RowFilter = "WiFi = $true or Switch = $true"
    $macView  | Format-Table
}

Write-Output "==============================================================================="
Write-Output "Sophos API - Wi-Fi / Switch ATR MAC Filter --- END"
Write-Output "==============================================================================="
