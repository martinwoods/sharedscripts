USE [#{VectorDBName}]
SET QUOTED_IDENTIFIER OFF 
BEGIN TRY

--
-- conf_Config changes
-- 

PRINT 'Setting Env to #{DBEnv}'
UPDATE dbo.conf_Config SET ConfigValue='#{DBEnv}' WHERE ConfigKey='Env';

PRINT 'Setting SiteUrl to https://#{VectorURL}/'
UPDATE dbo.conf_Config SET ConfigValue='https://#{VectorURL}/' WHERE ConfigKey='SiteUrl';

Print 'Setting SiteInternalUrl to #{SiteInternalUrl}'
UPDATE dbo.conf_Config SET ConfigValue='#{SiteInternalUrl}' WHERE ConfigKey='SiteInternalUrl';

Print 'Setting DataUrl to https://#{VectorURL}/Data/'
UPDATE dbo.conf_Config SET ConfigValue='https://#{VectorURL}/Data/' WHERE ConfigKey='DataUrl';

Print 'Setting DataInternalUrl to #{DataInternalUrl}'
UPDATE dbo.conf_Config SET ConfigValue='#{DataInternalUrl}' WHERE ConfigKey='DataInternalUrl';

Print 'Setting PhysicalRoot to #{VectorSiteDir}\'
UPDATE dbo.conf_Config SET ConfigValue='#{VectorSiteDir}\' WHERE ConfigKey='PhysicalRoot';

Print 'Setting DataPhysicalRoot to \\#{VectorFileServer}\#{VectorSiteName}\Data\'
UPDATE dbo.conf_Config SET ConfigValue='\\#{VectorFileServer}\#{VectorSiteName}\Data\' WHERE ConfigKey='DataPhysicalRoot';

UPDATE conf_Config SET ConfigValue = 'http://#{VectorURL}/vPack3/' WHERE Configkey = 'vPackSiteUrl'
UPDATE conf_Config SET ConfigValue = 'http://#{VectorURL}/vPack3/' WHERE Configkey = 'vPackSiteInternalUrl'
UPDATE conf_Config SET ConfigValue = 'http://#{VectorURL}/vPack3/' WHERE Configkey = 'vPackDataUrl'
UPDATE conf_Config SET ConfigValue = 'http://#{VectorURL}/vPack3/' WHERE Configkey = 'vPackDataInternalUrl'



Print 'Setting DBBackupPhysicalRoot to #{VectorDBBackupDrive}\#{VectorDBName}_SQLBackup\'
UPDATE dbo.conf_Config SET ConfigValue='#{VectorDBBackupDrive}\#{VectorDBName}_SQLBackup\' WHERE ConfigKey='DBBackupPhysicalRoot';

Print 'Setting ReportServerUrl to http://#{VectorReportServer}/ReportServer/'
UPDATE dbo.conf_Config SET ConfigValue='http://#{VectorReportServer}/ReportServer/' WHERE ConfigKey='ReportServerUrl';

Print 'Setting ReportPath to /#{VectorSiteName}/'
UPDATE dbo.conf_Config SET ConfigValue='/#{VectorSiteName}/' WHERE ConfigKey='ReportPath';

-- Report paths for vPos Control - DEVOPS-288
IF NOT EXISTS(SELECT * FROM conf_Config WHERE ConfigKey = 'vPosControlReportServerUrl')
	BEGIN
		Print 'Inserting vPosControlReportServerUrl with value http://#{VectorReportServer}/ReportServer/'
		INSERT INTO conf_Config (ConfigId, ConfigKey, ConfigValue) VALUES(315, 'vPosControlReportServerUrl', 'http://#{VectorReportServer}/ReportServer/')
	END
ELSE
	BEGIN
		Print 'Setting vPosControlReportServerUrl to http://#{VectorReportServer}/ReportServer/'
		UPDATE dbo.conf_Config SET ConfigValue='http://#{VectorReportServer}/ReportServer/' WHERE ConfigKey='vPosControlReportServerUrl';
	END
	
IF NOT EXISTS(SELECT * FROM conf_Config WHERE ConfigKey = 'vPosControlReportPath')
	BEGIN
    	Print 'Inserting vPosControlReportPath with value /#{VectorSiteName}/vPos/'
		INSERT INTO conf_Config (ConfigId, ConfigKey, ConfigValue) VALUES(325, 'vPosControlReportPath', '/#{VectorSiteName}/vPos/')
	END
ELSE
	BEGIN
		Print 'Setting ReportPath to /#{VectorSiteName}/vPos/'
		UPDATE dbo.conf_Config SET ConfigValue='/#{VectorSiteName}/vPos/' WHERE ConfigKey='vPosControlReportPath';
	END
    


Print 'Setting email redirect to #{RedirectToEmail}'
UPDATE dbo.conf_EmailAccount SET RedirectTo='#{RedirectToEmail}' WHERE ServerUrl='smtp.office365.com';

UPDATE dbo.conf_EmailAccount SET RedirectTo='#{RedirectToEmail}' WHERE ServerUrl='mail.ops.i-soms.com';


--
-- EDI and epos settings
--
PRINT 'Setting RiMApi endpoint to https://rim#{Env | ToLower}.i-soms.com/vesb/ (if applicable)'
-- Set RiMApi in RYR DB to connect to RIM endpoint
UPDATE dbo.conf_EDISetting SET URL='https://rim#{Env | ToLower}.i-soms.com/vesb/' WHERE EDISettingName='RiMApi';

PRINT 'Setting LocalApi endpoint to #{vESBLocalApiURL}'
UPDATE dbo.conf_EDISetting SET URL='#{vESBLocalApiURL}' WHERE EDISettingName='LocalApi';

-- Turn-off all background tasks 
UPDATE edi_Config set DateEnd = '2017-01-01', SendExternalSystem = 0
UPDATE conf_EDISetting set IsEnabled = 0


DECLARE @vPayURL NVARCHAR(256)
SELECT @vPayURL = SettingValue FROM epos_DeviceSettingValue WHERE SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayUrlServer')

IF(@vPayURL LIKE 'https://eu%')
	BEGIN
		PRINT 'Setting URLs for EU vPay'
		
		UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://eudemo.paygateservices.com/X9CH/BatchService.svc/Batch' WHERE SettingValue like 'https://eu%' AND SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayUrlServer')
		PRINT 'Setting vPayUrlServer to https://eudemo.paygateservices.com/X9CH/BatchService.svc/Batch'

		UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://eudemo.paygateservices.com/X9CH/RealTimeService.svc/RealTime' WHERE SettingValue like 'https://eu%' AND SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayRealTimeURL')
		PRINT 'Setting vPayRealTimeURL to https://eudemo.paygateservices.com/X9CH/RealTimeService.svc/RealTime'
		
		UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://eudemo.paygateservices.com/BlackListService.svc/GetBlackList' WHERE SettingValue like 'https://eu%' AND SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayBlacklistURL')
		PRINT 'Setting vPayBlacklistURL to https://eudemo.paygateservices.com/BlackListService.svc/GetBlackList'
		
		UPDATE dbo.conf_Setting_Value SET Value='https://eudemo.paygateservices.com/' WHERE Value like 'https://eu%' and SettingId IN (SELECT SettingId FROM conf_Setting WHERE SettingCode='VPay_EndPoint')
		PRINT 'Setting VPAY_EndPoint to https://eudemo.paygateservices.com/'
		
		UPDATE dbo.conf_Setting_Value SET Value='https://eudemo.paygateservices.com/ReportService.svc/PaymentStatus' WHERE Value like 'https://eu%' and SettingId IN (SELECT SettingId FROM conf_Setting WHERE SettingCode='VPay_URL')
		PRINT 'Setting VPay_URL to https://eudemo.paygateservices.com/ReportService.svc/PaymentStatusV2' 

		IF EXISTS (SELECT SettingId FROM dbo.epos_DeviceSetting WHERE SettingName='vPayTerminalIdServiceURL')
			BEGIN
				UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://eudemo.paygateservices.com/TidPedSerialNumberService.svc/Get' WHERE SettingValue like 'https://eu%' and SettingId IN (SELECT SettingId FROM dbo.epos_DeviceSetting WHERE SettingName='vPayTerminalIdServiceURL')
				PRINT 'Setting vPayTerminalIdServiceURL to https://eudemo.paygateservices.com/TidPedSerialNumberService.svc/Get' 
			END
	END
ELSE IF (@vPayURL LIKE 'https://us%')
	BEGIN
		PRINT ('Setting URLs for US vPay')
		
		UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://ustest.paygateservices.com/X9CH/BatchService.svc/Batch' WHERE SettingValue like 'https://us%' AND SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayUrlServer')
		PRINT 'Setting vPayUrlServer to https://ustest.paygateservices.com/X9CH/BatchService.svc/Batch'
		
		UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://ustest.paygateservices.com/X9CH/RealTimeService.svc/RealTime' WHERE SettingValue like 'https://us%' AND SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayRealTimeURL')
		PRINT 'Setting vPayRealTimeURL to https://ustest.paygateservices.com/X9CH/RealTimeService.svc/RealTime'
		
		UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://ustest.paygateservices.com/BlackListService.svc/GetBlackList' WHERE SettingValue like 'https://us%' AND SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayBlacklistURL')
		PRINT 'Setting vPayBlacklistURL to https://ustest.paygateservices.com/BlackListService.svc/GetBlackList'
		
		UPDATE dbo.conf_Setting_Value SET Value='https://ustest.paygateservices.com/' WHERE Value like 'https://us%' and SettingId IN(SELECT SettingId FROM conf_Setting WHERE SettingCode='VPay_EndPoint')
		PRINT 'Setting VPay_EndPoint to https://ustest.paygateservices.com/'
		
		UPDATE dbo.conf_Setting_Value SET Value='https://ustest.paygateservices.com/ReportService.svc/PaymentStatus' WHERE Value like 'https://us%' and SettingId IN (SELECT SettingId FROM conf_Setting WHERE SettingCode='VPay_URL')
		PRINT 'Setting VPay_URL https://ustest.paygateservices.com/ReportService.svc/PaymentStatusV2'

		IF EXISTS (SELECT SettingId FROM dbo.epos_DeviceSetting WHERE SettingName='vPayTerminalIdServiceURL')
			BEGIN
				UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://usdemo.paygateservices.com/TidPedSerialNumberService.svc/Get' WHERE SettingValue like 'https://us%' and SettingId IN (SELECT SettingId FROM dbo.epos_DeviceSetting WHERE SettingName='vPayTerminalIdServiceURL')
				PRINT 'Setting vPayTerminalIdServiceURL to https://usdemo.paygateservices.com/TidPedSerialNumberService.svc/Get' 
			END
	END
ELSE 
	BEGIN
		PRINT 'Setting URLs for Other vPay'
		
		UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://eudemo.paygateservices.com/X9CH/BatchService.svc/Batch' WHERE SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayUrlServer')
		PRINT 'Setting vPayUrlServer to https://eudemo.paygateservices.com/X9CH/BatchService.svc/Batch'

		UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://eudemo.paygateservices.com/X9CH/RealTimeService.svc/RealTime' WHERE SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayRealTimeURL')
		PRINT 'Setting vPayRealTimeURL to https://eudemo.paygateservices.com/X9CH/RealTimeService.svc/RealTime'
		
		UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://eudemo.paygateservices.com/BlackListService.svc/GetBlackList' WHERE SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayBlacklistURL')
		PRINT 'Setting vPayBlacklistURL to https://eudemo.paygateservices.com/BlackListService.svc/GetBlackList'
		
		UPDATE dbo.conf_Setting_Value SET Value='https://eudemo.paygateservices.com/' WHERE SettingId IN (SELECT SettingId FROM conf_Setting WHERE SettingCode='VPay_EndPoint')
		PRINT 'Setting VPAY_EndPoint to https://eudemo.paygateservices.com/'
		
		UPDATE dbo.conf_Setting_Value SET Value='https://eudemo.paygateservices.com/ReportService.svc/PaymentStatus' WHERE SettingId IN (SELECT SettingId FROM conf_Setting WHERE SettingCode='VPay_URL')
		PRINT 'Setting VPay_URL to https://eudemo.paygateservices.com/ReportService.svc/PaymentStatusV2' 

		IF EXISTS (SELECT SettingId FROM dbo.epos_DeviceSetting WHERE SettingName='vPayTerminalIdServiceURL')
			BEGIN
				UPDATE dbo.epos_DeviceSettingValue SET SettingValue='https://eudemo.paygateservices.com/TidPedSerialNumberService.svc/Get' WHERE SettingId IN (SELECT SettingId FROM dbo.epos_DeviceSetting WHERE SettingName='vPayTerminalIdServiceURL')
				PRINT 'Setting vPayTerminalIdServiceURL to https://eudemo.paygateservices.com/TidPedSerialNumberService.svc/Get' 
			END
	END

PRINT 'Setting vPay Passwords'
UPDATE dbo.epos_DeviceSettingValue SET SettingValue='#{vPayBlacklistPassword}' WHERE SettingId IN (SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vPayBlacklistPassword')
UPDATE dbo.epos_DeviceSettingValue SET SettingValue='#{vpayAuthPassword}' WHERE SettingId IN(SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vpayAuthPassword')
UPDATE dbo.conf_Setting_Value SET Value='#{VPay_Password}' WHERE SettingId IN (SELECT SettingId FROM conf_Setting WHERE SettingCode='VPay_Password')

-- the settingname in the db is actually spelled incorrectly vpayTerminalID -> vpayTermnialID
PRINT 'Prefixing vPay Terminal ID with UAT'
UPDATE dbo.epos_DeviceSettingValue SET SettingValue='UAT' + REPLACE(SettingValue, 'UAT', '') WHERE SettingId=(SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='vpayTermnialID')

PRINT 'Clearing SeatMap4U_URL'
UPDATE dbo.epos_DeviceSettingValue SET SettingValue='' WHERE SettingId=(SELECT SettingId FROM epos_DeviceSetting WHERE SettingName='SeatMap4U_URL')







--FTP ACCOUNTS
PRINT 'Setting FTP accounts'
	
-- Client specific updates

DECLARE @EdiConfigId INTEGER
DECLARE @SAP_M11_SenderNumber_SettingId INTEGER, @SAP_M11_ReceiveNumber_SettingId INTEGER, @SAP_M11_ReceivePort_SettingId INTEGER

-- RYR Navitaire URL
	IF ('#{SYS}' = 'RYR')
	BEGIN
		PRINT 'Setting navitaire URL for RYR'
		UPDATE dbo.conf_Setting_Value SET Value='https://frtestr4xapi.navitaire.com/' WHERE SettingId=(SELECT SettingId FROM conf_Setting WHERE SettingCode='ThirdParty_BookingEngine_RemoteAddress')
	END

	
--SAP INTEGRATION for 4U
	IF ('#{Sys}' = '4U')
	BEGIN
		PRINT 'Setting SAP settings for #{Sys} system'
		SELECT @SAP_M11_SenderNumber_SettingId = SettingId FROM conf_Setting cs WHERE DisplayName = 'SAP_M11_SenderNumber'
		SELECT @SAP_M11_ReceiveNumber_SettingId = SettingId FROM conf_Setting cs WHERE DisplayName = 'SAP_M11_ReceiveNumber'
		SELECT @SAP_M11_ReceivePort_SettingId = SettingId FROM conf_Setting cs WHERE DisplayName = 'SAP_M11_ReceivePort'

		IF EXISTS(
			SELECT 1
			FROM dbo.conf_Setting_Value WHERE SettingId = @SAP_M11_SenderNumber_SettingId
		) BEGIN
			UPDATE conf_Setting_Value SET Value = 'TVECTOR_4U' WHERE SettingId = @SAP_M11_SenderNumber_SettingId
		END
		ELSE 
		BEGIN 
			INSERT INTO conf_Setting_Value (SettingId, CompanyId, Value)
			VALUES (@SAP_M11_SenderNumber_SettingId, 2, 'TVECTOR_4U')
		END

		IF EXISTS(
			SELECT 1
			FROM dbo.conf_Setting_Value WHERE SettingId = @SAP_M11_ReceiveNumber_SettingId
		) BEGIN
			UPDATE conf_Setting_Value SET Value = 'LSGCK11002' WHERE SettingId = @SAP_M11_ReceiveNumber_SettingId
		END
		ELSE 
		BEGIN 
			INSERT INTO conf_Setting_Value (SettingId, CompanyId, Value)
			VALUES (@SAP_M11_ReceiveNumber_SettingId, 2, 'LSGCK11002')
		END

		IF EXISTS(
			SELECT 1
			FROM dbo.conf_Setting_Value WHERE SettingId = @SAP_M11_ReceivePort_SettingId
		) BEGIN
			UPDATE conf_Setting_Value SET Value = 'SAPK11' WHERE SettingId = @SAP_M11_ReceivePort_SettingId
		END
		ELSE 
		BEGIN 
			INSERT INTO conf_Setting_Value (SettingId, CompanyId, Value)
			VALUES (@SAP_M11_ReceivePort_SettingId, 2, 'SAPK11')
		END

		SELECT @EdiConfigId = ec.ConfigId FROM edi_Config ec WHERE ec.ConfigCode = 'IF119'

		IF @EdiConfigId IS NOT NULL BEGIN  
			UPDATE edi_Config SET ExtraSettings = '{ "Destination":"K11" }' WHERE ConfigId = @EdiConfigId
		END
	END

	--SAP INTEGRATION
	IF ('#{Sys}' = 'EDW')
	BEGIN
		PRINT 'Setting SAP settings for #{Sys} system'
		SELECT @SAP_M11_SenderNumber_SettingId = SettingId FROM conf_Setting cs WHERE DisplayName = 'SAP_M11_SenderNumber'
		SELECT @SAP_M11_ReceiveNumber_SettingId = SettingId FROM conf_Setting cs WHERE DisplayName = 'SAP_M11_ReceiveNumber'
		SELECT @SAP_M11_ReceivePort_SettingId = SettingId FROM conf_Setting cs WHERE DisplayName = 'SAP_M11_ReceivePort'

		IF EXISTS(
			SELECT 1
			FROM dbo.conf_Setting_Value WHERE SettingId = @SAP_M11_SenderNumber_SettingId
		) BEGIN
			UPDATE conf_Setting_Value SET Value = 'TVECTOR_WK' WHERE SettingId = @SAP_M11_SenderNumber_SettingId
		END
		ELSE 
		BEGIN 
			INSERT INTO conf_Setting_Value (SettingId, CompanyId, Value)
			VALUES (@SAP_M11_SenderNumber_SettingId, 65, 'TVECTOR_WK')
		END

		IF EXISTS(
			SELECT 1
			FROM dbo.conf_Setting_Value WHERE SettingId = @SAP_M11_ReceiveNumber_SettingId
		) BEGIN
			UPDATE conf_Setting_Value SET Value = 'LSGCK11002' WHERE SettingId = @SAP_M11_ReceiveNumber_SettingId
		END
		ELSE 
		BEGIN 
			INSERT INTO conf_Setting_Value (SettingId, CompanyId, Value)
			VALUES (@SAP_M11_ReceiveNumber_SettingId, 65, 'LSGCK11002')
		END

		IF EXISTS(
			SELECT 1
			FROM dbo.conf_Setting_Value WHERE SettingId = @SAP_M11_ReceivePort_SettingId
		) BEGIN
			UPDATE conf_Setting_Value SET Value = 'SAPK11' WHERE SettingId = @SAP_M11_ReceivePort_SettingId
		END
		ELSE 
		BEGIN 
			INSERT INTO conf_Setting_Value (SettingId, CompanyId, Value)
			VALUES (@SAP_M11_ReceivePort_SettingId, 65, 'SAPK11')
		END

		SELECT @EdiConfigId = ec.ConfigId FROM edi_Config ec WHERE ec.ConfigCode = 'IF119'

		IF @EdiConfigId IS NOT NULL BEGIN  
			UPDATE edi_Config SET ExtraSettings = '{ "Destination":"K11" }' WHERE ConfigId = @EdiConfigId
		END
	END

	--KDI INTEGRATION
	IF ('#{Sys}' = 'DLH')
	BEGIN
		PRINT 'Setting KDI integreation settings for #{Sys} system'
		UPDATE dbo.conf_Setting_Value SET Value ='eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzY29wZSI6WyJyZWFkIiwid3JpdGUiXSwiZXhwIjoxNTExNTExNzMzLCJhdXRob3JpdGllcyI6WyIxMTQiLCIxMTUiLCIzMiJdLCJqdGkiOiI3MGEwM2QyOS1kZDE5LTQzY2YtOTFhOC0yMGM5ZTRmNzljMzQiLCJjbGllbnRfaWQiOiJtc3BfcGFydG5lcl90b2tlbiIsImdyYW50X3R5cGUiOiJjbGllbnRfY3JlZGVudGlhbHMiLCJpc3N1ZXJfaWQiOiIxMSIsInBhcnRuZXJfc3lzdGVtX3Rva2VuIjp0cnVlLCJjb21tZW50IjoiVGVzdCBJQk8gTVNQIiwicGFydG5lcl9pZCI6MzM4LCJ1c2VyX25hbWUiOiJTVV9UU1RfaWJvbXNwIiwidXNlcl9pZCI6Mjk5Mn0.gxLf8QJr-X5SseZJboXSADXyLQYFYEi3wf_9FSRY5x_ZecQ2brNcw_gUMTH7IwGBAiFp4PLoa9UicwLqJPvajEJ8Pd4UY8vG5hQSzKKTZYT3AawjRdR6R8VZCCQ_Nr6Mz7X0XOB0xbNALcMn8v9tX2wnHRHu8G4CBcZhyvSxGFDm90NzneWmfGd5OWHo75RBQpVuC6fW3Bi4b6f2kbXwnFJaUwcrraEwmzcUbyOwcqOu6dnHU7arJC0hkBee8GHME76EFNhTOWWCyo0XjPyaK14mpd5hVgiM39rStDs8dwyg8PXv3kYtOpmtaA48ikoapDI-O-cQbimWwDDlZJ5Ehw' WHERE SettingId=(SELECT SettingId FROM conf_Setting WHERE SettingCode='ThirdParty_LoyaltyEngine_Login_Token')
	END
	
	
	-- MIM aero urls
	UPDATE dbo.epos_DeviceSettingValue
	SET SettingValue='https://demovpos-lsg.mim.aero:10010/api/'
	WHERE SettingValue='https://vpos.boardconnect.aero:10010/api/';
	
    
    -- Final safety net for ESB jobs that might not have been converted
    -- From https://support.retailinmotion.com/browse/VECTWO-28052
    UPDATE edi_Config SET ExtraSettings = REPLACE(ExtraSettings,'_PRD','_UAT') 
	UPDATE edi_Config SET ExtraSettings = REPLACE(ExtraSettings,'P11','K11')
END TRY  
BEGIN CATCH
	 SELECT  
        ERROR_NUMBER() AS ErrorNumber  
        ,ERROR_SEVERITY() AS ErrorSeverity  
        ,ERROR_STATE() AS ErrorState  
        ,ERROR_PROCEDURE() AS ErrorProcedure  
        ,ERROR_LINE() AS ErrorLine  
        ,ERROR_MESSAGE() AS ErrorMessage;  
END CATCH
SET QUOTED_IDENTIFIER ON
GO