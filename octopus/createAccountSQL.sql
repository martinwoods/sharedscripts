SET QUOTED_IDENTIFIER ON

BEGIN TRANSACTION

DECLARE @crtUserEmail VARCHAR(50)
DECLARE @crtUserDisplayName VARCHAR(50)
DECLARE @crtUserPassword VARCHAR(50)
DECLARE @crtCompanyName VARCHAR(50)
DECLARE @crtCompanyId INT
DECLARE @crtCompanySiteId INT
DECLARE @crtRole VARCHAR(50)
DECLARE @crtRoleId INT
DECLARE @superAdmin BIT
DECLARE @msg VARCHAR(MAX)
DECLARE @crtUserId INT
DECLARE @commit BIT
DECLARE @dynSQL VARCHAR(MAX)
DECLARE @userInsertProc VARCHAR(MAX) = ''
DECLARE @userUpdateProc VARCHAR(MAX) = ''
DECLARE @crtAccessColumn VARCHAR(50)
DECLARE @accessColumns VARCHAR(MAX) = ''
DECLARE @newAdminEmail VARCHAR(MAX) = ''
DECLARE @warehouseIdList VARCHAR(MAX) = ''

--REPLACE_WITH_VARIABLES


DECLARE @copyUserEmail VARCHAR(50) = @crtUserEmail

IF @superAdmin = 1
BEGIN
	--Get the list of the available 'access'-like columns in App_User, as we'll need them to set the access flag
	DECLARE c_accessColumns CURSOR FOR
		SELECT COLUMN_NAME
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_NAME = 'app_User' 
			AND COLUMN_NAME like '%access%'

	OPEN c_accessColumns
	FETCH NEXT FROM c_accessColumns INTO @crtAccessColumn

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @accessColumns = @accessColumns + ', ' + @crtAccessColumn + ' = 1'
		FETCH NEXT FROM c_accessColumns INTO @crtAccessColumn
	END
	CLOSE c_accessColumns
	DEALLOCATE c_accessColumns
END

--Cycle through companies set in the DB and create a user for each one
IF NOT EXISTS (SELECT *
				FROM dbo.app_Company
				WHERE IsAirlineCompany = 1
				AND IsActive = 1)
	BEGIN
		SET @msg = 'There is no suitable Airline company enabled in the database ' + DB_NAME() + ', cannot proceed.'
		RAISERROR (@msg, 16, -1)
		GOTO ABORT_NOW2
	END

DECLARE c_company CURSOR FOR
	SELECT CompanyId, Company, SiteId
	FROM dbo.app_Company
	WHERE IsAirlineCompany = 1
	AND IsActive = 1

OPEN c_company
FETCH NEXT FROM c_company INTO @crtCompanyId, @crtCompanyName, @crtCompanySiteId

