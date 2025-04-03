@echo off
setlocal EnableDelayedExpansion
title Windows System Info - Hardware Details - DO NOT CLOSE

:: Set colors for better visibility
color 1F
echo ===============================================
echo DETAILED HARDWARE INFORMATION - DO NOT CLOSE WINDOW!
echo ===============================================
echo.

:: Create log file
echo Creating log file...
set "logfile=%USERPROFILE%\Desktop\hardware_info.txt"
echo Windows Hardware Information > "%logfile%"
echo Generated: %DATE% %TIME% >> "%logfile%"
echo. >> "%logfile%"

:: Basic OS info
echo --- OPERATING SYSTEM INFORMATION ---
echo --- OPERATING SYSTEM INFORMATION --- >> "%logfile%"
for /f "tokens=*" %%a in ('systeminfo ^| findstr /B /C:"OS Name" /C:"OS Version" /C:"Original Install Date"') do (
    echo %%a
    echo %%a >> "%logfile%"
)
echo.
echo. >> "%logfile%"

:: Computer model information
echo --- COMPUTER MODEL INFORMATION ---
echo --- COMPUTER MODEL INFORMATION --- >> "%logfile%"
for /f "tokens=2 delims==" %%a in ('wmic computersystem get manufacturer /value 2^>nul') do (
    set "manufacturer=%%a"
    echo Manufacturer: !manufacturer!
    echo Manufacturer: !manufacturer! >> "%logfile%"
)

for /f "tokens=2 delims==" %%a in ('wmic computersystem get model /value 2^>nul') do (
    set "model=%%a"
    echo Model: !model!
    echo Model: !model! >> "%logfile%"
)
echo.
echo. >> "%logfile%"

:: CPU Information
echo --- CPU INFORMATION ---
echo --- CPU INFORMATION --- >> "%logfile%"
for /f "tokens=2 delims==" %%a in ('wmic cpu get name /value 2^>nul') do (
    set "cpuname=%%a"
    echo CPU Model: !cpuname!
    echo CPU Model: !cpuname! >> "%logfile%"
)

for /f "tokens=2 delims==" %%a in ('wmic cpu get numberofcores /value 2^>nul') do (
    set "cpucores=%%a"
    echo CPU Cores: !cpucores!
    echo CPU Cores: !cpucores! >> "%logfile%"
)

for /f "tokens=2 delims==" %%a in ('wmic cpu get numberoflogicalprocessors /value 2^>nul') do (
    set "cputhreads=%%a"
    echo CPU Logical Processors: !cputhreads!
    echo CPU Logical Processors: !cputhreads! >> "%logfile%"
)

for /f "tokens=2 delims==" %%a in ('wmic cpu get maxclockspeed /value 2^>nul') do (
    set "cpuspeed=%%a"
    set /a "cpughz=cpuspeed/1000"
    set /a "cpumhz=cpuspeed%%1000"
    echo CPU Speed: !cpughz!.!cpumhz:~0,1! GHz
    echo CPU Speed: !cpughz!.!cpumhz:~0,1! GHz >> "%logfile%"
)
echo.
echo. >> "%logfile%"

:: RAM Information
echo --- RAM INFORMATION ---
echo --- RAM INFORMATION --- >> "%logfile%"

:: More reliable method for total RAM using PowerShell
echo Checking RAM details...
powershell -Command "$totalMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory; Write-Output ([math]::Round($totalMemory / 1GB, 0))" > "%TEMP%\totalmem.txt" 2>nul
set "memgb=0"
for /f "tokens=*" %%a in (%TEMP%\totalmem.txt) do (
    set "memgb=%%a"
)

if %memgb% GTR 0 (
    echo Total RAM: %memgb% GB
    echo Total RAM: %memgb% GB >> "%logfile%"
) else (
    :: Fallback to wmic method if PowerShell fails
    for /f "tokens=2 delims==" %%a in ('wmic computersystem get totalphysicalmemory /value 2^>nul') do (
        set "totalmem=%%a"
        set /a "memgb=totalmem/1073741824"
        echo Total RAM: !memgb! GB
        echo Total RAM: !memgb! GB >> "%logfile%"
    )
)

:: Get detailed RAM information including individual sticks
powershell -Command "Get-CimInstance -ClassName Win32_PhysicalMemory | Format-Table DeviceLocator, Manufacturer, Capacity, Speed, ConfiguredClockSpeed -AutoSize | Out-String -Width 120" > "%TEMP%\ramdetails.txt" 2>nul
type "%TEMP%\ramdetails.txt"
type "%TEMP%\ramdetails.txt" >> "%logfile%"

:: Get RAM slots used with better detection
powershell -Command "(Get-CimInstance -ClassName Win32_PhysicalMemory).Count" > "%TEMP%\ramslots.txt" 2>nul
set "ramslots="
for /f "tokens=*" %%a in (%TEMP%\ramslots.txt) do (
    set "ramslots=%%a"
)

if defined ramslots (
    echo RAM Slots Used: !ramslots!
    echo RAM Slots Used: !ramslots! >> "%logfile%"
) else (
    echo RAM Slots Used: Not available
    echo RAM Slots Used: Not available >> "%logfile%"
)
echo.
echo. >> "%logfile%"

