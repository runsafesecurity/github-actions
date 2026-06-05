@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0dotnet-cli-interceptor.ps1" %*
