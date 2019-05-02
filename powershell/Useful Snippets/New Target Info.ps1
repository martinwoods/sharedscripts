function Format-HumanReadable 
        {
            param ($size)
            switch ($size) 
            {
                {$_ -ge 1PB}{"{0:#.#'P'}" -f ($size / 1PB); break}
                {$_ -ge 1TB}{"{0:#.#'T'}" -f ($size / 1TB); break}
                {$_ -ge 1GB}{"{0:#.#'G'}" -f ($size / 1GB); break}
                {$_ -ge 1MB}{"{0:#.#'M'}" -f ($size / 1MB); break}
                {$_ -ge 1KB}{"{0:#'K'}" -f ($size / 1KB); break}
                default {"{0}" -f ($size) + "B"}
            }
        }

(gwmi win32_operatingsystem).caption

$websiteDrives=@()

Foreach( $drive in (Get-PSDrive | Where-Object {$_.Provider.Name -eq "FileSystem" })){
#$size=$drive.Used + $drive.Free;
#$percent=[int]($drive.Used/$size * 100)
    
    # Get-ChildItem -Path $drive.Root  
     # check which drives contain a websites drive
     If(Test-Path "$($drive.Root)\Websites"){ 
        $websiteDrives+=$drive
        Write-Host "Website drive found at $($drive.Root)Websites"
        Get-ChildItem -Path "$($drive.Root)Websites" 
       # Write-Host "Size:$(Format-HumanReadable $size) Free:$(Format-HumanReadable $drive.Free) Used:$($percent)%"
     }
}

$connection = New-Object System.Data.SqlClient.SqlConnection
Register-ObjectEvent -inputobject $connection -eventname InfoMessage -action {
    write-host $event.SourceEventArgs
} | Out-Null

Foreach($drive in $websiteDrives){
    $folder="$($drive.Root)\Websites\"
    # Load the connection string

    $websiteFolders=Get-ChildItem -Path $folder
    Foreach($site in $websiteFolders) {
        # Check if we have access to this path
        $errors=@()
        get-childitem "$($site.FullName)\"  -ErrorAction SilentlyContinue -ErrorVariable +errors | Out-Null
        if($errors.Count -gt 0 ){
            $errors | Foreach-Object { Write-Host $_ }
        } else {
            # Check the connection string
            [xml]$connectionStringFile=(Get-ChildItem -Path "$($site.FullName)\*" -Include *ConnectionStrings.config | Get-Content)
            $connectionString=$connectionStringFile.connectionStrings.add.connectionString

            # Connect to the database and check values on conf_Config
            if(-not [string]::IsNullOrWhiteSpace($connectionString)) {
                Write-Host "::: Connection String for $($site.Name) : $connectionString "     
                $connection.ConnectionString = $connectionString
            
                try {
                    $connection.Open()
                    $SQLQuery="SELECT [ConfigKey], [ConfigValue] FROM [dbo].[conf_Config] WHERE ConfigKey IN ('Sys', 'Env', 'ReportServerUrl', 'DataPhysicalRoot')"

                    $Command = New-Object System.Data.SQLClient.SQLCommand
                    $Command.Connection = $connection
                    $Command.CommandText = $SQLQuery
                    $Reader = $Command.ExecuteReader()
                    while ($Reader.Read()) {
                            echo "$($Reader.GetValue(0)):$($Reader.GetValue(1))"
                    
                    }
                    $Reader.Dispose()
                    $Command.Dispose()
                } catch {
                    Write-Host $_.Exception.Message
                } finally {
                    $connection.Dispose()
                    $connection.Close()
                }
            }
            # check the web.config settings
            [xml]$webConfigFile=(Get-ChildItem -Path "$($site.FullName)\*" -Include *Web.config | Get-Content)
            Write-Host "::: Web.config settings for $($site.Name) ::: "
            Write-Host "Session server: $($webConfigFile.configuration.location.'system.web'.sessionState.stateConnectionString)"
            Write-Host "Vector settings;"
            $webConfigFile.configuration.applicationSettings.'Vector.Properties.Settings'.setting | Select-Object -Property name, value | Format-List
        }
    }
}