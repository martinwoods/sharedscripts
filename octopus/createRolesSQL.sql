SET QUOTED_IDENTIFIER ON

BEGIN TRANSACTION

SET XACT_ABORT ON

DECLARE @Company int
DECLARE @role varchar(10)
DECLARE @email varchar(max)
DECLARE @crtRole VARCHAR(50)
DECLARE @crtCompanyId INT
DECLARE @crtRoleId INT
DECLARE @counter INT = 0
DECLARE @commit BIT
DECLARE @useAppCompany BIT = 1
DECLARE @msg VARCHAR(MAX) = ''
DECLARE @newAdminEmail VARCHAR(MAX) = ''
DECLARE @crtCompanyName VARCHAR(50)
DECLARE @crtCompanySiteId INT
DECLARE @exceptionsInsert VARCHAR(MAX) = ''
DECLARE @userInsertProc VARCHAR(MAX) = ''
DECLARE @crtException VARCHAR(50)
DECLARE @crtExceptionDefault VARCHAR(50)
DECLARE @crtExceptionType VARCHAR(50)


--REPLACE_WITH_VARIABLES


IF OBJECT_ID('tempdb..#CreateVectorAccountExceptions') IS NOT NULL  
	DROP TABLE #CreateVectorAccountExceptions

CREATE TABLE #CreateVectorAccountExceptions
(
	property VARCHAR(50),
	defaultValue VARCHAR(50),
	isString BIT
)
--Compatibility exception
INSERT INTO #CreateVectorAccountExceptions
	(property, defaultValue, isString)
VALUES
	('PasswordPolicyId', 'NULL', 0),
	('keepUsernameClear', '1', 0),
	('BlockvPOSSales', '0', 0)

DECLARE c_Exceptions CURSOR FOR
	SELECT property, defaultValue, isString
	FROM #CreateVectorAccountExceptions

OPEN c_Exceptions
FETCH NEXT FROM c_Exceptions INTO @crtException, @crtExceptionDefault, @crtExceptionType

