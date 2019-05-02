$connection = New-Object System.Data.SqlClient.SqlConnection
$continueOnError = $true
Register-ObjectEvent -inputobject $connection -eventname InfoMessage -action {
    write-host $event.SourceEventArgs
} | Out-Null


function Get-SQLToOctoVar($ConnectionString, $Query, $ResultVarName){

    Write-Host "Connecting using $ConnectionString"
    try {

        $connection.ConnectionString = $ConnectionString
        $connection.Open()

        Write-Host "Executing script $Query"
        GenericSqlQuery $Query $ResultVarName

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
}

function GenericSqlQuery ($SQLQuery, $ResultVarName) {
    $Command = New-Object System.Data.SQLClient.SQLCommand
    $Command.Connection = $connection
    $Command.CommandText = $SQLQuery
    $Reader = $Command.ExecuteReader()
    while ($Reader.Read()) {
         echo "Setting Octopus Variable $ResultVarName to $($Reader.GetValue($1))"
         Set-OctopusVariable -name $ResultVarName -value $Reader.GetValue($1)
    }
}

Export-ModuleMember -Function 'Get-*'