:: GPU Information
echo --- GPU INFORMATION ---
echo --- GPU INFORMATION --- >> "%logfile%"
for /f "tokens=*" %%a in ('wmic path win32_VideoController get name 2^>nul') do (
    echo %%a | findstr /v /c:"Name" > nul
    if not errorlevel 1 (
        set "gpuname="
    ) else (
        echo GPU: %%a
        echo GPU: %%a >> "%logfile%"
    )
)

for /f "tokens=*" %%a in ('wmic path win32_VideoController get AdapterRAM 2^>nul') do (
    echo %%a | findstr /v /c:"AdapterRAM" > nul
    if not errorlevel 1 (
        set "gpuram="
    ) else (
        set /a "gpurammb=%%a/1048576"
        set /a "gpuramgb=gpurammb/1024"
        if !gpuramgb! GTR 0 (
            echo GPU RAM: !gpuramgb! GB
            echo GPU RAM: !gpuramgb! GB >> "%logfile%"
        ) else (
            echo GPU RAM: !gpurammb! MB
            echo GPU RAM: !gpurammb! MB >> "%logfile%"
        )
    )
)
echo.
echo. >> "%logfile%"

:: Storage Information
echo --- STORAGE INFORMATION ---
echo --- STORAGE INFORMATION --- >> "%logfile%"
echo Physical Disks:
echo Physical Disks: >> "%logfile%"

:: Get disk information using PowerShell for better type detection (with sizes in GB)
powershell -Command "$disks = Get-PhysicalDisk | Select-Object DeviceId, FriendlyName, MediaType, @{Name='Size(GB)';Expression={[math]::Round($_.Size / 1GB, 2)}}; $disks | Format-Table -AutoSize | Out-String -Width 150" > "%TEMP%\disks.txt" 2>nul
type "%TEMP%\disks.txt"
type "%TEMP%\disks.txt" >> "%logfile%"

echo.
echo Detailed Disk Information:
echo Detailed Disk Information: >> "%logfile%"
powershell -Command "Get-Disk | Select-Object Number, FriendlyName, @{Name='Size(GB)';Expression={[math]::Round($_.Size / 1GB, 2)}}, PartitionStyle, OperationalStatus, HealthStatus | Format-Table -AutoSize | Out-String -Width 150" > "%TEMP%\diskdetails.txt" 2>nul
type "%TEMP%\diskdetails.txt"
type "%TEMP%\diskdetails.txt" >> "%logfile%"

echo.
echo Disk Partitions:
echo Disk Partitions: >> "%logfile%"
powershell -Command "Get-Volume | Where-Object {$_.DriveLetter} | Select-Object DriveLetter, FileSystemLabel, FileSystem, @{Name='Size(GB)';Expression={[math]::Round($_.Size / 1GB, 2)}}, @{Name='FreeSpace(GB)';Expression={[math]::Round($_.SizeRemaining / 1GB, 2)}} | Format-Table -AutoSize | Out-String -Width 150" > "%TEMP%\volumes.txt" 2>nul
type "%TEMP%\volumes.txt"
type "%TEMP%\volumes.txt" >> "%logfile%"
echo.
echo. >> "%logfile%"

:: Motherboard Information
echo --- MOTHERBOARD INFORMATION ---
echo --- MOTHERBOARD INFORMATION --- >> "%logfile%"
for /f "tokens=2 delims==" %%a in ('wmic baseboard get product /value 2^>nul') do (
    set "mbmodel=%%a"
    echo Motherboard Model: !mbmodel!
    echo Motherboard Model: !mbmodel! >> "%logfile%"
)

for /f "tokens=2 delims==" %%a in ('wmic baseboard get manufacturer /value 2^>nul') do (
    set "mbmfg=%%a"
    echo Motherboard Manufacturer: !mbmfg!
    echo Motherboard Manufacturer: !mbmfg! >> "%logfile%"
)

for /f "tokens=2 delims==" %%a in ('wmic bios get serialnumber /value 2^>nul') do (
    set "sn=%%a"
    echo System Serial Number: !sn!
    echo System Serial Number: !sn! >> "%logfile%"
)
echo.
echo. >> "%logfile%"

:: Network Information
echo --- NETWORK INFORMATION ---
echo --- NETWORK INFORMATION --- >> "%logfile%"
for /f "tokens=2 delims==" %%a in ('wmic nic where "NetEnabled='True'" get MACAddress /value 2^>nul') do (
    set "mac=%%a"
    echo MAC Address: !mac!
    echo MAC Address: !mac! >> "%logfile%"
)

ipconfig | findstr /C:"IPv4 Address" /C:"Subnet Mask" /C:"Default Gateway"
ipconfig | findstr /C:"IPv4 Address" /C:"Subnet Mask" /C:"Default Gateway" >> "%logfile%"
echo.
echo. >> "%logfile%"

:: End of data collection
echo ===========================================
echo Data collection complete! 
echo Full details saved to: %logfile%
echo ===========================================
echo.

:: ==== PERMANENT WAITING SECTION ====
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
