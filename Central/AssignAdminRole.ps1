# add this code snippet to one of the auth code samples for Central Admin, Central Enterprise Dashboard or Central Partner (snippets 1 2 or 3)
# you will find a line that says INSERT CODE HERE

# SOPHOS Common API Headers:
$TenantHead = @{}
$TenantHead.Add("Authorization" ,"Bearer $Token")
$TenantHead.Add("X-Tenant-ID" ,"$TenantID")
$TenantHead.Add("Content-Type", "application/json")

# Initialize Variables
$AdminId = $null
$AdminRole = $null
$UserId = $null

# Specify Emailaddress of the user which should become Super Admin
$AdminEmail='<your admin email address>'

Write-Output "Getting details of already existing Administrators"
# Search all Admin Accounts in Tennant
$GetAdmins = (Invoke-RestMethod -Method Get -Uri $DataRegion"/common/v1/admins?pageTotal=true" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
foreach($Admin in $GetAdmins.items){
    if ($Admin.profile.email -eq $AdminEmail) {
        $AdminId=$Admin.id
        $AdminRole=$Admin.roleAssignments.RoleId
    }
}

Write-Output "Getting details of users defined in Sophos Central"
# Search all User Accounts in Tennant
$GetUsers = (Invoke-RestMethod -Method Get -Uri $DataRegion"/common/v1/directory/users?pageTotal=true" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
foreach($User in $GetUsers.items){
    if ($User.email -eq $AdminEmail) {
        $UserId=$User.id  
    }
}

Write-Output "Getting the ID of the Super Admin Role"
# Search ID of SuperAdmin Role
$GetRoles = (Invoke-RestMethod -Method Get -Uri $DataRegion"/common/v1/roles?pageTotal=true" -Headers $TenantHead -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
$RoleId=$GetRoles.items.Where{$_.Name -eq 'SuperAdmin'}.id


if ($null -eq $UserId){
    Write-Output 'ATTENTION: Email address not found. Please create an user first!' 
    exit
}

if ($AdminRole -eq $RoleId) {
    Write-Output 'ATTENTION: User is SuperAdmin already.'
    exit
}

# Body and URI are different for new Admins vs. Admins that are assigned a new role
if ($null -eq $AdminId){
    $Body = '{"userId": "' + $UserId + '", "roleAssignments": [{ "roleId": "' + $RoleId + '"}]}'
    $Uri = $DataRegion + "/common/v1/admins"
} else {
    $Body = '{ "roleId": "' + $RoleId + '"}'
    $Uri = $DataRegion + "/common/v1/admins/" + $AdminId + "/role-assignments"
}

try {
    $Result = (Invoke-RestMethod -Uri $Uri -Method Post -Headers $TenantHead -Body $Body -ErrorAction SilentlyContinue -ErrorVariable ScriptError)
} catch {
    Write-Output 'ERROR: Could not make the user a Super Admin.'
}

Write-Output  'DONE! The user was promoted to Super Admin.'
