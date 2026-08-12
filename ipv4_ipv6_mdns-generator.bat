@echo off
title IPv4 IPv6 mDNS Generator

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ipv4_ipv6_mdns-generator.ps1"

pause
