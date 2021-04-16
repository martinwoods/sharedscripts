$servers = @("rimpen-web-01","rimpen-web-02")
foreach ($server in $servers){
    Write-Host "Running on $server"
    Invoke-Command -ComputerName $server -ScriptBlock {
        Stop-Service -Name "Tomcat9" -Force
        Get-ChildItem -Path "C:\Program Files\Apache Software Foundation\Tomcat 9.0\webapps" -Filter "EposWS_WAVS_TEST*" | Remove-Item -Recurse -Force
        Start-Service -Name "Tomcat9"
    }
}