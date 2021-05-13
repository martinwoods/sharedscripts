IF COL_LENGTH('edi_Config','DeleteAfterProcess') IS NULL
BEGIN
   ALTER TABLE edi_Config ADD DeleteAfterProcess BIT NOT NULL DEFAULT 0;
END
--
GO
--
--- CHECK constraint update start ---
IF EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'CK_app_Setting_Value_Scope'))
BEGIN
	ALTER TABLE [dbo].[conf_Setting_Value] DROP CONSTRAINT [CK_app_Setting_Value_Scope]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'CK_app_Setting_Value_Scope_UserId'))
BEGIN
	ALTER TABLE [dbo].[conf_Setting_Value] WITH CHECK ADD CONSTRAINT [CK_app_Setting_Value_Scope_UserId] CHECK  (([SiteId] IS NOT NULL AND [CompanyId] IS NULL AND [UserId] IS NULL OR [SiteId] IS NULL AND [CompanyId] IS NOT NULL AND [UserId] IS NULL OR [SiteId] IS NULL AND [CompanyId] IS NULL AND [UserId] IS NOT NULL OR [SiteId] IS NULL AND [CompanyId] IS NOT NULL AND [UserId] IS NOT NULL))
	ALTER TABLE [dbo].[conf_Setting_Value] CHECK CONSTRAINT [CK_app_Setting_Value_Scope_UserId]
END
--- CHECK constraint update finish ---

DECLARE @UserId int,
		@CompanyId int,
		@vPosSyncUserId int

-- geting vESB User Id value to use in SQL later
SELECT TOP 1 @UserId = UserId FROM dbo.app_User WHERE Email LIKE 'admin%@vesbrim.com'
-- getting CompanyId based on Tenant code where this script is run
SELECT @CompanyId = ac.CompanyId FROM dbo.conf_Config cc JOIN dbo.app_Company ac ON ac.TenantCode = cc.ConfigValue
-- getting vPos sync user id in case that value is null when ran
SELECT TOP 1 @vPosSyncUserId = UserId FROM dbo.app_User WHERE Email LIKE 'vpos%@vesbrim.com'

DROP TABLE IF EXISTS #queries
CREATE TABLE #queries (
    query VARCHAR(MAX),
    execorder INT
);

