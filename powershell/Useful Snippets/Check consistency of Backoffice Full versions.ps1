$endpoint="http://rim-build-07/api/"

$apiKey="API-D4D9OTAC9SSRFCERYP5YS5FA9ME"
$apiKey="API-JKZOSPVTLDHNCB1XABPFZTI6DGY"
$headers=@{ 'X-Octopus-ApiKey' = $apiKey }
$project="vector-backoffice-full"


$project=(Invoke-WebRequest -Uri "$($endpoint)/projects/$($project)?apiKey=$apiKey" -UseBasicParsing).Content | ConvertFrom-Json
$projectId=$project.Id

$releases=(Invoke-WebRequest -Uri "$($endpoint)/projects/$($projectId)/releases?apiKey=$apiKey&take=500" -UseBasicParsing).Content | ConvertFrom-Json

Foreach ( $release in $releases.Items ){

    
    $dbVersion=($release.SelectedPackages | Where-Object {$_.StepName -eq "Deploy Vector BackOffice DB"}).Version
    $codeVersion=($release.SelectedPackages | Where-Object {$_.StepName -eq "Deploy BackOffice Codebase"}).Version
    $reportsVersion=($release.SelectedPackages | Where-Object {$_.StepName -eq "Deploy Vector Reports"}).Version
    
    If($release.Version -ne $dbVersion -or $release.Version -ne $codeVersion -or $release.Version -ne $reportsVersion) {
        Write-Output "$($release.Id)`t$($release.version)`t[DB: $dbVersion Code: $codeVersion Reports: $reportsVersion]"
    }
}