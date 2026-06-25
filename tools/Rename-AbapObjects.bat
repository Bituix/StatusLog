@echo off
powershell.exe -NoExit -ExecutionPolicy Bypass -File "%~dp0Rename-AbapObjects.ps1" %*
