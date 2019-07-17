#Run this when there are no FB deployments or deletions running (maybe temporarily disable FB Deploy project?)
#Get the list of present DBs from rimtest-sql-02 and rimtest-sql-05 and put them together in $presentDBlist by using the SQL >>SELECT name FROM master.dbo.sysdatabases WHERE name NOT IN ('master','model','msdb','tempdb')<< 
#Get the list of present sites from rimtest-web-03 (should be the same on 04) and put it in $currentSiteList by using this script in elevated PS: >>Import-Module WebAdministration; (Get-Website).Name<<
#Run the first section of the script (until the first Exit on line 45) - run the project FB delete in Octopus for the feature branches listed after "Run FB Delete"; copy the displayed declaration of $keepFB = @(....
#On each set of machines types tied to the FB environment, run the needed sections in elevated PS, making sure to get the declaration of $keepFB = @(... in first

$presentDBlist = @("PREO-843", "QA-PREO-EDW", "QA-PREO-RIM", "QA-SECSCAN-RYR", "VECTWO-19279", "VECTWO-27125", "VECTWO-28080", "VECTWO-28656", "VECTWO-28687", "VECTWO-29367", "VECTWO-29810", "VECTWO-30041", "VECTWO-30132", "VECTWO-30346", "VECTWO-30657", "VECTWO-30711", "VECTWO-30809", "VECTWO-30855", "VECTWO-30955", "VECTWO-31080", "VECTWO-31203", "VECTWO-31250", "VECTWO-31335", "VECWTO-21816")
$currentSiteList = @("DLH", "PREO-843", "QA-PREO-EDW", "QA-PREO-RIM", "QA-SECSCAN-RYR", "VECTWO-19279", "VECTWO-27125", "VECTWO-28080", "VECTWO-28656", "VECTWO-28687", "VECTWO-29367", "VECTWO-29810", "VECTWO-30041", "VECTWO-30132", "VECTWO-30346", "VECTWO-30657", "VECTWO-30711", "VECTWO-30809", "VECTWO-30855", "VECTWO-30955", "VECTWO-31080", "VECTWO-31203", "VECTWO-31250", "VECTWO-31335", "VRECTEST2")


$runFBDelete = @()
$keepFBs = @()

$presentDBlist | ForEach-Object {
    if ($_ -notin $currentSiteList){
        $runFBDelete += $_
    }
    else{
        if ($_ -notin $keepFBs) {
            $keepFBs += $_
        }
    }
}
$currentSiteList | ForEach-Object {
    if ($_ -notin $presentDBlist){
        $runFBDelete += $_
    }
    else{
        if ($_ -notin $keepFBs) {
            $keepFBs += $_
        }
    }
}
Write-host "Run FB Delete"
$runFBDelete
Write-host "---------------"

