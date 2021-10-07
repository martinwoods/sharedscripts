
<#
    Octopus instance API tests.
    To be run before and after Octopus upgrade to compare project information and release metrics.
#>

class OctopusInstance {
    [string]$name
    [string]$url
    [string]$space
    [string]$apiKey
}
$octopusInstanceList = @(
    [OctopusInstance]@{name="Live";url="http://octopus.rim.local";space="Default";apiKey="<API_KEY>"}
    [OctopusInstance]@{name="Sandbox";url="http://octopus-sandbox.rim.local";space="Default";apiKey="<API_KEY>"}
)

foreach ($instance in $octopusInstanceList)
{
    $outputJSON = @{}
    $projectList = New-Object System.Collections.ArrayList
    try
    {
        $header = @{ "X-Octopus-ApiKey" = $instance.apiKey }
        Write-Host "Processing $($instance.url) ..."

        $space = (Invoke-RestMethod -Method Get -Uri ($instance.url + "/api/spaces/all") -Headers $header) | Where-Object {$_.Name -eq $instance.space}
        $projectGroup = (Invoke-RestMethod -Method Get -Uri ($instance.url + "/api/projectgroups/all") -Headers $header) | Where-Object {$_.SpaceId -eq $space.Id}
        foreach ($projectGroupItem in $projectGroup)
        {
            $projects = (Invoke-RestMethod -Method Get -Uri ($instance.url + "/api/projects/all") -Headers $header) | Where-Object {$_.ProjectGroupId -eq $projectGroupItem.Id} 
            foreach ($projectItem in $projects)
            {
                $releases = (Invoke-RestMethod -Method Get -Uri ($instance.url + "/api/projects/" + $projectItem.Id  + "/releases") -Headers $header) 
                [void]$projectList.Add(@{"ProjectName"=$projectItem.Name;"ProjectId"=$projectItem.Id;"ReleaseCount"=$releases.Items.Count;"LatestRelease"=$releases.Items[0].Version;})
            }
        }
        
        $projectData = @{"Projects"=$projectList;}
        $outputJSON.Add($instance.name,$projectData)
        $outputJSONfilenameDate = Get-Date -format 'yyyyMMdd_HHmm'
        Write-Host "Generating OctopusInstanceData-$($instance.name)-$($outputJSONfilenameDate).json"
        $outputJSON | ConvertTo-Json -Depth 5 | Out-File ".\OctopusInstanceData-$($instance.name)-$($outputJSONfilenameDate).json"
    }
    catch
    {
        Write-Host $_
    }
}