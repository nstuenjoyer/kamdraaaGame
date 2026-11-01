param(
    [string]$GodotExe = 'C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe',
    [switch]$PackedGame
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$previousAppData = $env:APPDATA
try {
    $reviewData = Join-Path $projectRoot ('.godot/chapter-check-recorded-audio-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $reviewData -Force | Out-Null
    $env:APPDATA = $reviewData
    $log = Join-Path $reviewData 'recorded-audio.log'
    $arguments = @('--path', $projectRoot, '--resolution', '1280x720', '--rendering-method', 'gl_compatibility', '--log-file', $log, '--script', 'res://docs/review/check_recorded_audio.gd')
    if ($PackedGame) {
        $GodotExe = Join-Path $projectRoot 'build/dist/Kamdraaa.exe'
        $arguments[$arguments.IndexOf('--script') + 1] = Join-Path $projectRoot 'docs/review/check_recorded_audio.gd'
        $arguments += @('--main-pack', (Join-Path $projectRoot 'build/dist/Kamdraaa.pck'))
    }
    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) { Stop-Process -Id $process.Id; throw 'Recorded-audio check exceeded 60 seconds' }
    $report = Get-Content -LiteralPath $log -Encoding UTF8
    $report | Write-Output
    if ($process.ExitCode -ne 0 -or $report -match 'SCRIPT ERROR|^ERROR:|^FAIL ') { throw "Audio check failed: $log" }
} finally { $env:APPDATA = $previousAppData }
