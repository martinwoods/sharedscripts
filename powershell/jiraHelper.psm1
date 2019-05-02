function Jira-QueryApi
{
    Param (
        [Uri]$Query,
        [string]$Username,
        [string]$Password
    );

    Write-Host "Querying JIRA API $($Query.AbsoluteUri)"

    # Prepare the Basic Authorization header - PSCredential doesn't seem to work
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
    $headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}

    # Execute the query
    Invoke-RestMethod -Uri $Query -Headers $headers
}

function Get-JIRAClient
{
    Param (
        [string]$ServerURL,
        [string]$IssueKey,
        [string]$Username,
        [string]$Password
    );

    $jql="issuekey=$IssueKey&fields=customfield_11242"
     
    $query= New-Object -TypeName System.Uri -ArgumentList ("https://" + $ServerURL + "/rest/api/2/search?jql=" + $jql)
    $data=Jira-QueryApi -Query $query -Username $Username -Password $Password

    $value=$data.issues[0].fields.customfield_11242.value
   
    return $value.Substring(0, $value.IndexOf(" "))
}

function Get-JIRAClientToOctoVar {
    Param (
        [string]$OctoVarName,
        [string]$ServerURL,
        [string]$IssueKey,
        [string]$Username,
        [string]$Password
    );

    $client=Get-JIRAClient -ServerURL $ServerURL -IssueKey $IssueKey -Username $Username -Password $Password
    Set-OctopusVariable -name $OctoVarName -value $client
}

Export-ModuleMember -Function 'Get-*'