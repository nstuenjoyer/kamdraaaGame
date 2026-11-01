param(
    [string]$GodotExe = 'C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe',
    [switch]$PackedGame
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$previousAppData = $env:APPDATA
$previousUi = $env:KAMDRAAA_UI_CAPTURE_DIR
$previousAnimation = $env:KAMDRAAA_ANIMATION_CAPTURE_DIR
try {
    $env:KAMDRAAA_UI_CAPTURE_DIR = Join-Path $projectRoot 'docs/review/images/ui'
    $env:KAMDRAAA_ANIMATION_CAPTURE_DIR = Join-Path $projectRoot 'docs/review/images/animation'
    foreach ($scriptName in @('check_animation', 'check_ui_layout')) {
        $reviewData = Join-Path $projectRoot ('.godot/chapter-check-presentation-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $reviewData -Force | Out-Null
        $env:APPDATA = $reviewData
        $log = Join-Path $reviewData ($scriptName + '.log')
        $arguments = @('--path', $projectRoot, '--resolution', '1280x720', '--rendering-method', 'gl_compatibility', '--log-file', $log, '--script', ('res://docs/review/' + $scriptName + '.gd'))
        if ($PackedGame) {
            $GodotExe = Join-Path $projectRoot 'build/dist/Kamdraaa.exe'
            $arguments[$arguments.IndexOf('--script') + 1] = Join-Path $projectRoot ('docs/review/' + $scriptName + '.gd')
            $arguments += @('--main-pack', (Join-Path $projectRoot 'build/dist/Kamdraaa.pck'))
        }
        $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit(90000)) {
            Stop-Process -Id $process.Id
            throw "Presentation check exceeded 90 seconds: $scriptName"
        }
        $report = Get-Content -LiteralPath $log -Encoding UTF8
        $report | Write-Output
        if ($process.ExitCode -ne 0 -or $report -match 'SCRIPT ERROR|^ERROR:|^FAIL ') { throw "Presentation checks failed: $log" }
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:KAMDRAAA_UI_CAPTURE_DIR = $previousUi
    $env:KAMDRAAA_ANIMATION_CAPTURE_DIR = $previousAnimation
}
