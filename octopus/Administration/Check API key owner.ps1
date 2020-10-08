$OctopusURI = 'http://<OCTOPUS_URL>'
$AdminAPI = '<API_KEY>'
$Header =  @{ "X-Octopus-ApiKey" = $AdminAPI }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$OctoUser = ((Invoke-RestMethod -Uri "$OctopusURI/api/users/me" -Method Get -Headers $Header -UseBasicParsing -ErrorAction Stop))
$OctoUser