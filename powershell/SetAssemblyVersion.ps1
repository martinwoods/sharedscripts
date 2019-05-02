# SetAssemblyVersion.ps1
#
# http://www.luisrocha.net/2009/11/setting-assembly-version-with-windows.html
# http://blogs.msdn.com/b/dotnetinterop/archive/2008/04/21/powershell-script-to-batch-update-assemblyinfo-cs-with-new-version.aspx
# http://jake.murzy.com/post/3099699807/how-to-update-assembly-version-numbers-with-teamcity
# https://github.com/ferventcoder/this.Log/blob/master/build.ps1#L6-L19

Param(
    [string]$path=$pwd,
    [string]$infoVersion
)

function Help {
    "Sets the AssemblyVersion and AssemblyFileVersion of AssemblyInfo.cs files`n"
    ".\SetAssemblyVersion.ps1 [VersionNumber] -path [SearchPath]`n"
    "   [VersionNumber]     The version number to set, for example: 1.1.9301.0"
    "   [SearchPath]        The path to search for AssemblyInfo files.`n"
}
function Update-SourceVersion
{
    Param ([string]$Version, 
        [string]$InfoVersion
    )
   

    foreach ($o in $input) 
    {
        Write-Host "Updating  '$($o.FullName)' -> $Version"
    
        $assemblyVersionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
        $fileVersionPattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
        $infoVersionPattern = 'AssemblyInformationalVersion\(".*"\)'
        $assemblyVersion = 'AssemblyVersion("' + $version + '")';
        $fileVersion = 'AssemblyFileVersion("' + $version + '")';
        $newInfoVersion = 'AssemblyInformationalVersion("' + $InfoVersion + '")';

        # Update the file, check whether or not we need to update the info version too
        if( [string]::IsNullOrEmpty($InfoVersion)){
            (Get-Content $o.FullName) | ForEach-Object  { 
               % {$_ -replace $assemblyVersionPattern, $assemblyVersion } |
               % {$_ -replace $fileVersionPattern, $fileVersion }
            } | Out-File $o.FullName -encoding UTF8 -force
        } else {
              (Get-Content $o.FullName) | ForEach-Object  { 
               % {$_ -replace $assemblyVersionPattern, $assemblyVersion } |
               % {$_ -replace $fileVersionPattern, $fileVersion } |
               % {$_ -replace $infoVersionPattern, $newInfoVersion }
            } | Out-File $o.FullName -encoding UTF8 -force
        }
    }
}
function Update-AllAssemblyInfoFiles ( $version, $infoVersion, $path )
{
    Write-Host "Searching '$path'"
   foreach ($file in "AssemblyInfo.cs", "AssemblyInfo.vb" ) 
   {
        get-childitem $path -recurse |? {$_.Name -eq $file} | Update-SourceVersion $version $infoVersion;
   }
}

# validate arguments 
if ($args -ne $null) {
    $version = $args[0]
    if (($version -eq '/?') -or ($version -notmatch "[0-9]+(\.([0-9]+|\*)){1,3}")) {
        Help
        exit 1;
    }
} else {
    Help
    exit 1;
}

Update-AllAssemblyInfoFiles $version $infoVersion $path