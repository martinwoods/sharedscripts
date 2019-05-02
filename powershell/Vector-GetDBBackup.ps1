function Get-LatestDBPath {

    Param (
        [string]$NetworkPath,
        [string]$Username,
        [string]$Password,
        [string]$ClientID

    )
    $foundPath=""
    # Authenticate the network share
    net use $NetworkPath /user:$Username $Password
    # Look for production backups first
    $results=Get-ChildItem -Path "$NetworkPath" -Filter "*$ClientId*PROD*.bak" -Recurse
    if( $results.Count -gt 0 ) {
        $foundPath=($results | Sort LastWriteTime -Descending | Select -Last 1)
    }
   
    # No prod backup found, try for UAT
    $results=Get-ChildItem -Path "$NetworkPath" -Filter "*$ClientId*UAT*.bak" -Recurse
    if( $results.Count -gt 0 ) {
        $foundPath=($results | Sort LastWriteTime -Descending | Select -Last 1)
    }
    # No UAT DB either, check for Test?
    $results=Get-ChildItem -Path "$NetworkPath" -Filter "*$ClientId*TEST*.bak" -Recurse
    if( $results.Count -gt 0 ) {
        $foundPath=($results | Sort LastWriteTime -Descending | Select -Last 1)
    }
    if ($foundPath -eq "" ){
        Write-Error("Unable to locate DB Backup for $ClientId")
    } else {
        $foundPath
    }
}
$dbPath=Get-LatestDBPath -NetworkPath $DBBackupPath -Username $DBBackupUser -Password $DBBackupPassword -ClientID $SYS
    
Set-OctopusVariable -Name "LatestDBPath" -value $dbPath.Directory.FullName
Set-OctopusVariable -Name "LatestDBFilename" -value $dbPath.Name

Write-Host "Found $($dbPath.Name) to restore for $SYS"