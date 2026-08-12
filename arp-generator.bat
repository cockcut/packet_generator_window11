@echo off
title Raw Ethernet ARP Generator

net session >nul 2>&1

if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell.exe -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0arp-generator.ps1"

pause