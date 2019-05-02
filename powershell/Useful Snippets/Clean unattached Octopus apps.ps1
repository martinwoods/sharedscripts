Import-Module WebAdministration
Add-Type -AssemblyName Microsoft.VisualBasic

$directories=Get-ChildItem "D:\Octopus\Apps\New\*\*\*\*" 

Foreach ($dir in $directories) {

    $webapp=$(Get-WebApplication | Where-Object {$_.PhysicalPath -eq $dir.FullName})
    $website=$(Get-Website | Where-Object {$_.PhysicalPath -eq $dir.FullName})

    If($webapp -ne $null ) {
        Write-Output "Found Web App $($webapp.ApplicationPool) at $($dir.FullName)"
    } elseif ( $website -ne $null ) {
        Write-Output "Found Web Site $($webapp.ApplicationPool) at $($dir.FullName)"
    } else {
        Write-Warning "No webapp found for $($dir.FullName)"
        Write-Warning "Moving $($dir.FullName) to Recycle Bin"
        Remove-Item-ToRecycleBin($dir.FullName)
    }
}




function Remove-Item-ToRecycleBin($Path) {
    $item = Get-Item -Path $Path -ErrorAction SilentlyContinue
    if ($item -eq $null)
    {
        Write-Error("'{0}' not found" -f $Path)
    }
    else
    {
        $fullpath=$item.FullName
        Write-Verbose ("Moving '{0}' to the Recycle Bin" -f $fullpath)
        if (Test-Path -Path $fullpath -PathType Container)
        {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($fullpath,'OnlyErrorDialogs','SendToRecycleBin')
        }
        else
        {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($fullpath,'OnlyErrorDialogs','SendToRecycleBin')
        }
    }
}