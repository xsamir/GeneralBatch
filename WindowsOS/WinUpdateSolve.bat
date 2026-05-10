@echo off
:: Windows Update Repair Script
:: Purpose: Resets Windows Update components by clearing cache folders.

echo ============================================================
echo   Windows Update Component Reset Tool
echo ============================================================
echo.

:: Check for Administrative Privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Administrative privileges detected.
) else (
    echo [ERROR] Please run this script as Administrator!
    pause
    exit /b 1
)

echo.
echo [1/3] Stopping Windows Update services...
net stop wuauserv /y
net stop cryptSvc /y
net stop bits /y
net stop msiserver /y

echo.
echo [2/3] Renaming SoftwareDistribution and Catroot2 folders...
:: Deleting old backups if they exist to avoid conflict
if exist "C:\Windows\SoftwareDistribution.old" rmdir /s /q "C:\Windows\SoftwareDistribution.old"
if exist "C:\Windows\System32\catroot2.old" rmdir /s /q "C:\Windows\System32\catroot2.old"

ren "C:\Windows\SoftwareDistribution" SoftwareDistribution.old
ren "C:\Windows\System32\catroot2" catroot2.old

echo.
echo [3/3] Restarting Windows Update services...
net start wuauserv
net start cryptSvc
net start bits
net start msiserver

echo.
echo ============================================================
echo   Process Complete. Please check Windows Update now.
echo ============================================================
pause
