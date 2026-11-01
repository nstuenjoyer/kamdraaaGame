param(
    [string]$GodotExe = 'C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe',
    [switch]$PackedGame,
    [ValidateSet('gl_compatibility', 'forward_plus')][string]$Renderer = 'gl_compatibility'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$reviewData = Join-Path $projectRoot ('.godot/chapter-check-ui-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $reviewData -Force | Out-Null
$previousAppData = $env:APPDATA
$previousOutput = $env:KAMDRAAA_UI_CAPTURE_DIR
try {
    $env:APPDATA = $reviewData
    $env:KAMDRAAA_UI_CAPTURE_DIR = Join-Path $projectRoot 'docs/review/images/ui'
    $log = Join-Path $reviewData 'ui.log'
    $arguments = @('--path', $projectRoot, '--resolution', '1280x720', '--rendering-method', $Renderer, '--log-file', $log, '--script', 'res://docs/review/capture_ui.gd')
    if ($PackedGame) {
        $GodotExe = Join-Path $projectRoot 'build/dist/Kamdraaa.exe'
        $arguments[$arguments.IndexOf('--script') + 1] = Join-Path $projectRoot 'docs/review/capture_ui.gd'
        $arguments += @('--main-pack', (Join-Path $projectRoot 'build/dist/Kamdraaa.pck'))
    }
    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(180000)) {
        Stop-Process -Id $process.Id
        throw 'UI checks exceeded 180 seconds'
    }
    $report = Get-Content -LiteralPath $log -Encoding UTF8
    $report | Write-Output
    if ($process.ExitCode -ne 0 -or $report -match 'SCRIPT ERROR|^ERROR:|^FAIL ') {
        throw "UI checks failed. Log: $log"
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:KAMDRAAA_UI_CAPTURE_DIR = $previousOutput
}