WHILE @@FETCH_STATUS = 0
	BEGIN
	--PRINT 'Current exception:' + @crtException + ' = ' + @crtExceptionDefault
	IF EXISTS (
		SELECT *
		FROM sys.procedures pr
		JOIN sys.parameters pa
			ON pr.object_id = pa.object_id
		WHERE 
			pr.object_id = object_ID('dbo.appUserInsert')
		AND pa.name = '@' + @crtException
	)
		BEGIN
			IF @crtExceptionType = 1
				SET @exceptionsInsert = @exceptionsInsert + ',@' + @crtException + ' = ''' + @crtExceptionDefault + ''''
			ELSE
				SET @exceptionsInsert = @exceptionsInsert + ',@' + @crtException + ' = ' + @crtExceptionDefault
		END

	FETCH NEXT FROM c_Exceptions INTO @crtException, @crtExceptionDefault, @crtExceptionType
	END
CLOSE c_Exceptions
DEALLOCATE c_Exceptions

IF OBJECT_ID('tempdb..#CreateVectorAccountExceptions') IS NOT NULL  
	DROP TABLE #CreateVectorAccountExceptions


--Check if role creation is needed
--Join on app_user for existing users if there is no company with IsAirlineCompany set
IF NOT EXISTS (SELECT *
				FROM dbo.app_Company
				WHERE IsAirlineCompany = 1)
	BEGIN
		IF EXISTS (SELECT DISTINCT U.CompanyId 
						FROM dbo.app_User AS U
						JOIN dbo.app_Company AS C 
							ON (U.CompanyId = C.CompanyId))
			BEGIN
				SET @useAppCompany = 0
			END
		ELSE
			BEGIN
				SET @msg = 'There is no suitable Airline company enabled in the database ' + DB_NAME() + ', cannot proceed.'
				RAISERROR (@msg, 16, -1)
				GOTO ALL_DONE
			END
	END

IF @useAppCompany = 1
	BEGIN
		DECLARE c_company CURSOR FOR
			SELECT CompanyId, Company, SiteId
			FROM dbo.app_Company
			WHERE IsAirlineCompany = 1
	END
ELSE
	BEGIN
		DECLARE c_company CURSOR FOR
			SELECT CompanyId, Company, SiteId
			FROM dbo.app_Company
			WHERE CompanyId in (SELECT DISTINCT U.CompanyId 
						FROM dbo.app_User AS U
						JOIN dbo.app_Company AS C 
							ON (U.CompanyId = C.CompanyId))
	END

OPEN c_company
FETCH NEXT FROM c_company INTO @crtCompanyId, @crtCompanyName, @crtCompanySiteId

WHILE @@FETCH_STATUS = 0
BEGIN
	--Get the latest role created with this name, if more exist
	SET @crtRoleId = (SELECT MAX(UserId) 
						FROM dbo.app_User
						WHERE IsRole = 1
						  AND DisplayName = @crtRole
						  AND CompanyId = @crtCompanyId)
	IF @crtRoleId IS NULL
		BEGIN
        	PRINT 'Role not found for companyId ' + (CAST(@crtCompanyId as VARCHAR(10))) + ' : ' + @crtRole + ' .'
			SET @counter = @counter + 1
		END

	--Ensure a SuperAdmin role exists for every company
	SET @crtRoleId = (SELECT
						MAX(UserId) 
						FROM dbo.app_User
						WHERE IsRole = 1
						AND IsSuperAdmin = 1
						AND CompanyId = @crtCompanyId)

	PRINT 'Current Admin role is ' + (CAST(@crtRoleId as VARCHAR(10)))

	IF @crtRoleId IS NULL
		BEGIN
			PRINT 'No SuperAdmin role found for company ' + @crtCompanyName + ', creating one'
			SET @newAdminEmail = replace(replace(@crtCompanyName,' ',''),'''','') + 'SuperAdmin@RiM.com'
			SET @userInsertProc = 'EXEC dbo.appUserInsert
						@Email = ''' + @newAdminEmail + ''',
						@DisplayName = ''' + replace(@crtCompanyName,'''','') + ' SuperAdmin'',
						@Password = ''A9HetMZ4p5AWQp6DzL3prJR_FX-uxElYQgv0FZO9'',
						@CompanyId = ' + (CAST(@crtCompanyId as VARCHAR(10))) + ',
						@IsRole = 1,
						@CanEditRoles = 1,
						@RoleId = NULL,
						@LastModifiedUserId = 1--EXCEPTIONS'
			SET @userInsertProc = REPLACE(@userInsertProc,'--EXCEPTIONS',@exceptionsInsert)
			PRINT 'Creating admin role ' + @newAdminEmail + ' for company ' + replace(@crtCompanyName,'''','') + '-' + (CAST(@crtCompanyId as VARCHAR(10))) + '---'
			EXEC (@userInsertProc)

			SELECT @crtRoleId = (SELECT UserId 
									FROM dbo.app_User
									WHERE Email = @newAdminEmail)
			UPDATE dbo.app_User
				SET IsSuperAdmin = 1
				WHERE UserId = @crtRoleId
		END

	--Add the admin role to the sitemap (http://bitbucket.rim.local:7990/projects/BACKOFFICE/repos/vectorbo/browse/SQL/9_ImplementationSpecificData/app_UserSitemap.sql)
	declare @RoleEmail varchar(max)
	set @RoleEmail = (SELECT Email 
								FROM dbo.app_User
								WHERE UserId = @crtRoleId)
	PRINT	'Updating sitemap for ' + @RoleEmail
	merge	app_UserSiteMap as target
	using	(select	@crtRoleId, Id
	from	app_Sitemap sm JOIN app_Site_SiteMap ssm ON ssm.SiteMapId = sm.Id where ShowForEveryone = 0 and ssm.SiteId = @crtCompanySiteId) as source ([UserId], [SiteMapId])
			on		(target.[UserId] = source.[UserId] and target.[SiteMapId] = source.[SiteMapId])
	when not matched by target then
			insert ([UserId], [SiteMapId], [AccessLevels]) 
			values ([UserId], [SiteMapId], '')
	when not matched by source and target.UserId IN (select UserId from app_user where Email IN (@RoleEmail))
		then delete;

	FETCH NEXT FROM c_company INTO @crtCompanyId, @crtCompanyName, @crtCompanySiteId
END
CLOSE c_company
DEALLOCATE c_company

IF @counter = 0
      BEGIN
            PRINT 'Role ' + @crtRole + ' exists for all companies.'
            GOTO ALL_DONE
      END

--Create roles as per the list
PRINT 'Creating standard Vector roles.'
declare @new_roles table
(DispName varchar(10))
insert into @new_roles values('Rim_dev')
insert into @new_roles values('Rim_acmgr')
insert into @new_roles values('Rim_fls')
insert into @new_roles values('Rim_sls')
insert into @new_roles values('Rim_itops')
insert into @new_roles values('Rim_BA')
insert into @new_roles values('Rim_Fi')
insert into @new_roles values('Rim_QA')
insert into @new_roles values('Rim_hw')

--EXCLUDE SITE access as per the list (user create,user edit etc)--
select Id INTO #sitemap_exclude from app_SiteMap where (id in (3910,3911,3920,3924,3926,3930,3935,3945,3970,3980) 
or (
FilePath like '%User.aspx%'
or FilePath  like '%UserUpload.aspx%'
or FilePath  like '%Role.aspx%'
or FilePath  like '%UserChangeProfile.aspx%'
or FilePath  like '%UserSitemapEdit.aspx%'
or FilePath  like '%UploadRoster.aspx%'
or FilePath  like '%SitePages.aspx%'
or FilePath  like '%SiteMapEdit.aspx%'))

--Declare local tables
select top 1 * into #temp_user_source from app_user a
delete #temp_user_source where 1=1
select top 1 * into #temp_usersitemap from app_UserSiteMap
delete #temp_usersitemap where 1=1

--Handle app_User different structures - read columns
DECLARE @app_user_column_list AS varchar(max)
SELECT @app_user_column_list =COALESCE(@app_user_column_list,'') +  '['+Name+'],' from sys.columns where object_id =(select object_id from sys.tables where name = 'app_User')
--exclude computed column
and name <>'EPOSActive'

Set @app_user_column_list = Left(@app_user_column_list,Len(@app_user_column_list)-1)

--Declare cursor for airline companies for the environment

IF @useAppCompany = 1
	BEGIN
		DECLARE db_cursor CURSOR FOR
			SELECT CompanyId
			FROM dbo.app_Company
			WHERE IsAirlineCompany = 1
	END
ELSE
	BEGIN
		DECLARE db_cursor CURSOR FOR
			SELECT CompanyId
			FROM dbo.app_Company
			WHERE CompanyId in (SELECT DISTINCT U.CompanyId 
						FROM dbo.app_User AS U
						JOIN dbo.app_Company AS C 
							ON (U.CompanyId = C.CompanyId))
	END

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @crtCompanyId

WHILE @@FETCH_STATUS = 0  
BEGIN  

DECLARE @template1 AS varchar(max)
DECLARE @template2 AS varchar(max)
DECLARE @template3 AS varchar(max)

--declare sql commands with dynamic app_user columns
SET @template1 = 'SET IDENTITY_INSERT #temp_user_source ON; Insert into #temp_user_source ({COLUMN_LIST}) select {COLUMN_LIST} from app_user a where  UserId =(select MAX(UserId) from app_User b where CompanyId =a.CompanyId and IsRole =1 and DisplayName like ''%dev%'') and CompanyId ={@crtCompanyId} SET IDENTITY_INSERT #temp_user_source OFF;'
SET @template2 = 'SET IDENTITY_INSERT #temp_user_source ON; Insert into #temp_user_source ({COLUMN_LIST}) select {COLUMN_LIST} from app_user a where  UserId =(select MAX(UserId) from app_User b where CompanyId =a.CompanyId and IsRole =1 and DisplayName like ''%super%admin%'') and CompanyId ={@crtCompanyId} SET IDENTITY_INSERT #temp_user_source OFF;'
SET @template3 = 'DECLARE @UserId int Insert into app_user ({COLUMN_LIST}) select {COLUMN_LIST} from #temp_user_source; select @UserId = SCOPE_IDENTITY(); Insert into app_UserSiteMap (UserId,SiteMapId,AccessLevels,LastModifiedUserId,LastModifiedDate,Reason) select @UserId,SiteMapId,AccessLevels,LastModifiedUserId,GETDATE(),Reason from #temp_usersitemap;'
SET @template1 = REPLACE(@template1, '{COLUMN_LIST}', @app_user_column_list)
SET @template2 = REPLACE(@template2, '{COLUMN_LIST}', @app_user_column_list)
SET @template3 = REPLACE(@template3, '{COLUMN_LIST}', @app_user_column_list)
SET @template1 = REPLACE(@template1, '{@crtCompanyId}', @crtCompanyId)
SET @template2 = REPLACE(@template2, '{@crtCompanyId}', @crtCompanyId)
SET @template3 = REPLACE(@template3, '{@crtCompanyId}', @crtCompanyId)
SET @template3 = REPLACE(@template3, '[UserId],', '')

if (select COUNT(*) from app_user where IsRole =1 and DisplayName like '%dev%' and CompanyId = @crtCompanyId
and exists (select Top 1 * from app_UserSiteMap where app_user.UserId = UserId)) <>0
BEGIN
--create template for a role based on existing Rim_dev role (exclude selected sitemaps)
EXEC (@template1)
END
ELSE
BEGIN
--create template for a role based on Super Admin role if dev doesn't exist (exclude selected sitemaps)
EXEC (@template2)
END
--create template for sitemap based on found role
      Insert into #temp_usersitemap (UserId,SiteMapId,AccessLevels,LastModifiedUserId,LastModifiedDate,Reason)
      select UserId,SiteMapId,AccessLevels,LastModifiedUserId,GETDATE(),Reason
      from app_UserSiteMap where UserId = (select MAX(#temp_user_source.UserId) from #temp_user_source)
--exlude not needed sitemap
      and SiteMapId not in (select ID from #sitemap_exclude)

--do the job if template user found
IF (select COUNT (*) from #temp_user_source) <>0 
BEGIN 
      --create second cursor for required roles
      DECLARE db_cursor2 CURSOR FOR 
      select DispName from @new_roles 
      OPEN db_cursor2  
      FETCH NEXT FROM db_cursor2 INTO @role 
            WHILE @@FETCH_STATUS = 0  
            BEGIN
            select @email = @role + '@rim' +Convert(varchar(max),@crtCompanyId)+ '.com'
            IF (select COUNT (*) from app_User where (Email like @email or DisplayName like '%'+@role+'%' or UserName like '%'+@role+'%') and CompanyId = @crtCompanyId) =0
            BEGIN
            --update required columns on user template
            update #temp_user_source set CompanyId=@crtCompanyId,Email =@email,DisplayName=@role,UserName=@role+'_'+CONVERT(Varchar,@crtCompanyId),DateModified =GETDATE()
            --can't assign roles to other users - CanEditRoles = 0
            IF (@app_user_column_list like '%CanEditRoles%')
            BEGIN
            update #temp_user_source set CanEditRoles = 0
            END
            --is not superadmin  - IsSuperAdmin = 0
            IF (@app_user_column_list like '%IsSuperAdmin%')
            BEGIN
            update #temp_user_source set IsSuperAdmin =0
            END   
            --insert role and sitemap for new role
            EXEC (@template3)
            END 
            FETCH NEXT FROM db_cursor2 INTO @role 
            END
            CLOSE db_cursor2  
            DEALLOCATE db_cursor2 
END
FETCH NEXT FROM db_cursor INTO @crtCompanyId
TRUNCATE Table #temp_user_source
TRUNCATE Table #temp_usersitemap
END 
--clear temp structures
DROP TABLE #temp_user_source
DROP TABLE #temp_usersitemap
DROP TABLE #sitemap_exclude
CLOSE db_cursor  
DEALLOCATE db_cursor 

ALL_DONE:

IF @commit = 1 
	BEGIN
		PRINT 'Changes commited.'
		COMMIT
	END
ELSE
	BEGIN
		PRINT 'Changes rolled back.'
		ROLLBACK
	END