INSERT INTO #queries SELECT 
	'IF EXISTS(SELECT TOP 1 Routine_Name FROM information_schema.routines WHERE routine_type = ''PROCEDURE'' AND Routine_Name = ''esbEdiConfigInsert'' AND ROUTINE_DEFINITION LIKE ''%@DeleteAfterProcess%'') '
	+ 'BEGIN '
	+ 'exec dbo.esbEdiConfigInsert '
	 + '@ConfigCode=''' + c.ConfigCode + ''''
	 + ', @Config=''' + c.Config + ''''
	 + ', @SiteId=' + CONVERT(NVARCHAR,ISNULL(c.SiteId,1)) 
	 + ', @CompanyId=' + CONVERT(NVARCHAR,ISNULL(c.CompanyId,@CompanyId)) 
	 + ', @PeriodicityId=' + CONVERT(NVARCHAR,c.PeriodicityId) 
	 + ISNULL(', @ExecutionDay=' + CONVERT(NVARCHAR,c.ExecutionDay)  ,'')
	 + ISNULL(', @DataTypeId=' + CONVERT(NVARCHAR,c.DataTypeId)  ,'')
	 + ISNULL(', @AssemblyType=''' + c.AssemblyType + '''' ,'')
	 + ISNULL(', @DropLocation=''' + c.DropLocation + '''' ,'')
	 + ISNULL(', @DailyProcDropLocation=''' + c.DailyProcDropLocation + '''' ,'')
     + ISNULL(', @DateStart=''' + CONVERT(NVARCHAR,c.DateStart, 120) + '''' ,'')
     + ISNULL(', @DateEnd=''' + CONVERT(NVARCHAR,c.DateEnd, 120) + '''' ,'')
	 + ISNULL(', @FilePrefix=''' + c.FilePrefix + '''' ,'')
	 + ISNULL(', @FileSufix=''' + c.FileSufix + '''' ,'')
	 + ISNULL(', @FileExtension=''' + c.FileExtension + '''' ,'')
	 + ISNULL(', @ExtraSettings=''' + c.ExtraSettings + '''' ,'')
	 + ISNULL(', @SendExternalSystem=' + CONVERT(NVARCHAR,c.SendExternalSystem)  ,'')
	 + ISNULL(', @DailyProcDropLocationIsAbsolute=' + CONVERT(NVARCHAR,c.DailyProcDropLocationIsAbsolute)  ,'')
	 + ISNULL(', @SendTypeId=' + CONVERT(NVARCHAR,c.SendTypeId)  ,'')
	 + ISNULL(', @LastModifiedUserId=' + CONVERT(NVARCHAR,ISNULL(c.LastModifiedUserId, @UserId))  ,'')
	 + ISNULL(', @Reason=''' + c.Reason + '''' ,'')
	 + ISNULL(', @JobTypeId=' + CONVERT(NVARCHAR,c.JobTypeId)  ,'')
	 + ISNULL(', @ExecutionTime=''' + CONVERT(NVARCHAR(8),c.ExecutionTime) + '''' ,'')
	 + ISNULL(', @RetryTimeout=''' + CONVERT(NVARCHAR(8),c.RetryTimeout) + '''' ,'')
	 + ISNULL(', @RetryCount=' + CONVERT(NVARCHAR,c.RetryCount)  ,'')
	 + ISNULL(', @AvailableConfigTypeId=' + CONVERT(NVARCHAR,c.AvailableConfigTypeId)  ,'')
	 + ISNULL(', @PriorityId=' + CONVERT(NVARCHAR,c.PriorityId)  ,'')
	 + ISNULL(', @Timeout=''' + CONVERT(NVARCHAR(8),c.Timeout) + '''' ,'')
	 + ISNULL(', @EmailTemplateId=' + CONVERT(NVARCHAR,c.EmailTemplateId)  ,'')
	 + ISNULL(', @SemaphoreThreadCount=' + CONVERT(NVARCHAR,c.SemaphoreThreadCount)  ,'')
	 + ISNULL(', @FetchTypeId=' + CONVERT(NVARCHAR,c.FetchTypeId)  ,'')
	 + ISNULL(', @FetchPath=''' + c.FetchPath + '''' ,'')
	 + ISNULL(', @FetchPrefix=' + c.FetchPrefix  ,'')
	 + ISNULL(', @ApplyTimeStamp=' + CONVERT(NVARCHAR,c.ApplyTimeStamp)  ,'')
	 + ISNULL(', @MatchChecksum=' + CONVERT(NVARCHAR,c.MatchChecksum)  ,'')
	 + ISNULL(', @SendZip=' + CONVERT(NVARCHAR,c.SendZip)  ,'')
	 + ISNULL(', @ZipPrefix=''' + c.ZipPrefix + '''' ,'')
	 + CASE 
        WHEN EXISTS(SELECT TOP 1 Routine_Name FROM information_schema.routines WHERE routine_type = 'PROCEDURE' AND Routine_Name = 'esbEdiConfigInsert' AND ROUTINE_DEFINITION LIKE '%@DeleteAfterProcess%') 
        THEN ISNULL(', @DeleteAfterProcess=' + CONVERT(NVARCHAR,c.DeleteAfterProcess)  ,'')
        ELSE ''
       END
     + ', @ConfigId=NULL;'
	 + 'END '
	 +'ELSE '
	 +'BEGIN '
	 	+ 'exec dbo.esbEdiConfigInsert '
	 + '@ConfigCode=''' + c.ConfigCode + ''''
	 + ', @Config=''' + c.Config + ''''
	 + ', @SiteId=' + CONVERT(NVARCHAR,ISNULL(c.SiteId,1)) 
	 + ', @CompanyId=' + CONVERT(NVARCHAR,ISNULL(c.CompanyId,@CompanyId)) 
	 + ', @PeriodicityId=' + CONVERT(NVARCHAR,c.PeriodicityId) 
	 + ISNULL(', @ExecutionDay=' + CONVERT(NVARCHAR,c.ExecutionDay)  ,'')
	 + ISNULL(', @DataTypeId=' + CONVERT(NVARCHAR,c.DataTypeId)  ,'')
	 + ISNULL(', @AssemblyType=''' + c.AssemblyType + '''' ,'')
	 + ISNULL(', @DropLocation=''' + c.DropLocation + '''' ,'')
	 + ISNULL(', @DailyProcDropLocation=''' + c.DailyProcDropLocation + '''' ,'')
     + ISNULL(', @DateStart=''' + CONVERT(NVARCHAR,c.DateStart, 120) + '''' ,'')
     + ISNULL(', @DateEnd=''' + CONVERT(NVARCHAR,c.DateEnd, 120) + '''' ,'')
	 + ISNULL(', @FilePrefix=''' + c.FilePrefix + '''' ,'')
	 + ISNULL(', @FileSufix=''' + c.FileSufix + '''' ,'')
	 + ISNULL(', @FileExtension=''' + c.FileExtension + '''' ,'')
	 + ISNULL(', @ExtraSettings=''' + c.ExtraSettings + '''' ,'')
	 + ISNULL(', @SendExternalSystem=' + CONVERT(NVARCHAR,c.SendExternalSystem)  ,'')
	 + ISNULL(', @DailyProcDropLocationIsAbsolute=' + CONVERT(NVARCHAR,c.DailyProcDropLocationIsAbsolute)  ,'')
	 + ISNULL(', @SendTypeId=' + CONVERT(NVARCHAR,c.SendTypeId)  ,'')
	 + ISNULL(', @LastModifiedUserId=' + CONVERT(NVARCHAR,ISNULL(c.LastModifiedUserId, @UserId))  ,'')
	 + ISNULL(', @Reason=''' + c.Reason + '''' ,'')
	 + ISNULL(', @JobTypeId=' + CONVERT(NVARCHAR,c.JobTypeId)  ,'')
	 + ISNULL(', @ExecutionTime=''' + CONVERT(NVARCHAR(8),c.ExecutionTime) + '''' ,'')
	 + ISNULL(', @RetryTimeout=''' + CONVERT(NVARCHAR(8),c.RetryTimeout) + '''' ,'')
	 + ISNULL(', @RetryCount=' + CONVERT(NVARCHAR,c.RetryCount)  ,'')
	 + ISNULL(', @AvailableConfigTypeId=' + CONVERT(NVARCHAR,c.AvailableConfigTypeId)  ,'')
	 + ISNULL(', @PriorityId=' + CONVERT(NVARCHAR,c.PriorityId)  ,'')
	 + ISNULL(', @Timeout=''' + CONVERT(NVARCHAR(8),c.Timeout) + '''' ,'')
	 + ISNULL(', @EmailTemplateId=' + CONVERT(NVARCHAR,c.EmailTemplateId)  ,'')
	 + ISNULL(', @SemaphoreThreadCount=' + CONVERT(NVARCHAR,c.SemaphoreThreadCount)  ,'')
	 + ISNULL(', @FetchTypeId=' + CONVERT(NVARCHAR,c.FetchTypeId)  ,'')
	 + ISNULL(', @FetchPath=''' + c.FetchPath + '''' ,'')
	 + ISNULL(', @FetchPrefix=''' + c.FetchPrefix + '''' ,'')
	 + ISNULL(', @ApplyTimeStamp=' + CONVERT(NVARCHAR,c.ApplyTimeStamp)  ,'')
	 + ISNULL(', @MatchChecksum=' + CONVERT(NVARCHAR,c.MatchChecksum)  ,'')
	 + ISNULL(', @SendZip=' + CONVERT(NVARCHAR,c.SendZip)  ,'')
	 + ISNULL(', @ZipPrefix=''' + c.ZipPrefix + '''' ,'')
	 + ', @ConfigId=NULL;'
	 +'END ' AS query, 1 AS execorder
  FROM edi_Config c 

-- DEVOPS-413 - Setting values for vESB

INSERT INTO #queries SELECT 'DELETE sv FROM conf_Setting_Value sv INNER JOIN conf_Setting s on sv.SettingId=s.SettingId WHERE s.SettingGroupId = 15 AND s.SettingId between 15000 and 15999;' AS query, 2 AS execorder
INSERT INTO #queries SELECT 'INSERT INTO conf_Setting_Value (SettingId, SiteId, CompanyId, UserId, [Value], LastModifiedUserId, LastModifiedDate, Reason)'
	+ ' VALUES (' 
	+ CONVERT(NVARCHAR,sv.SettingId) + ', ' 
	+ ISNULL(CONVERT(NVARCHAR,sv.SiteId), 'NULL') + ', ' 
	+ ISNULL(CONVERT(NVARCHAR,ISNULL(sv.CompanyId, @CompanyId)), 'NULL') + ', ' 
	+ ISNULL(CONVERT(NVARCHAR,ISNULL(sv.UserId, @UserId)), 'NULL') + ', ' 
	+ '''' +  sv.[Value] + ''', ' 
	+ ISNULL(CONVERT(NVARCHAR, ISNULL(sv.LastModifiedUserId, @UserId)), 'NULL') + ', ' 
	+ ISNULL('''' + CONVERT(NVARCHAR, sv.LastModifiedDate, 120) + '''', 'NULL') + ', '
	+ ISNULL('''' +  sv.Reason + '''', 'NULL') + ');'
	 AS query, 4 AS execorder
FROM conf_Setting s
INNER JOIN conf_Setting_Value sv on s.SettingId = sv.SettingId
WHERE s.SettingId between 15000 and 15999
AND   s.SettingGroupId = 15


--
-- DEVOPS-413 - Setting values for vReceipts
-- DEVOPS-417 - Add new Handheld settings
--


-- Delete the old values
INSERT INTO #queries SELECT 'DELETE dsv FROM epos_DeviceSettingValue dsv INNER JOIN epos_DeviceSetting ds on dsv.SettingId=ds.SettingId'
+ ' WHERE ds.SettingName IN (''vectorClientId'',''vectorClientSecret'',''vectorPassword'',''vectorUsername'',  ''Vector3ServiceURL'', ''enablevirtualreceipt'')'  AS query, 6 AS execorder

-- Delete the old setting keys
INSERT INTO #queries SELECT 'DELETE ds FROM epos_DeviceSetting ds'
+ ' WHERE ds.SettingName IN (''vectorClientId'',''vectorClientSecret'',''vectorPassword'',''vectorUsername'',  ''Vector3ServiceURL'', ''enablevirtualreceipt'')'  AS query, 7 AS execorder

INSERT INTO #queries SELECT 'SET IDENTITY_INSERT epos_DeviceSetting ON' AS query, 8 AS execorder

-- Output an INSERT statement to restore the setting keys
INSERT INTO #queries SELECT 'INSERT INTO epos_DeviceSetting (SettingId, SettingName, SettingValueMaxLength, HelpText, ScreenName, SettingValueType, SettingGroupId, Visible)'
	+ ' VALUES (' 
	+ CONVERT(NVARCHAR,ds.SettingId) + ', ' 
	+ ISNULL('''' + CONVERT(NVARCHAR,ds.SettingName) + '''', 'NULL') + ', ' 
	+ CONVERT(NVARCHAR,ds.SettingValueMaxLength) + ', ' 
	+ ISNULL('''' + CONVERT(NVARCHAR,ds.HelpText) + '''', 'NULL') + ', ' 
	+ ISNULL('''' + CONVERT(NVARCHAR,ds.ScreenName) + '''', 'NULL') + ', ' 
	+ CONVERT(NVARCHAR,ds.SettingValueType) + ', ' 
	+ CONVERT(NVARCHAR,ds.SettingGroupId) + ', ' 
	+ CONVERT(NVARCHAR,ds.Visible) + ');'  AS query, 9 AS execorder
FROM epos_DeviceSetting ds
WHERE ds.SettingName IN ('vectorClientId','vectorClientSecret','vectorPassword','vectorUsername', 'Vector3ServiceURL', 'enablevirtualreceipt')


-- Output an INSERT statement to restore the setting values
INSERT INTO #queries SELECT 'INSERT INTO epos_DeviceSettingValue (SettingId, CompanyId, SettingValue, LastModifiedDate, LastModifiedUserId, Reason)'
	+ ' VALUES (' 
	+ CONVERT(NVARCHAR,dsv.SettingId) + ', ' 
	+ ISNULL(CONVERT(NVARCHAR,dsv.CompanyId), 'NULL') + ', ' 
	+ '''' +  REPLACE(dsv.SettingValue, '''', '''''') + ''', ' 
	+ ISNULL('''' + CONVERT(NVARCHAR, dsv.LastModifiedDate, 120) + '''', 'NULL') + ', '
	+ ISNULL(CONVERT(NVARCHAR, ISNULL(dsv.LastModifiedUserId, @vPosSyncUserId)), 'NULL') + ', ' 
	+ ISNULL('''' +  dsv.Reason + '''', 'NULL') + ');'  AS query, 10 AS execorder
FROM epos_DeviceSetting ds
INNER JOIN epos_DeviceSettingValue dsv on ds.SettingId = dsv.SettingId
WHERE ds.SettingName IN ('vectorClientId','vectorClientSecret','vectorPassword','vectorUsername', 'Vector3ServiceURL', 'enablevirtualreceipt')

INSERT INTO #queries SELECT 'SET IDENTITY_INSERT epos_DeviceSetting OFF' AS query, 11 AS execorder

SELECT [query]  FROM #queries ORDER BY execorder ASC
GO
DROP TABLE #queries
GO