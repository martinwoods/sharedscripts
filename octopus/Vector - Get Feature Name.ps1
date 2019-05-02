
$pkgInfo=$OctopusParameters["Octopus.Action["+ $StepName +"].Package.NuGetPackageVersion"] -split "\."

Set-OctopusVariable -name "FeatureName" -value $pkgInfo[3]





