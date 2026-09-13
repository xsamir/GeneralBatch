@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Windows Security Health - Automatic Repair V2
color 0B

rem ================================================================
rem Windows Security Health Automatic Repair V2
rem Pure ASCII / CRLF batch file - no UTF-8 BOM.
rem Main target:
rem   SecurityHealthSSO.dll / SecurityHealthHost.exe corruption
rem   Bad Image / 0xC000012F
rem
rem Primary fix:
rem   Reinstall the official Microsoft Windows Security platform
rem   KB5007651, then repair/re-register SecHealthUI.
rem
rem DISM/SFC are ONLY a final fallback.
rem ================================================================

rem ---------- Self elevate ----------
fltmc >nul 2>&1
if errorlevel 1 (
    echo Requesting Administrator permission...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

rem ---------- Paths ----------
set "WORK=%ProgramData%\SecurityHealthRepair"
set "LOG=%WORK%\SecurityHealthRepair.log"
set "SETUP=%WORK%\SecurityHealthSetup.exe"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "TARGETDIR="
set "BADBACKUP="
set "NEED_REBOOT=0"

if not exist "%WORK%" md "%WORK%" >nul 2>&1

> "%LOG%" echo ================================================================
>>"%LOG%" echo Windows Security Health Automatic Repair V2
>>"%LOG%" echo Started: %date% %time%
>>"%LOG%" echo Computer: %COMPUTERNAME%
>>"%LOG%" echo User: %USERNAME%
>>"%LOG%" echo Script: %~f0
>>"%LOG%" echo ================================================================

call :Banner "WINDOWS SECURITY HEALTH - AUTOMATIC REPAIR V2"
call :Log "Repair started."

rem ---------- Get Windows build without relying on PowerShell ----------
set "BUILD="
for /f "tokens=3" %%B in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul ^| findstr.exe /i "CurrentBuildNumber"') do set "BUILD=%%B"
if not defined BUILD (
    for /f "tokens=3" %%B in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul ^| findstr.exe /i "CurrentBuild"') do set "BUILD=%%B"
)
if not defined BUILD set "BUILD=0"

set "ARCH=%PROCESSOR_ARCHITECTURE%"
if defined PROCESSOR_ARCHITEW6432 set "ARCH=%PROCESSOR_ARCHITEW6432%"

echo Windows build : %BUILD%
echo Architecture  : %ARCH%
echo Log file      : %LOG%
echo.
call :Log "Windows build: %BUILD%"
call :Log "Architecture: %ARCH%"

if %BUILD% LSS 22000 (
    call :Log "This is not Windows 11 build 22000 or later."
    goto :GENERIC_REPAIR
)

rem ---------- Microsoft Update Catalog package ----------
rem Latest KB5007651 in Microsoft Update Catalog at time this V2 was built:
rem Version 10.0.29628.1000, dated 2026-07-30.
if /I "%ARCH%"=="ARM64" (
    set "MSURL=https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/defu/2026/07/securityhealthsetup_660338b236d35588cb1e6c4db2021ed679653c01.exe"
) else (
    set "MSURL=https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/defu/2026/07/securityhealthsetup_21fb0c228dbf70d24ecb707b0ee9f97c2786961f.exe"
)

call :Banner "1/8 - INITIAL DIAGNOSTIC"
call :GetLatestSecurityHealthDir
if defined TARGETDIR (
    echo SecurityHealth platform:
    echo   %TARGETDIR%
    call :Log "Detected platform directory: %TARGETDIR%"
) else (
    echo No versioned SecurityHealth platform directory was found.
    call :Log "No versioned platform directory found."
)

call :HealthCheck
if not errorlevel 1 (
    echo Core SecurityHealth binaries currently pass PE/signature checks.
    call :Log "Initial HealthCheck: PASS."
) else (
    echo Core SecurityHealth binaries are missing, malformed, or invalid.
    call :Log "Initial HealthCheck: FAIL."
)

call :Banner "2/8 - OBTAINING OFFICIAL MICROSOFT PACKAGE"
if exist "%SETUP%" del /f /q "%SETUP%" >nul 2>&1

echo Downloading KB5007651 from Microsoft Update Catalog...
call :Log "Primary download URL: %MSURL%"

"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%MSURL%' -OutFile '%SETUP%'" >>"%LOG%" 2>&1

if not exist "%SETUP%" (
    call :Log "Invoke-WebRequest failed; trying curl.exe."
    where.exe curl.exe >nul 2>&1
    if not errorlevel 1 (
        curl.exe -L --fail --retry 3 --connect-timeout 20 -o "%SETUP%" "%MSURL%" >>"%LOG%" 2>&1
    )
)

rem If Internet download failed, try Microsoft's already cached/local setup.
if not exist "%SETUP%" (
    call :Log "Online download failed; checking local SecurityHealthSetup.exe."
    if exist "%SystemRoot%\System32\SecurityHealth\SecurityHealthSetup.exe" (
        copy /y "%SystemRoot%\System32\SecurityHealth\SecurityHealthSetup.exe" "%SETUP%" >>"%LOG%" 2>&1
    )
)

if not exist "%SETUP%" (
    echo Direct package download was not available.
    echo Trying Windows Update API for the Windows Security platform...
    call :Log "No setup EXE available. Trying Windows Update API."
    call :InstallViaWindowsUpdate
    goto :AFTER_FIRST_INSTALL
)

echo Verifying the installer digital signature...
call :VerifyMicrosoftFile "%SETUP%"
if errorlevel 1 (
    echo ERROR: Installer is not a valid Microsoft-signed executable.
    call :Log "Installer signature verification FAILED. File will not run."
    del /f /q "%SETUP%" >nul 2>&1
    call :InstallViaWindowsUpdate
    goto :AFTER_FIRST_INSTALL
)

for /f "usebackq delims=" %%H in (`"%PS%" -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath '%SETUP%').Hash"`) do set "SETUPHASH=%%H"
echo Microsoft signature: VALID
echo SHA256: %SETUPHASH%
call :Log "Installer Microsoft signature: VALID."
call :Log "Installer SHA256: %SETUPHASH%"

call :Banner "3/8 - TARGETED WINDOWS SECURITY PLATFORM REINSTALL"
call :StopSecurityHealth

echo Installing the Microsoft Windows Security platform...
call :RunSecuritySetup
timeout /t 12 /nobreak >nul

:AFTER_FIRST_INSTALL
call :RepairSecHealthUI
call :StartSecurityServices
call :GetLatestSecurityHealthDir
call :HealthCheck
if not errorlevel 1 (
    call :Log "First targeted reinstall passed final binary checks."
    goto :FINAL_VERIFY
)

call :Banner "4/8 - REMOVING ONLY INVALID SECURITYHEALTH BINARIES"
call :Log "First targeted repair did not pass. Starting invalid-file replacement."
call :StopSecurityHealth
call :GetLatestSecurityHealthDir

if not defined TARGETDIR (
    call :Log "No platform folder after first repair."
    goto :HARD_PLATFORM_RESET
)

call :RemoveIfInvalid "%TARGETDIR%\SecurityHealthSSO.dll"
call :RemoveIfInvalid "%TARGETDIR%\SecurityHealthHost.exe"

if exist "%SETUP%" (
    call :VerifyMicrosoftFile "%SETUP%"
    if not errorlevel 1 (
        call :RunSecuritySetup
        timeout /t 12 /nobreak >nul
    )
) else (
    call :InstallViaWindowsUpdate
)

call :RepairSecHealthUI
call :StartSecurityServices
call :GetLatestSecurityHealthDir
call :HealthCheck
if not errorlevel 1 (
    call :Log "Invalid-file replacement passed."
    goto :FINAL_VERIFY
)

:HARD_PLATFORM_RESET
call :Banner "5/8 - HARD RESET OF THE BROKEN PLATFORM FOLDER"
call :Log "Starting hard platform folder reset."
call :StopSecurityHealth
call :GetLatestSecurityHealthDir

if defined TARGETDIR call :BackupBrokenPlatformFolder

if defined TARGETDIR if exist "%TARGETDIR%" (
    call :Log "Broken folder could not be renamed because files are still locked."
    set "NEED_REBOOT=1"
) else (
    if exist "%SETUP%" (
        call :VerifyMicrosoftFile "%SETUP%"
        if not errorlevel 1 (
            call :RunSecuritySetup
            timeout /t 15 /nobreak >nul
        )
    ) else (
        call :InstallViaWindowsUpdate
    )

    call :RepairSecHealthUI
    call :StartSecurityServices
    call :GetLatestSecurityHealthDir
    call :HealthCheck
    if not errorlevel 1 (
        call :Log "Hard platform reset passed."
        goto :FINAL_VERIFY
    )
)

call :Banner "6/8 - FINAL FALLBACK: WINDOWS COMPONENT STORE"
echo The targeted SecurityHealth repair still did not verify.
echo Running DISM and SFC only as the LAST fallback...
call :Log "Starting DISM RestoreHealth fallback."

DISM.exe /Online /Cleanup-Image /RestoreHealth >>"%LOG%" 2>&1
call :Log "DISM completed."

sfc.exe /scannow >>"%LOG%" 2>&1
call :Log "SFC completed."

rem Re-run SecurityHealth package AFTER component-store repair.
if exist "%SETUP%" (
    call :VerifyMicrosoftFile "%SETUP%"
    if not errorlevel 1 (
        call :StopSecurityHealth
        call :RunSecuritySetup
        timeout /t 15 /nobreak >nul
    )
) else (
    call :InstallViaWindowsUpdate
)

call :RepairSecHealthUI
call :StartSecurityServices
call :GetLatestSecurityHealthDir
call :HealthCheck
if errorlevel 1 (
    set "NEED_REBOOT=1"
    goto :FINAL_FAIL
)

goto :FINAL_VERIFY


:GENERIC_REPAIR
call :Banner "GENERIC WINDOWS SECURITY REPAIR"
call :StopSecurityHealth
call :RepairSecHealthUI
call :StartSecurityServices
DISM.exe /Online /Cleanup-Image /RestoreHealth >>"%LOG%" 2>&1
sfc.exe /scannow >>"%LOG%" 2>&1
call :RepairSecHealthUI
call :StartSecurityServices
goto :FINAL_VERIFY


:FINAL_VERIFY
call :Banner "7/8 - FINAL VERIFICATION"
call :GetLatestSecurityHealthDir

if %BUILD% GEQ 22000 (
    call :HealthCheck
    if errorlevel 1 (
        set "NEED_REBOOT=1"
        goto :FINAL_FAIL
    )
)

call :CheckSecHealthUIPackage
if errorlevel 1 (
    call :Log "SecHealthUI package check failed."
    goto :FINAL_FAIL
)

sc.exe query SecurityHealthService >>"%LOG%" 2>&1

"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "try { Get-MpComputerStatus | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,AntivirusSignatureVersion | Format-List | Out-String | Write-Output } catch { Write-Output ('Get-MpComputerStatus: '+$_.Exception.Message) }" >>"%LOG%" 2>&1

rem Update Defender signatures only if Defender cmdlet is available.
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "if(Get-Command Update-MpSignature -ErrorAction SilentlyContinue){try{Update-MpSignature -ErrorAction Stop | Out-Null}catch{}}; exit 0" >>"%LOG%" 2>&1

call :Banner "8/8 - FINISHED"
echo.
echo ================================================================
echo   WINDOWS SECURITY HEALTH REPAIR: SUCCESS
echo ================================================================
echo.
echo The core SecurityHealth files passed:
echo   - PE executable/header validation
echo   - Microsoft Authenticode signature validation
echo   - Windows Security UI package validation
echo.
echo Log:
echo   %LOG%
echo.
call :Log "FINAL RESULT: SUCCESS."
call :Log "Finished: %date% %time%"
echo Press any key to close this window.
pause >nul
exit /b 0


:FINAL_FAIL
call :Banner "8/8 - FINISHED WITH AN UNRESOLVED CONDITION"
echo.
echo ================================================================
echo   WINDOWS SECURITY HEALTH REPAIR: NOT FULLY VERIFIED
echo ================================================================
echo.
if "%NEED_REBOOT%"=="1" (
    echo A SecurityHealth file/folder is still locked or Windows has a
    echo pending replacement. Restart Windows, then run this SAME V2
    echo batch once more. No manual file copying is required.
    echo.
) else (
    echo The repair completed all safe automatic stages but final
    echo validation still failed.
    echo.
)
echo Log:
echo   %LOG%
echo.
call :Log "FINAL RESULT: NOT FULLY VERIFIED. NEED_REBOOT=%NEED_REBOOT%"
call :Log "Finished: %date% %time%"
echo Press any key to close this window.
pause >nul
exit /b 1


rem ================================================================
rem SUBROUTINES
rem ================================================================

:Banner
echo.
echo ================================================================
echo %~1
echo ================================================================
echo.
exit /b 0

:Log
>>"%LOG%" echo [%date% %time%] %~1
exit /b 0

:GetLatestSecurityHealthDir
set "TARGETDIR="
for /f "usebackq delims=" %%D in (`"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$r=Join-Path $env:SystemRoot 'System32\SecurityHealth'; if(Test-Path -LiteralPath $r){$d=Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '^\d+\.\d+\.\d+\.\d+-\d+$'} | Sort-Object @{Expression={try{[version](($_.Name -split '-')[0])}catch{[version]'0.0'}};Descending=$true},LastWriteTime -Descending | Select-Object -First 1; if($d){$d.FullName}}"`) do set "TARGETDIR=%%D"
exit /b 0

:HealthCheck
rem 0 = healthy
rem 2 = no platform folder
rem 3 = missing required file
rem 4 = malformed PE / Bad Image candidate
rem 5 = invalid/non-Microsoft signature
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "$r=Join-Path $env:SystemRoot 'System32\SecurityHealth';" ^
 "$d=Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '^\d+\.\d+\.\d+\.\d+-\d+$'} | Sort-Object @{Expression={try{[version](($_.Name -split '-')[0])}catch{[version]'0.0'}};Descending=$true},LastWriteTime -Descending | Select-Object -First 1;" ^
 "if(-not $d){Write-Output 'HealthCheck: platform folder missing'; exit 2};" ^
 "$files=@('SecurityHealthSSO.dll','SecurityHealthHost.exe');" ^
 "foreach($n in $files){" ^
 " $p=Join-Path $d.FullName $n;" ^
 " if(-not(Test-Path -LiteralPath $p)){Write-Output ('HealthCheck: missing '+$p); exit 3};" ^
 " try{$fs=[IO.File]::Open($p,'Open','Read','ReadWrite'); $b1=$fs.ReadByte(); $b2=$fs.ReadByte(); $fs.Close()}catch{Write-Output ('HealthCheck: unreadable '+$p); exit 4};" ^
 " if($b1 -ne 77 -or $b2 -ne 90){Write-Output ('HealthCheck: invalid MZ header '+$p); exit 4};" ^
 " $s=Get-AuthenticodeSignature -LiteralPath $p;" ^
 " if($s.Status -ne 'Valid' -or -not $s.SignerCertificate -or $s.SignerCertificate.Subject -notmatch 'Microsoft'){Write-Output ('HealthCheck: invalid Microsoft signature '+$p+' / '+$s.Status); exit 5}" ^
 "};" ^
 "Write-Output ('HealthCheck: PASS '+$d.FullName); exit 0" >>"%LOG%" 2>&1
exit /b %errorlevel%

:VerifyMicrosoftFile
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "$p='%~1'; if(-not(Test-Path -LiteralPath $p)){exit 2};" ^
 "try{$fs=[IO.File]::Open($p,'Open','Read','ReadWrite');$a=$fs.ReadByte();$b=$fs.ReadByte();$fs.Close()}catch{exit 3};" ^
 "if($a -ne 77 -or $b -ne 90){exit 4};" ^
 "$s=Get-AuthenticodeSignature -LiteralPath $p;" ^
 "if($s.Status -eq 'Valid' -and $s.SignerCertificate -and $s.SignerCertificate.Subject -match 'Microsoft'){exit 0}else{Write-Output ('Signature failure: '+$s.Status+' '+$s.StatusMessage);exit 5}" >>"%LOG%" 2>&1
exit /b %errorlevel%

:StopSecurityHealth
call :Log "Stopping SecurityHealth UI processes/services where Windows permits it."
taskkill.exe /f /im SecurityHealthSystray.exe >>"%LOG%" 2>&1
taskkill.exe /f /im SecurityHealthHost.exe >>"%LOG%" 2>&1
taskkill.exe /f /im SecHealthUI.exe >>"%LOG%" 2>&1
sc.exe stop SecurityHealthService >>"%LOG%" 2>&1
timeout /t 2 /nobreak >nul
exit /b 0

:StartSecurityServices
call :Log "Starting Windows Security related services."
sc.exe start SecurityHealthService >>"%LOG%" 2>&1
sc.exe start wscsvc >>"%LOG%" 2>&1
exit /b 0

:RunSecuritySetup
if not exist "%SETUP%" exit /b 2
call :VerifyMicrosoftFile "%SETUP%"
if errorlevel 1 exit /b 3
call :Log "Executing Microsoft SecurityHealthSetup."
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "$p=Start-Process -FilePath '%SETUP%' -PassThru -Wait -ErrorAction Stop; if($null -ne $p.ExitCode){exit $p.ExitCode}else{exit 0}" >>"%LOG%" 2>&1
exit /b %errorlevel%

:RepairSecHealthUI
call :Log "Repairing/re-registering Microsoft.SecHealthUI."
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='SilentlyContinue';" ^
 "$pkgs=Get-AppxPackage -AllUsers Microsoft.SecHealthUI;" ^
 "foreach($p in $pkgs){$m=Join-Path $p.InstallLocation 'AppXManifest.xml';if(Test-Path -LiteralPath $m){Add-AppxPackage -DisableDevelopmentMode -Register $m -ForceApplicationShutdown -ErrorAction SilentlyContinue}};" ^
 "$u=Get-AppxPackage Microsoft.SecHealthUI -ErrorAction SilentlyContinue;" ^
 "if($u -and (Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue)){try{$u | Reset-AppxPackage -ErrorAction SilentlyContinue}catch{}};" ^
 "exit 0" >>"%LOG%" 2>&1

rem If package is absent, install an embedded APPX/MSIX bundle if present.
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "if(Get-AppxPackage -AllUsers Microsoft.SecHealthUI -ErrorAction SilentlyContinue){exit 0};" ^
 "$r=Join-Path $env:SystemRoot 'System32\SecurityHealth';" ^
 "$d=Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '^\d+\.\d+\.\d+\.\d+-\d+$'} | Sort-Object LastWriteTime -Descending | Select-Object -First 1;" ^
 "if(-not $d){exit 0};" ^
 "$f=Get-ChildItem -LiteralPath $d.FullName -File -ErrorAction SilentlyContinue | Where-Object {$_.Extension -in '.msixbundle','.appxbundle','.msix','.appx'} | Sort-Object Length -Descending | Select-Object -First 1;" ^
 "if($f){try{Add-AppxPackage -Path $f.FullName -ForceApplicationShutdown -ErrorAction Stop}catch{Write-Output $_.Exception.Message}};exit 0" >>"%LOG%" 2>&1
exit /b 0

:CheckSecHealthUIPackage
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "$p=Get-AppxPackage -AllUsers Microsoft.SecHealthUI -ErrorAction SilentlyContinue | Select-Object -First 1;" ^
 "if(-not $p){Write-Output 'SecHealthUI check: package missing';exit 2};" ^
 "$m=Join-Path $p.InstallLocation 'AppXManifest.xml';" ^
 "if(-not(Test-Path -LiteralPath $m)){Write-Output 'SecHealthUI check: manifest missing';exit 3};" ^
 "Write-Output ('SecHealthUI check: PASS version '+$p.Version+' at '+$p.InstallLocation);exit 0" >>"%LOG%" 2>&1
exit /b %errorlevel%

:RemoveIfInvalid
set "CHECKFILE=%~1"
if not exist "%CHECKFILE%" (
    call :Log "Required file is already missing; setup should recreate: %CHECKFILE%"
    exit /b 0
)

call :VerifyMicrosoftFile "%CHECKFILE%"
if not errorlevel 1 (
    call :Log "File is valid and will not be touched: %CHECKFILE%"
    exit /b 0
)

call :Log "Invalid file detected: %CHECKFILE%"
set "FILEBACKUP=%CHECKFILE%.CORRUPT_%RANDOM%_%RANDOM%"

move /y "%CHECKFILE%" "%FILEBACKUP%" >>"%LOG%" 2>&1
if not exist "%CHECKFILE%" (
    call :Log "Invalid file backed up to: %FILEBACKUP%"
    exit /b 0
)

takeown.exe /f "%CHECKFILE%" /a >>"%LOG%" 2>&1
icacls.exe "%CHECKFILE%" /grant *S-1-5-32-544:F /c >>"%LOG%" 2>&1
move /y "%CHECKFILE%" "%FILEBACKUP%" >>"%LOG%" 2>&1

if exist "%CHECKFILE%" (
    call :Log "Could not move locked invalid file: %CHECKFILE%"
    set "NEED_REBOOT=1"
    exit /b 1
)

call :Log "Invalid file backed up after ACL repair: %FILEBACKUP%"
exit /b 0

:BackupBrokenPlatformFolder
for %%Z in ("%TARGETDIR%") do set "BADBACKUP=%%~dpZ%%~nxZ.BAD_%RANDOM%_%RANDOM%"
echo Backing up broken platform folder...
echo   %TARGETDIR%
call :Log "Attempting folder rename to: %BADBACKUP%"

move /y "%TARGETDIR%" "%BADBACKUP%" >>"%LOG%" 2>&1
if not exist "%TARGETDIR%" exit /b 0

call :Log "Normal folder rename failed. Taking ownership of the broken folder only."
takeown.exe /f "%TARGETDIR%" /a /r /d y >>"%LOG%" 2>&1
icacls.exe "%TARGETDIR%" /grant *S-1-5-32-544:F /t /c >>"%LOG%" 2>&1
move /y "%TARGETDIR%" "%BADBACKUP%" >>"%LOG%" 2>&1
if exist "%TARGETDIR%" exit /b 1
exit /b 0

:InstallViaWindowsUpdate
call :Log "Trying Windows Update API for KB5007651 / Windows Security platform."
sc.exe start bits >>"%LOG%" 2>&1
sc.exe start wuauserv >>"%LOG%" 2>&1

"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';" ^
 "$s=New-Object -ComObject Microsoft.Update.Session;" ^
 "$searcher=$s.CreateUpdateSearcher();" ^
 "$r=$searcher.Search('IsInstalled=0 and IsHidden=0 and Type=''Software''');" ^
 "$c=New-Object -ComObject Microsoft.Update.UpdateColl;" ^
 "foreach($u in $r.Updates){if($u.Title -match 'KB5007651|Windows Security platform'){if(-not $u.EulaAccepted){$u.AcceptEula()};[void]$c.Add($u)}};" ^
 "if($c.Count -eq 0){Write-Output 'Windows Update API: no pending matching update found.';exit 2};" ^
 "$d=$s.CreateUpdateDownloader();$d.Updates=$c;$dr=$d.Download();Write-Output ('Windows Update download result: '+$dr.ResultCode);" ^
 "$i=$s.CreateUpdateInstaller();$i.Updates=$c;$ir=$i.Install();Write-Output ('Windows Update install result: '+$ir.ResultCode+' reboot='+$ir.RebootRequired);" ^
 "if($ir.RebootRequired){exit 3010}; if($ir.ResultCode -eq 2 -or $ir.ResultCode -eq 3){exit 0}else{exit 4}" >>"%LOG%" 2>&1

rem 3010 modulo 256 can appear as 194 through cmd.exe.
if "%errorlevel%"=="194" set "NEED_REBOOT=1"
exit /b 0
