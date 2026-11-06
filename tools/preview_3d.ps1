param([string]$GodotExe = 'C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
# Dedicated prototype profile: preview cannot overwrite a player's 2D saves/settings.
$previewData = Join-Path $projectRoot '.godot/3d-preview-profile'
New-Item -ItemType Directory -Path $previewData -Force | Out-Null
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = $previewData
    # This is the interactive game window explicitly requested by invoking preview.
    Start-Process -FilePath $GodotExe -ArgumentList @('--path', $projectRoot, '--resolution', '1280x720', 'res://scenes/chapter_1_3d/apartment.tscn') -WindowStyle Normal
} finally { $env:APPDATA = $previousAppData }
