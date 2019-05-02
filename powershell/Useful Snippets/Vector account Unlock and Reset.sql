-- UNLOCK AN ACCOUNT

update app_User 
set LockoutEndDate = '2017-10-12 13:50:08.087', PasswordAttempts = 0
where UserId = (Select UserId from app_User where email = 'admin@i-soms.com')


-- RESET A PASSWORD TO Ireland1

UPDATE dbo.app_User
SET Password='3K3NoU0s_rlKKUouKHeCos05sl9Trxhk9Yhb07C7'
WHERE Email='admin@i-soms.com';