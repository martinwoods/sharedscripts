# Remove characters which are incompatible with the SemVer 2.0.0 specification
# https://semver.org/spec/v2.0.0.html
# This is the required format for Octopus packages
param(
	[string]$fileName
)

$semVerString="$fileName" -replace "[^0-9A-Za-z-\.\+]",""

"##teamcity[setParameter name='semVerString' value='{0}']" -f $semVerString