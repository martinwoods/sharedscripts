$lockedFile="E:\Websites\Vector_JON_UAT\bin\zlib64.dll"
Get-Process | foreach{$processVar = $_;$_.Modules | foreach{if($_.FileName -eq $lockedFile){$processVar.Name + " PID:" + $processVar.id}}}