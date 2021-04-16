#
# This script will loop through a comma seperated list of feature branch tickets (in $siteList), 
# Use the following SQL query on rimtest-sql-05/09 to get a list of active DBs;
#
# SELECT name FROM master.dbo.sysdatabases WHERE name LIKE 'VECTWO-%' OR name LIKE 'POSAND-%' OR name LIKE 'POSCON-%'
#
# check their status matches either Closed or For Regression in JIRA, and if so, 
# trigger a delete of that feature branch via octopus
# Populate the $siteList, $jiraPassword and $octopusApiKey variables to run

$siteList=""
$jiraPassword=""
$octopusApiKey=""


$sites=$siteList.Split(",")
$jiraUser="Release"
$jiraUrl="support.retailinmotion.com"
$octopusUrl="http://octopus.rim.local"

$jiraAuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $jiraUser,$jiraPassword)))
$jiraHeaders = @{Authorization=("Basic {0}" -f $jiraAuthInfo)}

$statusesToDelete=@("Closed","For Regression","Ready to Merge")

$timestamp=Get-Date -Format 'yyyy.MM.dd-HHmm'
Foreach($site in $sites){
    $query= New-Object -TypeName System.Uri -ArgumentList ("https://" + $jiraUrl + "/rest/api/2/issue/" + $site + "")
    $issueData=(Invoke-RestMethod -Uri $Query -Headers $jiraHeaders)
    $status=$issueData.fields.status.name
    Write-Host "Current site: $site; status: $status"

    If($statusesToDelete.Contains($status)){
        Write-Output "Will delete $site - status: $status"
        &octo.exe --create-release --project "Feature Branch Delete" --version "$($timestamp)+CLEANUP-$($env:USERNAME)-$site" --variable=FeatureBranch.Name:$site --deployTo "Feature Branch Test"  --server $octopusUrl --apiKey $octopusApiKey
    }
}
