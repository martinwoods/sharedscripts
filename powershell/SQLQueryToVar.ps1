param (
	[string]$ConnectionString,
	[string]$Query,
    [string]$ResultVarName
)



$connection = New-Object System.Data.SqlClient.SqlConnection

$continueOnError = $true
Register-ObjectEvent -inputobject $connection -eventname InfoMessage -action {
    write-host $event.SourceEventArgs
} | Out-Null


function GenericSqlQuery ($SQLQuery) {
    $Command = New-Object System.Data.SQLClient.SQLCommand
    $Command.Connection = $connection
    $Command.CommandText = $SQLQuery
    $Reader = $Command.ExecuteReader()
    while ($Reader.Read()) {
        # Set-OctopusVariable -name $ResultVarName -value $Reader.GetValue($1)
         $Reader.GetValue($1)
    }
}

Write-Host "Connecting using $ConnectionString"
try {

    $connection.ConnectionString = $ConnectionString
    $connection.Open()

    Write-Host "Executing script"
    GenericSqlQuery $Query

}
catch {
	if ($continueOnError) {
		Write-Host $_.Exception.Message
	}
	else {
		throw
	}
}
finally {
    Write-Host "Closing connection"
    $connection.Dispose()
    $connection.Close()
}