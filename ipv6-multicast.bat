@echo off
chcp 65001 >nul
title IPv6 MLDv2 Multicast Test

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 관리자 권한이 필요합니다.
    echo 관리자 권한으로 다시 실행합니다.
    powershell.exe -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ipv6-multicast.ps1"

pause
