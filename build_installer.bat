@echo off
echo ========================================================
echo   Kamdraaa Game Build ^& Installer
echo ========================================================

set GODOT_EXE=C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe
set ISCC_EXE=C:\Users\ilya\AppData\Local\Programs\Inno Setup 6\ISCC.exe
set PROJECT_DIR=e:\kamdraaa-game
set DIST_DIR=%PROJECT_DIR%\build\dist
set INSTALLER_DIR=%PROJECT_DIR%\installer

if not exist "%GODOT_EXE%" (
    echo [ERROR] Godot executable not found: %GODOT_EXE%
    exit /b 1
)

if not exist "%ISCC_EXE%" (
    echo [ERROR] Inno Setup compiler not found: %ISCC_EXE%
    exit /b 1
)

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
if not exist "%INSTALLER_DIR%" mkdir "%INSTALLER_DIR%"

echo [1/4] Exporting game package (PCK)...
"%GODOT_EXE%" --headless --path "%PROJECT_DIR%" --export-pack "Windows Desktop" "%DIST_DIR%\Kamdraaa.pck"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Godot export failed! Exit code: %ERRORLEVEL%
    exit /b 1
)

echo [2/4] Copying game binary...
copy /y "%GODOT_EXE%" "%DIST_DIR%\Kamdraaa.exe" >nul
if exist "%PROJECT_DIR%\build\app_icon.ico" (
    copy /y "%PROJECT_DIR%\build\app_icon.ico" "%DIST_DIR%\app_icon.ico" >nul
)

echo [3/4] Compiling Inno Setup installer...
"%ISCC_EXE%" "%PROJECT_DIR%\installer.iss"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Inno Setup compilation failed! Exit code: %ERRORLEVEL%
    exit /b 1
)

echo [4/4] Creating portable ZIP archive...
powershell -NoProfile -Command "Compress-Archive -Path '%DIST_DIR%\*' -DestinationPath '%INSTALLER_DIR%\Kamdraaa_v0.2.0_Portable.zip' -Force"

echo ========================================================
echo   BUILD COMPLETE! Ready to distribute:
echo   1. Installer: %INSTALLER_DIR%\Kamdraaa_Setup_v0.2.0.exe
echo   2. Portable:  %INSTALLER_DIR%\Kamdraaa_v0.2.0_Portable.zip
echo ========================================================
