Function Get-OctopusProject {
    Param(
         [string]$server,
         [string]$apiKey,
         [string]$projectSlug
    )
	# Get the project
    $projectUrl="$($server)/api/projects/$($projectSlug)?apiKey=$apiKey"
    $project=(Invoke-WebRequest -UseBasicParsing $projectUrl).Content | ConvertFrom-Json
    return $project
}

Function Get-OctopusDeploymentProcess {
     Param(
         [string]$server,
         [string]$apiKey,
         [string]$deploymentProcessId
    )
	# Get the Deployment process
    $deploymentProcessUrl="$($server)/api/deploymentprocesses/$($deploymentProcessId)?apiKey=$apiKey"
    return (Invoke-WebRequest -UseBasicParsing $deploymentProcessUrl).Content | ConvertFrom-Json
}

Function Get-OctopusProjectRelease {
     Param(
         [string]$server,
         [string]$apiKey,
         [string]$projectId, 
         [string]$releaseVersion
    )
	# Get the project Id
    $releaseUrl="$($server)/api/projects/$($projectId)/releases/$($releaseVersion)?apiKey=$apiKey"
    
    return (Invoke-WebRequest -UseBasicParsing $releaseUrl).Content | ConvertFrom-Json
}


Function Get-OctopusVariables {
    Param (
        [string]$server, 
        [string]$apiKey,
        [string]$projectId,
        [string]$projectSlug,
        [string]$environmentId,
        [string]$tenantId,
        [string]$channelId,
        [string]$machineId,
        [string]$role,
        [string]$step
        
    )

    $params=""
    If( $projectSlug -ne "") {
        $projectId=(Get-OctopusProject -server $server -apiKey $apiKey -projectSlug $projectSlug).Id
    }
    If( $projectId -ne ""){ $params+="project=$($projectId)&" }
    If( $environmentId -ne ""){ $params+="environment=$($environmentId)&" }
    If( $tenantId -ne "") { $params+="tenant=$($tenantId)&"}
    If( $channelId -ne "") { $params+="channel=$($channelId)&"}
    If( $machineId -ne "") { $params+="machine=$($machineId)&"}
    If( $role -ne "") { $params+="role=$($role)&"}
    If( $step -ne "") { $params+="action=$($step)&"}

    If($params -ne ""){
        $url="$($server)/api/variables/preview?$($params)&apiKey=$apiKey"
        Write-Verbose "Querying $url"
        $variables=(Invoke-WebRequest -UseBasicParsing $url).Content | ConvertFrom-Json
        # Take the variables returned and put the name/value pairs into a hashmap
        $hashmap=@{}
        $variables.Variables.Foreach({
            if(-not $_.Name.StartsWith('Octopus')){
                $hashmap.Add($_.Name, $_.Value)
            }
        })
        return $hashmap
    } else {
        return $false
    }
}
Function Test-TenantHasProject {
    Param(
         [string]$server,
         [string]$apiKey,
         [string]$tenantId,
         [string]$environmentId,
         [string]$projectSlug
    )

    Write-Verbose "Checking project $($projectSlug) for $($tenantId) in $($environmentId)"
    $projectId=(Get-OctopusProject -server $server -projectSlug $projectSlug -apiKey $apiKey).Id

   
    # Get the projects/environments for this tenant
    $tenantUrl="$($server)/api/tenants/$($tenantId)?apiKey=$apiKey"
    $tenant=(Invoke-WebRequest -UseBasicParsing $tenantUrl).Content | ConvertFrom-Json
    if($tenant.ProjectEnvironments."$($projectId)" -ne $null) {
        $environments=$tenant.ProjectEnvironments."$($projectId)"
    
        # Check if the tenant has the required project in the current environment
        If($environments.Contains($environmentId)) {
            Return $True
        } else {
            Return $False    
        }
    } else {
        Return $False
    }
}

# Check if we should deploy a project for a tenant
# If the version number is set to 0, NA or any other value in NoArray
# or the project is not connected for this tenant
# Then do not deploy, otherwise, do
Function Get-OctopusShouldDeployProjectForTenant {
 Param (
    [string]$server,
    [string]$apiKey,
    [string]$projectSlugOrId,
    [string]$version = $null,
    [string]$environmentId,
    [string]$environmentName,
    [string]$tenantId,
    [string]$tenantName
 )
 $deploy=$True
 $NoArray="0", 0, "No", "NA", "N/A", "N\A", "N-A", "False"
  # Check if the version matches a "No" value
  If($NoArray.Contains($version)){
      $deploy=$False
      Write-Host "Skipping Deployment for Project $projectSlugOrId"
  } Else {
  	# Check if the tenant has this project linked
    $check=Test-TenantHasProject -server $server -apiKey $apiKey -tenantId $tenantId -environmentId $environmentId -projectSlug $projectSlugOrId
    If(-not $check){
    	$deploy=$False
    	Write-Highlight "$tenantName does not have project $projectSlugOrId linked in $environmentName"
    }
  }

  Return $deploy
}

