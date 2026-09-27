@echo off
echo ========================================================
echo   Indexing Kamdraaa Codebase
echo ========================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0index_codebase.ps1"

pause
