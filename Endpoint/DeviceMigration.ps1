# Moves installed endpoionts from one Central Admin tenant to another
param ([switch] $Debug)
<#
    Description: Migrate devices that start with a specific text from one tenant to another tenant
#>

###################################################################################################################
# Define OAUTH Access Data before running the script!
###################################################################################################################

# Define OAUTH Access Data for the source (sending) account 
$SrcID = ""
$SrcSecret = ""
$SrcToken = ""

# Define OAUTH Access Data for the destination (receiving) account 
$DstID = ""
$DstSecret = ""
$DstToken = ""

# Define which devices are te be migrated, for this we use the hostname. Full name means only one device is migrated, 
# a blank string ("") all devices and "WKS" means that only devices starting with that string are migrated.
$HostSelect = "WKS"

###################################################################################################################

Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos API - Device Migration"
Write-Output "==============================================================================="

function API_Authenticate {
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $ID,
         [Parameter(Mandatory=$true, Position=1)]
         [string] $Secret
    )

    # Define SOPHOS OAuth URL and Request Header
    $TokenURI = "https://id.sophos.com/api/v2/oauth2/token"
    $TokenRequestHeaders = @{
	    "content-type" = "application/x-www-form-urlencoded";
    }

    # Set TLS Version
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Define TokenRequestBody for OAuth and the source Account
    $TokenRequestBody = @{
    	"grant_type" = "client_credentials";
    	"client_id" = $ID;
    	"client_secret" = $Secret;
    	"scope" = "token";
    }

    # Post Request to SOPHOS for OAuth2 token
    try {
        $APIAuthResult = (Invoke-RestMethod -Method Post -Uri $TokenURI -Body $TokenRequestBody -Headers $TokenRequestHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    } catch {
        # If there's an error requesting the token, say so, display the error, and break:
        Write-Output "" 
    	Write-Output "AUTHENTICATION FAILED"
        Write-Output "Please verify the credentials used for the source account!" 
        Read-Host -Prompt "Press ENTER to continue..."
        Break
    }

    # Set the Token for use later on:
    return $APIAuthResult.access_token

}

function API_Whoami {
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $Token
    )

    # SOPHOS Whoami URI:
    $WhoamiURI = "https://api.central.sophos.com/whoami/v1"

    # SOPHOS Whoami Headers:
    $WhoamiRequestHeaders = @{
    	"Content-Type" = "application/json";
    	"Authorization" = "Bearer $Token";
    }

    # Post Request to SOPHOS for Whoami Details:
    $APIWhoamiResult = (Invoke-RestMethod -Method Get -Uri $WhoamiURI -Headers $WhoamiRequestHeaders -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

    # Set the Token for use later on:
    return $APIWhoamiResult
}

if ( ($SrcID -eq "") -or ($SrcSecret -eq "") -or ($DstID -eq "") -or ($DstSecret -eq "")) {
    Write-Output "You must enter the OAUTH2 Access Data in the script to be able to use the script!"
}

# Authenticate against the source (sending) account and get whoami details
Write-Output "[SRC] Authenticate using credentials of the sending account"
$SrcToken = API_Authenticate -id $SrcID -Secret $SrcSecret
$SrcWhoami = API_Whoami -Token $SrcToken

# Define refresh time when we want to renew our token during the monitor phase
$SrcRefresh = Get-Date 
$SrcRefresh = $SrcRefresh.AddMinutes(50)

# Authenticate against the destination (receiving) account and get whoami details
Write-Output "[DST] Authenticate using credentials of the receiving account"
$DstToken =  API_Authenticate -id $DstID -Secret $DstSecret
$DstWhoami = API_Whoami -Token $DstToken

# Retrieve List of Endpoints from the source (sending) account 
Write-Output "[SRC] Create a list of all devices to be migrated"
$EndpointList = @()
$NextKey = $null

# SOPHOS Endpoint API Headers
$APIHeader = @{ "Authorization" = "Bearer $SrcToken"; "X-Tenant-ID" = "$($SrcWhoami.id)";}

