$apiKey = '' #API key to connect to the desired Octopus instance
$octopusServer = "Sandbox" #Sandbox or Live
$projectSlugToConnect = "" #eg "create-vector-account"
$environmentExceptions = @("Dev", "Staging") #As named in Octopus > Infrastructure > Environments
$tenantExceptions = @() #As named in Octopus > Tenants

#----------------------------------------------------------------------------------------------------------

if ($octopusServer.ToLower().Contains("live")){
    $octopusMachine = "rim-build-07"
}
else{
    $octopusMachine = "rim-build-05"
}

Add-Type -Path "\\$octopusMachine\C$\Program Files\Octopus Deploy\Octopus\Octopus.Client.dll"
$octopusUrl = "http://$octopusMachine"

#Connect to Octopus instance and get the needed project and environment info
$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusUrl,$apiKey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint
$project = $repository.Projects.Get($projectSlugToConnect)
$environments = $repository.Environments.FindAll() | Where-Object {$_.Name -notin $environmentExceptions}
$tenants = $repository.Tenants.GetAll()

#Create the environment collection to be used for scoping the project
$collection = New-Object Octopus.Client.Model.ReferenceCollection
$collectionCopy = New-Object Octopus.Client.Model.ReferenceCollection
foreach ($envId in $environments.Id){
    $a = $collection.Add($envId)
    $a = $collectionCopy.Add($envId)
}

if ($null -eq $project -or $null -eq $collection -or $null -eq $environments){
    Write-Error "Something's wrong!"
    exit
}

foreach ($tenant in $tenants){
    if ($tenant.name -in $tenantExceptions){
        continue
    }
    Write-Host "Updating tenant $($tenant.name)"
    $tenantCollection = $null
    $tenantProjEnv = $tenant.ProjectEnvironments[$project.Id]
    if ($null -eq $tenantProjEnv){
        #Project is not connected to the tenant, add it with the environment list
        $tenant.ProjectEnvironments.Add($project.Id, $collection)
    }
    else{
        #Project is already connected to the tenant, update the environment list and keep existing environments
        $tenantCollection = $collection
        $tenantProjEnv | ForEach-Object{
            if ($_ -notin $collection){
                $a = $tenantCollection.Add($_)
            }
        }
        $tenant.ProjectEnvironments[$project.Id] = $tenantCollection
    }
    #Modify update tenant with the new ProjectEnvironment list
    $a = $repository.Tenants.Modify($tenant)
    Write-Host "Successfully updated tenant $($tenant.name)"
    $collection = $collectionCopy
}
