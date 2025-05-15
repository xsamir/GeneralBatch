@echo off
title Windows Login & Microsoft-Account Toggle

:MENU
cls
echo =======================================
echo    Windows Login & Microsoft-Account  
echo               Toggle  
echo =======================================
echo 1. Remove login screen (auto-login)
echo 2. Restore login screen
echo 3. Disable Microsoft-account sign-in (local only)
echo 4. Enable Microsoft-account sign-in
echo 5. Exit
echo.
set /p choice=Choose an option [1-5]:

if "%choice%"=="1" goto REMOVE_LOGIN
if "%choice%"=="2" goto RESTORE_LOGIN
if "%choice%"=="3" goto DISABLE_MSA
if "%choice%"=="4" goto ENABLE_MSA
if "%choice%"=="5" exit /b
echo Invalid choice.
pause
goto MENU

:REMOVE_LOGIN
echo.
echo –– Enable auto-login ––
set /p UserName=  Enter account name to auto-login: 
set /p Password=  Enter password for %UserName%: 

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d "%UserName%" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d "%Password%" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon  /t REG_SZ /d "1"        /f

echo.
echo Auto-login enabled. Reboot to apply.
pause
goto MENU

:RESTORE_LOGIN
echo.
echo –– Disable auto-login ––
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon  /f

echo.
echo Auto-login disabled. Reboot to apply.
pause
goto MENU

:DISABLE_MSA
echo.
echo –– Block Microsoft-account sign-in ––
rem 0=Not configured, 1=Admins only, 2=Users only, 3=Block all
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v NoConnectedUser /t REG_DWORD /d 3 /f

echo.
echo Microsoft-account sign-in is now blocked.
pause
goto MENU

:ENABLE_MSA
echo.
echo –– Allow Microsoft-account sign-in ––
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v NoConnectedUser /f

echo.
echo Microsoft-account sign-in is now allowed.
pause
goto MENU