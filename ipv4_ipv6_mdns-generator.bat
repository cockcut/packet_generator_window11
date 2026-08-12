@echo off
title IPv4 IPv6 mDNS Generator

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0mdns-generator.ps1"

pause