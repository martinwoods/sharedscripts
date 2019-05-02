#
# Powershell script to provide helper functions which are used in Octopus deployment of SSRS reports
# Some code is re-used from existing run_publish_new_reports.ps1 script
# Additional code taken from Octopus Community Step "Deploy SSRS Reports from a package"
#
# Author: Keith Douglas
# Date: Feb 2018


# Upload all the reports in a given folder
Function Upload-Reports {
    Param ( 
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        [Parameter(Mandatory=$true)]
        [string]$SSRSFolder,
        [Parameter(Mandatory=$true)]
        [object]$SSRSProxy
    )

    Write-Host "Uploading reports from $SourcePath to $SSRSFolder"
    $reports = @(get-childitem $SourcePath *.rdl -rec|where-object {!($_.psiscontainer)})

    ForEach($report in $reports){
        Write-Host "Uploading $($report.FullName)"

        $filename=$report.BaseName
        $bytes=[System.IO.File]::ReadAllBytes($report.FullName)
        $warnings=$SSRSProxy.CreateReport($filename, "$SSRSFolder", $true, $bytes, $null)
        

        if ($warnings)
        {
            foreach ($warn in $warnings)
            {
                # Ignore data source not published warnings since we will update them after uploading reports
                if($warn.Code -ne "rsDataSourceReferenceNotPublished" ) {
                    Write-Warning "$($warn.Message)"
                }
            }
        }
    }


}


# Clean out the SSRS folder
Function Clear-SSRSFolder {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$SSRSFolder,
        [Parameter(Mandatory=$true)]
        [object]$SSRSProxy
    )
    
    
    
    if ($SSRSProxy.GetItemType("$SSRSFolder") -eq 'Folder') {
        Write-Host ("Clearing the {0} folder" -f $SSRSFolder)
        $SSRSProxy.ListChildren("$SSRSFolder", $false) | ForEach-Object {
            Write-Verbose "Deleting item: $($_.Path)"
            $SSRSProxy.DeleteItem($_.Path)
        }
    }
}

# Create a new datasource
Function New-SSRSDataSource {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$RdsPath, 
        [Parameter(Mandatory=$true)]
        [string]$SSRSFolder, 
        [Parameter(Mandatory=$true)]
        [object]$SSRSProxy,
        [bool]$OverwriteDataSources,
        [string]$ConnectionString,
        [bool]$UseIntegratedSecurity = $true,
        [string]$Username,
        [string]$Password
    ) 
    Write-Verbose "Creating new datasource from $RdsPath for $SSRSFolder"
    
    [xml]$Rds = Get-Content -Path $RdsPath
    $dsName = $Rds.RptDataSource.Name
    $ConnProps = $Rds.RptDataSource.ConnectionProperties
    
	$type = $SSRSProxy.GetType().Namespace #Get proxy type
	$DSDdatatype = ($type + '.DataSourceDefinition')
	 
	$Definition = new-object ($DSDdatatype)
	if($Definition -eq $null){
	 Write-Error Failed to create data source definition object
	}
	
	# replace the connection string variable that is configured in the octopus project
	if ($ConnectionString) {
	    $Definition.ConnectString = $ConnectionString
	} else {
	    $Definition.ConnectString = $ConnProps.ConnectString
	}
	
    $Definition.Extension = $ConnProps.Extension 

	if ($UseIntegratedSecurity) {
        Write-Verbose "Setting datasource to use integrated security"
		$Definition.CredentialRetrieval = 'Integrated'
	}
	else {
        Write-Verbose "Using stored credentials for datasource"
		$Definition.CredentialRetrieval = 'Store'
		
		$Definition.UserName = $Username;
        $Definition.Password = $Password;
	}

    $DataSource = New-Object -TypeName PSObject -Property @{
        Name = $Rds.RptDataSource.Name
        Path =  $SSRSFolder + '/' + $Rds.RptDataSource.Name
    }
    
    if ($OverwriteDataSources -or $SSRSProxy.GetItemType($DataSource.Path) -eq 'Unknown') {
        Write-Host "Overwriting datasource $($DataSource.Name)"
        $SSRSProxy.CreateDataSource($DataSource.Name, $SSRSFolder, $OverwriteDataSources, $Definition, $null)
    }
    
    return $DataSource 
}

# Update all reports in a given folder to point to the datasource
Function Set-ReportsDataSource {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$SSRSFolder,
        [Parameter(Mandatory=$true)]
        [object]$SSRSProxy,
        [Parameter(Mandatory=$true)]
        [string]$SSRSDatasourcePath
        
        )

        $SSRSItems=$SSRSProxy.ListChildren("$SSRSFolder", $true) | SELECT Type, Path, ID, Name | Where-Object {$_.Type -eq "Report"}

        ForEach($report in $SSRSItems){
            $dataSources = $SSRSProxy.GetItemDataSources($report.Path)
			$dataSources | ForEach-Object {
                $proxyNamespace = $_.GetType().Namespace
			    $newDataSource = New-Object ("$proxyNamespace.DataSource")
			   # $newDataSource.Name = $SSRSDatasourceName
			    $newDataSource.Item = New-Object ("$proxyNamespace.DataSourceReference")
			    $newDataSource.Item.Reference = $SSRSDatasourcePath
			    $_.item = $newDataSource.Item
			    $SSRSProxy.SetItemDataSources($report.Path, $_)
			    # Write-Progress -activity "Updating datasource to $reportPath to /$myDataSource.Name/$myDataSource.Name "
			    Write-Output "Updating datasource for $($report.Path) to $SSRSDataSourcePath"
            }
        }
}

