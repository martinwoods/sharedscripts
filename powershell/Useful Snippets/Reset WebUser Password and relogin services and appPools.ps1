$tenant = "" # ie WAVS
$env = "" # ie Test
$username = $tenant + $env + "WebUser" # ie WAVSTestWebUser
$password = '' # this should be the generic VectorDBPass (also shared in TSS)

##################################################


# Reset Windows password
& net user $username $password


# Update AppPool Identity to use the new password
Import-Module WebAdministration
$appPools = Get-ChildItem IIS:\AppPools | Where-Object {$_.Name -like "$tenant$env*"}
foreach ($pool in $appPools){
    Set-ItemProperty "IIS:\AppPools\$($pool.name)" -name processModel -value @{userName="$username";password="$password";identitytype="SpecificUser"}
    if ($pool.State -eq "Stopped"){
        Start-WebAppPool $pool.name
    }
    elseif($pool.State -eq "Running"){
        Restart-WebAppPool $pool.name
    }
}


# Update services LogOnAs to use the new password
$servicesToChange = @()
$servicesToChange += Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE Name = 'RiM.Vector.Web.Terminal.$tenant.$env'" #terminal service
$servicesToChange += Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE Name = 'Vector Bridge Service.$tenant'" #bridge service
foreach ($service in $servicesToChange){
    Write-Host "Altering $($service.name)..."
    $result = ($service.Change($null,$null,$null,$null,$null,$null,".\$username",$password,$null,$null,$null)).ReturnValue
    Write-Host "ExitCode: $result"
	$service.StopService() | Out-Null
	$service.StartService() | Out-Null
}