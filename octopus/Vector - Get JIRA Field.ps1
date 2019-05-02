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

function Get-JIRACustomFieldValue
{
    Param (
        [string]$ServerURL,
        [string]$IssueKey,
        [string]$FieldID,
        [string]$Username,
        [string]$Password
    );

     
    $query= New-Object -TypeName System.Uri -ArgumentList ("https://" + $ServerURL + "/rest/api/2/issue/" + $IssueKey + "?fields=" + $FieldId)
    $data=Jira-QueryApi -Query $query -Username $Username -Password $Password

   
    
    if($data.fields."$FieldId".GetType().Name -eq "PSCustomObject"){
        $value=$data.fields."$FieldId".value
    } else {
        $value=$data.fields."$FieldId"
    }
   
    return $value
}

function Get-JIRACustomFieldID
{
	Param (
        [string]$ServerURL,
        [string]$IssueKey,
        [string]$FieldName,
        [string]$Username,
        [string]$Password
    );
	
	$query=New-Object -TypeName System.Uri -ArgumentList ("https://" + $ServerURL + "/rest/api/2/issue/"+ $IssueKey +"/editmeta")
    Write-Host $query.PathAndQuery
	$data=Jira-QueryApi -Query $query -Username $Username -Password $Password
	
	$data.fields.PSObject.Properties | ForEach-Object {
        If ($_.Name.ToLower() -eq $FieldName.ToLower() -or
            $_.Value.name.ToLower() -eq $FieldName.ToLower()) {
            Return $_.Name
        }
    }

	
}
function Get-JIRAFieldToOctoVar {
    Param (
        [string]$ServerURL,
        [string]$IssueKey,
        [string]$JIRAFieldName,
		[string]$OutputFieldName,
        [string]$Username,
        [string]$Password
    );
    $fieldid=Get-JIRACustomFieldId  -FieldName $JIRAFieldName -ServerURL $ServerURL -IssueKey $IssueKey -Username $Username -Password $Password
    $fieldvalue=Get-JIRACustomFieldValue -FieldId $fieldid -ServerURL $ServerURL -IssueKey $IssueKey -Username $Username -Password $Password

    Set-OctopusVariable -name "$OutputFieldName" -value "$fieldvalue"
}

Get-JIRAFieldToOctoVar -JIRAFieldName $VectorJIRAFieldName -OutputFieldName $VectorOutputFieldName -ServerURL $VectorJIRAServer -IssueKey $VectorJIRAIssue -Username $VectorJIRAUser -Password $VectorJIRAPassword