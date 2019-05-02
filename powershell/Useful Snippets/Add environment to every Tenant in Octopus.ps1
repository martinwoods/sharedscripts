$endpoint="http://rim-build-05/api/tenants/"
$tenantId="Tenants-21"
$apiKey=""
$headers=@{ 'X-Octopus-ApiKey' = $apiKey }
$newEnvironment=""
$backupDir="OctopusTenants"

$tenantlist=(Invoke-WebRequest -Uri "$($endpoint)/all?apiKey=$apiKey" -UseBasicParsing).Content | ConvertFrom-Json

Foreach($tenant IN $tenantlist ){

$tenantId=$tenant.Id

    If(-not (Test-Path -Path "$($backupDir)\Before") ) {
       New-Item -Path "$($backupDir)\Before"  -ItemType Directory
    }

    If(-not (Test-Path -Path "$($backupDir)\After") ) {
       New-Item -Path "$($backupDir)\After"  -ItemType Directory
    }
    $content=(Invoke-WebRequest -Uri "$($endpoint)$($tenantId)?apiKey=$($apiKey)" -UseBasicParsing).Content
    $tenantData=$content | ConvertFrom-Json

    $content | Out-File -Force -FilePath "$($backupDir)\Before\$($tenantId).json"


    foreach($pe in $tenantData.ProjectEnvironments.PSObject.Properties) { 

    $list={$tenantData.ProjectEnvironments."$($pe.Name)"}.Invoke()

        If(-not $list.Contains($newEnvironment)){
            $list.Add($newEnvironment)
            $tenantData.ProjectEnvironments."$($pe.Name)"=$list
        }
    }

    $tenantJson = $tenantData | ConvertTo-Json
    $tenantJson | Out-File -Force -FilePath "$($backupDir)\After\$($tenantId).json"

    Invoke-RestMethod -Method PUT -URI "$($endpoint)$($tenantId)" -Header $headers -Body $tenantJson
}