$keepDisplay = '$keepFB = @('
$keepFBs | ForEach-Object {$keepDisplay += """$_"","}
$keepDisplay = $keepDisplay.Substring(0, $keepDisplay.Length - 1) + ")"
Write-host "---------------"
$keepDisplay
Write-host "---------------"

exit

# =========================================================
# Run on web-servers as Admin
# =========================================================

Import-Module WebAdministration

$keepFB = 

$webSites = Get-Website
$appPools = Get-ChildItem IIS:\AppPools

$sitesToRemove = @()
foreach ($site in $webSites){
    if ($site.Name -notin $keepFB){
        $sitesToRemove += $site.Name
    }
}

$appPoolsToRemove = $appPools
foreach ($fbName in $keepFB){
    $appPoolsCheck = $appPoolsToRemove | Where-Object {!($_.Name.Contains($fbName))}
    $appPoolsToRemove = $appPoolsCheck
}

$siteFolders = Get-ChildItem -path "D:\Websites" | Where-Object {$_.PSIsContainer}
$siteFoldersToRemove = @()
foreach ($siteFolder in $siteFolders) {
    if ($siteFolder.Name -notin $keepFB -and $siteFolder.Name -notin @("API", "connectionstring")){
        $siteFoldersToRemove += $siteFolder.FullName
    }
}

$usersToRemove = @()
$localUsers = Get-LocalUser | Select-Object *
$localUsers | ForEach-Object{
    if ($_.Name -notin $keepFB -and ($_.Name -like "*VECTWO*" -or $_.Name -like "*TestWebUser")){
        $usersToRemove += $_
    }
}

$servicesToRemove = @()
$localServices = Get-WmiObject win32_service | Select-Object name, startname
$localServices | ForEach-Object {
    if ($_.startname.Replace("`.`\") -in $usersToRemove) {
        $servicesToRemove += $_.Name
    }
}

$tempPath = [System.IO.Path]::GetTempPath()
$import = Join-Path -Path $tempPath -ChildPath "import.inf"
$export = Join-Path -Path $tempPath -ChildPath "export.inf"
$secedt = Join-Path -Path $tempPath -ChildPath "secedt.sdb"
if (Test-Path $import) { 
    Remove-Item -Path $import -Force 
}
if (Test-Path $export) { 
    Remove-Item -Path $export -Force 
}
if (Test-Path $secedt) { 
    Remove-Item -Path $secedt -Force 
}
$keepSids = ""
secedit /export /cfg $export
$sids = ((select-string $export -pattern "SeServiceLogonRight").line.Split("=").Trim()[1]) -Split ",\*"
foreach ($sid in $sids){
    if ($sid -in $localUsers.SID -and $sid -notin $usersToRemove.SID){
        $keepSids += ",*$sid"
    }
}
$keepSids = $keepSids.Substring(1, $keepSids.Length - 1)





# -------- REMOVAL --------

$sitesToRemove | ForEach-Object{
    Remove-Website $_
}
$appPoolsToRemove | ForEach-Object{
    Remove-WebAppPool $_
}
$siteFoldersToRemove | ForEach-Object{
    Remove-Item -Path $_ -recurse -Force -WhatIf
}
$servicesToRemove | ForEach-Object{
    Stop-Service $_
    & sc.exe delete """$_)"""
}


foreach ($line in @("[Unicode]", "Unicode=yes", "[System Access]", "[Event Audit]", "[Registry Values]", "[Version]", "signature=`"`$CHICAGO$`"", "Revision=1", "[Profile Description]", "Description=GrantLogOnAsAService security template", "[Privilege Rights]", "SeServiceLogonRight = $keepSids")) {
    Add-Content $import $line
}
Write-Verbose "Calling secedit..."
secedit /import /db $secedt /cfg $import
secedit /configure /db $secedt
Write-Verbose "Calling gpupdate..."
gpupdate
Write-Verbose "Cleaning up temp files..."
Remove-Item -Path $import -Force
Remove-Item -Path $export -Force
Remove-Item -Path $secedt -Force

$usersToRemove | ForEach-Object{
    Remove-LocalUser $_.Name
    $userFolder = Join-Path "C:\Users" $_.Name
    if (Test-Path $userFolder){
        Remove-Item -Path $userFolder -Force -Recurse
    }
}





# =========================================================
# Run for reportServer
# =========================================================


# Create an instance of the proxy for interaction with the report server
Function Create-SSRSProxy{
    Param (
        [Parameter(Mandatory=$true)]
        [string]$ServerURI,
        [string]$Username,
        [string]$Password
    )


    # check to see if credentials were supplied for the services
    if(([string]::IsNullOrEmpty($Username) -ne $true) -and ([string]::IsNullOrEmpty($Password) -ne $true))
    {
        # secure the password
        $secpasswd = ConvertTo-SecureString "$Password" -AsPlainText -Force

        # create credential object
        $ServiceCredential = New-Object System.Management.Automation.PSCredential ($Username, $secpasswd)

        # create proxy
        $ReportServerProxy = New-WebServiceProxy -Uri $ServerURI -Credential $ServiceCredential
        $ReportServerProxy.Timeout=100000
    }
    else
    {
        # create proxies using current identity
        $ReportServerProxy = New-WebServiceProxy -Uri $ServerURI -UseDefaultCredential
        $ReportServerProxy.Timeout=100000
    }
    Return $ReportServerProxy
}


# Return the full URI to the web service for the given hostname
Function Get-ServerURI{
    Param (
        [Parameter(Mandatory=$true)]
        [string]$Hostname
        )

    Return "http://$Hostname/ReportServer/ReportService2005.asmx?wsdl"
}

$keepFB = 

$proxy = Create-SSRSProxy -ServerURI (Get-ServerURI -Hostname "rimtest-rps-02")

$ssrsFolders = $proxy.ListChildren("/",$false) | Where-Object {$_.type -eq "Folder"} | Select-Object Name, Path

foreach ($folder in $ssrsFolders){
    if ($folder.Name -notin $keepFB){
        $foldersToRemove += $folder.Path
    }
}

# REMOVAL

$foldersToRemove | ForEach-Object {
    $proxy.DeleteItem($_)
}



# =========================================================
# Run on FS
# =========================================================

$keepFB = 

$fsFoldersToDelete = Get-ChildItem -Path "D:\" -Directory | Where-Object {$_.Name -notin $keepFB -and $_.Name -ne "Octopus"}

# Removal
$fsFoldersToDelete | ForEach-Object {
    Remove-SmbShare -Name $_.Name -Force -ErrorAction Continue
    Remove-Item -Path $_.FullName -Force -Recurse
}
