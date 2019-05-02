# Parse the branch name to identify the type of build (bugfix, hotfix, feature, release, branch)
# And where applicable, identify the feature/bugfix name
# Examples which will match;
# feature/VECTWO-14795-vpos-dashboard-1
# bugfix/VECTWO-15215-tcx-mastercontrol-containers
# c
# release/RC_20171106
# AirAsia_Branch


param(
	[string]$branchName
)

echo "" > build.properties
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

    echo "longFeatureName=$longFeatureName" > build.properties

} ELSE {
    $buildType="branch"
    $featureName="$branchName"
}

echo "buildType=$buildType" >> build.properties
echo "featureName=$featureName" >> build.properties