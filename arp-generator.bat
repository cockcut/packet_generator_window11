@echo off
title IPv4 ARP Generator

:: Check administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell.exe -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ========================================
echo        IPv4 ARP Generator Started
echo ========================================
echo.

set /p TARGET_IP=Target IP: 
set /p INTERVAL=Interval (ms): 

echo.
echo Target IP : %TARGET_IP%
echo Interval  : %INTERVAL% ms
echo.
echo Press Ctrl+C to stop.
echo.

set "TARGET_IP=%TARGET_IP%"
set "INTERVAL=%INTERVAL%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { $ip=$env:TARGET_IP; $interval=[int]$env:INTERVAL; while($true) { arp.exe -d $ip 2>$null; ping.exe -4 -n 1 -w 1 $ip | Out-Null; Write-Host ('ARP -> ' + $ip); Start-Sleep -Milliseconds $interval } }"

pause
