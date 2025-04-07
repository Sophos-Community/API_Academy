# Part 2 - Checks progress of previous started migration

<#
    Description: Monitor the progress of Device Migration Tasks
#>

###################################################################################################################
# Define OAUTH Access Data for the account you want to monitor
###################################################################################################################

$SrcID = ""
$SrcSecret = ""

###################################################################################################################

Clear-Host
Write-Output "==============================================================================="
Write-Output "Sophos API - Device Migration Monitor"
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

if ( ($SrcID -eq "") -or ($SrcSecret -eq "") ) {
    Write-Output "You must enter the OAUTH Access Data in the script to be able to use the script!"
}

# Authenticate against the source (sending) account and get whoami details
Write-Output "[SRC] Authenticate using credentials of the sending account"
$SrcToken = API_Authenticate -id $SrcID -Secret $SrcSecret
$SrcWhoami = API_Whoami -Token $SrcToken

# Retrieve List of Migration Tasks
Write-Output "[SRC] Create a list of all sending Migration Tasks in this account"
    
$APIHeader = @{ "Authorization" = "Bearer $SrcToken"; "X-Tenant-ID" = "$($SrcWhoami.id)";}
$Uri = $SrcWhoami.apiHosts.dataRegion + "/endpoint/v1/migrations?mode=sending"
$Migrations = (Invoke-RestMethod -Method Get -Uri $Uri -Headers $APIHeader -ErrorAction SilentlyContinue -ErrorVariable ScriptError)

foreach ($Migration in $Migrations.items) {
    Write-Output ""
    Write-Output "[SRC] Migration Task found"
    Write-Output "      +-> Task created at $($Migration.createdAt)"
    Write-Output "      +-> Task expires at $($Migration.expiresAt)"

    $Uri = $SrcWhoami.apiHosts.dataRegion + "/endpoint/v1/migrations/" + $Migration.id + "/endpoints?pageSize=1000"
    $Devices = (Invoke-RestMethod -Method Get -Uri $Uri -Headers $APIHeader -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
        
    $CountPending = $Devices.items.where{$_.status -match 'pending'}.count
    $CountSucceeded = $Devices.items.where{$_.status -match 'succeeded'}.count
    $CountFailed = $Devices.items.where{$_.status -match 'failed'}.count
        
    foreach ($Device in $Devices.items) {
        if($Device.status -eq "pending") {
            Write-Output "      +-> Device with ID $($Device.id) is still pending"
        }  
        if($Device.status -eq "failed") {
            Write-Output "      +-> Device with ID $($Device.id) failed to migrate"
        }  
    }
    Write-Output "[SRC] Summary: migrated $CountSucceeded - failed $CountFailed - pending $CountPending devices"
}

Write-Output ""
Write-Output "[SRC] Scan complete!"
