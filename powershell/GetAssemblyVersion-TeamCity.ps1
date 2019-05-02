# Read the current values set in the assemblyinfo
# This can be then be modified/reused in TeamCity as required
# Major Ver and Minor Ver will likely always come from AssemblyInfo, with Build and revision being overwritten at build time

param(
	[string]$filePath
)

# Look for the assembly file version 
$pattern = '\[assembly: AssemblyFileVersion\("(.*)"\)\]'
Get-Content $filePath | ForEach-Object{
    if($_ -match $pattern){
        # We have found the matching line
        # Parse the version number
        $fileVersion = [version]$matches[1]
        'AssemblyVersion("{0}")' -f $fileVersion
        # output as a service message for team city to parse
        "##teamcity[setParameter name='AssemblyMajorVer' value='{0}']" -f $fileVersion.Major
        "##teamcity[setParameter name='AssemblyMinorVer' value='{0}']" -f $fileVersion.Minor
        "##teamcity[setParameter name='AssemblyBuildVer' value='{0}']" -f $fileVersion.Build
        "##teamcity[setParameter name='AssemblyRevision' value='{0}']" -f $fileVersion.Revision
    } 
} 