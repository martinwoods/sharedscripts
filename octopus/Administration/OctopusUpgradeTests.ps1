
<#
    Octopus instance API tests.
    To be run before and after Octopus upgrade to compare project information and release metrics.
#>

class OctopusInstance {
    [string]$name
    [string]$url
    [string]$spaces
    [string]$apiKey
}
$octopusInstanceList = @(
    [OctopusInstance]@{name="Live";url="http://octopus.rim.local";spaces="Default,vPay";apiKey="<API_KEY>"}
    [OctopusInstance]@{name="Sandbox";url="http://octopus-sandbox.rim.local";spaces="Default,vPay";apiKey="<API_KEY>"}
)

foreach ($instance in $octopusInstanceList)
{
    try
    {
        $header = @{ "X-Octopus-ApiKey" = $instance.apiKey }
        $spaces = $instance.spaces.Split(",")
        foreach ($spaceItem in $spaces)
        {
            Write-Host "Processing '$($instance.url)' '$spaceItem' space ..."
            $outputJSON = @{}
            $projectList = New-Object System.Collections.ArrayList
            $space = (Invoke-RestMethod -Method Get -Uri ($instance.url + "/api/spaces/all") -Headers $header) | Where-Object {$_.Name -eq $spaceItem}
            $projects = (Invoke-RestMethod -Method Get -Uri ($instance.url + "/api/" + $space.Id + "/projects/all") -Headers $header) 
            foreach ($projectItem in $projects)
            {
                $releases = (Invoke-RestMethod -Method Get -Uri ($instance.url + "/api/" + $space.Id + "/projects/" + $projectItem.Id  + "/releases") -Headers $header) 
                [void]$projectList.Add(@{"ProjectName"=$projectItem.Name;"ProjectId"=$projectItem.Id;"ReleaseItemCount"=$releases.Items.Count;"LatestReleaseVersion"=$releases.Items[0].Version;})
            }
    
            $projectData = @{$spaceItem=$projectList;}
            $outputJSON.Add($instance.name,$projectData)
            $outputJSONfilenameDate = Get-Date -format 'yyyyMMdd_HHmm'
            Write-Host "Generating OctopusInstanceData-$($instance.name)-$($spaceItem)-$($outputJSONfilenameDate).json`n"
            $outputJSON | ConvertTo-Json -Depth 5 | Out-File ".\OctopusInstanceData-$($instance.name)-$($spaceItem)-$($outputJSONfilenameDate).json"
        }
    }
    catch
    {
        Write-Host $_
    }
}