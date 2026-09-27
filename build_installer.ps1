[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Kamdraaa Game Build & Installer" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$godotExe = "C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe"
$isccExe = "C:\Users\ilya\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
$projectDir = "e:\kamdraaa-game"
$distDir = "$projectDir\build\dist"
$installerDir = "$projectDir\installer"

if (-not (Test-Path $godotExe)) {
    Write-Host "[ERROR] Godot executable not found: $godotExe" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $isccExe)) {
    Write-Host "[ERROR] Inno Setup compiler not found: $isccExe" -ForegroundColor Red
    exit 1
}

Write-Host "`n[1/4] Preparing directories..." -ForegroundColor Yellow
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir -Force | Out-Null }
if (-not (Test-Path $installerDir)) { New-Item -ItemType Directory -Path $installerDir -Force | Out-Null }

Write-Host "[2/4] Exporting game package (PCK)..." -ForegroundColor Yellow
$pckOut = "$distDir\Kamdraaa.pck"
$godotArgs = "--headless --path `"$projectDir`" --export-pack `"Windows Desktop`" `"$pckOut`""
$proc = Start-Process -FilePath $godotExe -ArgumentList $godotArgs -Wait -NoNewWindow -PassThru
if ($proc.ExitCode -ne 0) {
    Write-Host "[ERROR] Godot export failed with code $($proc.ExitCode)!" -ForegroundColor Red
    exit 1
}

Write-Host "[3/4] Copying game binary and assets..." -ForegroundColor Yellow
Copy-Item $godotExe "$distDir\Kamdraaa.exe" -Force
if (Test-Path "$projectDir\build\app_icon.ico") {
    Copy-Item "$projectDir\build\app_icon.ico" "$distDir\app_icon.ico" -Force
}

Write-Host "[4/4] Compiling Inno Setup installer..." -ForegroundColor Yellow
$procIscc = Start-Process -FilePath $isccExe -ArgumentList "`"$projectDir\installer.iss`"" -Wait -NoNewWindow -PassThru
if ($procIscc.ExitCode -ne 0) {
    Write-Host "[ERROR] Inno Setup compilation failed with code $($procIscc.ExitCode)!" -ForegroundColor Red
    exit 1
}

Write-Host "[5/5] Creating portable ZIP archive..." -ForegroundColor Yellow
Compress-Archive -Path "$distDir\*" -DestinationPath "$installerDir\Kamdraaa_v0.2.0_Portable.zip" -Force

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "  BUILD SUCCESS! Files ready for distribution:" -ForegroundColor Green
Write-Host "  1. Installer: $installerDir\Kamdraaa_Setup_v0.2.0.exe" -ForegroundColor Green
Write-Host "  2. Portable:  $installerDir\Kamdraaa_v0.2.0_Portable.zip" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
