$targetOctopusServer = "rim-build-05" # use rim-build-05 or rim-build-07
$exportFolder = "C:\OctopusExport"
$apiKey = ''


# ------------------------------------------------------------------------


if($env:COMPUTERNAME -notin @("rim-build-05","rim-build-07")){
    Write-Host "Run this on the Octopus server" -ForegroundColor Red
    EXIT
}

# Remove these folders from the export
$cleanupItems = @(
    "ActionTemplateVersions",
    "Attachments",
    "RunbookSnapshots"
)


Add-Type -Path "C:\Program Files\Octopus Deploy\Octopus\Octopus.Client.dll"
$migratorPath = "C:\Program Files\Octopus Deploy\Octopus\Octopus.Migrator.exe"

# Extract the list of Project Groups
$octopusUrl = "http://$targetOctopusServer"
$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusUrl,$apiKey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint
$projectGroupsNames = ($repository.ProjectGroups.GetAll()).Name

if (-not (Test-Path($exportFolder))){
    New-Item -Path $exportFolder -ItemType Directory -Force | Out-Null
}

# Cleanup the destination export folder
Remove-Item "$exportFolder\*" -Recurse -Force

# Export the data, one project group at a time
foreach ($projectGroup in $projectGroupsNames){
    & "$migratorPath" partial-export --directory="$exportFolder" --projectGroup="$projectGroup" --ignore-certificates --ignore-deployments --ignore-history --ignore-machines --ignore-tenants --password="bec@useWeN33d0ne"
}

# Cleanup unwanted folders
ForEach ($folder in $cleanupItems){
	$folder = $folder.Trim()
	$crtDir = "$exportFolder\$folder"
    If ((Test-Path $crtDir) -and ($folder -ne "")) {
        Remove-Item -Path $crtDir -Recurse
    }
}

# Zip the exported data
$zipPath = "$($env:USERPROFILE)\Desktop\OctopusExport_$targetOctopusServer.zip"
Write-host "Saving export archive to $zipPath"
Compress-Archive -Path "$exportFolder\*" -DestinationPath $zipPath -CompressionLevel Optimal
