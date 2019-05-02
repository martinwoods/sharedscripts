# Read the current values set in the assemblyinfo
# This can be then be modified/reused in Jenkins as required
# Major Ver and Minor Ver will likely always come from AssemblyInfo, with Build and revision being overwritten at build time

$filePath="$env:WORKSPACE\Vector\Properties\AssemblyInfo.cs"
# Look for the assembly file version 
$pattern = '\[assembly: AssemblyFileVersion\("(.*)"\)\]'
Get-Content $filePath | ForEach-Object{
	if($_ -match $pattern){
		# We have found the matching line
		# Parse the version number
		$fileVersion = [version]$matches[1]
		'AssemblyVersion("{0}")' -f $fileVersion
		# output as a service message for team city to parse
		"assemblyMajorVer:6" | Set-Content build.properties
		"assemblyMinorVer:7" | Add-Content build.properties
		"assemblyBuildVer:8" | Add-Content build.properties
		"assemblyRevision:9" | Add-Content build.properties
	} 
}
EXIT 0