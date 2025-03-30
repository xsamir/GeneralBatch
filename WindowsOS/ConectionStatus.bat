@echo off
color 0A
echo ==========================================
echo Network Speed Checker - by @SamirJunaid
echo ==========================================
echo.
echo Select an option:
echo [1] Simple results
echo [2] Generate CSV report
echo.
set /p option=Enter your choice (1 or 2): 

if "%option%"=="1" goto Simple
if "%option%"=="2" goto CSV

echo Invalid option, exiting...
pause
exit

:Simple
cls
echo ==========================================
echo Simple Network Adapter Speed Results
echo ==========================================
powershell -command "Get-NetAdapter | Select-Object Name, LinkSpeed, Status | Format-Table -AutoSize"
echo.
pause
exit

:CSV
cls
set filename=network_report.csv
powershell -command "Get-NetAdapter | Select-Object Name, LinkSpeed, Status | Export-Csv -Path '%filename%' -NoTypeInformation"
echo Adapter report generated as %filename%
echo.

powershell -command "$ping = Test-Connection -ComputerName samirjunaid.sa -Count 1 -Quiet; $status = if ($ping) {'Connected'} else {'Disconnected'}; \"Internet_Status,$status\" | Out-File -FilePath '%filename%' -Append"

echo Internet connection status appended to %filename%
echo.
echo Report generation completed.
pause
exit
