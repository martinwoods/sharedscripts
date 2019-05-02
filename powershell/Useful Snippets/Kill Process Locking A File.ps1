$lockedFile="E:\Websites\Vector_AXM_UAT\bin\zlib64.dll"
Get-Process | foreach{$processVar = $_;$_.Modules | foreach{
  if($_.FileName -eq $lockedFile){
      "Killing " + $processVar.Name + " PID:" + $processVar.id
      Stop-Process -Force -Id $processVar.id
  }
}}