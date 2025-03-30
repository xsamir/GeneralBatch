@echo off
color 0A
setlocal EnableDelayedExpansion
set "filename=network_report.csv"
set "scriptfile=%temp%\netscan_script.ps1"
set "fullpath=%cd%\%filename%"
cls
echo ==========================================
echo Network Speed Checker - by @SamirJunaid
echo ==========================================
echo.
echo Select an option:
echo [1] Simple results
echo [2] Generate Comprehensive CSV report
echo.
set /p option=Enter your choice (1 or 2): 
if "%option%"=="1" goto Simple
if "%option%"=="2" goto CSV
echo Invalid option, exiting...
pause
exit /b
:Simple
cls
echo ==========================================
echo Simple Network Adapter Speed Results
echo ==========================================
powershell -Command "Get-NetAdapter | Select Name, InterfaceDescription, LinkSpeed, Status | Format-Table -AutoSize"
echo.
pause
exit /b
:CSV
cls
echo Generating comprehensive CSV report, please wait...
if exist "%scriptfile%" del "%scriptfile%"
echo # Create an array for the CSV data > "%scriptfile%"
echo $csvData = @() >> "%scriptfile%"
echo. >> "%scriptfile%"
echo # Get network adapters >> "%scriptfile%"
echo $adapters = Get-NetAdapter ^| Select-Object Name, InterfaceDescription, MacAddress, LinkSpeed, Status >> "%scriptfile%"
echo $csvData += $adapters ^| ConvertTo-Csv -NoTypeInformation >> "%scriptfile%"
echo $csvData += """" >> "%scriptfile%"
echo. >> "%scriptfile%"
echo # Check internet connectivity >> "%scriptfile%"
echo $internetStatus = New-Object PSObject >> "%scriptfile%"
echo $internetStatus ^| Add-Member -MemberType NoteProperty -Name "Parameter" -Value "Internet Status" >> "%scriptfile%"
echo if (Test-Connection google.com -Count 1 -Quiet) { >> "%scriptfile%"
echo     $internetStatus ^| Add-Member -MemberType NoteProperty -Name "Value" -Value "Connected" >> "%scriptfile%"
echo } else { >> "%scriptfile%"
echo     $internetStatus ^| Add-Member -MemberType NoteProperty -Name "Value" -Value "Disconnected" >> "%scriptfile%"
echo } >> "%scriptfile%"
echo $csvData += $internetStatus ^| ConvertTo-Csv -NoTypeInformation ^| Select-Object -Skip 1 >> "%scriptfile%"
echo. >> "%scriptfile%"
echo # Get default gateway (router IP) >> "%scriptfile%"
echo $gateway = New-Object PSObject >> "%scriptfile%"
echo $gateway ^| Add-Member -MemberType NoteProperty -Name "Parameter" -Value "Router IP (Default Gateway)" >> "%scriptfile%"
echo $defaultGateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" ^| Select-Object -ExpandProperty NextHop -First 1) >> "%scriptfile%"
echo if (-not $defaultGateway) { $defaultGateway = "Not Found" } >> "%scriptfile%"
echo $gateway ^| Add-Member -MemberType NoteProperty -Name "Value" -Value $defaultGateway >> "%scriptfile%"
echo $csvData += $gateway ^| ConvertTo-Csv -NoTypeInformation ^| Select-Object -Skip 1 >> "%scriptfile%"
echo $csvData += """" >> "%scriptfile%"
echo. >> "%scriptfile%"
echo # Get open TCP ports >> "%scriptfile%"
echo $portsObj = New-Object PSObject >> "%scriptfile%"
echo $portsObj ^| Add-Member -MemberType NoteProperty -Name "Parameter" -Value "Open Ports (TCP)" >> "%scriptfile%"
echo $ports = Get-NetTCPConnection -State Listen ^| Select-Object -ExpandProperty LocalPort -Unique ^| Sort-Object >> "%scriptfile%"
echo if ($ports) { >> "%scriptfile%"
echo     $portsObj ^| Add-Member -MemberType NoteProperty -Name "Value" -Value ($ports -join "; ") >> "%scriptfile%"
echo } else { >> "%scriptfile%"
echo     $portsObj ^| Add-Member -MemberType NoteProperty -Name "Value" -Value "No open ports found" >> "%scriptfile%"
echo } >> "%scriptfile%"
echo $csvData += $portsObj ^| ConvertTo-Csv -NoTypeInformation ^| Select-Object -Skip 1 >> "%scriptfile%"
echo $csvData += """" >> "%scriptfile%"
echo. >> "%scriptfile%"
echo # Get ARP entries (devices on LAN) >> "%scriptfile%"
echo $csvData += "Devices on LAN (ARP entries)," >> "%scriptfile%"
echo $arp = arp -a ^| Select-String "\d+\.\d+\.\d+\.\d+" >> "%scriptfile%"
echo if ($arp) { >> "%scriptfile%"
echo     foreach ($line in $arp) { >> "%scriptfile%"
echo         $arpEntry = New-Object PSObject >> "%scriptfile%"
echo         $arpEntry ^| Add-Member -MemberType NoteProperty -Name "IP Address" -Value (($line.Line -split "\s+")[1]) >> "%scriptfile%"
echo         $arpEntry ^| Add-Member -MemberType NoteProperty -Name "MAC Address" -Value (($line.Line -split "\s+")[2]) >> "%scriptfile%"
echo         $arpEntry ^| Add-Member -MemberType NoteProperty -Name "Type" -Value (($line.Line -split "\s+")[3]) >> "%scriptfile%"
echo         $csvData += $arpEntry ^| ConvertTo-Csv -NoTypeInformation ^| Select-Object -Skip 1 >> "%scriptfile%"
echo     } >> "%scriptfile%"
echo } else { >> "%scriptfile%"
echo     $csvData += "No devices found," >> "%scriptfile%"
echo } >> "%scriptfile%"
echo. >> "%scriptfile%"
echo # Save the CSV file >> "%scriptfile%"
echo $csvPath = "%fullpath%" >> "%scriptfile%"
echo $csvPath = $csvPath.Replace("\", "\\") >> "%scriptfile%"
echo $csvData ^| Out-File -FilePath $csvPath -Encoding utf8 >> "%scriptfile%"
powershell -ExecutionPolicy Bypass -File "%scriptfile%"
if exist "%fullpath%" (
    echo.
    echo Report successfully saved to: %fullpath%
    echo.
    echo Note: To get proper column widths, open the CSV file in Excel or
    echo another spreadsheet program and use "Format Columns" feature.
) else (
    echo.
    echo Failed to create the report. Please check permissions.
)
del "%scriptfile%" >nul 2>&1
pause
exit /b
