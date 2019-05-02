function Get-Data {
	
	# CSV Data is stored in VectorSystemsLookup.xlsx under the build_scripts repo in GIT
	# When new data needs to be added, update the excel file and export CSV before updating here
	# Do not update this powershell script without adding the to excel file first
				$csvData=@"
JIRA Client Name,Company,ID,ICAO,SYS,Epics
AAL - American Airlines,American Airlines,269,AAL,AAL,VESB-601;VECTWO-5712;VECTWO-4058;
,Air Asia Thai,190,AIQ,AIRASIA,VESB-1808;
,LATAM Colombia,105,ARE,ARE,
,US Airways,331,AWE,AWE,
,Air Asia Indonesia,200,AWQ,AIRASIA,
,Air Asia Malaysia,185,AXM,AIRASIA,
AZA - Alitalia,Alitalia,140,AZA,AZA,VESB-1557;VECTWO-9846;VECTWO-8729;
BRU - Brussels Airlines,Brussels Airlines,4,BEL,BEL,VECTWO-6716;VECTWO-6521;VECTWO-4059;
,TUI Nordics,0,BLX,BLX,VESB-1225;
DLH - Miles & More,Lufthasa (Miles & More),75,DLH,DLH,VESB-983;VESB-707;VECTWO-10121;VECTWO-5362
,LATAM Argentina,130,DSM,DSM,
EDW - Edelweiss,Edelweiss,65,EDW,EDW,VESB-334;VECTWO-8529;VECTWO-4060;
EIN - Aer Lingus,Aer Lingus,155,EIN,EIN,VESB-1592;VECTWO-9847;VECTWO-9237;
EW - Eurowings,Eurowings,2,EWG,EWG,VESB-376;VECTWO-7239;VECTWO-4057;
EXS - Jet2,Jet2,85,EXS,EXS,VESB-936;VECTWO-6412;VECTWO-6400;
,Air Asia Philippine,210,EZD,AIRASIA,
FDB - Fly Dubai,FlyDubai,225,FDB,FDB,VESB-2098;VECTWO-14939;VECTWO-13122;
FBD - Flybondi,Flybondi,255,FO,FBD,VECTWO-16813
,ASL Airlines,5,FPO,FPO,VESB-868;VECTWO-9555;
HAL - Hawaiian,Hawaian,115,HAL,HAL,VESB-1363;VECTWO-8323;VECTWO-6456;
,Air Asia India,215,IAD,AIRASIA,
ICE - Iceland Air,Icelandair,45,ICE,ICE,VESB-230;VECTWO-5527;VECTWO-4062;
,Air Asia Indonesia X,205,IDX,AIRASIA,
TUI fly Belgium (Jetairfly),TUI Jetairfly,80,JAF,JAF,VESB-743;VECTWO-15117;
JOON - Boost,JOON,165,JON,JON,VESB-2000;VECTWO-13061;VECTWO-12096;VECTWO-12006
LAN - LATAM Chile,LATAM Chile,125,LAN,LATAM,
LNE - LATAM Ecuador,LATAM Ecuador,135,LNE,LATAM,
LPE - LATAM Peru,LATAM Peru,120,LPE,LATAM,
NKS - Spirit,Spirit,30,NKS,NKS,VESB-962;VECTWO-5402;VECTWO-4063;
RAM - Royal Air Maroc,Royal Air Maroc,230,RAM,RAM,VESB-2563;VECTWO-14938;VECTWO-14485;
RIM - Retail inMotion,Retail inMotion,1,RIM,RIM,
RYR - Ryanair,Ryanair,61,RYR,RYR,VESB-232;VECTWO-6486;VECTWO-5360;VECTWO-4056
SKU - Sky Airlines,Sky Airline,70,SKU,SKU,VESB-527;VECTWO-4064;
STK - Stobart Air,Stobart Air,150,STK,STK,VECTWO-14847;VECTWO-7697;VECTWO-4065;
SWR - Swissair,Swiss,100,SWR,SWR,VESB-1664;VECTWO-10215;VECTWO-5948;
SXD - Sun Express Germany,SunExpress Germany,15,SXD,SXD,VESB-400;VECTWO-7385;VECTWO-4066;
SXS - Sun Express Turkey,SunExpress Turkey,25,SXS,SXS,VECTWO-8352;VECTWO-4067;
,Air Asia Thai X,195,TAX,AIRASIA,
TCX - Thomas Cook,Thomas Cook UK,95,TCX,TCX,VESB-1130;VECTWO-6413;VECTWO-6362;
TUI fly NL (Arkefly),TUI NL (ArkeFly),10,TFL,TUI,VESB-705;VECTWO-15118;VECTWO-8533;VECTWO-4068
TOM - TUI Thomson,TUI Thomson,50,TOM,TUI,VESB-233;VECTWO-10886;VECTWO-5363;
TUI Fly Germany,TUI Fly Germany,35,TUI,TUI,VESB-231;VECTWO-14381;VECTWO-10122;VECTWO-8225
TVF - Transavia,Transavia France,90,TVF,TVF,VESB-1084;VECTWO-7678;VECTWO-6233;
VIV - Viva Aerobus,Viva Aerobus,40,VIV,VIV,VESB-272;VECTWO-5405;VECTWO-4071;
,Thomas Cook Scandinavia,170,VKG,TCX,VECTWO-13917;
VOZ - Virgin Australia,Virgin Australia,160,VOZ,VOZ,VESB-1809;VECTWO-10507;VECTWO-10230;
,Air Asia Japan,220,WAJ,AIRASIA,
WOW - WOW Airlines,WOW Air,110,WOW,WOW,VESB-1959;VECTWO-8025;VECTWO-7601;VECTWO-6978
XAX - Air Asia,Air Asia Malaysia X,145,XAX,AIRASIA,
"@


	ConvertFrom-CSV $csvData

}

function Get-DataForClient {
	Param (
		[string]$JIRAClientName,
        [string]$JIRAEpicID
	);
    # If we have an epic, and it's not VECTWO-15901 (3 Level Support), use it
    If( -not [string]::IsNullOrEmpty($JIRAEpicId) -and $JIRAEpicID -ne "VECTWO-15901" ){
        $data=Get-Data | Where-Object { $_.Epics -like "*$JIRAEpicID*" }
    } else {
    # Otherwise, use the client
        $data=Get-Data | Where-Object { $_."JIRA Client Name" -eq $JIRAClientName }
    }
	
	Write-Host "Found $($data.Company) info: SYS; $($data.SYS), ID; $($data.ID), ICAO; $($data.ICAO)"
	
	Set-OctopusVariable -name "Company" -value $data.Company
	Set-OctopusVariable -name "CompanyID" -value $data.ID
	Set-OctopusVariable -name "CompanyICAO" -value $data.ICAO
	Set-OctopusVariable -name "CompanySYS" -value $data.SYS
	
	
}

Get-DataForClient -JIRAClientName $JIRAClientName -JIRAEpicId $JIRAEpicId