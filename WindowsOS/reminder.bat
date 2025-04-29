@echo off
title Screen Break Scheduler
setlocal

rem ── Configuration ───────────────────────────────────────────────────────────
set "TASKNAME=Screen Break Reminder"
set "SCRIPT=%~dp0screen_break.vbs"
rem ─────────────────────────────────────────────────────────────────────────────

:menu
cls
echo ==========================================
echo   SCREEN BREAK SCHEDULER by @SamirJunaid
echo ==========================================
echo 1) Run reminder
echo 2) Stop reminder
echo 3) Exit
echo.
set /p choice=Select an option [1-3]:

if "%choice%"=="1" goto :run
if "%choice%"=="2" goto :stop
if "%choice%"=="3" exit /b

echo Invalid choice. Please enter 1, 2, or 3.
pause
goto :menu

:run
cls
set /p interval=Enter reminder interval in minutes: 

rem — basic numeric check
for /f "delims=0123456789" %%A in ("%interval%") do (
  echo ERROR: “%interval%” is not a valid number.
  pause
  goto :menu
)

rem — Build the VBScript that shows a Windows MessageBox
> "%SCRIPT%" echo Dim args: Set args = WScript.Arguments
>> "%SCRIPT%" echo Dim mins: mins = args.Item(0)
>> "%SCRIPT%" echo Dim txt: txt = "You have spent " ^& mins ^& " minutes in front of the screen, take a rest"
>> "%SCRIPT%" echo MsgBox txt, vbOKOnly + vbInformation, "Break time"

rem — Remove old task if it exists
schtasks /Delete /F /TN "%TASKNAME%" >nul 2>&1

rem — Register new task to run our VBScript every %interval% minutes, interactively
schtasks /Create /F ^
  /SC MINUTE /MO %interval% ^
  /TN "%TASKNAME%" ^
  /TR "wscript.exe \"%SCRIPT%\" %interval%" ^
  /RL HIGHEST /IT >nul 2>&1

if errorlevel 1 (
  echo Failed to create the scheduled task. Make sure you run this script AS ADMINISTRATOR.
) else (
  echo Task “%TASKNAME%” created—every %interval% minutes you’ll get a Windows MessageBox.
)
pause
goto :menu

:stop
cls
rem — Delete the scheduled task
schtasks /Delete /F /TN "%TASKNAME%" >nul 2>&1

if errorlevel 1 (
  echo No existing task “%TASKNAME%” was found.
) else (
  echo Task “%TASKNAME%” has been removed.
)

rem — Clean up VBScript if you like (optional)
if exist "%SCRIPT%" del "%SCRIPT%" >nul 2>&1

pause
goto :menu
