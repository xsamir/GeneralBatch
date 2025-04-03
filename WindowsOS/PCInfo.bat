@echo off
setlocal EnableDelayedExpansion
title System Hardware Information - DO NOT CLOSE
color 1F
echo ===============================================
echo BASIC HARDWARE INFORMATION - by @SamirJunaid
echo ===============================================
echo.
echo Creating log file...
set "logfile=%USERPROFILE%\Desktop\basic_hardware_info.txt"
echo Windows Hardware Information > "%logfile%"
echo Generated: %DATE% %TIME% >> "%logfile%"
echo. >> "%logfile%"
echo --- COMPUTER INFORMATION ---
echo --- COMPUTER INFORMATION --- >> "%logfile%"
systeminfo | findstr /B /C:"Host Name" /C:"OS Name" /C:"OS Version" /C:"System Manufacturer" /C:"System Model" /C:"System Type" /C:"Total Physical Memory"
systeminfo | findstr /B /C:"Host Name" /C:"OS Name" /C:"OS Version" /C:"System Manufacturer" /C:"System Model" /C:"System Type" /C:"Total Physical Memory" >> "%logfile%"
echo.
echo. >> "%logfile%"
echo --- CPU INFORMATION ---
echo --- CPU INFORMATION --- >> "%logfile%"
echo CPU Model:
wmic cpu get name
wmic cpu get name >> "%logfile%"
echo.
echo CPU Details:
wmic cpu get NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
wmic cpu get NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed >> "%logfile%"
echo.
echo. >> "%logfile%"
echo --- RAM INFORMATION ---
echo --- RAM INFORMATION --- >> "%logfile%"
echo Total RAM:
for /f "tokens=2 delims=:" %%a in ('systeminfo ^| findstr /C:"Total Physical Memory"') do (
    for /f "tokens=1" %%b in ("%%a") do echo %%b GB
    for /f "tokens=1" %%b in ("%%a") do echo %%b GB >> "%logfile%"
)
echo.
echo RAM Details (if available):
echo Capacity (GB)    Speed    Location 
echo Capacity (GB)    Speed    Location >> "%logfile%"
powershell -command "$memoryChips = Get-WmiObject -Class 'Win32_PhysicalMemory'; foreach($chip in $memoryChips) { $capacityGB = [math]::Round($chip.Capacity / 1GB, 2); Write-Host ($capacityGB.ToString() + ' GB    ' + $chip.Speed + ' MHz    ' + $chip.DeviceLocator) }"
powershell -command "$logPath = '%logfile%'; $memoryChips = Get-WmiObject -Class 'Win32_PhysicalMemory'; foreach($chip in $memoryChips) { $capacityGB = [math]::Round($chip.Capacity / 1GB, 2); Add-Content -Path $logPath -Value ($capacityGB.ToString() + ' GB    ' + $chip.Speed + ' MHz    ' + $chip.DeviceLocator) }"
echo.
echo. >> "%logfile%"
echo --- GPU INFORMATION ---
echo --- GPU INFORMATION --- >> "%logfile%"
echo Video Controller Details:
echo Name    VRAM (GB)    Driver Version
echo Name    VRAM (GB)    Driver Version >> "%logfile%"
powershell -command "$gpus = Get-WmiObject -Class 'Win32_VideoController'; foreach($gpu in $gpus) { if($gpu.AdapterRAM -ne $null) { $vramGB = [math]::Round($gpu.AdapterRAM / 1GB, 2); Write-Host $gpu.Name '    ' $vramGB ' GB    ' $gpu.DriverVersion } else { Write-Host $gpu.Name '    N/A    ' $gpu.DriverVersion }}"
powershell -command "$logPath = '%logfile%'; $gpus = Get-WmiObject -Class 'Win32_VideoController'; foreach($gpu in $gpus) { if($gpu.AdapterRAM -ne $null) { $vramGB = [math]::Round($gpu.AdapterRAM / 1GB, 2); Add-Content -Path $logPath -Value ($gpu.Name + '    ' + $vramGB + ' GB    ' + $gpu.DriverVersion) } else { Add-Content -Path $logPath -Value ($gpu.Name + '    N/A    ' + $gpu.DriverVersion) }}"
echo.
echo. >> "%logfile%"
echo --- DISK INFORMATION ---
echo --- DISK INFORMATION --- >> "%logfile%"
echo Physical Disks:
echo Model    Size (GB)    Type
echo Model    Size (GB)    Type >> "%logfile%"
powershell -command "Get-WmiObject Win32_DiskDrive | ForEach-Object { $size = [math]::Round($_.Size / 1GB, 2); $model = $_.Model; $diskType = if($model -match 'SSD') {'SSD'} elseif($_.MediaType -match 'Fixed') {'HDD'} else {$_.MediaType}; Write-Host $model '   ' $size 'GB   ' $diskType }"
powershell -command "$logPath = '%logfile%'; Get-WmiObject Win32_DiskDrive | ForEach-Object { $size = [math]::Round($_.Size / 1GB, 2); $model = $_.Model; $diskType = if($model -match 'SSD') {'SSD'} elseif($_.MediaType -match 'Fixed') {'HDD'} else {$_.MediaType}; Add-Content -Path $logPath -Value ($model + '   ' + $size + ' GB   ' + $diskType) }"
echo.
echo Logical Drives:
echo Drive    Label    Size (GB)    Free Space (GB)    Type
echo Drive    Label    Size (GB)    Free Space (GB)    Type >> "%logfile%"
powershell -command "$physicalDisks = @{}; Get-WmiObject Win32_DiskDrive | ForEach-Object { $diskIndex = $_.Index; $diskType = if($_.Model -match 'SSD') {'SSD'} elseif($_.MediaType -match 'Fixed') {'HDD'} else {$_.MediaType}; $physicalDisks[$diskIndex] = $diskType }; Get-WmiObject Win32_LogicalDisk | ForEach-Object { $size = [math]::Round($_.Size / 1GB, 2); $free = [math]::Round($_.FreeSpace / 1GB, 2); $partitions = Get-WmiObject -Query \"ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($_.DeviceID)'} WHERE ResultClass=Win32_DiskPartition\"; $driveType = 'Unknown'; foreach($partition in $partitions) { $drives = Get-WmiObject -Query \"ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE ResultClass=Win32_DiskDrive\"; foreach($drive in $drives) { $driveType = $physicalDisks[$drive.Index] } }; Write-Host $_.DeviceID '   ' $_.VolumeName '   ' $size 'GB   ' $free 'GB   ' $driveType }"
powershell -command "$logPath = '%logfile%'; $physicalDisks = @{}; Get-WmiObject Win32_DiskDrive | ForEach-Object { $diskIndex = $_.Index; $diskType = if($_.Model -match 'SSD') {'SSD'} elseif($_.MediaType -match 'Fixed') {'HDD'} else {$_.MediaType}; $physicalDisks[$diskIndex] = $diskType }; Get-WmiObject Win32_LogicalDisk | ForEach-Object { $size = [math]::Round($_.Size / 1GB, 2); $free = [math]::Round($_.FreeSpace / 1GB, 2); $partitions = Get-WmiObject -Query \"ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($_.DeviceID)'} WHERE ResultClass=Win32_DiskPartition\"; $driveType = 'Unknown'; foreach($partition in $partitions) { $drives = Get-WmiObject -Query \"ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE ResultClass=Win32_DiskDrive\"; foreach($drive in $drives) { $driveType = $physicalDisks[$drive.Index] } }; Add-Content -Path $logPath -Value ($_.DeviceID + '   ' + $_.VolumeName + '   ' + $size + ' GB   ' + $free + ' GB   ' + $driveType) }"
echo.
echo. >> "%logfile%"
echo --- MOTHERBOARD INFORMATION ---
echo --- MOTHERBOARD INFORMATION --- >> "%logfile%"
echo Motherboard Details:
wmic baseboard get product, manufacturer, serialnumber
wmic baseboard get product, manufacturer, serialnumber >> "%logfile%"
echo.
echo BIOS Details:
wmic bios get name, version, serialnumber
wmic bios get name, version, serialnumber >> "%logfile%"
echo.
echo. >> "%logfile%"
echo --- NETWORK INFORMATION ---
echo --- NETWORK INFORMATION --- >> "%logfile%"
echo Network Adapters:
wmic nic where NetEnabled=true get Name, MACAddress
wmic nic where NetEnabled=true get Name, MACAddress >> "%logfile%"
echo.
echo IP Configuration:
ipconfig | findstr /C:"IPv4 Address" /C:"Subnet Mask" /C:"Default Gateway"
ipconfig | findstr /C:"IPv4 Address" /C:"Subnet Mask" /C:"Default Gateway" >> "%logfile%"
echo.
echo. >> "%logfile%"
echo --- HARDWARE SUMMARY ---
echo --- HARDWARE SUMMARY --- >> "%logfile%"
echo Data collection complete!
echo All details have been saved to: %logfile%
echo.
echo ===============================================
echo Type EXIT and press ENTER when you want to close
echo Or press CTRL+C and select "No" to end the batch job
echo ===============================================
echo.
:WAITLOOP
set INPUT=
set /p INPUT="Command (type EXIT to close): "
if /i "%INPUT%"=="exit" goto ENDSCRIPT
if /i "%INPUT%"=="quit" goto ENDSCRIPT
goto WAITLOOP
:ENDSCRIPT
echo Closing in 5 seconds...
timeout /t 5
echo Press any key to close the window...
pause > nul
