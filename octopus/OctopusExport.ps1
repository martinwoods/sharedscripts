<#
.SYNOPSIS
    This script does a partial export of the data in an Octopus Server

.DESCRIPTION
    All projects, runbooks, variable sets, step templates and script modules from the Octopus server instance.
    Script connects to the API to get the list of all Project Groups, then runs a Octopus.Migrator.exe partial export command for each existing Project Group. 
    This will extract the projects, runbooks and all connected library var sets, script modules and used step templates.
    Exported items will be zipped and saved on the user's Desktop, overwriting the target .zip if already existing.

.PARAMETER apiKey
    The parameter apiKey is used to define the value of your personal Octopus ApiKey for the target server

.PARAMETER exportActionTemplateVersions
    The parameter exportActionTemplateVersions (bool) is used to control exporting all versions of the step templates.
    The default is False
    Only set to True if you want all versions extracted for cases where not all projects are on the same version

.NOTES
    Author: Vlad Petrescu
    Last Edit: 2021-01-04
    Version 1.0 - initial release

    Notes: 
    -   The script needs to be executed on the machine the Octopus server runs on.
    -   Step templates are exported as LibraryVariableSets.
    -   Octopus.Migrator requires a password for the export in order to encrypt sensitive values - this is then used for decryption when running an import on the destination server.
        We are not importing the output anywhere, yet still need to meet the requirement for a password, so generate a random password for each export - there's no need to keep it.
        
#>


$apiKey = ''
$exportActionTemplateVersions = $false  

# ------------------------------------------------------------------------


$exportFolder = "C:\OctopusExport"

# Check the apiKei was populated
if($null -eq $apiKey -or $apiKey -eq ''){
    Write-Host "You need to set `$apiKey to your Octopus API key for $($env:COMPUTERNAME)" -ForegroundColor Red
    EXIT
}

# Check the script is running on an Octopus server
$targetOctopusServer = $env:COMPUTERNAME
if($targetOctopusServer.ToLower() -notin @("rim-build-05","rim-build-07")){
    Write-Host "Run this directly on the Octopus server" -ForegroundColor Red
    EXIT
}

# Remove these folders from the export
$cleanupItems = @(
    "Attachments",
    "RunbookSnapshots"
)
if(-not $exportActionTemplateVersions){
    $cleanupItems += "ActionTemplateVersions"
}

Add-Type -Path "C:\Program Files\Octopus Deploy\Octopus\Octopus.Client.dll"
$migratorPath = "C:\Program Files\Octopus Deploy\Octopus\Octopus.Migrator.exe"
[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null

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
    # See notes about the password
    $exportPassword = [System.Web.Security.Membership]::GeneratePassword(20,0)
    & "$migratorPath" partial-export --directory="$exportFolder" --projectGroup="$projectGroup" --ignore-certificates --ignore-deployments --ignore-history --ignore-machines --ignore-tenants --password=$exportPassword
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
Write-host "Saving export archive to $zipPath (overwrites target if existing)"
Compress-Archive -Path "$exportFolder\*" -DestinationPath $zipPath -CompressionLevel Optimal -Force