do {
    $Uri = $SrcWhoami.apiHosts.dataRegion + "/endpoint/v1/endpoints?pageTotal=true&pageFromKey=$NextKey&fields=hostname,type&sort=id"
    $GetEndpoints = (Invoke-RestMethod -Method Get -Uri $Uri -Headers $APIHeader -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

    foreach ($Endpoint in $GetEndpoints.items) {

        if ($Endpoint.hostname.StartsWith($HostSelect)) {
            $EndpointList += $Endpoint    
        }
    }

    $NextKey = $GetEndpoints.pages.nextKey
} while ($null -ne $NextKey) 

# Show some statistics
write-output ("      +-> Total amount of computers to be migrated: " + $EndpointList.where{$_.type -match 'computer'}.count)
write-output ("      +-> Total amount of servers to be migrated..: " + $EndpointList.where{$_.type -match 'server'}.count)

# Displaying a list of device names that will be migrated
if ($Debug) {
    write-output ""
    write-output "[SRC] Hostname of devices to be Migrated:"
    Write-Output ($EndpointList.hostname -join ', ')
    write-output ""
}

# Abort migration when no devices
if ($EndpointList.Length -eq 0) {
    write-output ""
    write-output "Aborting migration, no devices found!"
    break
}

# Abort migration when too many devices, you can address this by splitting the list in separate jobs with max. 1000 devices per job
if ($EndpointList.Length -gt 1000) {
    write-output ""
    write-output "Aborting migration, too many devices found, this script supports up to max. 1000 devices!"
    break
}

# Only start migration after explicit approval
do { $yn = Read-Host "[SRC] Start Device Migration Process? [Y/N]"; if ($yn -eq 'n') {exit}; } while($yn -ne "y")

# Start receiver for the migration task on destination (receiving) account
Write-Output "[DST] Start a migration job in the receiving tenant"
$Header = @{ "Authorization" = "Bearer $DstToken"; "X-Tenant-ID" = "$($DstWhoami.id)"; "Content-Type" = "application/json";}
$Uri = $DstWhoami.apiHosts.dataRegion + "/endpoint/v1/migrations"

# EndpointList must be an array even when it only contains one object
if ($EndpointList.Count -eq 1) {
    $Body = '{ "fromTenant": "' + $($SrcWhoami.id) + '", "endpoints": [' + ($EndpointList.id | ConvertTo-Json) + '] }' 
} else {
    $Body = '{ "fromTenant": "' + $($SrcWhoami.id) + '", "endpoints": ' + ($EndpointList.id | ConvertTo-Json) + ' }' 
}

try {
    $Result = (Invoke-RestMethod -Method Post -Uri $Uri -Body $Body -Headers $Header -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    Write-Host "      +-> Migration receiver created!"
} catch {
    Write-Host "      +-> Something went wrong, status code: $($_.Exception.Response.StatusCode.value__)"
    break
}

# Start migration task on source (sending) account
Write-Output "[SRC] Start a migration job in the sending tenant"
$Header = @{ "Authorization" = "Bearer $SrcToken"; "X-Tenant-ID" = "$($SrcWhoami.id)"; "Content-Type" = "application/json";}
$Uri = $DstWhoami.apiHosts.dataRegion + "/endpoint/v1/migrations/$($Result.id)"

# EndpointList must be an array even when it only contains one object
if ($EndpointList.Count -eq 1) {
    $Body = '{ "id": "' + $($Result.id) + '", "token": "' + $($Result.token) + '", "endpoints": [' + ($EndpointList.id | ConvertTo-Json) + '] }' 
} else {
    $Body = '{ "id": "' + $($Result.id) + '", "token": "' + $($Result.token) + '", "endpoints": ' + ($EndpointList.id | ConvertTo-Json) + ' }' 
}

try {
    $Result = (Invoke-RestMethod -Method Put -Uri $Uri -Body $Body -Headers $Header -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
    Write-Host "      +-> Migration started in sending tenant!"
} catch {
    Write-Host "      +-> Something went wrong, status code: $($_.Exception.Response.StatusCode.value__)"
    Write-Host "          403? --> Make sure that Migrations are active in the sending account!"
    break
}

# Retrieve List of Migration Tasks
do { $yn = Read-Host "[SRC] Start Device Migration Monitoring Mode? [Y/N]"; if ($yn -eq 'n') {exit}; } while($yn -ne "y")

do {
    Clear-Host
    Write-Output "==============================================================================="
    Write-Output "Sophos API - Device Migration Progress Monitor"
    Write-Output "==============================================================================="
    Write-Output "[SRC] Task created at $($Result.createdAt)"
    Write-Output "[SRC] Task expires at $($Result.expiresAt) "

    # Check if we neet to refresh out access token and do so if needed
    $CurrTime = Get-Date
    if ($SrcRefresh -lt $Currtime) {
        $SrcToken = API_Authenticate -id $SrcID -Secret $SrcSecret
        $SrcRefresh = $Currtime.AddMinutes(50)
    }
    
    $Header = @{ "Authorization" = "Bearer $SrcToken"; "X-Tenant-ID" = "$($SrcWhoami.id)";}
    $Uri = $SrcWhoami.apiHosts.dataRegion + "/endpoint/v1/migrations/" + $Result.id + "/endpoints?pageSize=1000"
    $Devices = (Invoke-RestMethod -Method Get -Uri $Uri -Headers $Header -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
     
    # Calculate statistics
    $CountPending = $Devices.items.where{$_.status -match 'pending'}.count
    $CountSucceeded = $Devices.items.where{$_.status -match 'succeeded'}.count
    $CountFailed = $Devices.items.where{$_.status -match 'failed'}.count

    if ( $CountPending -gt 0 ) {
        Write-Output " "
        Write-Output "[SRC] Pending devices:"

        foreach ($Device in $Devices.items) {
            if($Device.status -eq "pending") {
                $Hostname = $EndpointList.where{$_.id -match $Device.id}.hostname      
                Write-Output "      +-> $($Device.id) with Hostname $Hostname"
            }  
        }
    }
    
    Write-Output ""
    Write-Output "[SRC] Summary: migrated $CountSucceeded - failed $CountFailed - pending $CountPending devices"
    Write-Output ""

    if ( $CountPending -gt 0 ) {
        Write-Output "[SRC] Reload in one minute, make sure that pending devices are turned on"
        Start-Sleep -Seconds 60
    }

} while ( $CountPending -gt 0 )

Write-Output "[SRC] No more pending migrations, process complete!"
