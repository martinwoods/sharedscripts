$webBox1 = "rimtest-web-03"
$webBox2 = "rimtest-web-04"

$web1 = Invoke-Command -ComputerName $webBox1 -ScriptBlock {Import-Module WebAdministration; Get-WebSite | Select-Object Name, Id}
$web2 = Invoke-Command -ComputerName $webBox2 -ScriptBlock {Import-Module WebAdministration; Get-WebSite | Select-Object Name, Id}

"$webBox1 count: " + $web1.count
"$webBox2 count: " + $web2.count

Write-Host "$webBox1 diffs"
foreach ($site in $web1) {

    $otherBox = $web2 | Where-Object {$_.name -eq $site.name}
    if ($site.id -ne $otherBox.id) {
        Write-Host "name: $($site.name); web1_id: $($site.id); web2_id: $($otherBox.id)"
    } 
    
}
Write-Host "$webBox2 diffs"
foreach ($site in $web2) {
    $otherBox = $web1 | Where-Object {$_.name -eq $site.name}
    if ($site.id -ne $otherBox.id) {
        Write-Host "name: $($site.name); web1_id: $($otherBox.id); web2_id: $($site.id)"
    } 
}