WHILE @@FETCH_STATUS = 0
BEGIN
	IF @superAdmin = 1
		BEGIN
			--Get the latest SuperAdmin role created for this company, if more exist
			SET @crtRoleId = (SELECT
								MAX(UserId) 
								FROM dbo.app_User
								WHERE IsRole = 1
								AND IsSuperAdmin = 1
								AND CompanyId = @crtCompanyId)
			IF @crtRoleId IS NULL
				BEGIN
					SET @msg = 'No SuperAdmin role exists on the database ' + DB_NAME() + ' for company ' + @crtCompanyName + '.'
					RAISERROR (@msg, 16, -1)
					GOTO ABORT_NOW
				END

			--Ensure the admin role has the access columns flags set
			PRINT 'Ensure access is properly set for the selected admin role'
			SET @dynSQL = 'UPDATE dbo.app_User
				SET IsSuperAdmin = 1,
				CanEditRoles = 1,
				OMSUserRoleId = 1,
				OMSCanSeePrices = 1,
				PreorderEnabled = 1--ACCESS_ADDONS
				WHERE UserId = ' + (CAST(@crtRoleId as VARCHAR(10)))
			SET @dynSQL = REPLACE(@dynSQL,'--ACCESS_ADDONS',@accessColumns)
			-- PRINT @dynSQL
			EXEC (@dynSQL)

			PRINT 'Current role id: ' + (CAST(@crtRoleId as VARCHAR(10)))
		END
	ELSE
		BEGIN
			--Get the latest role created with this name, if more exist
			SET @crtRoleId = (SELECT
								MAX(UserId) 
								FROM dbo.app_User
								WHERE IsRole = 1
								AND DisplayName = @crtRole
								AND CompanyId = @crtCompanyId)
		END
	IF @crtRoleId IS NULL
		BEGIN
			SET @msg = 'The role "' + @crtRole + '" does not exist on the database ' + DB_NAME() + ' for company ' + @crtCompanyName + '.'
			RAISERROR (@msg, 16, -1)
			GOTO ABORT_NOW
		END

	--Ensure the role has access to warehouses
	PRINT 'Granting warehouse access to role ' + (CAST(@crtRoleId as VARCHAR(10)))
	SET @warehouseIdList = ''
	SELECT @warehouseIdList = 
		CASE WHEN @warehouseIdList = ''
			THEN CAST (WarehouseId as VARCHAR(10))
		ELSE @warehouseIdList + COALESCE(',' + CAST(WarehouseId as VARCHAR(10)), '')
		END
	FROM dbo.loc_Warehouse 
	WHERE SiteId = @crtCompanySiteId
	EXEC dbo.appUserUpdateUserWarehouses @UserId = @crtRoleId, @warehouseids = @warehouseIdList


	--Add the company Id to the email address
	SET @crtUserEmail = REPLACE(@copyUserEmail, 'RiM', 'RiM-' + (CAST(@crtCompanyId as VARCHAR(10))))
	SET @crtUserId = (SELECT
    					UserId
						FROM dbo.app_User
						WHERE IsRole = 0
						  AND Email = @crtUserEmail)
	IF @crtUserId IS NULL
		BEGIN
			--Create new user
			SET @userInsertProc = 'EXEC dbo.appUserInsert
				@Email = ''' + @crtUserEmail + ''',
				@DisplayName = ''' + @crtUserDisplayName + ''',
				@Password = ''' + @crtUserPassword + ''',
				@CompanyId = ' + (CAST(@crtCompanyId as VARCHAR(10))) + ',
				@IsRole = 0,
				@CanEditRoles = 0,
				@RoleId = ' + (CAST(@crtRoleId as VARCHAR(10))) + ',
				@LastModifiedUserId = 1,
				@PasswordPolicyId = NULL,
				@keepUsernameClear = 1,
				@BlockvPOSSales = 0'
			PRINT 'Creating login ' + @crtUserEmail + ' for company ' + replace(@crtCompanyName,'''','') + '-' + (CAST(@crtCompanyId as VARCHAR(10))) + '---'
			EXEC (@userInsertProc)
            SET @crtUserId = (SELECT 
            					UserId
                                FROM dbo.app_User
                                WHERE IsRole = 0
                                  AND Email = @crtUserEmail)
		END
	ELSE
		BEGIN
			--Update existing user
			SET @userUpdateProc = 'EXEC dbo.appUserUpdate
				@Email = ''' + @crtUserEmail + ''',
				@UserId = ' + (CAST(@crtUserId as VARCHAR(10))) + ',
				@DisplayName = ''' + @crtUserDisplayName + ''',
				@CompanyId = ' + (CAST(@crtCompanyId as VARCHAR(10))) + ',
                @IsInactive = 0,
				@IsRole = 0,
				@CanEditRoles = 0,
				@IsSuperAdmin = ' + (CAST(@superAdmin as VARCHAR(10))) + ',
				@RoleId = ' + (CAST(@crtRoleId as VARCHAR(10))) + ',
				@LastModifiedUserId = 1,
				@PasswordPolicyId = NULL,
				@keepUsernameClear = 1,
				@BlockvPOSSales = 0'
			PRINT 'Updating login ' + @crtUserEmail + ' for company ' + replace(@crtCompanyName,'''','') + '-' + (CAST(@crtCompanyId as VARCHAR(10))) + '---'
			EXEC (@userUpdateProc)
			--Reset user password
			--appUserChangePassword was introduced in R2019.11 - need to keep this until all clients move past this release
			IF EXISTS (
					SELECT name
					FROM sys.procedures 
					WHERE name = 'appUserChangePassword'
				)
				BEGIN
				EXEC dbo.appUserChangePassword
					@UserId = @crtUserId,
					@PasswordHash = @crtUserPassword,
					@LoggedInUserId = @crtUserId
				END
			ELSE
				BEGIN
				EXEC dbo.appUserResetPassword 
					@LoggedInUserId = @crtUserId,
					@UserId = @crtUserId,
					@PasswordHash = @crtUserPassword
				END
		END
	-- Force password change on next login
	UPDATE dbo.app_User
		SET ForcePasswordChange = 1
        WHERE Email = @crtUserEmail

	-- Make sure the user is Active
    IF EXISTS (SELECT 1 
				FROM sysobjects so 
				INNER JOIN syscolumns sc ON sc.id=so.id
				WHERE so.name = 'app_User' 
					AND sc.name = 'ActivationDate')
        BEGIN
		SET @dynSQL = 'UPDATE dbo.app_User
			SET ActivationDate = ''' + convert(varchar, getdate(), 112) + '''
            WHERE Email = ''' + @crtUserEmail + ''''
		EXEC (@dynSQL)
        END
	SET @dynSQL = 'UPDATE dbo.app_User
		SET LastLoggedIn = ''' + convert(varchar, getdate(), 112) + '''
		WHERE Email = ''' + @crtUserEmail + ''''
		print(@dynSQL)
	EXEC (@dynSQL)
    IF NOT EXISTS (SELECT UserId
    				FROM dbo.app_User
    				WHERE Email = @crtUserEmail)
		BEGIN
			SET @msg = 'Could not create the user ' + @crtUserEmail + ' on the database ' + DB_NAME() + '.'
			RAISERROR (@msg, 16, -1)
			GOTO ABORT_NOW
		END

	--Ensure the user has access to warehouses
	PRINT 'Granting warehouse access to user '+ @crtUserEmail
	SET @warehouseIdList = ''
	SELECT @warehouseIdList = 
		CASE WHEN @warehouseIdList = ''
			THEN CAST (WarehouseId as VARCHAR(10))
		ELSE @warehouseIdList + COALESCE(',' + CAST(WarehouseId as VARCHAR(10)), '')
		END
	FROM dbo.loc_Warehouse 
	WHERE SiteId = @crtCompanySiteId
	EXEC dbo.appUserUpdateUserWarehouses @UserId = @crtUserId, @warehouseids = @warehouseIdList

	--Set SuperAdmin and ensure the user has the access columns flags set
	IF @superAdmin = 1
		BEGIN
			PRINT 'Ensure access is properly set for the user with admin role'
			SET @dynSQL = 'UPDATE dbo.app_User
				SET IsSuperAdmin = 1,
				CanEditRoles = 1,
				OMSUserRoleId = 1,
				OMSCanSeePrices = 1,
				PreorderEnabled = 1--ACCESS_ADDONS
				WHERE UserId = ' + (CAST(@crtUserId as VARCHAR(10)))
			SET @dynSQL = REPLACE(@dynSQL,'--ACCESS_ADDONS',@accessColumns)
			EXEC (@dynSQL)
		END

	FETCH NEXT FROM c_company INTO @crtCompanyId, @crtCompanyName, @crtCompanySiteId
END

ABORT_NOW:

CLOSE c_company
DEALLOCATE c_company

ABORT_NOW2:

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