# Backup all reports in the given folder to the local path
Function Backup-Reports{
    Param (
        [Parameter(Mandatory=$true)]
        [string]$BackupPath,
        [Parameter(Mandatory=$true)]
        [string]$SSRSFolder,
        [Parameter(Mandatory=$true)]
        [object]$SSRSProxy
        )
        # Make sure our backup folder exists
        if((Test-Path $BackupPath) -ne $true){
            Write-Verbose "Create directory $BackupPath"
            New-Item -ItemType Directory -Path $BackupPath | Out-Null
        }
        Write-Host "Backing up reports from $SSRSFolder to $BackupPath"
        Try {
       		$SSRSItems=$SSRSProxy.ListChildren("$SSRSFolder", $true) | SELECT Type, Path, ID, Name | Where-Object {$_.Type -eq "Report"}

        	ForEach($item in $SSRSItems){
            	#need to figure out if it has a folder name
				$subfolderName = split-path $item.Path;
				$reportName = split-path $item.Path -Leaf;
				$targetDir = $BackupPath + $subfolderName;
			
				# Make sure our backup folder exists
            	if((Test-Path $targetDir) -ne $true){
                	Write-Verbose "Creating directory $targetDir"
                	New-Item -ItemType Directory -Path $targetDir | Out-Null
            	}
		 
				$rdlFile = New-Object System.Xml.XmlDocument;
				[byte[]] $reportDefinition = $null;
                $reportDefinition = $SSRSProxy.GetReportDefinition($item.Path);


                #note here we're forcing the actual definition to be 
                #stored as a byte array
                #if you take out the @() from the MemoryStream constructor, you'll 
                #get an error
                [System.IO.MemoryStream] $memStream = New-Object System.IO.MemoryStream(@(,$reportDefinition));
                $rdlFile.Load($memStream);

                $fullReportFileName = $targetDir + "\" + $item.Name +  ".rdl";

                $rdlFile.Save( $fullReportFileName);

                Write-Verbose "Saved report file to $fullReportFileName"
        	}
	} Catch  {
     		Write-Host $_.Exception.Message
            Write-Host $_.Exception.GetType().FullName
    		Write-Host "Couldn't find folder $SSRSFolder to backup"
    }

}

# Create an instance of the proxy for interaction with the report server
Function Create-SSRSProxy{
    Param (
        [Parameter(Mandatory=$true)]
        [string]$ServerURI,
        [string]$Username,
        [string]$Password
    )


    # check to see if credentials were supplied for the services
    if(([string]::IsNullOrEmpty($Username) -ne $true) -and ([string]::IsNullOrEmpty($Password) -ne $true))
    {
        # secure the password
        $secpasswd = ConvertTo-SecureString "$Password" -AsPlainText -Force

        # create credential object
        $ServiceCredential = New-Object System.Management.Automation.PSCredential ($Username, $secpasswd)

        # create proxy
        $ReportServerProxy = New-WebServiceProxy -Uri $ServerURI -Credential $ServiceCredential
    }
    else
    {
        # create proxies using current identity
        $ReportServerProxy = New-WebServiceProxy -Uri $ServerURI -UseDefaultCredential 
    }
    Return $ReportServerProxy
}


# Return the full URI to the web service for the given hostname
Function Get-ServerURI{
    Param (
        [Parameter(Mandatory=$true)]
        [string]$Hostname
        )

    Return "http://$Hostname/ReportServer/ReportService2005.asmx?wsdl"
}

Function Create-SSRSFolder{
    Param (
        [Parameter(Mandatory=$true)]
        [string]$SSRSFolder,
        [Parameter(Mandatory=$true)]
        [object]$SSRSProxy
        )
        $root=(Split-Path -Path $SSRSFolder).Replace("\", "/")
        $folder=Split-Path -Path $SSRSFolder -Leaf

        if($root -eq "" ) { $root="/" }
       
        $folderCount=$($SSRSProxy.ListChildren($root, $false) | SELECT Type, Path, ID, Name | Where-Object {$_.Type -eq "Folder" -and $_.Path -eq $SSRSFolder} | Measure-Object).Count
        If( $folderCount -lt 1) { 
            Write-Host "Creating folder $SSRSFolder"
            $SSRSProxy.CreateFolder($folder.TrimStart("/"), $root, $null)
        }


}
Export-ModuleMember -Function '*'

