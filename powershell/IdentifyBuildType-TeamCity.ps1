# Parse the branch name to identify the type of build (bugfix, hotfix, feature, release, branch)
# And where applicable, identify the feature/bugfix name
# Examples which will match;
# feature/VECTWO-14795-vpos-dashboard-1
# bugfix/VECTWO-15215-tcx-mastercontrol-containers
# feature/VECTWO-14898-tcx-mc-extend-devices-inventory
# release/RC_20171106
# AirAsia_Branch


param(
	[string]$branchName
)

If ("$branchName".Contains("/")){
    $branchInfo="$branchName" -match "(.*)(\/)(.*)"

    $buildType=[string]$matches[1]
    $longFeatureName=[string]$matches[3]

    $featureInfo="$longFeatureName" -match "([A-Z]*\-{1}[0-9]*)(.*)"
    If ($featureInfo) {
        $featureName=[string]$matches[1]
    } ELSE {
        $featureName=$longFeatureName
    }

    "##teamcity[setParameter name='longFeatureName' value='{0}']" -f $longFeatureName

} ELSE {
    $buildType="branch"
    $featureName="$branchName"
}

"##teamcity[setParameter name='buildType' value='{0}']" -f $buildType
"##teamcity[setParameter name='featureName' value='{0}']" -f $featureName