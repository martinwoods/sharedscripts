# This script will check the target octopus server for user accounts with multiple AD identities
# This causes an issue in Octopus which results in a second account being created for the user
# and their permissions are not accessible
# The affected users will likely have 2 Active Directory identities in Octopus
# One with just the Sam Account Name, and a second one with Sam Account Name, Email Address and User principal name
# To resolve, remove the identity with just the Sam Account Name and any duplicate accounts that may have been created


$OctopusServer="http://octopus.rim.local"
$APIKey="API-YOURAPIKEY"

Add-Type -Path "Octopus.Client.dll"
$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $OctopusServer,$APIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$found=0
ForEach ($user in $repository.Users.FindAll()){
    $count=$user.Identities.Where({$_.IdentityProviderName -eq 'Active Directory'}).Count
    If($count -gt 1){
        Write-Output "User $($user.Username) has $count Active Directory Identities"
        $found++
    }
}

Write "Found $found user(s) with multiple AD identities to be fixed."