#
# Add a project to the target environment for a given client
# Adds the project only if it is not already mapped
#
Function Add-TenantProject {
    Param(
         [string]$server,
         [string]$apiKey,
         [string]$tenantId,
         [string]$environmentId,
         [string]$projectSlug
    )

    
    # Get tenant object
    $tenantUrl="$($server)/api/tenants/$($tenantId)?apiKey=$apiKey"
    $tenant=(Invoke-WebRequest -UseBasicParsing $tenantUrl).Content | ConvertFrom-Json

    $projectId=(Get-OctopusProject -Server $server -projectSlug $projectSlug -apiKey $apiKey).Id

    # Get the project/environments array
    [System.Collections.ArrayList]$environments=$tenant.ProjectEnvironments."$($projectId)"

    # If the project doesn't exist in any environment, need to add an array to the ProjectEnvironments member
    if( $environments -eq $null){
        Write-Verbose "$($tenant.Name) does not have $($projectSlug) in any environment, creating."
        Add-Member -InputObject $tenant.ProjectEnvironments -MemberType NoteProperty -Name $projectId -Value (New-Object System.Collections.ArrayList)
        [System.Collections.ArrayList]$environments=$tenant.ProjectEnvironments."$($projectId)"
    }
    # Add the project to this environment, if it isn't already present
    if( -not $environments.Contains($environmentId)) {
        Write-Host "Adding $($projectSlug) for $($tenant.Name) in environment $($environmentId)."
        
        $environments.Add($environmentId)
        $tenant.ProjectEnvironments."$($projectId)"=$environments
        $tenantJson=$tenant | ConvertTo-Json
        # PUT the updated tenant info, and update the tenant variable with the updated version
        $tenant=(Invoke-WebRequest -UseBasicParsing -Method PUT $tenantUrl -Body $tenantJson).Content | ConvertFrom-Json
        ## Add env to PE?
    }
    
    return $tenant
    
}

# Update all variables in a project
# If $recurse is set to True, this will also update the variables with any child projects deployed using a Deploy a Release step

Function Update-OctopusVariables {
    Param(
        [string]$server,
        [string]$apiKey,
        [string]$projectSlugOrId,
        [string]$releaseVersion,
        [boolean]$recurse = $false,
        [int]$depth = 0
    )

    $headers=@{ 'X-Octopus-ApiKey' = $apiKey }
    $project=Get-OctopusProject -server $server -apiKey $apiKey -projectSlug $projectSlugOrId
    $projectId=$project.Id
    $projectName=$project.Name
    Write-Highlight "$("`t" * $depth)$(">" * $depth)Updating variables for $projectName release $releaseVersion"
    $release=Get-OctopusProjectRelease -server $server -apiKey $apiKey -projectId $projectId -releaseVersion $releaseVersion
    $updateUrl="$($server)/api/releases/$($release.Id)/snapshot-variables"

    $response=(Invoke-RestMethod -Method POST -Uri $updateUrl -Headers $headers)

    # If recurse is true, get the deployment process, and update any child project which has a Octopus.DeployRelease ActionType
    If($recurse) {
        $project=Get-OctopusProject -server $server -apiKey $apiKey -projectSlug $projectId
        $deploymentProcessId=$project.DeploymentProcessId
        $deploymentProcess=Get-OctopusDeploymentProcess -server $server -apiKey $apiKey -deploymentProcessId $deploymentProcessId


        Foreach($steps in $deploymentProcess.Steps){
            If($steps.Actions[0].ActionType -eq "Octopus.DeployRelease"){
                $stepProjectId=$steps.Actions[0].Properties."Octopus.Action.DeployRelease.ProjectId"
                $stepReleaseVersion=($release.SelectedPackages | Where-Object { $_.'StepName' -eq $steps.Name }).Version
                If($stepReleaseVersion -ne $null -and $stepReleaseVersion -ne "0"){ # this will be null if the snapshot does not contain this step or 0 if the version was not selected
                    Update-OctopusVariables -server $server -apiKey $apiKey -projectSlugOrId $stepProjectId -releaseVersion $stepReleaseVersion -recurse $true -depth ($depth+1)
                } else {
                    Write-Highlight "$("`t" * ($depth+1))Ignoring $($steps.Name), it does not exist in this snapshot, or has been set to 0."
                }
            }
        }
    }
}



Function Update-OctopusTenantVariable {
	Param (
		[string]$server,
        [string]$apiKey,
        [string]$projectSlugOrId,
		[string]$tenantId,
        [string]$environmentId,
		[string]$variableName,
		[string]$newValue
	)
	
	$headers=@{ 'X-Octopus-ApiKey' = $apiKey }
    $project=Get-OctopusProject -server $server -apiKey $apiKey -projectSlug $projectSlugOrId
    $projectId=$project.Id
	
	$tenantVariablesUrl="$($server)/api/tenants/$($tenantId)/variables"

    $existingVariables=(Invoke-WebRequest -UseBasicParsing "$($tenantVariablesUrl)?apiKey=$($apiKey)").Content | ConvertFrom-Json

    $variableInfo=$existingVariables.ProjectVariables."$projectId".Templates | Where-Object {$_.Name -eq "$variableName"}
    $variableId=$variableInfo.Id
    $variableId=$variableInfo.Id
    If($existingVariables.ProjectVariables."$projectId".Variables.$environmentId -eq $null){
        Write-Highlight "[Error] Tenant $tenantId does not have project $projectSlugOrId connected in environment $environmentId, Unable to Update variable $variableName."
        Return $false
    } ElseIf($existingVariables.ProjectVariables."$projectId".Variables.$environmentId."$variableId" -eq $null){
       $existingVariables.ProjectVariables."$projectId".Variables.$environmentId | Add-Member -MemberType NoteProperty -Name "$variableId" -Value ("{HasValue:true, NewValue: '$newValue'}" | ConvertFrom-Json)
    } else {
        $existingVariables.ProjectVariables."$projectId".Variables."$environmentId"."$variableId".NewValue=$newValue
    }

    $tenantVariablesJson=$existingVariables | ConvertTo-Json -Depth 50 


    $response=(Invoke-RestMethod -Method POST -Uri $tenantVariablesUrl -Headers $headers -Body $tenantVariablesJson)
	Return $response
}

Export-ModuleMember -Function '*'